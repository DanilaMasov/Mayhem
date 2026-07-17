import 'package:flutter_test/flutter_test.dart';
import 'package:mayhem_mobile/app/vnext/vnext_runtime.dart';
import 'package:mayhem_mobile/core/feature_flags/feature_flags.dart';
import 'package:mayhem_mobile/features/season/domain/season_action_journal.dart';
import 'package:mayhem_mobile/features/season/domain/season_experience_state.dart';
import 'package:mayhem_mobile/features/sync/domain/backend_models.dart';

import '../../support/memory_vnext_database.dart';
import '../../support/vnext_runtime_harness.dart';

void main() {
  test('Join becomes active only after the exact server ACK', () async {
    final runtime = await _runtime();
    addTearDown(runtime.dispose);
    runtime.season.attachRemote(
      synchronize: () => _ackLatestJoin(runtime, accepted: true),
    );

    expect(runtime.season.state.membership, SeasonMembership.notJoined);
    expect(runtime.season.canJoin, isTrue);

    await runtime.season.join();

    expect(runtime.season.state.membership, SeasonMembership.active);
    expect(
      (await runtime.store.seasonActions.latestJoin('season-0'))?.delivery,
      SeasonActionDelivery.synced,
    );
  });

  test('staged Join survives process death and retries one event', () async {
    final database = buildVNextTestDatabase();
    final first = await _runtime(database: database);

    await first.seasonParticipation.stageJoin();
    final staged = await first.store.seasonActions.latestJoin('season-0');
    expect(staged?.delivery, SeasonActionDelivery.pending);
    first.dispose();

    final restored = await _runtime(database: database, seedSeason: false);
    addTearDown(restored.dispose);
    var synchronizeCalls = 0;
    restored.season.attachRemote(
      synchronize: () async {
        synchronizeCalls += 1;
        return _ackLatestJoin(restored, accepted: true);
      },
    );

    expect(
      restored.season.state.membership,
      SeasonMembership.joinFailedRetryable,
    );
    await restored.season.join();

    expect(synchronizeCalls, 1);
    expect(restored.season.state.membership, SeasonMembership.active);
    final joinEvents = database.executor
        .rows('event_log_v2')
        .where((row) => row['event_type'] == 'season_joined');
    expect(joinEvents, hasLength(1));
    expect(joinEvents.single['event_id'], staged?.eventId);
  });

  test('network failure leaves one retryable pending Join', () async {
    final runtime = await _runtime();
    addTearDown(runtime.dispose);
    runtime.season.attachRemote(synchronize: () async => false);

    await runtime.season.join();

    expect(
      runtime.season.state.membership,
      SeasonMembership.joinFailedRetryable,
    );
    expect(
      (await runtime.store.seasonActions.latestJoin('season-0'))?.delivery,
      SeasonActionDelivery.pending,
    );
  });

  test(
    'server rejection clears optimistic participation for safe retry',
    () async {
      final runtime = await _runtime();
      addTearDown(runtime.dispose);
      runtime.season.attachRemote(
        synchronize: () => _ackLatestJoin(runtime, accepted: false),
      );

      await runtime.season.join();

      expect(
        runtime.season.state.membership,
        SeasonMembership.joinFailedRetryable,
      );
      expect(await runtime.store.seasonParticipation.load('season-0'), isNull);
      expect(runtime.season.canJoin, isTrue);
    },
  );
}

Future<VNextRuntime> _runtime({
  MemoryVNextDatabase? database,
  bool seedSeason = true,
}) async {
  final runtime = await buildVNextTestRuntime(
    database: database,
    debugOverrides: const {
      MayhemFeatureFlag.newFeedEnabled: true,
      MayhemFeatureFlag.seasonZeroEnabled: true,
      MayhemFeatureFlag.bossRaidEnabled: true,
    },
  );
  if (seedSeason) {
    await runtime.store.season.saveValidatedSnapshot(_season());
  }
  await runtime.season.initialize();
  return runtime;
}

Future<bool> _ackLatestJoin(
  VNextRuntime runtime, {
  required bool accepted,
}) async {
  final pending = await runtime.store.eventSync.loadAllPending();
  final join = pending.singleWhere(
    (event) => event.eventType.wireName == 'season_joined',
  );
  await runtime.store.eventSync.applyServerResults(
    results: [
      RemoteEventResult(
        eventId: join.eventId,
        accepted: accepted,
        disposition: accepted
            ? RemoteEventDisposition.accepted
            : RemoteEventDisposition.invalidTransition,
      ),
    ],
    receivedAt: DateTime.utc(2026, 7, 13, 9, 1),
  );
  return true;
}

RemoteSeasonSnapshot _season() => RemoteSeasonSnapshot(
  seasonId: 'season-0',
  revision: 1,
  title: 'Нулевая неделя',
  startsAt: DateTime.utc(2026, 7, 10),
  endsAt: DateTime.utc(2026, 7, 17),
  payload: {
    'days': [
      for (var day = 1; day <= 7; day++)
        {
          'day': day,
          'title': 'День $day',
          'featuredContentIds': ['q-$day'],
        },
    ],
    'boss': {
      'bossEventId': 'boss-0',
      'contentId': 'boss-content',
      'contentRevision': 1,
      'startsAt': '2026-07-16T08:00:00.000Z',
      'endsAt': '2026-07-17T00:00:00.000Z',
      'normalRoute': {'copy': 'Сделай шаг'},
      'lowPressureRoute': {'copy': 'Сделай малый шаг'},
      'advancedRoute': null,
      'advancedRouteSafetyApproved': false,
    },
    'artifacts': [
      {'artifactId': 'founder-1', 'title': 'Первопроходец'},
    ],
  },
);
