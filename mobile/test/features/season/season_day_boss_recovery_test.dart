import 'package:flutter_test/flutter_test.dart';
import 'package:mayhem_mobile/app/vnext/vnext_runtime.dart';
import 'package:mayhem_mobile/core/feature_flags/feature_flags.dart';
import 'package:mayhem_mobile/features/challenge/domain/challenge_models.dart';
import 'package:mayhem_mobile/features/season/domain/season_action_journal.dart';
import 'package:mayhem_mobile/features/season/domain/season_experience_state.dart';
import 'package:mayhem_mobile/features/sync/domain/backend_models.dart';

import '../../support/memory_vnext_database.dart';
import '../../support/vnext_runtime_harness.dart';

void main() {
  test('Day becomes completed only after its exact server ACK', () async {
    final runtime = await _joinedRuntime();
    addTearDown(runtime.dispose);
    runtime.season.attachRemote(
      synchronize: () => _ackPending(runtime, 'season_day_completed'),
    );

    expect(runtime.season.state.dayPhase, SeasonDayPhase.available);
    await runtime.season.completeDay();

    expect(runtime.season.state.dayPhase, SeasonDayPhase.completed);
    expect(
      (await runtime.store.seasonActions.latestDays('season-0'))[4]?.delivery,
      SeasonActionDelivery.synced,
    );
  });

  test(
    'pending Day survives process death and retries the same event',
    () async {
      final database = buildVNextTestDatabase();
      final first = await _joinedRuntime(database: database);
      final staged = await first.seasonParticipation.stageDay(4);
      first.dispose();

      final restored = await _joinedRuntime(
        database: database,
        seedSeason: false,
        seedJoin: false,
      );
      addTearDown(restored.dispose);
      restored.season.attachRemote(
        synchronize: () => _ackPending(restored, 'season_day_completed'),
      );

      expect(restored.season.state.dayPhase, SeasonDayPhase.failedRetryable);
      await restored.season.completeDay();

      expect(restored.season.state.dayPhase, SeasonDayPhase.completed);
      final events = database.executor
          .rows('event_log_v2')
          .where((row) => row['event_type'] == 'season_day_completed');
      expect(events, hasLength(1));
      expect(events.single['event_id'], staged.eventId);
    },
  );

  test('Day rejection rolls back only the optimistic day', () async {
    final runtime = await _joinedRuntime();
    addTearDown(runtime.dispose);
    runtime.season.attachRemote(
      synchronize: () =>
          _ackPending(runtime, 'season_day_completed', accepted: false),
    );

    await runtime.season.completeDay();

    expect(runtime.season.state.membership, SeasonMembership.active);
    expect(runtime.season.state.dayPhase, SeasonDayPhase.failedRetryable);
    expect(
      (await runtime.store.seasonParticipation.load('season-0'))!.completedDays,
      isNot(contains(4)),
    );
  });

  test(
    'Boss network retry reuses one event and exact ACK confirms it',
    () async {
      final database = buildVNextTestDatabase();
      final runtime = await _joinedRuntime(database: database);
      addTearDown(runtime.dispose);
      var online = false;
      runtime.season.attachRemote(
        synchronize: () async {
          if (!online) return false;
          return _ackPending(runtime, 'boss_participated');
        },
      );

      await runtime.season.participateBoss(ChallengeRouteType.lowPressure);
      expect(runtime.season.state.bossPhase, SeasonBossPhase.failedRetryable);
      expect(runtime.season.retriesPendingBoss, isTrue);
      online = true;
      await runtime.season.participateBoss(ChallengeRouteType.normal);

      expect(
        runtime.season.state.bossPhase,
        SeasonBossPhase.alreadyParticipated,
      );
      expect(runtime.season.retriesPendingBoss, isFalse);
      final events = database.executor
          .rows('event_log_v2')
          .where((row) => row['event_type'] == 'boss_participated');
      expect(events, hasLength(1));
      expect(
        (await runtime.store.seasonActions.latestBoss(
          'season-0',
          'boss-0',
        ))?.delivery,
        SeasonActionDelivery.synced,
      );
    },
  );

  test(
    'Boss rejection clears optimistic participation for safe retry',
    () async {
      final runtime = await _joinedRuntime();
      addTearDown(runtime.dispose);
      runtime.season.attachRemote(
        synchronize: () =>
            _ackPending(runtime, 'boss_participated', accepted: false),
      );

      await runtime.season.participateBoss(ChallengeRouteType.normal);

      expect(runtime.season.state.bossPhase, SeasonBossPhase.failedRetryable);
      expect(
        (await runtime.store.seasonParticipation.load(
          'season-0',
        ))?.bossParticipatedAt,
        isNull,
      );
      expect(runtime.season.canParticipateBoss, isTrue);
    },
  );
}

Future<VNextRuntime> _joinedRuntime({
  MemoryVNextDatabase? database,
  bool seedSeason = true,
  bool seedJoin = true,
}) async {
  final runtime = await buildVNextTestRuntime(
    database: database,
    debugOverrides: const {
      MayhemFeatureFlag.newFeedEnabled: true,
      MayhemFeatureFlag.seasonZeroEnabled: true,
      MayhemFeatureFlag.bossRaidEnabled: true,
    },
  );
  if (seedSeason) await runtime.store.season.saveValidatedSnapshot(_season());
  if (seedJoin) {
    await runtime.seasonParticipation.stageJoin();
    await _ackPending(runtime, 'season_joined');
  }
  await runtime.season.initialize();
  return runtime;
}

Future<bool> _ackPending(
  VNextRuntime runtime,
  String eventType, {
  bool accepted = true,
}) async {
  final event = (await runtime.store.eventSync.loadAllPending()).singleWhere(
    (event) => event.eventType.wireName == eventType,
  );
  await runtime.store.eventSync.applyServerResults(
    results: [
      RemoteEventResult(
        eventId: event.eventId,
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
      'startsAt': '2026-07-13T08:00:00.000Z',
      'endsAt': '2026-07-13T10:00:00.000Z',
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
