import '../../progress/domain/progress_models.dart';

enum OnboardingStage { opening, calibration, safety, profileReveal, completed }

class OnboardingProgress {
  OnboardingProgress({
    required this.stage,
    required this.calibrationRevision,
    required Map<Trait, int> answerIndexByTrait,
    required this.acceptedSafetyRevision,
    required this.migratedFromLegacy,
  }) : answerIndexByTrait = Map.unmodifiable(answerIndexByTrait) {
    if (calibrationRevision.trim().isEmpty || acceptedSafetyRevision < 0) {
      throw const FormatException('Onboarding revision is invalid');
    }
    for (final entry in answerIndexByTrait.entries) {
      if (entry.value < 0 || entry.value > 3) {
        throw const FormatException('Calibration answer is invalid');
      }
    }
  }

  factory OnboardingProgress.fresh() => OnboardingProgress(
    stage: OnboardingStage.opening,
    calibrationRevision: CalibrationPolicy.revision,
    answerIndexByTrait: const {},
    acceptedSafetyRevision: 0,
    migratedFromLegacy: false,
  );

  factory OnboardingProgress.migrated({required bool safetyAccepted}) =>
      OnboardingProgress(
        stage: safetyAccepted
            ? OnboardingStage.completed
            : OnboardingStage.safety,
        calibrationRevision: CalibrationPolicy.revision,
        answerIndexByTrait: const {},
        acceptedSafetyRevision: safetyAccepted
            ? CalibrationPolicy.safetyRevision
            : 0,
        migratedFromLegacy: true,
      );

  final OnboardingStage stage;
  final String calibrationRevision;
  final Map<Trait, int> answerIndexByTrait;
  final int acceptedSafetyRevision;
  final bool migratedFromLegacy;

  bool get isComplete =>
      stage == OnboardingStage.completed &&
      acceptedSafetyRevision >= CalibrationPolicy.safetyRevision;

  OnboardingProgress copyWith({
    OnboardingStage? stage,
    Map<Trait, int>? answerIndexByTrait,
    int? acceptedSafetyRevision,
  }) => OnboardingProgress(
    stage: stage ?? this.stage,
    calibrationRevision: calibrationRevision,
    answerIndexByTrait: answerIndexByTrait ?? this.answerIndexByTrait,
    acceptedSafetyRevision:
        acceptedSafetyRevision ?? this.acceptedSafetyRevision,
    migratedFromLegacy: migratedFromLegacy,
  );

  Map<String, Object?> toJson() => {
    'stage': stage.name,
    'calibrationRevision': calibrationRevision,
    'answerIndexByTrait': {
      for (final entry in answerIndexByTrait.entries)
        entry.key.name: entry.value,
    },
    'acceptedSafetyRevision': acceptedSafetyRevision,
    'migratedFromLegacy': migratedFromLegacy,
  };

  factory OnboardingProgress.fromJson(Map<String, dynamic> json) {
    final answers =
        json['answerIndexByTrait'] as Map<String, dynamic>? ?? const {};
    final acceptedRevision =
        (json['acceptedSafetyRevision'] as num?)?.toInt() ?? 0;
    var stage = OnboardingStage.values.byName(
      json['stage'] as String? ?? OnboardingStage.opening.name,
    );
    if (stage == OnboardingStage.completed &&
        acceptedRevision < CalibrationPolicy.safetyRevision) {
      stage = OnboardingStage.safety;
    }
    return OnboardingProgress(
      stage: stage,
      calibrationRevision:
          json['calibrationRevision'] as String? ?? CalibrationPolicy.revision,
      answerIndexByTrait: {
        for (final entry in answers.entries)
          Trait.values.byName(entry.key): (entry.value as num).toInt(),
      },
      acceptedSafetyRevision: acceptedRevision,
      migratedFromLegacy: json['migratedFromLegacy'] == true,
    );
  }
}

abstract final class CalibrationPolicy {
  static const revision = 'calibration_config_dev_v1';
  static const safetyRevision = 1;
  static const traitOrder = [
    Trait.initiation,
    Trait.expression,
    Trait.connection,
    Trait.presence,
  ];
  static const _ratings = [3.5, 2.8, 2.1, 1.5];

  static double ratingFor(int answerIndex) {
    if (answerIndex < 0 || answerIndex >= _ratings.length) {
      throw const FormatException('Calibration answer is out of range');
    }
    return _ratings[answerIndex];
  }

  static int signalFor(int answerIndex) =>
      (ratingFor(answerIndex) * 20).round();

  static Map<Trait, DifficultyState> difficulty(
    Map<Trait, int> answers,
    DateTime at,
  ) {
    if (!traitOrder.every(answers.containsKey)) {
      throw const FormatException('Calibration is incomplete');
    }
    return {
      for (final trait in traitOrder)
        trait: DifficultyState(
          trait: trait,
          rating: ratingFor(answers[trait]!),
          confidence: 0.25,
          observations: 0,
          recommendedIntensity: ratingFor(answers[trait]!).round().clamp(1, 5),
          updatedAt: at.toUtc(),
        ),
    };
  }
}
