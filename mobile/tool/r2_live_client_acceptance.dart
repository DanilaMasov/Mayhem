import 'dart:io';

import 'package:mayhem_mobile/core/auth/anonymous_session_coordinator.dart';
import 'package:mayhem_mobile/core/auth/remote_auth_session.dart';
import 'package:mayhem_mobile/core/feature_flags/feature_flags.dart';
import 'package:mayhem_mobile/core/sync/event_envelope_v2.dart';
import 'package:mayhem_mobile/features/feed/application/remote_feed_refresh_service.dart';
import 'package:mayhem_mobile/features/season/application/season_bootstrap_activator.dart';
import 'package:mayhem_mobile/features/settings/application/delete_everywhere_coordinator.dart';
import 'package:mayhem_mobile/features/settings/application/delete_everywhere_recovery_store.dart';
import 'package:mayhem_mobile/features/sync/application/projection_reconciler.dart';
import 'package:mayhem_mobile/features/sync/application/remote_content_refresh_service.dart';
import 'package:mayhem_mobile/features/sync/domain/backend_models.dart';
import 'package:mayhem_mobile/infrastructure/security/flutter_secure_session_store.dart';
import 'package:mayhem_mobile/infrastructure/sqlite/sqlite_vnext_store.dart';
import 'package:mayhem_mobile/infrastructure/supabase/dart_io_json_http_executor.dart';
import 'package:mayhem_mobile/infrastructure/supabase/supabase_anonymous_auth_gateway.dart';
import 'package:mayhem_mobile/infrastructure/supabase/supabase_event_sync_transport.dart';
import 'package:mayhem_mobile/infrastructure/supabase/supabase_runtime_config.dart';
import 'package:mayhem_mobile/infrastructure/supabase/supabase_vnext_backend_gateway.dart';
import 'package:uuid/uuid.dart';

import '../test/support/memory_vnext_database.dart';

const _confirmation = 'I_UNDERSTAND_THIS_IS_DISPOSABLE';

Future<Map<String, Object?>> runR2LiveClientAcceptance() async {
  final startedAt = DateTime.now().toUtc();
  final environment = Platform.environment;
  final environmentId = (environment['MAYHEM_R2_ENVIRONMENT_ID'] ?? '').trim();
  _require(
    environmentId.isNotEmpty &&
        !environmentId.toLowerCase().contains(RegExp(r'prod(uction)?')),
    'R2 client environment identifier is missing or unsafe',
  );
  _require(
    environment['MAYHEM_R2_CONFIRM_DISPOSABLE'] == _confirmation,
    'R2 client disposable confirmation is missing',
  );

  final config = SupabaseRuntimeConfig(
    projectUrl: environment['SUPABASE_URL'] ?? '',
    anonKey: environment['SUPABASE_ANON_KEY'] ?? '',
    runtimeEnvironment: 'development',
  );
  _require(config.isUsable, 'R2 client Supabase configuration is unusable');

  final checks = <String>[];
  final storage = _MemorySecureKeyValueStore();
  final sessions = FlutterSecureSessionStore(
    storage: storage,
    environment: environmentId,
  );
  final auth = SupabaseAnonymousAuthGateway(
    config: config,
    http: const DartIoJsonHttpExecutor(),
    clock: () => DateTime.now().toUtc(),
  );
  final firstCoordinator = AnonymousSessionCoordinator(
    gateway: auth,
    store: sessions,
  );
  final created = await firstCoordinator.ensureSession(DateTime.now().toUtc());

  final restartedSessions = FlutterSecureSessionStore(
    storage: storage,
    environment: environmentId,
  );
  final restartedCoordinator = AnonymousSessionCoordinator(
    gateway: auth,
    store: restartedSessions,
  );
  final restored = await restartedCoordinator.ensureSession(
    DateTime.now().toUtc(),
  );
  _require(
    restored.remoteUserId == created.remoteUserId,
    'Session restore drifted',
  );

  await restartedSessions.write(
    RemoteAuthSession(
      remoteUserId: restored.remoteUserId,
      accessToken: restored.accessToken,
      refreshToken: restored.refreshToken,
      expiresAt: DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
      isAnonymous: true,
    ),
  );
  final refreshed = await restartedCoordinator.ensureSession(
    DateTime.now().toUtc(),
  );
  _require(
    refreshed.remoteUserId == created.remoteUserId,
    'Refresh changed user',
  );
  checks.add('anonymous_bootstrap_secure_restore_and_refresh');

  final rpc = SupabaseRpcClient(
    config: config,
    accessTokenProvider: () async =>
        (await restartedSessions.read())?.accessToken,
    http: const DartIoJsonHttpExecutor(),
    refreshSession: restartedCoordinator.refreshSession,
  );
  final backend = SupabaseVNextBackendGateway(rpc);
  final installationId = const Uuid().v4();
  const localUserId = 'r2-dart-live-client';
  final registration = await backend.registerInstallation(
    installationId: installationId,
    localUserId: localUserId,
    platform: 'test',
    appVersion: 'r2-live-client',
    capabilities: CapabilityRevisionSet({'feed_vnext': 1, 'season_vnext': 1}),
  );
  _require(
    registration.remoteUserId == refreshed.remoteUserId,
    'Installation owner mismatch',
  );
  final bootstrap = await backend.getBootstrapPayload(
    installationId: installationId,
    locale: 'ru',
    environment: 'development',
  );
  _require(
    bootstrap.remoteUserId == refreshed.remoteUserId,
    'Bootstrap mismatch',
  );
  _require(
    bootstrap.flags.every((flag) => !flag.enabled),
    'A live flag is enabled',
  );
  checks.add('installation_bootstrap_and_safe_flags');

  final manifest = await backend.getContentManifest(locale: 'ru');
  _require(manifest.items.length == 20, 'Live manifest is incomplete');
  final revisions = await backend.getContentRevisions(manifest.items);
  _require(
    revisions.length == manifest.items.length,
    'Live content revision count mismatches the manifest',
  );
  final feed = await backend.getFeedBatch(locale: 'ru', limit: 1);
  _require(feed.assignments.length == 1, 'Live Feed did not return one item');
  checks.add('remote_content_validation_and_feed_parsing');

  final localDatabase = MemoryVNextDatabase(
    seed: {
      'user_identity': [
        {
          'local_user_id': localUserId,
          'remote_user_id': refreshed.remoteUserId,
          'installation_id': installationId,
          'created_at': startedAt.toIso8601String(),
          'linked_at': startedAt.toIso8601String(),
        },
      ],
    },
  );
  final localStore = SqliteVNextStore(
    localDatabase,
    clock: () => DateTime.now().toUtc(),
  );
  final contentRefresh = await RemoteContentRefreshService(
    backend: backend,
    content: localStore.content,
  ).refresh();
  _require(
    contentRefresh.downloadedCount == 20,
    'Remote content was not saved',
  );
  final feedRefresh = await RemoteFeedRefreshService(
    backend: backend,
    feed: localStore.feed,
    attempts: localStore.challenge,
    identity: localStore.identity,
    content: localStore.content,
    clock: () => DateTime.now().toUtc(),
  ).refresh();
  final savedAssignments = localDatabase.executor.rows('feed_assignments');
  _require(feedRefresh.committed, 'Remote Feed was not committed');
  _require(
    savedAssignments.length == 20,
    'Remote Feed persistence is incomplete',
  );
  _require(
    savedAssignments.map((row) => row['assignment_id']).toSet().length == 20 &&
        savedAssignments.map((row) => row['content_id']).toSet().length == 20,
    'Remote Feed persistence contains duplicates',
  );
  checks.add('remote_content_and_feed_local_persistence');

  final firstEvent = _event(
    eventId: const Uuid().v4(),
    installationId: installationId,
    sequence: 1,
    type: CanonicalEventTypeV2.onboardingStarted,
  );
  final firstAck = await backend.ingestEvents(
    installationId: installationId,
    events: [firstEvent],
  );
  _require(
    firstAck.results.single.accepted,
    'Exact ACK rejected a valid event',
  );

  final validPartial = _event(
    eventId: const Uuid().v4(),
    installationId: installationId,
    sequence: 2,
    type: CanonicalEventTypeV2.calibrationAnswered,
    payload: const {'trait': 'presence', 'answer': 2},
  );
  final rejectedId = const Uuid().v4();
  final rejectedPartial = _event(
    eventId: rejectedId,
    installationId: installationId,
    sequence: 3,
    type: CanonicalEventTypeV2.reflectionSubmitted,
  ).toSyncJson()..['payload'] = const {'privateNote': 'must stay local'};
  final partialValue = await rpc.invoke('ingest_events_v2', {
    'p_installation_id': installationId,
    'p_events': [validPartial.toSyncJson(), rejectedPartial],
  });
  final partialAck = EventIngestAckV2.fromJson(partialValue);
  _require(
    partialAck.results.first.accepted,
    'Partial ACK lost its valid event',
  );
  _require(
    !partialAck.results.last.accepted &&
        partialAck.results.last.eventId == rejectedId,
    'Partial ACK accepted private reflection text',
  );
  checks.add('exact_and_partial_ack_through_production_gateway');

  final seasonJoin = _event(
    eventId: const Uuid().v4(),
    installationId: installationId,
    sequence: 4,
    type: CanonicalEventTypeV2.seasonJoined,
    payload: const {'seasonId': 'r2-live-season', 'seasonRevision': 1},
  );
  final bossParticipation = _event(
    eventId: const Uuid().v4(),
    installationId: installationId,
    sequence: 5,
    type: CanonicalEventTypeV2.bossParticipated,
    contentId: 'r2-live-boss-content',
    contentRevision: 1,
    payload: const {
      'seasonId': 'r2-live-season',
      'seasonRevision': 1,
      'bossEventId': 'r2-live-boss',
      'route': 'normal',
    },
  );
  final seasonAck = await backend.ingestEvents(
    installationId: installationId,
    events: [seasonJoin, bossParticipation],
  );
  _require(
    seasonAck.results.every((result) => result.accepted),
    'Live Season participation was rejected',
  );
  final seasonBootstrap = await backend.getBootstrapPayload(
    installationId: installationId,
    locale: 'ru',
    environment: 'development',
  );
  final season = seasonBootstrap.activeSeason;
  _require(season != null, 'Live Season bootstrap is unavailable');
  final remoteParticipation = season!.participation;
  _require(
    remoteParticipation != null &&
        remoteParticipation.seasonId == 'r2-live-season' &&
        remoteParticipation.seasonRevision == 1 &&
        remoteParticipation.completedDays.isEmpty &&
        remoteParticipation.bossParticipatedAt != null &&
        !remoteParticipation.bossParticipatedAt!.isBefore(
          remoteParticipation.joinedAt,
        ),
    'Live Season participation snapshot is incomplete',
  );
  _require(
    seasonBootstrap.projection.projectionRevision > 0 &&
        seasonBootstrap.projection.ownedArtifacts.length == 1,
    'Artifact projection revision was not advanced',
  );
  final activation =
      await SeasonBootstrapActivator(
        localActivationEnabled: true,
        store: localStore.season,
        participation: localStore.seasonParticipation,
        actions: localStore.seasonActions,
      ).apply(
        snapshot: season,
        flags: FeatureFlagSnapshot(
          values: const {
            MayhemFeatureFlag.seasonZeroEnabled: true,
            MayhemFeatureFlag.bossRaidEnabled: true,
            MayhemFeatureFlag.socialProofEnabled: true,
          },
        ),
      );
  _require(
    activation == SeasonActivationStatus.activated,
    'Season not activated',
  );
  _require(
    await localStore.season.loadActivePackage(DateTime.now().toUtc()) != null,
    'Season package was not persisted',
  );
  final persistedParticipation = await localStore.seasonParticipation.load(
    'r2-live-season',
  );
  _require(
    persistedParticipation != null &&
        persistedParticipation.serverConfirmed &&
        persistedParticipation.completedDays.isEmpty &&
        persistedParticipation.bossParticipatedAt != null,
    'Authoritative Season participation was not persisted',
  );
  final reconciled = const ProjectionReconciler().reconcile(
    local: seasonBootstrap.projection.projection,
    server: seasonBootstrap.projection,
    lastServerProjectionRevision: 0,
    pendingEvents: const [],
    challengeDescriptors: const {},
    now: DateTime.now().toUtc(),
  );
  await localStore.reconciliation.commit(reconciled);
  _require(
    (await localStore.reconciliation.loadOwnedArtifacts()).length == 1,
    'Owned artifact was not reconciled locally',
  );
  checks.add('season_bootstrap_persistence_and_artifact_reconciliation');

  final recovery = SecureDeleteEverywhereRecoveryStore(
    storage: storage,
    environment: environmentId,
  );
  final deletionBackend = _CountingDeletionBackend(backend);
  var localClearAttempts = 0;
  final deletion = DeleteEverywhereCoordinator(
    backend: deletionBackend,
    sessions: restartedSessions,
    recovery: recovery,
    clearLocalData: () async {
      localClearAttempts += 1;
      if (localClearAttempts == 1) throw StateError('simulated interruption');
    },
  );
  try {
    await deletion.delete();
    throw StateError('Interrupted deletion unexpectedly completed');
  } on DeleteEverywhereFailure catch (error) {
    _require(
      error.code == 'local_data_clear_failed' && error.recoveryPending,
      'Interrupted deletion did not create recovery state',
    );
  }
  await deletion.recoverPendingLocalWipe();
  _require(deletionBackend.calls == 1, 'Recovery repeated cloud deletion');
  _require(await restartedSessions.read() == null, 'Deleted session survived');
  _require(await recovery.read() == null, 'Deletion recovery marker survived');
  _require(localClearAttempts == 2, 'Local wipe was not resumed exactly once');
  checks.add('delete_everywhere_interruption_and_recovery');

  const offline = SupabaseRuntimeConfig(projectUrl: '', anonKey: '');
  _require(
    !offline.isConfigured && !offline.isUsable,
    'Offline config is unsafe',
  );
  checks.add('backend_absence_fails_closed');

  final completedAt = DateTime.now().toUtc();
  return {
    'environmentId': environmentId,
    'checks': checks,
    'startedAt': startedAt.toIso8601String(),
    'completedAt': completedAt.toIso8601String(),
    'durationMs': completedAt.difference(startedAt).inMilliseconds,
    'result': 'passed',
  };
}

EventEnvelopeV2 _event({
  required String eventId,
  required String installationId,
  required int sequence,
  required CanonicalEventTypeV2 type,
  Map<String, Object?> payload = const {},
  String? contentId,
  int? contentRevision,
}) => EventEnvelopeV2(
  eventId: eventId,
  eventType: type,
  localUserId: 'r2-dart-live-client',
  installationId: installationId,
  clientSequence: sequence,
  occurredAtUtc: DateTime.now().toUtc(),
  timezoneId: 'Etc/UTC',
  timezoneOffsetMinutes: 0,
  contentId: contentId,
  contentRevision: contentRevision,
  payload: payload,
);

void _require(bool condition, String message) {
  if (!condition) throw StateError(message);
}

class _MemorySecureKeyValueStore implements SecureKeyValueStore {
  final values = <String, String>{};

  @override
  Future<void> delete({required String key}) async => values.remove(key);

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }
}

class _CountingDeletionBackend implements VNextBackendGateway {
  _CountingDeletionBackend(this.delegate);

  final VNextBackendGateway delegate;
  int calls = 0;

  @override
  Future<DataDeletionReceipt> deleteMyData() {
    calls += 1;
    return delegate.deleteMyData();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
