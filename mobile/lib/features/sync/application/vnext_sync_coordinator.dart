import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math';

import '../../../content/domain/content_repository.dart';
import '../../../core/auth/anonymous_session_coordinator.dart';
import '../../../core/feature_flags/feature_flag_runtime.dart';
import '../../../core/feature_flags/feature_flags.dart';
import '../../../core/feature_flags/remote_feature_flag_resolver.dart';
import '../../../core/identity/local_identity_repository.dart';
import '../../../core/sync/event_envelope_v2.dart';
import '../../progress/domain/progress_repository.dart';
import '../../feed/application/remote_feed_refresh_service.dart';
import '../../season/application/season_bootstrap_activator.dart';
import '../domain/backend_models.dart';
import '../domain/event_sync_store_v2.dart';
import '../domain/reconciliation_models.dart';
import '../domain/remote_flag_cache.dart';
import 'projection_reconciler.dart';
import 'remote_content_refresh_service.dart';

abstract final class MayhemRemoteCapabilities {
  static final current = CapabilityRevisionSet(const {
    'backend_vnext': 1,
    'event_contract': 2,
    'remote_content': 1,
    'feed_batch': 1,
    'season_zero': 1,
    'boss_raid': 1,
    'artifact_ownership': 1,
    'social_proof': 1,
    'projection_reconciliation': 1,
    'reward_policy_dev_v1': 1,
    'difficulty_model_dev_v1': 1,
    'rank_config_dev_v1': 1,
    'momentum_policy_dev_v1': 1,
  });
}

enum SyncTrigger { coldStart, foreground, terminalResult, manual }

enum SyncRunStatus { disabled, synchronized, failed }

class SyncRunResult {
  const SyncRunResult({
    required this.status,
    required this.trigger,
    required this.uploadedCount,
    required this.retriedCount,
  });

  final SyncRunStatus status;
  final SyncTrigger trigger;
  final int uploadedCount;
  final int retriedCount;
}

abstract interface class RemoteSynchronizer {
  Future<SyncRunResult> synchronize({SyncTrigger trigger = SyncTrigger.manual});
}

class VNextSyncCoordinator implements RemoteSynchronizer {
  VNextSyncCoordinator({
    required this.remoteOperationsEnabled,
    required this.sessions,
    required this.backend,
    required this.identity,
    required this.identityBinding,
    required this.events,
    required this.progress,
    required this.reconciliationStore,
    required this.content,
    required this.contentRefresh,
    required this.flagCache,
    required this.featureFlags,
    required this.platform,
    required this.appVersion,
    required this.clock,
    this.locale = 'ru',
    this.environment = 'production',
    this.seasonActivation,
    this.remoteFeed,
    this.onProjectionCommitted,
    this.onSeasonStateCommitted,
    this.onRemoteFeedCommitted,
    CapabilityRevisionSet? capabilities,
    this.reconciler = const ProjectionReconciler(),
    Random? random,
  }) : capabilities = capabilities ?? MayhemRemoteCapabilities.current,
       _random = random ?? Random.secure();

  final bool remoteOperationsEnabled;
  final AnonymousSessionCoordinator sessions;
  final VNextBackendGateway backend;
  final LocalIdentityRepository identity;
  final RemoteIdentityBindingRepository identityBinding;
  final EventSyncStoreV2 events;
  final ProgressRepository progress;
  final ProjectionReconciliationStore reconciliationStore;
  final ContentRepository content;
  final RemoteContentRefresher contentRefresh;
  final RemoteFlagCache flagCache;
  final FeatureFlagRuntime featureFlags;
  final SeasonBootstrapActivation? seasonActivation;
  final RemoteFeedRefresher? remoteFeed;
  final Future<void> Function()? onProjectionCommitted;
  final Future<void> Function()? onSeasonStateCommitted;
  final Future<void> Function()? onRemoteFeedCommitted;
  final String platform;
  final String appVersion;
  final DateTime Function() clock;
  final String locale;
  final String environment;
  final CapabilityRevisionSet capabilities;
  final ProjectionReconciler reconciler;
  final Random _random;

  Future<SyncRunResult>? _inFlight;
  SyncTrigger? _queuedTrigger;

  void onColdStart() => _schedule(SyncTrigger.coldStart);

  void onForeground() => _schedule(SyncTrigger.foreground);

  void onTerminalResult() => _schedule(SyncTrigger.terminalResult);

  void _schedule(SyncTrigger trigger) {
    if (!remoteOperationsEnabled) return;
    if (_inFlight != null) {
      _queuedTrigger = trigger;
      return;
    }
    unawaited(synchronize(trigger: trigger));
  }

  @override
  Future<SyncRunResult> synchronize({
    SyncTrigger trigger = SyncTrigger.manual,
  }) {
    if (!remoteOperationsEnabled) {
      return Future.value(
        SyncRunResult(
          status: SyncRunStatus.disabled,
          trigger: trigger,
          uploadedCount: 0,
          retriedCount: 0,
        ),
      );
    }
    final running = _inFlight;
    if (running != null) return running;
    final next = _run(trigger);
    _inFlight = next;
    next.whenComplete(() {
      if (!identical(_inFlight, next)) return;
      _inFlight = null;
      final queued = _queuedTrigger;
      _queuedTrigger = null;
      if (queued != null) _schedule(queued);
    });
    return next;
  }

  Future<SyncRunResult> _run(SyncTrigger trigger) async {
    final now = clock().toUtc();
    var retryCandidates = <PendingEventV2>[];
    try {
      retryCandidates = await events.loadReadyPending(now: now);
      final session = await sessions.ensureSession(now);
      final localIdentity = await identity.loadIdentity();
      final registration = await backend.registerInstallation(
        installationId: localIdentity.installationId,
        localUserId: localIdentity.localUserId,
        platform: platform,
        appVersion: appVersion,
        capabilities: capabilities,
      );
      if (registration.remoteUserId != session.remoteUserId ||
          registration.installationId != localIdentity.installationId) {
        throw StateError('Backend registration identity mismatch');
      }
      await identityBinding.bindRemoteUser(
        registration.remoteUserId,
        registration.registeredAt,
      );

      final bootstrap = await backend.getBootstrapPayload(
        installationId: localIdentity.installationId,
        locale: locale,
        environment: environment,
      );
      if (bootstrap.remoteUserId != session.remoteUserId ||
          bootstrap.localUserId != localIdentity.localUserId ||
          bootstrap.installationId != localIdentity.installationId) {
        throw StateError('Bootstrap identity mismatch');
      }
      final resolvedFlags = RemoteFeatureFlagResolver.resolve(
        records: bootstrap.flags,
        capabilities: capabilities,
      );
      final flagsExpireAt = bootstrap.serverTime.add(const Duration(hours: 6));
      await flagCache.save(
        records: bootstrap.flags,
        fetchedAt: bootstrap.serverTime,
        expiresAt: flagsExpireAt,
      );
      final flagsApplied = featureFlags.applySnapshot(
        snapshot: resolvedFlags,
        source: FeatureFlagSnapshotSource.server,
        fetchedAt: bootstrap.serverTime,
        expiresAt: flagsExpireAt,
        now: now,
      );
      final effectiveFlags = flagsApplied
          ? featureFlags.snapshot
          : FeatureFlagSnapshot.safeDefaults();
      final activation = seasonActivation;
      if (activation != null) {
        try {
          await activation.apply(
            snapshot: bootstrap.activeSeason,
            flags: effectiveFlags,
          );
          await onSeasonStateCommitted?.call();
        } catch (error, stackTrace) {
          developer.log(
            'Season bootstrap activation failed closed',
            name: 'mayhem.season',
            error: error.runtimeType,
            stackTrace: stackTrace,
          );
        }
      }

      var authoritative = bootstrap.projection;
      var uploadedCount = 0;
      if (retryCandidates.isNotEmpty) {
        final ack = await backend.ingestEvents(
          installationId: localIdentity.installationId,
          events: retryCandidates.map((item) => item.event).toList(),
        );
        await events.applyServerResults(
          results: ack.results,
          receivedAt: ack.serverTime,
        );
        final resolvedIds = ack.results.map((result) => result.eventId).toSet();
        retryCandidates = retryCandidates
            .where((item) => !resolvedIds.contains(item.event.eventId))
            .toList(growable: false);
        uploadedCount = ack.results.where((result) => result.accepted).length;
        authoritative = ack.projection;
      }

      final pending = await events.loadAllPending();
      final descriptors = await _loadChallengeDescriptors(pending);
      final localProjection =
          await progress.loadProjection() ?? authoritative.projection;
      final lastServerRevision = await reconciliationStore
          .loadLastServerProjectionRevision();
      final reconciled = reconciler.reconcile(
        local: localProjection,
        server: authoritative,
        lastServerProjectionRevision: lastServerRevision,
        pendingEvents: pending,
        challengeDescriptors: descriptors,
        now: now,
      );
      await reconciliationStore.commit(reconciled);
      if (reconciled.applied) await onProjectionCommitted?.call();

      if (effectiveFlags.isEnabled(MayhemFeatureFlag.remoteContentEnabled)) {
        await contentRefresh.refresh(locale: locale);
      }
      final feedRefresher = remoteFeed;
      if (feedRefresher != null &&
          effectiveFlags.isEnabled(MayhemFeatureFlag.newFeedEnabled)) {
        try {
          final result = await feedRefresher.refresh(locale: locale);
          if (result.committed) await onRemoteFeedCommitted?.call();
        } catch (error, stackTrace) {
          developer.log(
            'Remote Feed refresh failed; local Feed remains active',
            name: 'mayhem.feed.remote',
            error: error.runtimeType,
            stackTrace: stackTrace,
          );
        }
      }
      developer.log(
        'V2 sync completed: uploaded=$uploadedCount pending=${pending.length}',
        name: 'mayhem.sync.v2',
      );
      return SyncRunResult(
        status: SyncRunStatus.synchronized,
        trigger: trigger,
        uploadedCount: uploadedCount,
        retriedCount: 0,
      );
    } catch (error, stackTrace) {
      final retries = _retryUpdates(retryCandidates, now, error.runtimeType);
      var retriedCount = 0;
      if (retries.isNotEmpty) {
        try {
          await events.scheduleRetries(retries);
          retriedCount = retries.length;
        } catch (retryError, retryStackTrace) {
          developer.log(
            'V2 sync retry persistence failed',
            name: 'mayhem.sync.v2',
            error: retryError.runtimeType,
            stackTrace: retryStackTrace,
          );
        }
      }
      developer.log(
        'V2 sync failed; retry scheduled for $retriedCount events',
        name: 'mayhem.sync.v2',
        error: error.runtimeType,
        stackTrace: stackTrace,
      );
      return SyncRunResult(
        status: SyncRunStatus.failed,
        trigger: trigger,
        uploadedCount: 0,
        retriedCount: retriedCount,
      );
    }
  }

  Future<Map<String, PendingChallengeDescriptor>> _loadChallengeDescriptors(
    Iterable<EventEnvelopeV2> pending,
  ) async {
    final descriptors = <String, PendingChallengeDescriptor>{};
    for (final event in pending) {
      if (event.eventType != CanonicalEventTypeV2.challengeAttempted &&
          event.eventType != CanonicalEventTypeV2.challengeCompleted) {
        continue;
      }
      final contentId = event.contentId;
      final revision = event.contentRevision;
      if (contentId == null || revision == null) {
        throw const FormatException('Pending challenge identity is missing');
      }
      final key = '$contentId@$revision';
      if (descriptors.containsKey(key)) continue;
      final contentRevision = await content.findRevision(
        contentId: contentId,
        revision: revision,
        locale: locale,
      );
      if (contentRevision == null) {
        throw StateError('Pending challenge content is unavailable');
      }
      descriptors[key] = PendingChallengeDescriptor.fromContent(
        contentRevision,
      );
    }
    return descriptors;
  }

  List<EventRetryV2> _retryUpdates(
    Iterable<PendingEventV2> pending,
    DateTime now,
    Type errorType,
  ) => pending
      .map((item) {
        final attempts = item.attempts + 1;
        final exponent = attempts.clamp(1, 8);
        final baseSeconds = min(300, 1 << exponent);
        final jitter = _random.nextInt(max(1, baseSeconds ~/ 4));
        return EventRetryV2(
          eventId: item.event.eventId,
          attempts: attempts,
          nextRetryAt: now.add(Duration(seconds: baseSeconds + jitter)),
          errorCode: 'temporary_${errorType.toString()}',
        );
      })
      .toList(growable: false);
}
