import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mayhem_mobile/features/challenge/domain/challenge_models.dart';
import 'package:mayhem_mobile/features/challenge/domain/reward_policy.dart';
import 'package:mayhem_mobile/features/progress/domain/development_rank_config.dart';
import 'package:mayhem_mobile/features/progress/domain/difficulty_update_policy.dart';
import 'package:mayhem_mobile/features/progress/domain/progress_models.dart';
import 'package:mayhem_mobile/features/streak/domain/momentum_policy.dart';
import 'package:mayhem_mobile/features/streak/domain/momentum_state.dart';

void main() {
  late Map<String, dynamic> golden;

  setUpAll(() async {
    golden =
        jsonDecode(
              await File('../contracts/v1/policy_golden.json').readAsString(),
            )
            as Map<String, dynamic>;
  });

  test('frozen revision identifiers match the shared contract', () {
    final revisions = golden['revisions'] as Map<String, dynamic>;
    expect(revisions['reward'], const RewardPolicyConfig().revision);
    expect(
      revisions['difficulty'],
      const DifficultyUpdatePolicy().algorithmRevision,
    );
    expect(revisions['rank'], DevelopmentRankConfig.revision);
    expect(revisions['momentum'], MomentumPolicy.revision);
  });

  test('reward policy matches every shared golden case', () {
    final policy = RewardPolicy(const RewardPolicyConfig());
    for (final source in golden['rewardCases'] as List<dynamic>) {
      final item = source as Map<String, dynamic>;
      final advanced = item['route'] == 'advanced';
      final reward = policy.calculate(
        definition: _definition(
          baseXp: (item['baseXp'] as num).toInt(),
          advancedApproved: item['advancedApproved'] == true,
        ),
        outcome: AttemptOutcome.values.byName(item['outcome'] as String),
        route: advanced
            ? ChallengeRouteType.advanced
            : ChallengeRouteType.normal,
        reflectionSubmitted: item['reflection'] == true,
        priorTerminalAttemptsWithinRollingSevenDays:
            (item['priorTerminalAttempts'] as num).toInt(),
      );
      expect(reward.xp, item['expectedXp'], reason: item['id'] as String);
      expect(
        reward.repeatMultiplierPercent,
        item['expectedRepeatPercent'],
        reason: item['id'] as String,
      );
    }
  });

  test('difficulty policy matches every shared golden vector', () {
    const policy = DifficultyUpdatePolicy();
    final base = DifficultyState(
      trait: Trait.presence,
      rating: 3,
      confidence: 0,
      observations: 0,
      recommendedIntensity: 3,
      updatedAt: DateTime.utc(2026, 7, 12),
    );
    for (final source in golden['difficultyCases'] as List<dynamic>) {
      final item = source as Map<String, dynamic>;
      final observation = item['skipReason'] == null
          ? DifficultyObservation(
              intensity: 3,
              outcome: AttemptOutcome.values.byName(item['outcome'] as String),
              felt: FeltComparedToExpected.values.byName(
                item['felt'] as String,
              ),
            )
          : DifficultyObservation(
              intensity: 3,
              skipReason: DifficultySkipReason.values.byName(
                item['skipReason'] as String,
              ),
            );
      final updated = policy.update(
        base,
        observation,
        DateTime.utc(2026, 7, 13),
      );
      expect(
        updated.rating,
        closeTo(3 + (item['delta'] as num).toDouble(), 0.0001),
      );
    }
  });

  test('rank ladder matches the shared golden contract', () {
    expect(
      DevelopmentRankConfig.policy().thresholds
          .map((item) => [item.rank.label, item.totalXp, item.minimumTraitXp])
          .toList(),
      golden['rankThresholds'],
    );
  });

  test('Momentum policy matches every shared golden scenario', () {
    const policy = MomentumPolicy();
    for (final source in golden['momentumCases'] as List<dynamic>) {
      final item = source as Map<String, dynamic>;
      final state = MomentumState(
        currentDays: (item['currentDays'] as num).toInt(),
        longestDays: (item['longestDays'] as num).toInt(),
        earnedToday: false,
        shieldsAvailable: (item['shields'] as num).toInt(),
        lastEarnedLocalDate: item['lastLocalDate'] as String?,
        lastEarnedAtUtc: _date(item['lastEarnedAtUtc']),
        lastEarnedTimezoneId: item['lastTimezoneId'] as String?,
        protectedLocalDates: const {},
        nextMilestone: 100,
      );
      final update = policy.earnDay(
        state,
        localDate: item['localDate'] as String,
        earnedAtUtc: DateTime.parse(item['earnedAtUtc'] as String),
        timezoneId: item['timezoneId'] as String,
      );
      expect(
        update.state.currentDays,
        item['expectedCurrentDays'],
        reason: item['id'] as String,
      );
      expect(update.state.longestDays, item['expectedLongestDays']);
      expect(update.state.shieldsAvailable, item['expectedShields']);
      expect(update.state.pendingTimezoneReview, item['expectedPending']);
    }
  });
}

ChallengeDefinition _definition({
  required int baseXp,
  required bool advancedApproved,
}) => ChallengeDefinition(
  contentId: 'golden_challenge',
  revision: 1,
  title: 'Golden challenge',
  primaryTrait: Trait.presence,
  secondaryTraitWeights: const {},
  intensity: 3,
  baseXp: baseXp,
  contextTags: const {},
  completionCriteria: 'Complete the fixture.',
  normalRoute: const ChallengeRoute(copy: 'Normal'),
  lowPressureRoute: const ChallengeRoute(copy: 'Low pressure'),
  advancedRoute: const ChallengeRoute(copy: 'Advanced'),
  advancedRouteSafetyApproved: advancedApproved,
  preparationContentIds: const [],
  momentumEligible: true,
  repeatable: true,
);

DateTime? _date(Object? value) =>
    value == null ? null : DateTime.parse(value as String).toUtc();
