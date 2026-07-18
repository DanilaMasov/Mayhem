import 'package:flutter_test/flutter_test.dart';
import 'package:mayhem_mobile/app/vnext/vnext_runtime.dart';
import 'package:mayhem_mobile/core/feature_flags/feature_flags.dart';
import 'package:mayhem_mobile/features/challenge/domain/challenge_models.dart';
import 'package:mayhem_mobile/features/season/application/season_bootstrap_activator.dart';
import 'package:mayhem_mobile/features/season/domain/season_experience_state.dart';
import 'package:mayhem_mobile/features/sync/domain/backend_models.dart';

import '../../support/vnext_runtime_harness.dart';

void main() {
  test(
    'cross-device participation is active without a local Join event',
    () async {
      final runtime = await _runtime();
      addTearDown(runtime.dispose);

      await _activator(runtime).apply(
        snapshot: _snapshot(participation: _participation(days: {1, 2})),
        flags: _flags,
      );
      await runtime.completeRemoteRefresh(succeeded: true);

      expect(await runtime.store.seasonActions.latestJoin('season-0'), isNull);
      expect(runtime.season.state.availability, SeasonAvailability.ready);
      expect(runtime.season.state.membership, SeasonMembership.active);
      expect(runtime.season.state.participation?.completedDays, {1, 2});
      expect(runtime.season.state.participation?.serverConfirmed, isTrue);
    },
  );

  test('remote refresh preserves only a same-revision pending Day', () async {
    final runtime = await _runtime();
    addTearDown(runtime.dispose);
    final activator = _activator(runtime);
    await activator.apply(
      snapshot: _snapshot(participation: _participation()),
      flags: _flags,
    );

    final staged = await runtime.seasonParticipation.stageDay(4);
    await activator.apply(
      snapshot: _snapshot(participation: _participation(days: {1, 2})),
      flags: _flags,
    );
    await runtime.season.initialize();

    final state = await runtime.store.seasonParticipation.load('season-0');
    expect(state?.completedDays, {1, 2, 4});
    expect(state?.serverConfirmed, isTrue);
    expect(runtime.season.state.dayPhase, SeasonDayPhase.failedRetryable);
    expect(
      (await runtime.store.seasonActions.latestDays('season-0'))[4]?.eventId,
      staged.eventId,
    );
  });

  test('empty server state does not erase a pending Join', () async {
    final runtime = await _runtime();
    addTearDown(runtime.dispose);
    final activator = _activator(runtime);
    await activator.apply(snapshot: _snapshot(), flags: _flags);
    final staged = await runtime.seasonParticipation.stageJoin();

    await activator.apply(snapshot: _snapshot(), flags: _flags);
    await runtime.season.initialize();

    final state = await runtime.store.seasonParticipation.load('season-0');
    expect(state, isNotNull);
    expect(state?.serverConfirmed, isFalse);
    expect(
      runtime.season.state.membership,
      SeasonMembership.joinFailedRetryable,
    );
    expect(
      (await runtime.store.seasonActions.latestJoin('season-0'))?.eventId,
      staged.eventId,
    );
  });

  test('server base preserves a same-revision pending Boss', () async {
    final runtime = await _runtime();
    addTearDown(runtime.dispose);
    final activator = _activator(runtime);
    await activator.apply(
      snapshot: _snapshot(participation: _participation()),
      flags: _flags,
    );
    final staged = await runtime.seasonParticipation.stageBoss(
      ChallengeRouteType.normal,
    );

    await activator.apply(
      snapshot: _snapshot(participation: _participation()),
      flags: _flags,
    );
    await runtime.season.initialize();

    final state = await runtime.store.seasonParticipation.load('season-0');
    expect(state?.bossParticipatedAt, DateTime.utc(2026, 7, 13, 9));
    expect(state?.serverConfirmed, isTrue);
    expect(runtime.season.state.bossPhase, SeasonBossPhase.failedRetryable);
    expect(
      (await runtime.store.seasonActions.latestBoss(
        'season-0',
        'boss-0',
      ))?.eventId,
      staged.eventId,
    );
  });

  test('new server snapshot replaces stale cross-device fields', () async {
    final runtime = await _runtime();
    addTearDown(runtime.dispose);
    final activator = _activator(runtime);
    await activator.apply(
      snapshot: _snapshot(participation: _participation(days: {1})),
      flags: _flags,
    );

    await activator.apply(
      snapshot: _snapshot(
        participation: _participation(
          days: {1, 2, 3},
          bossParticipatedAt: DateTime.utc(2026, 7, 13, 8, 30),
        ),
      ),
      flags: _flags,
    );

    final state = await runtime.store.seasonParticipation.load('season-0');
    expect(state?.completedDays, {1, 2, 3});
    expect(state?.bossParticipatedAt, DateTime.utc(2026, 7, 13, 8, 30));
  });

  test(
    'server absence clears stale participation without pending actions',
    () async {
      final runtime = await _runtime();
      addTearDown(runtime.dispose);
      final activator = _activator(runtime);
      await activator.apply(
        snapshot: _snapshot(participation: _participation(days: {1})),
        flags: _flags,
      );

      await activator.apply(snapshot: _snapshot(), flags: _flags);
      await runtime.season.initialize();

      expect(await runtime.store.seasonParticipation.load('season-0'), isNull);
      expect(runtime.season.state.membership, SeasonMembership.notJoined);
    },
  );
}

Future<VNextRuntime> _runtime() => buildVNextTestRuntime(
  debugOverrides: const {
    MayhemFeatureFlag.newFeedEnabled: true,
    MayhemFeatureFlag.seasonZeroEnabled: true,
    MayhemFeatureFlag.bossRaidEnabled: true,
  },
);

SeasonBootstrapActivator _activator(VNextRuntime runtime) =>
    SeasonBootstrapActivator(
      localActivationEnabled: true,
      store: runtime.store.season,
      participation: runtime.store.seasonParticipation,
      actions: runtime.store.seasonActions,
    );

final _flags = FeatureFlagSnapshot(
  values: {
    MayhemFeatureFlag.seasonZeroEnabled: true,
    MayhemFeatureFlag.bossRaidEnabled: true,
    MayhemFeatureFlag.socialProofEnabled: false,
  },
);

RemoteSeasonParticipationSnapshot _participation({
  Set<int> days = const {},
  DateTime? bossParticipatedAt,
}) => RemoteSeasonParticipationSnapshot(
  seasonId: 'season-0',
  seasonRevision: 1,
  joinedAt: DateTime.utc(2026, 7, 10, 1),
  completedDays: days,
  bossParticipatedAt: bossParticipatedAt,
);

RemoteSeasonSnapshot _snapshot({
  RemoteSeasonParticipationSnapshot? participation,
}) => RemoteSeasonSnapshot(
  seasonId: 'season-0',
  revision: 1,
  title: 'Нулевая неделя',
  startsAt: DateTime.utc(2026, 7, 10),
  endsAt: DateTime.utc(2026, 7, 17),
  participation: participation,
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
