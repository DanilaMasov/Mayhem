import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mayhem_mobile/features/challenge/application/challenge_flow_coordinator.dart';
import 'package:mayhem_mobile/features/challenge/domain/challenge_models.dart';
import 'package:mayhem_mobile/features/challenge/domain/reward_policy.dart';
import 'package:mayhem_mobile/features/feed/domain/feed_models.dart';
import 'package:mayhem_mobile/features/progress/domain/progress_models.dart';
import 'package:mayhem_mobile/features/progress/domain/rank_policy.dart';
import 'package:mayhem_mobile/infrastructure/sqlite/sqlite_vnext_store.dart';

import '../../support/memory_vnext_database.dart';

void main() {
  final acceptedAt = DateTime.parse('2026-07-13T09:00:00Z');
  final resolvedAt = DateTime.parse('2026-07-13T09:10:00Z');

  test('Attempted earns 60 percent XP and continues Momentum', () async {
    final harness = _Harness(acceptedAt);
    final acceptance = await harness.accept();

    final resolution = await harness.coordinator.resolve(
      attemptId: acceptance.attempt.attemptId,
      definition: harness.definition,
      outcome: AttemptOutcome.attempted,
      felt: FeltComparedToExpected.stoppedEarly,
      resolvedAt: resolvedAt,
      localDate: '2026-07-13',
      timezoneOffsetMinutes: 180,
    );

    expect(resolution.applied, isTrue);
    expect(resolution.reward?.xp, 45);
    expect(resolution.projection.totalXp, 45);
    expect(resolution.projection.traitXp[Trait.initiation], 45);
    expect(resolution.projection.traitXp[Trait.expression], 9);
    expect(resolution.projection.attemptedCount, 1);
    expect(resolution.projection.completedCount, 0);
    expect(resolution.momentum.currentDays, 1);
    expect(resolution.momentum.earnedToday, isTrue);
    expect(
      harness.eventTypes,
      containsAllInOrder([
        'challenge_accepted',
        'challenge_attempted',
        'momentum_day_earned',
      ]),
    );
  });

  test(
    'Completed earns full reward and repeated callback is a no-op',
    () async {
      final harness = _Harness(acceptedAt);
      final acceptance = await harness.accept();

      final first = await harness.coordinator.resolve(
        attemptId: acceptance.attempt.attemptId,
        definition: harness.definition,
        outcome: AttemptOutcome.completed,
        felt: FeltComparedToExpected.aboutAsExpected,
        resolvedAt: resolvedAt,
        localDate: '2026-07-13',
        timezoneOffsetMinutes: 180,
      );
      final repeated = await harness.coordinator.resolve(
        attemptId: acceptance.attempt.attemptId,
        definition: harness.definition,
        outcome: AttemptOutcome.completed,
        felt: FeltComparedToExpected.aboutAsExpected,
        resolvedAt: resolvedAt,
        localDate: '2026-07-13',
        timezoneOffsetMinutes: 180,
      );

      expect(first.reward?.xp, 75);
      expect(first.projection.totalXp, 75);
      expect(first.projection.completedCount, 1);
      expect(repeated.applied, isFalse);
      expect(repeated.reward, isNull);
      expect(repeated.projection.totalXp, 75);
      expect(
        harness.eventTypes.where((type) => type == 'challenge_completed'),
        hasLength(1),
      );
    },
  );

  test(
    'optional reflection adds bounded bonus and note remains local',
    () async {
      final harness = _Harness(acceptedAt);
      final acceptance = await harness.accept();

      final resolution = await harness.coordinator.resolve(
        attemptId: acceptance.attempt.attemptId,
        definition: harness.definition,
        outcome: AttemptOutcome.completed,
        felt: FeltComparedToExpected.easierThanExpected,
        resolvedAt: resolvedAt,
        localDate: '2026-07-13',
        timezoneOffsetMinutes: 180,
        reflection: const ReflectionInput(
          fearBefore: 8,
          feelAfter: 4,
          wantRepeat: true,
          privateNote: 'I did the hard part',
        ),
      );

      expect(resolution.reward?.xp, 83);
      final reflection = await harness.store.reflection.findForAttempt(
        acceptance.attempt.attemptId,
      );
      expect(reflection?.privateNote, 'I did the hard part');
      final eventPayloads = harness.database.executor
          .rows('event_log_v2')
          .map((row) => row['payload_json'] as String);
      expect(
        eventPayloads,
        everyElement(isNot(contains('I did the hard part'))),
      );
      final reflectionPayload =
          jsonDecode(
                harness.database.executor
                        .rows('event_log_v2')
                        .singleWhere(
                          (row) => row['event_type'] == 'reflection_submitted',
                        )['payload_json']
                    as String,
              )
              as Map<String, dynamic>;
      expect(reflectionPayload['hasPrivateNote'], isTrue);
    },
  );

  test('stale event sequence metadata heals before result commit', () async {
    final harness = _Harness(acceptedAt);
    final acceptance = await harness.accept();
    await harness.store.metadata.write('client_sequence:installation-1', '0');

    final resolution = await harness.coordinator.resolve(
      attemptId: acceptance.attempt.attemptId,
      definition: harness.definition,
      outcome: AttemptOutcome.completed,
      felt: FeltComparedToExpected.aboutAsExpected,
      resolvedAt: resolvedAt,
      localDate: '2026-07-13',
      timezoneOffsetMinutes: 180,
      reflection: const ReflectionInput(
        fearBefore: 8,
        feelAfter: 10,
        wantRepeat: true,
        privateNote: '',
      ),
    );

    expect(resolution.applied, isTrue);
    final sequences = harness.database.executor
        .rows('event_log_v2')
        .map((row) => row['client_sequence'])
        .toList();
    expect(sequences, orderedEquals([1, 2, 3, 4]));
    expect(
      harness.database.executor
          .rows('private_reflections')
          .single['private_note'],
      isNull,
    );
  });

  test('same revision repeats diminish across rolling seven days', () async {
    final harness = _Harness(acceptedAt);
    final first = await harness.accept(assignmentId: 'assignment-1');
    await harness.coordinator.resolve(
      attemptId: first.attempt.attemptId,
      definition: harness.definition,
      outcome: AttemptOutcome.completed,
      felt: FeltComparedToExpected.aboutAsExpected,
      resolvedAt: resolvedAt,
      localDate: '2026-07-13',
      timezoneOffsetMinutes: 180,
    );
    final second = await harness.accept(assignmentId: 'assignment-2');
    final secondResult = await harness.coordinator.resolve(
      attemptId: second.attempt.attemptId,
      definition: harness.definition,
      outcome: AttemptOutcome.completed,
      felt: FeltComparedToExpected.aboutAsExpected,
      resolvedAt: resolvedAt.add(const Duration(hours: 1)),
      localDate: '2026-07-13',
      timezoneOffsetMinutes: 180,
    );
    final third = await harness.accept(assignmentId: 'assignment-3');
    final thirdResult = await harness.coordinator.resolve(
      attemptId: third.attempt.attemptId,
      definition: harness.definition,
      outcome: AttemptOutcome.completed,
      felt: FeltComparedToExpected.aboutAsExpected,
      resolvedAt: resolvedAt.add(const Duration(hours: 2)),
      localDate: '2026-07-13',
      timezoneOffsetMinutes: 180,
    );

    expect(secondResult.reward?.xp, 56);
    expect(secondResult.reward?.repeatMultiplierPercent, 75);
    expect(thirdResult.reward?.xp, 38);
    expect(thirdResult.reward?.repeatMultiplierPercent, 50);
  });
}

class _Harness {
  _Harness(this.acceptedAt)
    : database = MemoryVNextDatabase(seed: _seed(acceptedAt)) {
    store = SqliteVNextStore(database, clock: () => acceptedAt);
    coordinator = ChallengeFlowCoordinator(
      attempts: store.challenge,
      progress: store.progress,
      momentum: store.momentum,
      commits: store.challenge,
      rewardPolicy: RewardPolicy(const RewardPolicyConfig()),
      rankPolicy: _rankPolicy(),
      idGenerator: () => 'generated-${++_nextId}',
    );
  }

  final DateTime acceptedAt;
  final MemoryVNextDatabase database;
  late final SqliteVNextStore store;
  late final ChallengeFlowCoordinator coordinator;
  var _nextId = 0;

  final definition = ChallengeDefinition(
    contentId: 'challenge-1',
    revision: 1,
    title: 'Start the conversation',
    primaryTrait: Trait.initiation,
    secondaryTraitWeights: const {Trait.expression: 0.2},
    intensity: 2,
    baseXp: 75,
    contextTags: const {'public'},
    completionCriteria: 'Say the opening line.',
    normalRoute: const ChallengeRoute(copy: 'Say hello first.'),
    lowPressureRoute: const ChallengeRoute(copy: 'Ask one simple question.'),
    preparationContentIds: const [],
    momentumEligible: true,
    repeatable: false,
  );

  Future<ChallengeAcceptance> accept({String assignmentId = 'assignment-1'}) =>
      coordinator.accept(
        assignment: FeedAssignment(
          assignmentId: assignmentId,
          localUserId: 'local-user-1',
          contentId: definition.contentId,
          contentRevision: definition.revision,
          locale: 'ru-RU',
          position: 0,
          batchId: 'batch-1',
          assignmentReason: 'difficulty_edge',
          assignedAt: acceptedAt,
          boundedMetadata: const {},
        ),
        definition: definition,
        route: ChallengeRouteType.normal,
        acceptedAt: acceptedAt,
        timezoneId: 'Europe/Moscow',
        timezoneOffsetMinutes: 180,
      );

  List<String> get eventTypes => database.executor
      .rows('event_log_v2')
      .map((row) => row['event_type'] as String)
      .toList();

  static Map<String, List<Map<String, Object?>>> _seed(DateTime at) => {
    'user_identity': [
      {
        'local_user_id': 'local-user-1',
        'installation_id': 'installation-1',
        'remote_user_id': null,
      },
    ],
    'app_metadata': [
      {
        'key': 'client_sequence:installation-1',
        'value': '0',
        'updated_at': at.toIso8601String(),
      },
    ],
  };

  static RankPolicy _rankPolicy() => RankPolicy(
    thresholds: [
      RankThreshold(
        rank: PrestigeRank(
          family: RankFamily.spark,
          tier: 1,
          configRevision: 'test_v1',
        ),
        totalXp: 0,
        minimumTraitXp: 0,
      ),
      RankThreshold(
        rank: PrestigeRank(
          family: RankFamily.spark,
          tier: 2,
          configRevision: 'test_v1',
        ),
        totalXp: 100,
        minimumTraitXp: 10,
      ),
    ],
  );
}
