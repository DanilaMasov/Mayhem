import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mayhem_mobile/core/sync/event_envelope_v2.dart';
import 'package:mayhem_mobile/features/challenge/domain/challenge_models.dart';
import 'package:mayhem_mobile/features/season/application/season_participation_coordinator.dart';
import 'package:mayhem_mobile/features/season/domain/season_participation_state.dart';
import 'package:mayhem_mobile/features/sync/domain/backend_models.dart';
import 'package:mayhem_mobile/infrastructure/sqlite/sqlite_season_package_store.dart';
import 'package:mayhem_mobile/infrastructure/sqlite/sqlite_season_participation_repository.dart';
import 'package:mayhem_mobile/infrastructure/sqlite/sqlite_vnext_context.dart';

import '../../support/memory_vnext_database.dart';

void main() {
  test(
    'join, day and Boss participation commit canonical events once',
    () async {
      final harness = await _Harness.create();

      expect(await harness.coordinator.join(), isTrue);
      expect(await harness.coordinator.join(), isFalse);
      expect(await harness.coordinator.completeDay(1), isTrue);
      expect(await harness.coordinator.completeDay(1), isFalse);
      harness.now = DateTime.utc(2026, 8, 7, 13);
      expect(
        await harness.coordinator.participateBoss(
          ChallengeRouteType.lowPressure,
        ),
        isTrue,
      );
      expect(
        await harness.coordinator.participateBoss(
          ChallengeRouteType.lowPressure,
        ),
        isFalse,
      );

      final state = await harness.participation.load('season_social_reset_0');
      expect(state?.completedDays, {1});
      expect(state?.bossParticipatedAt, harness.now);
      final events = harness.database.executor.rows('event_log_v2');
      expect(events.map((row) => row['event_type']), [
        'season_joined',
        'season_day_completed',
        'boss_participated',
      ]);
      expect(events.map((row) => row['client_sequence']), [1, 2, 3]);
      expect(events.last['content_id'], 'boss_social_reset_content');
      expect(harness.terminalActions, 3);
    },
  );

  test('future Season day and inactive Boss window are rejected', () async {
    final harness = await _Harness.create();
    await harness.coordinator.join();

    await expectLater(
      () => harness.coordinator.completeDay(2),
      throwsFormatException,
    );
    await expectLater(
      () => harness.coordinator.participateBoss(ChallengeRouteType.normal),
      throwsFormatException,
    );

    expect(harness.database.executor.rows('event_log_v2'), hasLength(1));
  });

  test('event-log failure rolls participation state back atomically', () async {
    final harness = await _Harness.create();
    harness.database.executor.failNextInsertInto = 'event_log_v2';

    await expectLater(() => harness.coordinator.join(), throwsStateError);

    expect(await harness.participation.load('season_social_reset_0'), isNull);
    expect(harness.database.executor.rows('event_log_v2'), isEmpty);
  });

  test(
    'active package revision change blocks further local transitions',
    () async {
      final harness = await _Harness.create();
      await harness.coordinator.join();
      await harness.packages.saveValidatedSnapshot(_snapshot(revision: 2));

      await expectLater(
        () => harness.coordinator.completeDay(1),
        throwsStateError,
      );

      expect(harness.database.executor.rows('event_log_v2'), hasLength(1));
    },
  );

  test('cached participation identity must match its metadata key', () async {
    final harness = await _Harness.create();
    await harness.database.executor.insert('app_metadata', {
      'key': 'season.participation.season_social_reset_0',
      'value': jsonEncode({
        'seasonId': 'different-season',
        'seasonRevision': 1,
        'joinedAt': harness.now.toIso8601String(),
        'completedDays': <int>[],
        'bossParticipatedAt': null,
      }),
      'updated_at': harness.now.toIso8601String(),
    });

    await expectLater(
      () => harness.participation.load('season_social_reset_0'),
      throwsFormatException,
    );
  });

  test('repository rejects a join event with a mismatched timestamp', () async {
    final harness = await _Harness.create();
    final state = SeasonParticipationState(
      seasonId: 'season_social_reset_0',
      seasonRevision: 1,
      joinedAt: harness.now,
      completedDays: const {},
    );

    await expectLater(
      () => harness.participation.commit(
        state: state,
        event: EventDraftV2(
          eventId: 'forged-join',
          eventType: CanonicalEventTypeV2.seasonJoined,
          occurredAtUtc: harness.now.add(const Duration(minutes: 1)),
          timezoneId: 'Europe/Moscow',
          timezoneOffsetMinutes: 180,
          payload: const {
            'seasonId': 'season_social_reset_0',
            'seasonRevision': 1,
          },
        ),
      ),
      throwsFormatException,
    );
    expect(await harness.participation.load('season_social_reset_0'), isNull);
    expect(harness.database.executor.rows('event_log_v2'), isEmpty);
  });
}

class _Harness {
  _Harness._({
    required this.database,
    required this.packages,
    required this.participation,
    required this.coordinator,
    required this.now,
  });

  static Future<_Harness> create() async {
    final database = MemoryVNextDatabase(
      seed: {
        'user_identity': [
          {
            'local_user_id': 'local-user',
            'remote_user_id': null,
            'installation_id': 'installation-id',
          },
        ],
      },
    );
    var now = DateTime.utc(2026, 8, 1, 12);
    var event = 0;
    final context = SqliteVNextContext(database, clock: () => now);
    final packages = SqliteSeasonPackageStore(context);
    final participation = SqliteSeasonParticipationRepository(context);
    await packages.saveValidatedSnapshot(_snapshot());
    late final _Harness harness;
    final coordinator = SeasonParticipationCoordinator(
      packages: packages,
      participation: participation,
      eventIdGenerator: () => 'season-event-${++event}',
      clock: () => harness.now,
      timezoneId: 'Europe/Moscow',
      timezoneOffsetMinutes: 180,
      onTerminalAction: () => harness.terminalActions += 1,
    );
    harness = _Harness._(
      database: database,
      packages: packages,
      participation: participation,
      coordinator: coordinator,
      now: now,
    );
    return harness;
  }

  final MemoryVNextDatabase database;
  final SqliteSeasonPackageStore packages;
  final SqliteSeasonParticipationRepository participation;
  final SeasonParticipationCoordinator coordinator;
  DateTime now;
  int terminalActions = 0;
}

RemoteSeasonSnapshot _snapshot({int revision = 1}) => RemoteSeasonSnapshot(
  seasonId: 'season_social_reset_0',
  revision: revision,
  title: 'Social Reset',
  startsAt: DateTime.utc(2026, 8, 1),
  endsAt: DateTime.utc(2026, 8, 8),
  payload: {
    'days': [
      for (var day = 1; day <= 7; day++)
        {
          'day': day,
          'title': 'Day $day',
          'featuredContentIds': ['season_day_$day'],
        },
    ],
    'boss': {
      'bossEventId': 'boss_social_reset',
      'contentId': 'boss_social_reset_content',
      'contentRevision': 1,
      'startsAt': '2026-08-07T12:00:00.000Z',
      'endsAt': '2026-08-08T00:00:00.000Z',
      'normalRoute': {'copy': 'Complete the public route'},
      'lowPressureRoute': {'copy': 'Complete the private route'},
      'advancedRoute': {'copy': 'Complete the advanced route'},
      'advancedRouteSafetyApproved': true,
    },
    'artifacts': [
      {'artifactId': 'founder_social_reset', 'title': 'Founder'},
    ],
  },
);
