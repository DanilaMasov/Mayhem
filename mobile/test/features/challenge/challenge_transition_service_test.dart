import 'package:flutter_test/flutter_test.dart';
import 'package:mayhem_mobile/features/challenge/domain/challenge_models.dart';
import 'package:mayhem_mobile/features/challenge/domain/challenge_transition_service.dart';
import 'package:mayhem_mobile/features/challenge/domain/reward_policy.dart';
import 'package:mayhem_mobile/features/feed/domain/feed_models.dart';
import 'package:mayhem_mobile/features/progress/domain/progress_models.dart';

void main() {
  final definition = ChallengeDefinition(
    contentId: 'challenge_start_first_001',
    revision: 3,
    title: 'Start first',
    primaryTrait: Trait.initiation,
    secondaryTraitWeights: const {Trait.presence: 0.25},
    intensity: 2,
    baseXp: 50,
    contextTags: const {'event'},
    completionCriteria: 'Introduce yourself and ask one contextual question.',
    normalRoute: const ChallengeRoute(copy: 'Approach one person.'),
    lowPressureRoute: const ChallengeRoute(copy: 'Ask someone familiar.'),
    advancedRoute: const ChallengeRoute(copy: 'Ask a follow-up question.'),
    advancedRouteSafetyApproved: true,
    preparationContentIds: const ['training_followup_001'],
    momentumEligible: true,
    repeatable: true,
  );
  final assignment = FeedAssignment(
    assignmentId: 'assignment-1',
    localUserId: 'local-1',
    contentId: definition.contentId,
    contentRevision: definition.revision,
    locale: 'ru',
    position: 0,
    batchId: 'batch-1',
    assignmentReason: 'difficulty_edge',
    assignedAt: DateTime.parse('2026-07-13T10:00:00Z'),
    boundedMetadata: const {},
  );
  const transitions = ChallengeTransitionService();

  ChallengeAttempt accept() => transitions.accept(
    assignment: assignment,
    definition: definition,
    route: ChallengeRouteType.lowPressure,
    attemptId: 'attempt-1',
    acceptedAt: DateTime.parse('2026-07-13T10:01:00Z'),
    timezoneId: 'Europe/Moscow',
  );

  test('accept creates one revision-bound active attempt without Energy', () {
    final attempt = accept();

    expect(attempt.status, ChallengeAttemptStatus.active);
    expect(attempt.contentRevision, 3);
    expect(attempt.selectedRoute, ChallengeRouteType.lowPressure);
    expect(attempt.rewardAppliedLocally, isFalse);
  });

  test(
    'attempted is terminal and cannot be rewarded through a second result',
    () {
      final resolved = transitions.resolve(
        attempt: accept(),
        result: const AttemptResult(
          outcome: AttemptOutcome.attempted,
          felt: FeltComparedToExpected.harderThanExpected,
        ),
        resolvedAt: DateTime.parse('2026-07-13T10:10:00Z'),
      );

      expect(resolved.status, ChallengeAttemptStatus.attempted);
      expect(
        () => transitions.resolve(
          attempt: resolved,
          result: const AttemptResult(
            outcome: AttemptOutcome.completed,
            felt: FeltComparedToExpected.aboutAsExpected,
          ),
          resolvedAt: DateTime.parse('2026-07-13T10:11:00Z'),
        ),
        throwsA(isA<ChallengeTransitionException>()),
      );
    },
  );

  test('defer and resume do not create a terminal penalty state', () {
    final deferred = transitions.defer(accept());
    final resumed = transitions.resume(deferred);

    expect(deferred.status, ChallengeAttemptStatus.deferred);
    expect(deferred.resolvedAt, isNull);
    expect(resumed.status, ChallengeAttemptStatus.active);
  });

  test('reward policy gives sixty percent for attempt and full completion', () {
    final policy = RewardPolicy(const RewardPolicyConfig());

    expect(
      policy
          .calculate(
            definition: definition,
            outcome: AttemptOutcome.attempted,
            route: ChallengeRouteType.normal,
            reflectionSubmitted: false,
          )
          .xp,
      30,
    );
    expect(
      policy
          .calculate(
            definition: definition,
            outcome: AttemptOutcome.completed,
            route: ChallengeRouteType.normal,
            reflectionSubmitted: false,
          )
          .xp,
      50,
    );
    expect(
      policy
          .calculate(
            definition: definition,
            outcome: AttemptOutcome.completed,
            route: ChallengeRouteType.normal,
            reflectionSubmitted: false,
            priorTerminalAttemptsWithinRollingSevenDays: 1,
          )
          .xp,
      38,
    );
    expect(
      policy
          .calculate(
            definition: definition,
            outcome: AttemptOutcome.completed,
            route: ChallengeRouteType.normal,
            reflectionSubmitted: false,
            priorTerminalAttemptsWithinRollingSevenDays: 2,
          )
          .xp,
      25,
    );
    expect(
      policy
          .calculate(
            definition: definition,
            outcome: AttemptOutcome.completed,
            route: ChallengeRouteType.advanced,
            reflectionSubmitted: true,
          )
          .xp,
      60,
    );
    expect(
      policy
          .calculate(
            definition: ChallengeDefinition(
              contentId: 'unapproved-advanced',
              revision: 1,
              title: 'Unapproved route',
              primaryTrait: Trait.initiation,
              secondaryTraitWeights: const {},
              intensity: 1,
              baseXp: 50,
              contextTags: const {},
              completionCriteria: 'Complete it.',
              normalRoute: const ChallengeRoute(copy: 'Normal.'),
              lowPressureRoute: const ChallengeRoute(copy: 'Low pressure.'),
              advancedRoute: const ChallengeRoute(copy: 'Advanced.'),
              preparationContentIds: const [],
              momentumEligible: true,
              repeatable: true,
            ),
            outcome: AttemptOutcome.completed,
            route: ChallengeRouteType.advanced,
            reflectionSubmitted: false,
          )
          .xp,
      50,
    );
    expect(policy.config.revision, 'reward_policy_dev_v1');
    expect(
      () => RewardPolicy(const RewardPolicyConfig(reflectionBonusPercent: 11)),
      throwsFormatException,
    );
  });
}
