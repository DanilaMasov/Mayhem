import '../../challenge/domain/challenge_models.dart';
import 'progress_models.dart';

enum DifficultySkipReason {
  tooEasy,
  tooIntense,
  notMySituation,
  notInterested,
  unsafeOrUncomfortable,
}

class DifficultyObservation {
  const DifficultyObservation({
    required this.intensity,
    this.outcome,
    this.felt,
    this.skipReason,
  });

  final int intensity;
  final AttemptOutcome? outcome;
  final FeltComparedToExpected? felt;
  final DifficultySkipReason? skipReason;
}

class DifficultyUpdatePolicy {
  const DifficultyUpdatePolicy({
    this.algorithmRevision = 'difficulty_model_dev_v1',
  });

  final String algorithmRevision;

  DifficultyState update(
    DifficultyState current,
    DifficultyObservation observation,
    DateTime updatedAt,
  ) {
    if (algorithmRevision.trim().isEmpty ||
        observation.intensity < 1 ||
        observation.intensity > 5) {
      throw const FormatException('Difficulty observation is invalid');
    }
    final delta = _delta(observation);
    final rating = (current.rating + delta).clamp(1.0, 5.0);
    return DifficultyState(
      trait: current.trait,
      rating: rating,
      confidence: (current.confidence + 0.08).clamp(0.0, 1.0),
      observations: current.observations + 1,
      recommendedIntensity: rating.round().clamp(1, 5),
      updatedAt: updatedAt.toUtc(),
    );
  }

  double _delta(DifficultyObservation observation) {
    switch (observation.skipReason) {
      case DifficultySkipReason.tooEasy:
        return 0.25;
      case DifficultySkipReason.tooIntense:
        return -0.4;
      case DifficultySkipReason.unsafeOrUncomfortable:
      case DifficultySkipReason.notMySituation:
      case DifficultySkipReason.notInterested:
        return 0;
      case null:
        break;
    }
    if (observation.outcome == null || observation.felt == null) {
      throw const FormatException('Outcome observation requires felt signal');
    }
    final completed = observation.outcome == AttemptOutcome.completed;
    return switch (observation.felt!) {
      FeltComparedToExpected.easierThanExpected => completed ? 0.30 : 0.15,
      FeltComparedToExpected.aboutAsExpected => completed ? 0.15 : 0.05,
      FeltComparedToExpected.harderThanExpected => completed ? 0.05 : -0.15,
      FeltComparedToExpected.stoppedEarly => completed ? -0.10 : -0.30,
    };
  }
}
