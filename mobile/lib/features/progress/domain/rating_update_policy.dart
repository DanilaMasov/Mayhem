import '../../challenge/domain/challenge_models.dart';

class RatingUpdate {
  const RatingUpdate({
    required this.previousScore,
    required this.score,
    required this.delta,
    required this.algorithmRevision,
  });

  final int previousScore;
  final int score;
  final int delta;
  final String algorithmRevision;
}

/// A compact competitive rating model. XP remains permanent, while this score
/// can move in both directions so a prestige title reflects recent outcomes.
class RatingUpdatePolicy {
  const RatingUpdatePolicy({
    this.algorithmRevision = 'rating_model_dev_v1',
    this.minimumScore = 0,
    this.maximumScore = 5000,
  });

  final String algorithmRevision;
  final int minimumScore;
  final int maximumScore;

  RatingUpdate update({
    required int currentScore,
    required AttemptOutcome outcome,
    required FeltComparedToExpected felt,
    required ChallengeRouteType route,
    required int intensity,
    required int repeatMultiplierPercent,
  }) {
    if (algorithmRevision.trim().isEmpty ||
        currentScore < minimumScore ||
        currentScore > maximumScore ||
        intensity < 1 ||
        intensity > 5 ||
        repeatMultiplierPercent < 0 ||
        repeatMultiplierPercent > 100) {
      throw const FormatException('Rating observation is invalid');
    }

    var raw = switch ((outcome, felt)) {
      (AttemptOutcome.completed, FeltComparedToExpected.easierThanExpected) =>
        18,
      (AttemptOutcome.completed, FeltComparedToExpected.aboutAsExpected) => 25,
      (AttemptOutcome.completed, FeltComparedToExpected.harderThanExpected) =>
        32,
      (AttemptOutcome.completed, FeltComparedToExpected.stoppedEarly) => 5,
      (AttemptOutcome.attempted, FeltComparedToExpected.easierThanExpected) =>
        8,
      (AttemptOutcome.attempted, FeltComparedToExpected.aboutAsExpected) => 3,
      (AttemptOutcome.attempted, FeltComparedToExpected.harderThanExpected) =>
        -12,
      (AttemptOutcome.attempted, FeltComparedToExpected.stoppedEarly) => -22,
    };
    if (raw > 0) {
      raw += (intensity - 3) * 2;
      if (route == ChallengeRouteType.advanced) {
        raw = _roundHalfUp(raw * 115 / 100);
      } else if (route == ChallengeRouteType.lowPressure) {
        raw = _roundHalfUp(raw * 80 / 100);
      }
      raw = _roundHalfUp(raw * repeatMultiplierPercent / 100);
    } else if (raw < 0 && route == ChallengeRouteType.lowPressure) {
      raw = _roundHalfUp(raw * 50 / 100);
    }
    final next = (currentScore + raw).clamp(minimumScore, maximumScore);
    return RatingUpdate(
      previousScore: currentScore,
      score: next,
      delta: next - currentScore,
      algorithmRevision: algorithmRevision,
    );
  }

  int _roundHalfUp(num value) =>
      value >= 0 ? (value + 0.5).floor() : (value - 0.5).ceil();
}
