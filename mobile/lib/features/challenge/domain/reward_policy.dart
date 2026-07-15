import 'challenge_models.dart';

class RewardPolicyConfig {
  const RewardPolicyConfig({
    this.attemptPercent = 60,
    this.reflectionBonusPercent = 10,
    this.advancedRouteBonusPercent = 10,
    this.secondAttemptRepeatPercent = 75,
    this.thirdAndLaterAttemptRepeatPercent = 50,
    this.revision = 'reward_policy_dev_v1',
  });

  final int attemptPercent;
  final int reflectionBonusPercent;
  final int advancedRouteBonusPercent;
  final int secondAttemptRepeatPercent;
  final int thirdAndLaterAttemptRepeatPercent;
  final String revision;

  void validate() {
    if (attemptPercent < 0 || attemptPercent > 100) {
      throw const FormatException('Attempt reward percent is invalid');
    }
    if (reflectionBonusPercent < 0 || reflectionBonusPercent > 10) {
      throw const FormatException(
        'Reflection bonus must not exceed ten percent',
      );
    }
    if (advancedRouteBonusPercent < 0 || advancedRouteBonusPercent > 10) {
      throw const FormatException(
        'Advanced route bonus must not exceed ten percent',
      );
    }
    if (secondAttemptRepeatPercent < 0 ||
        secondAttemptRepeatPercent > 100 ||
        thirdAndLaterAttemptRepeatPercent < 0 ||
        thirdAndLaterAttemptRepeatPercent > secondAttemptRepeatPercent ||
        revision.trim().isEmpty) {
      throw const FormatException('Reward policy configuration is invalid');
    }
  }
}

class ChallengeReward {
  const ChallengeReward({
    required this.xp,
    required this.policyRevision,
    required this.repeatMultiplierPercent,
  });

  final int xp;
  final String policyRevision;
  final int repeatMultiplierPercent;
}

class RewardPolicy {
  RewardPolicy(this.config) {
    config.validate();
  }

  final RewardPolicyConfig config;

  ChallengeReward calculate({
    required ChallengeDefinition definition,
    required AttemptOutcome outcome,
    required ChallengeRouteType route,
    required bool reflectionSubmitted,
    int priorTerminalAttemptsWithinRollingSevenDays = 0,
  }) {
    if (priorTerminalAttemptsWithinRollingSevenDays < 0) {
      throw const FormatException('Prior attempt count must not be negative');
    }
    var percent = outcome == AttemptOutcome.completed
        ? 100
        : config.attemptPercent;
    if (reflectionSubmitted) percent += config.reflectionBonusPercent;
    if (route == ChallengeRouteType.advanced &&
        definition.advancedRouteSafetyApproved) {
      percent += config.advancedRouteBonusPercent;
    }
    final repeatMultiplierPercent =
        switch (priorTerminalAttemptsWithinRollingSevenDays) {
          0 => 100,
          1 => config.secondAttemptRepeatPercent,
          _ => config.thirdAndLaterAttemptRepeatPercent,
        };
    return ChallengeReward(
      xp:
          (definition.baseXp * percent * repeatMultiplierPercent + 5000) ~/
          10000,
      policyRevision: config.revision,
      repeatMultiplierPercent: repeatMultiplierPercent,
    );
  }
}
