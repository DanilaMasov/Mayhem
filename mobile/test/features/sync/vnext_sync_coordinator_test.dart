import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mayhem_mobile/content/domain/content_item_revision.dart';
import 'package:mayhem_mobile/content/domain/content_repository.dart';
import 'package:mayhem_mobile/core/auth/anonymous_session_coordinator.dart';
import 'package:mayhem_mobile/core/auth/remote_auth_gateway.dart';
import 'package:mayhem_mobile/core/auth/remote_auth_session.dart';
import 'package:mayhem_mobile/core/auth/secure_session_store.dart';
import 'package:mayhem_mobile/core/feature_flags/feature_flag_runtime.dart';
import 'package:mayhem_mobile/core/feature_flags/feature_flags.dart';
import 'package:mayhem_mobile/core/identity/local_identity_repository.dart';
import 'package:mayhem_mobile/core/sync/event_envelope_v2.dart';
import 'package:mayhem_mobile/features/progress/domain/development_rank_config.dart';
import 'package:mayhem_mobile/features/progress/domain/progress_models.dart';
import 'package:mayhem_mobile/features/progress/domain/progress_repository.dart';
import 'package:mayhem_mobile/features/feed/application/remote_feed_refresh_service.dart';
import 'package:mayhem_mobile/features/season/application/season_bootstrap_activator.dart';
import 'package:mayhem_mobile/features/streak/domain/momentum_state.dart';
import 'package:mayhem_mobile/features/sync/application/remote_content_refresh_service.dart';
import 'package:mayhem_mobile/features/sync/application/vnext_sync_coordinator.dart';
import 'package:mayhem_mobile/features/sync/domain/backend_models.dart';
import 'package:mayhem_mobile/features/sync/domain/event_sync_store_v2.dart';
import 'package:mayhem_mobile/features/sync/domain/reconciliation_models.dart';
import 'package:mayhem_mobile/features/sync/domain/remote_flag_cache.dart';

void main() {
  test(
    'remote operations remain a no-op behind the local production gate',
    () async {
      final harness = _Harness(remoteOperationsEnabled: false);

      final result = await harness.coordinator.synchronize();

      expect(result.status, SyncRunStatus.disabled);
      expect(harness.backend.registerCalls, 0);
      expect(harness.auth.signInCalls, 0);
    },
  );

  test(
    'authenticated v2 sync registers, ingests, ACKs, and reconciles once',
    () async {
      final harness = _Harness(remoteOperationsEnabled: true);

      final result = await harness.coordinator.synchronize(
        trigger: SyncTrigger.terminalResult,
      );

      expect(result.status, SyncRunStatus.synchronized);
      expect(result.uploadedCount, 1);
      expect(harness.backend.registerCalls, 1);
      expect(harness.backend.bootstrapCalls, 1);
      expect(harness.backend.ingestCalls, 1);
      expect(harness.identity.remoteUserId, 'remote-user');
      expect(harness.events.pending, isEmpty);
      expect(harness.reconciliation.committed?.serverProjectionRevision, 1);
      expect(harness.flags.saved, 1);
      expect(harness.remoteContent.refreshCalls, 0);
      expect(harness.projectionRefreshes, 1);
    },
  );

  test(
    'temporary transport failure schedules bounded retry with jitter',
    () async {
      final harness = _Harness(
        remoteOperationsEnabled: true,
        ingestFailure: StateError('temporary'),
      );

      final result = await harness.coordinator.synchronize();

      expect(result.status, SyncRunStatus.failed);
      expect(result.retriedCount, 1);
      expect(harness.events.retries.single.attempts, 1);
      expect(
        harness.events.retries.single.nextRetryAt.isBefore(
          DateTime.utc(2026, 7, 13, 12, 0, 2),
        ),
        isFalse,
      );
      expect(
        harness.events.retries.single.nextRetryAt.isBefore(
          DateTime.utc(2026, 7, 13, 12, 0, 3),
        ),
        isTrue,
      );
    },
  );

  test(
    'terminal lifecycle sync is coalesced behind an active cold start',
    () async {
      final gate = Completer<void>();
      final harness = _Harness(
        remoteOperationsEnabled: true,
        registrationGate: gate.future,
      );

      harness.coordinator.onColdStart();
      await pumpEventQueue();
      expect(harness.backend.registerCalls, 1);

      harness.coordinator.onTerminalResult();
      gate.complete();
      await pumpEventQueue(times: 20);

      expect(harness.backend.registerCalls, 2);
      expect(harness.backend.bootstrapCalls, 2);
    },
  );

  test('invalid optional Season activation does not block core sync', () async {
    final activation = _SeasonActivation();
    final harness = _Harness(
      remoteOperationsEnabled: true,
      seasonActivation: activation,
    );

    final result = await harness.coordinator.synchronize();

    expect(result.status, SyncRunStatus.synchronized);
    expect(activation.calls, 1);
    expect(harness.seasonRefreshes, 0);
    expect(harness.seasonFailures, [
      SeasonActivationFailure.incompatiblePackage,
    ]);
  });

  test('Season persistence failure is exposed as recoverable', () async {
    final activation = _SeasonActivation(failure: StateError('disk'));
    final harness = _Harness(
      remoteOperationsEnabled: true,
      seasonActivation: activation,
    );

    final result = await harness.coordinator.synchronize();

    expect(result.status, SyncRunStatus.synchronized);
    expect(harness.seasonRefreshes, 0);
    expect(harness.seasonFailures, [SeasonActivationFailure.recoverable]);
  });

  test(
    'successful Season activation refreshes its runtime projection',
    () async {
      final activation = _SeasonActivation(failure: null);
      final harness = _Harness(
        remoteOperationsEnabled: true,
        seasonActivation: activation,
      );

      final result = await harness.coordinator.synchronize();

      expect(result.status, SyncRunStatus.synchronized);
      expect(activation.calls, 1);
      expect(harness.seasonRefreshes, 1);
    },
  );

  test('validated bootstrap flags update the effective runtime', () async {
    final harness = _Harness(
      remoteOperationsEnabled: true,
      bootstrapFlags: [
        RemoteFlagRecord(
          flag: MayhemFeatureFlag.remoteContentEnabled,
          enabled: true,
          requiredCapabilityKey: 'remote_content',
          requiredCapabilityRevision: 1,
          updatedAt: DateTime.utc(2026, 7, 13, 12),
        ),
        RemoteFlagRecord(
          flag: MayhemFeatureFlag.newFeedEnabled,
          enabled: true,
          requiredCapabilityKey: 'feed_batch',
          requiredCapabilityRevision: 1,
          updatedAt: DateTime.utc(2026, 7, 13, 12),
        ),
      ],
    );

    final result = await harness.coordinator.synchronize();

    expect(result.status, SyncRunStatus.synchronized);
    expect(harness.effectiveFlags.source, FeatureFlagSnapshotSource.server);
    expect(
      harness.effectiveFlags.isEnabled(MayhemFeatureFlag.remoteContentEnabled),
      isTrue,
    );
    expect(harness.remoteContent.refreshCalls, 1);
    expect(harness.remoteFeed.refreshCalls, 1);
    expect(harness.remoteFeedRefreshes, 1);
  });
}

class _Harness {
  _Harness({
    required bool remoteOperationsEnabled,
    Object? ingestFailure,
    Future<void>? registrationGate,
    SeasonBootstrapActivation? seasonActivation,
    List<RemoteFlagRecord> bootstrapFlags = const [],
  }) : auth = _AuthGateway(),
       sessions = _SessionStore(),
       identity = _Identity(),
       events = _Events(),
       progress = _Progress(_projection(100, 1)),
       reconciliation = _Reconciliation(),
       content = _Content(),
       remoteContent = _RemoteContent(),
       remoteFeed = _RemoteFeed(),
       flags = _Flags(),
       effectiveFlags = FeatureFlagRuntime.safe(),
       backend = _Backend(
         ingestFailure: ingestFailure,
         registrationGate: registrationGate,
         bootstrapFlags: bootstrapFlags,
       ) {
    addTearDown(effectiveFlags.dispose);
    coordinator = VNextSyncCoordinator(
      remoteOperationsEnabled: remoteOperationsEnabled,
      sessions: AnonymousSessionCoordinator(gateway: auth, store: sessions),
      backend: backend,
      identity: identity,
      identityBinding: identity,
      events: events,
      progress: progress,
      reconciliationStore: reconciliation,
      content: content,
      contentRefresh: remoteContent,
      remoteFeed: remoteFeed,
      flagCache: flags,
      featureFlags: effectiveFlags,
      platform: 'test',
      appVersion: '1.0.0+1',
      clock: () => DateTime.utc(2026, 7, 13, 12),
      random: Random(1),
      seasonActivation: seasonActivation,
      onProjectionCommitted: () async => projectionRefreshes += 1,
      onSeasonStateCommitted: () async => seasonRefreshes += 1,
      onSeasonActivationFailed: (failure) async => seasonFailures.add(failure),
      onRemoteFeedCommitted: () async => remoteFeedRefreshes += 1,
    );
  }

  int projectionRefreshes = 0;
  int seasonRefreshes = 0;
  final List<SeasonActivationFailure> seasonFailures = [];
  int remoteFeedRefreshes = 0;

  final _AuthGateway auth;
  final _SessionStore sessions;
  final _Identity identity;
  final _Events events;
  final _Progress progress;
  final _Reconciliation reconciliation;
  final _Content content;
  final _RemoteContent remoteContent;
  final _RemoteFeed remoteFeed;
  final _Flags flags;
  final FeatureFlagRuntime effectiveFlags;
  final _Backend backend;
  late final VNextSyncCoordinator coordinator;
}

class _SeasonActivation implements SeasonBootstrapActivation {
  _SeasonActivation({this.failure = const FormatException('invalid')});

  final Object? failure;
  int calls = 0;

  @override
  Future<SeasonActivationStatus> apply({
    required RemoteSeasonSnapshot? snapshot,
    required FeatureFlagSnapshot flags,
  }) async {
    calls += 1;
    if (failure case final failure?) throw failure;
    return SeasonActivationStatus.noActiveSeason;
  }
}

class _AuthGateway implements RemoteAuthGateway {
  int signInCalls = 0;

  @override
  Future<RemoteAuthSession> signInAnonymously() async {
    signInCalls += 1;
    return _session();
  }

  @override
  Future<RemoteAuthSession> refresh(RemoteAuthSession current) async => current;

  @override
  Future<RemoteAuthSession> linkIdentity(
    RemoteAuthSession current,
    ExternalIdentityProvider provider,
  ) async => current;
}

class _SessionStore implements SecureSessionStore {
  RemoteAuthSession? value;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<RemoteAuthSession?> read() async => value;

  @override
  Future<void> write(RemoteAuthSession session) async => value = session;
}

class _Identity
    implements LocalIdentityRepository, RemoteIdentityBindingRepository {
  String? remoteUserId;

  @override
  Future<LocalIdentity> loadIdentity() async => LocalIdentity(
    localUserId: 'local-user',
    installationId: '11111111-1111-4111-8111-111111111111',
    remoteUserId: remoteUserId,
  );

  @override
  Future<void> bindRemoteUser(String remoteUserId, DateTime linkedAt) async {
    this.remoteUserId = remoteUserId;
  }
}

class _Events implements EventSyncStoreV2 {
  final List<PendingEventV2> pending = [
    PendingEventV2(event: _event(), attempts: 0),
  ];
  List<EventRetryV2> retries = const [];

  @override
  Future<void> applyServerResults({
    required List<RemoteEventResult> results,
    required DateTime receivedAt,
  }) async {
    final resolved = results.map((result) => result.eventId).toSet();
    pending.removeWhere((item) => resolved.contains(item.event.eventId));
  }

  @override
  Future<List<EventEnvelopeV2>> loadAllPending({int limit = 500}) async =>
      pending.map((item) => item.event).take(limit).toList();

  @override
  Future<List<PendingEventV2>> loadReadyPending({
    required DateTime now,
    int limit = 100,
  }) async => pending.take(limit).toList();

  @override
  Future<void> scheduleRetries(List<EventRetryV2> retries) async {
    this.retries = retries;
  }
}

class _Progress implements ProgressRepository {
  _Progress(this.value);

  ProgressProjection? value;

  @override
  Future<ProgressProjection?> loadProjection() async => value;

  @override
  Future<void> saveProjection(ProgressProjection projection) async {
    value = projection;
  }
}

class _Reconciliation implements ProjectionReconciliationStore {
  ReconciledState? committed;

  @override
  Future<void> commit(ReconciledState state) async => committed = state;

  @override
  Future<int> loadLastServerProjectionRevision() async => 0;

  @override
  Future<CorrectionNotice?> takePendingCorrectionNotice() async => null;
}

class _Content implements ContentRepository {
  @override
  Future<void> activateBundledCatalog(
    Iterable<ContentItemRevision> revisions,
  ) async {}

  @override
  Future<void> activateRemoteManifest({
    required String locale,
    required int manifestRevision,
    required Set<String> identities,
  }) async {}

  @override
  Future<List<ContentItemRevision>> activeRevisions({
    required String locale,
    required DateTime atUtc,
  }) async => const [];

  @override
  Future<ContentItemRevision?> findRevision({
    required String contentId,
    required int revision,
    required String locale,
  }) async => null;

  @override
  Future<void> saveValidatedRevisions(
    Iterable<ContentItemRevision> revisions,
  ) async {}
}

class _RemoteContent implements RemoteContentRefresher {
  int refreshCalls = 0;

  @override
  Future<RemoteContentRefreshResult> refresh({String locale = 'ru'}) async {
    refreshCalls += 1;
    return const RemoteContentRefreshResult(
      manifestRevision: 1,
      downloadedCount: 0,
      activeCount: 0,
    );
  }
}

class _RemoteFeed implements RemoteFeedRefresher {
  int refreshCalls = 0;

  @override
  Future<RemoteFeedRefreshResult> refresh({String locale = 'ru'}) async {
    refreshCalls += 1;
    return const RemoteFeedRefreshResult(
      receivedCount: 1,
      savedCount: 1,
      committed: true,
    );
  }
}

class _Flags implements RemoteFlagCache {
  int saved = 0;

  @override
  Future<CachedRemoteFlags?> load({
    required DateTime now,
    required CapabilityRevisionSet capabilities,
  }) async => null;

  @override
  Future<void> save({
    required Iterable<RemoteFlagRecord> records,
    required DateTime fetchedAt,
    required DateTime expiresAt,
  }) async {
    saved += 1;
  }
}

class _Backend implements VNextBackendGateway {
  _Backend({
    this.ingestFailure,
    this.registrationGate,
    this.bootstrapFlags = const [],
  });

  final Object? ingestFailure;
  final Future<void>? registrationGate;
  final List<RemoteFlagRecord> bootstrapFlags;
  int registerCalls = 0;
  int bootstrapCalls = 0;
  int ingestCalls = 0;

  @override
  Future<InstallationRegistration> registerInstallation({
    required String installationId,
    required String localUserId,
    required String platform,
    required String appVersion,
    required CapabilityRevisionSet capabilities,
  }) async {
    registerCalls += 1;
    await registrationGate;
    return InstallationRegistration(
      installationId: installationId,
      remoteUserId: 'remote-user',
      registeredAt: DateTime.utc(2026, 7, 13, 12),
    );
  }

  @override
  Future<BootstrapPayload> getBootstrapPayload({
    required String installationId,
    required String locale,
    String environment = 'production',
  }) async {
    bootstrapCalls += 1;
    return BootstrapPayload(
      remoteUserId: 'remote-user',
      localUserId: 'local-user',
      installationId: installationId,
      flags: bootstrapFlags,
      projection: _serverProjection(0, 0),
      contentManifest: RemoteContentManifest(
        revision: 0,
        locale: locale,
        generatedAt: DateTime.utc(2026, 7, 13, 12),
        items: const [],
      ),
      serverTime: DateTime.utc(2026, 7, 13, 12),
    );
  }

  @override
  Future<EventIngestAckV2> ingestEvents({
    required String installationId,
    required List<EventEnvelopeV2> events,
  }) async {
    ingestCalls += 1;
    if (ingestFailure != null) throw ingestFailure!;
    return EventIngestAckV2(
      results: [
        for (final event in events)
          RemoteEventResult(
            eventId: event.eventId,
            accepted: true,
            disposition: RemoteEventDisposition.accepted,
          ),
      ],
      projection: _serverProjection(100, 1),
      serverTime: DateTime.utc(2026, 7, 13, 12),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

RemoteAuthSession _session() => RemoteAuthSession(
  remoteUserId: 'remote-user',
  accessToken: 'access-token',
  refreshToken: 'refresh-token',
  expiresAt: DateTime.utc(2027),
  isAnonymous: true,
);

EventEnvelopeV2 _event() => EventEnvelopeV2(
  eventId: 'event-id',
  eventType: CanonicalEventTypeV2.challengeCompleted,
  localUserId: 'local-user',
  installationId: '11111111-1111-4111-8111-111111111111',
  clientSequence: 1,
  occurredAtUtc: DateTime.utc(2026, 7, 13, 11),
  timezoneId: 'Europe/Moscow',
  timezoneOffsetMinutes: 180,
  assignmentId: 'assignment-id',
  attemptId: 'attempt-id',
  contentId: 'challenge',
  contentRevision: 1,
  payload: const {'rewardXp': 100, 'felt': 'aboutAsExpected'},
);

ServerProjectionSnapshot _serverProjection(int totalXp, int revision) =>
    ServerProjectionSnapshot.fromJson({
      'totalXp': totalXp,
      'traitXp': {
        'initiation': 0,
        'expression': 0,
        'connection': 0,
        'presence': totalXp,
      },
      'rank': {
        'family': 'spark',
        'tier': 1,
        'configRevision': 'rank_config_dev_v1',
      },
      'rewardPolicyRevision': 'reward_policy_dev_v1',
      'completedCount': totalXp > 0 ? 1 : 0,
      'attemptedCount': 0,
      'projectionRevision': revision,
      'updatedAt': '2026-07-13T12:00:00.000Z',
      'difficulty': <String, Object?>{},
      'momentum': {
        'currentDays': 0,
        'longestDays': 0,
        'shieldsAvailable': 0,
        'protectedLocalDates': <String>[],
        'policyRevision': 'momentum_policy_dev_v1',
        'projectionRevision': revision,
      },
    });

ProgressProjection _projection(int totalXp, int completedCount) {
  final traitXp = {
    Trait.initiation: 0,
    Trait.expression: 0,
    Trait.connection: 0,
    Trait.presence: totalXp,
  };
  final rank = DevelopmentRankConfig.policy().resolve(
    totalXp: totalXp,
    traitXp: traitXp,
  );
  return ProgressProjection(
    totalXp: totalXp,
    traitXp: traitXp,
    rank: rank.rank,
    rankProgress: rank.progressToNext,
    momentum: MomentumState.empty(),
    difficulty: {
      for (final trait in Trait.values)
        trait: DifficultyState(
          trait: trait,
          rating: 2,
          confidence: 0,
          observations: 0,
          recommendedIntensity: 2,
          updatedAt: DateTime.utc(2026, 7, 13),
        ),
    },
    completedCount: completedCount,
    attemptedCount: 0,
    updatedAt: DateTime.utc(2026, 7, 13),
    source: ProjectionSource.localCheckpoint,
  );
}
