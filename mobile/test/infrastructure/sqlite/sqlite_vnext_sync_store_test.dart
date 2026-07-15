import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mayhem_mobile/core/feature_flags/feature_flags.dart';
import 'package:mayhem_mobile/core/sync/event_envelope_v2.dart';
import 'package:mayhem_mobile/features/sync/domain/backend_models.dart';
import 'package:mayhem_mobile/features/sync/domain/event_sync_store_v2.dart';
import 'package:mayhem_mobile/features/sync/domain/reconciliation_models.dart';
import 'package:mayhem_mobile/features/season/domain/artifact_ownership.dart';
import 'package:mayhem_mobile/infrastructure/sqlite/sqlite_event_sync_store_v2.dart';
import 'package:mayhem_mobile/infrastructure/sqlite/sqlite_projection_reconciliation_store.dart';
import 'package:mayhem_mobile/infrastructure/sqlite/sqlite_remote_feature_flag_cache.dart';
import 'package:mayhem_mobile/infrastructure/sqlite/sqlite_vnext_context.dart';

import '../../support/memory_vnext_database.dart';

void main() {
  test('v2 queue loads only ready events in client sequence order', () async {
    final first = _event('event-1', 1).toDatabaseMap();
    final second = _event('event-2', 2).toDatabaseMap()
      ..['next_retry_at'] = '2026-07-13T13:00:00.000Z';
    final database = MemoryVNextDatabase(
      seed: {
        'event_log_v2': [second, first],
      },
    );
    final store = SqliteEventSyncStoreV2(SqliteVNextContext(database));

    final before = await store.loadReadyPending(
      now: DateTime.utc(2026, 7, 13, 12),
    );
    final after = await store.loadReadyPending(
      now: DateTime.utc(2026, 7, 13, 14),
    );

    expect(before.map((item) => item.event.eventId), ['event-1']);
    expect(after.map((item) => item.event.eventId), ['event-1', 'event-2']);
    expect(await store.loadAllPending(), hasLength(2));
  });

  test(
    'accepted and permanent results are durable without deleting events',
    () async {
      final database = MemoryVNextDatabase(
        seed: {
          'event_log_v2': [
            _event('event-1', 1).toDatabaseMap(),
            _event('event-2', 2).toDatabaseMap(),
          ],
        },
      );
      final store = SqliteEventSyncStoreV2(SqliteVNextContext(database));

      await store.applyServerResults(
        results: const [
          RemoteEventResult(
            eventId: 'event-1',
            accepted: true,
            disposition: RemoteEventDisposition.duplicateEvent,
          ),
          RemoteEventResult(
            eventId: 'event-2',
            accepted: false,
            disposition: RemoteEventDisposition.permanentSchema,
          ),
        ],
        receivedAt: DateTime.utc(2026, 7, 13, 12),
      );

      final rows = database.executor.rows('event_log_v2');
      expect(rows, hasLength(2));
      expect(
        rows.firstWhere((row) => row['event_id'] == 'event-1')['sync_status'],
        'synced',
      );
      expect(
        rows.firstWhere((row) => row['event_id'] == 'event-2')['sync_status'],
        'rejected',
      );
      final quarantine = database.executor.rows('event_quarantine').single;
      expect(quarantine['reason'], 'server_rejected:permanent_schema');
      expect(quarantine['raw_row_json'], isNot(contains('privateNote')));
    },
  );

  test(
    'corrupt pending events are quarantined during reconciliation',
    () async {
      final valid = _event('event-1', 1).toDatabaseMap();
      final corrupt = _event('event-2', 2).toDatabaseMap()
        ..['payload_json'] = '{not-json';
      final database = MemoryVNextDatabase(
        seed: {
          'event_log_v2': [valid, corrupt],
        },
      );
      final store = SqliteEventSyncStoreV2(
        SqliteVNextContext(
          database,
          clock: () => DateTime.utc(2026, 7, 13, 12),
        ),
      );

      final pending = await store.loadAllPending();

      expect(pending.map((event) => event.eventId), ['event-1']);
      expect(database.executor.rows('event_quarantine'), hasLength(1));
      final rejected = database.executor
          .rows('event_log_v2')
          .firstWhere((row) => row['event_id'] == 'event-2');
      expect(rejected['sync_status'], 'rejected');
      expect(rejected['last_error_code'], 'permanent_schema');
    },
  );

  test(
    'retry scheduling remains pending and records bounded diagnostics',
    () async {
      final database = MemoryVNextDatabase(
        seed: {
          'event_log_v2': [_event('event-1', 1).toDatabaseMap()],
        },
      );
      final store = SqliteEventSyncStoreV2(SqliteVNextContext(database));

      await store.scheduleRetries([
        EventRetryV2(
          eventId: 'event-1',
          attempts: 2,
          nextRetryAt: DateTime.utc(2026, 7, 13, 12, 5),
          errorCode: 'temporary_network',
        ),
      ]);

      final row = database.executor.rows('event_log_v2').single;
      expect(row['sync_status'], 'pending');
      expect(row['attempt_count'], 2);
      expect(row['last_error_code'], 'temporary_network');
    },
  );

  test('cached flags are re-evaluated against current capabilities', () async {
    final database = MemoryVNextDatabase();
    final cache = SqliteRemoteFeatureFlagCache(SqliteVNextContext(database));
    final record = RemoteFlagRecord(
      flag: MayhemFeatureFlag.remoteContentEnabled,
      enabled: true,
      requiredCapabilityKey: 'remote_content',
      requiredCapabilityRevision: 2,
      updatedAt: DateTime.utc(2026, 7, 13, 12),
    );
    await cache.save(
      records: [record],
      fetchedAt: DateTime.utc(2026, 7, 13, 12),
      expiresAt: DateTime.utc(2026, 7, 13, 18),
    );

    final unsupported = await cache.load(
      now: DateTime.utc(2026, 7, 13, 13),
      capabilities: CapabilityRevisionSet(const {'remote_content': 1}),
    );
    final supported = await cache.load(
      now: DateTime.utc(2026, 7, 13, 13),
      capabilities: CapabilityRevisionSet(const {'remote_content': 2}),
    );
    final expired = await cache.load(
      now: DateTime.utc(2026, 7, 13, 19),
      capabilities: CapabilityRevisionSet(const {'remote_content': 2}),
    );

    expect(
      unsupported.isEnabled(MayhemFeatureFlag.remoteContentEnabled),
      isFalse,
    );
    expect(supported.isEnabled(MayhemFeatureFlag.remoteContentEnabled), isTrue);
    expect(expired.isEnabled(MayhemFeatureFlag.remoteContentEnabled), isFalse);
    expect(
      jsonDecode(
        database.executor
                .rows('feature_flags_cache')
                .firstWhere(
                  (row) => row['flag_key'] == 'account_linking_enabled',
                )['value_json']
            as String,
      ),
      containsPair('enabled', false),
    );
  });

  test('server correction notice is consumed exactly once', () async {
    final database = MemoryVNextDatabase();
    final store = SqliteProjectionReconciliationStore(
      SqliteVNextContext(database),
    );
    final server = _serverProjection();
    final notice = CorrectionNotice(
      noticeId: 'projection:1:rank_corrected',
      reasons: const {CorrectionReason.rankCorrected},
      createdAt: DateTime.utc(2026, 7, 13, 12),
    );
    final state = ReconciledState(
      projection: server.projection,
      momentum: server.projection.momentum,
      serverProjectionRevision: 1,
      applied: true,
      correctionNotice: notice,
    );

    await store.commit(state);
    final first = await store.takePendingCorrectionNotice();
    final second = await store.takePendingCorrectionNotice();
    await store.commit(state);
    final replayed = await store.takePendingCorrectionNotice();

    expect(first?.noticeId, notice.noticeId);
    expect(first?.reasons, {CorrectionReason.rankCorrected});
    expect(second, isNull);
    expect(replayed, isNull);
    expect(await store.loadLastServerProjectionRevision(), 1);
  });

  test(
    'server-owned artifacts commit atomically and corrupt cache clears',
    () async {
      final database = MemoryVNextDatabase();
      final store = SqliteProjectionReconciliationStore(
        SqliteVNextContext(database),
      );
      final server = _serverProjection();
      final artifact = OwnedFounderArtifact(
        artifactId: 'founder-1',
        seasonId: 'season-0',
        seasonRevision: 1,
        bossEventId: 'boss-0',
        unlockedAt: DateTime.utc(2026, 7, 13, 12, 30),
      );

      await store.commit(
        ReconciledState(
          projection: server.projection,
          momentum: server.projection.momentum,
          serverProjectionRevision: 2,
          applied: true,
          ownedArtifacts: [artifact],
        ),
      );

      final restored = await store.loadOwnedArtifacts();
      expect(restored.single.artifactId, artifact.artifactId);
      expect(restored.single.unlockedAt, artifact.unlockedAt);

      await database.executor.update(
        'app_metadata',
        {'value': '{broken'},
        where: 'key = ?',
        whereArgs: ['sync.owned_artifacts.v1'],
      );
      expect(await store.loadLastServerProjectionRevision(), 0);
      expect(await store.loadOwnedArtifacts(), isEmpty);
      expect(
        database.executor
            .rows('app_metadata')
            .where((row) => row['key'] == 'sync.owned_artifacts.v1'),
        isEmpty,
      );
    },
  );
}

EventEnvelopeV2 _event(String eventId, int sequence) => EventEnvelopeV2(
  eventId: eventId,
  eventType: CanonicalEventTypeV2.challengeCompleted,
  localUserId: 'local-user',
  installationId: 'installation-id',
  clientSequence: sequence,
  occurredAtUtc: DateTime.utc(2026, 7, 13, 12),
  timezoneId: 'Europe/Moscow',
  timezoneOffsetMinutes: 180,
  assignmentId: 'assignment-id',
  attemptId: 'attempt-id',
  contentId: 'challenge',
  contentRevision: 1,
  payload: const {'rewardXp': 100, 'felt': 'aboutAsExpected'},
);

ServerProjectionSnapshot _serverProjection() =>
    ServerProjectionSnapshot.fromJson({
      'totalXp': 0,
      'traitXp': {
        'initiation': 0,
        'expression': 0,
        'connection': 0,
        'presence': 0,
      },
      'rank': {
        'family': 'spark',
        'tier': 1,
        'configRevision': 'rank_config_dev_v1',
      },
      'rewardPolicyRevision': 'reward_policy_dev_v1',
      'completedCount': 0,
      'attemptedCount': 0,
      'projectionRevision': 1,
      'updatedAt': '2026-07-13T12:00:00.000Z',
      'difficulty': <String, Object?>{},
      'momentum': {
        'currentDays': 0,
        'longestDays': 0,
        'shieldsAvailable': 0,
        'protectedLocalDates': <String>[],
        'policyRevision': 'momentum_policy_dev_v1',
        'projectionRevision': 1,
      },
    });
