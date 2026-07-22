import 'package:flutter_test/flutter_test.dart';
import 'package:mayhem_mobile/features/challenge/domain/challenge_models.dart';
import 'package:mayhem_mobile/features/progress/domain/difficulty_update_policy.dart';
import 'package:mayhem_mobile/features/progress/domain/development_rank_config.dart';
import 'package:mayhem_mobile/features/progress/domain/progress_models.dart';
import 'package:mayhem_mobile/features/progress/domain/rating_update_policy.dart';
import 'package:mayhem_mobile/features/progress/domain/rank_policy.dart';
import 'package:mayhem_mobile/infrastructure/sqlite/sqlite_vnext_mappers.dart';

void main() {
  PrestigeRank rank(RankFamily family, int tier) => PrestigeRank(
    family: family,
    tier: tier,
    configRevision: 'development_v1',
  );

  test('rank ladder requires balanced traits and blocks one-trait farming', () {
    final policy = RankPolicy(
      thresholds: [
        RankThreshold(
          rank: rank(RankFamily.spark, 1),
          ratingScore: 1000,
          minimumTraitXp: 0,
        ),
        RankThreshold(
          rank: rank(RankFamily.spark, 2),
          ratingScore: 1100,
          minimumTraitXp: 10,
        ),
      ],
    );

    final oneTrait = policy.resolve(
      ratingScore: 1500,
      traitXp: const {Trait.initiation: 500},
    );
    expect(oneTrait.rank.label, 'ИСКРА');
    expect(oneTrait.progressToNext, 0);
    expect(
      policy
          .resolve(
            ratingScore: 1100,
            traitXp: const {
              Trait.initiation: 25,
              Trait.expression: 25,
              Trait.connection: 25,
              Trait.presence: 25,
            },
          )
          .rank
          .label,
      'ИМПУЛЬС',
    );
    expect(
      policy
          .resolve(
            ratingScore: 1050,
            traitXp: const {
              Trait.initiation: 5,
              Trait.expression: 5,
              Trait.connection: 5,
              Trait.presence: 5,
            },
          )
          .progressToNext,
      0.5,
    );
  });

  test(
    'difficulty moves toward observed growth edge with bounded confidence',
    () {
      const policy = DifficultyUpdatePolicy();
      final current = DifficultyState(
        trait: Trait.expression,
        rating: 2.0,
        confidence: 0.96,
        observations: 4,
        recommendedIntensity: 2,
        updatedAt: DateTime.utc(2026, 7, 12),
      );

      final easier = policy.update(
        current,
        const DifficultyObservation(
          intensity: 2,
          outcome: AttemptOutcome.completed,
          felt: FeltComparedToExpected.easierThanExpected,
        ),
        DateTime.utc(2026, 7, 13),
      );
      final tooIntense = policy.update(
        easier,
        const DifficultyObservation(
          intensity: 3,
          skipReason: DifficultySkipReason.tooIntense,
        ),
        DateTime.utc(2026, 7, 14),
      );

      expect(easier.rating, closeTo(2.3, 0.001));
      expect(easier.confidence, 1.0);
      expect(tooIntense.rating, closeTo(1.9, 0.001));
      expect(tooIntense.observations, 6);
      expect(policy.algorithmRevision, 'difficulty_model_dev_v1');
    },
  );

  test('development rank config exposes unique score-based titles', () {
    final thresholds = DevelopmentRankConfig.policy().thresholds;

    expect(DevelopmentRankConfig.revision, 'rank_config_dev_v2');
    expect(
      thresholds
          .map(
            (item) => [item.rank.label, item.ratingScore, item.minimumTraitXp],
          )
          .toList(),
      [
        ['ИСКРА', 1000, 0],
        ['ИМПУЛЬС', 1125, 0],
        ['РАЗРЯД', 1250, 0],
        ['ВЕКТОР', 1400, 100],
        ['ДРАЙВЕР', 1550, 150],
        ['ПРОРЫВ', 1700, 200],
        ['КАТАЛИЗАТОР', 1875, 300],
        ['РЕЗОНАНС', 2050, 400],
        ['СИНЕРГИЯ', 2250, 500],
        ['МАВЕРИК', 2475, 650],
        ['АВАНГАРД', 2700, 800],
        ['ПЕРВОПРОХОДЕЦ', 2950, 1000],
        ['МАГНИТ', 3225, 1200],
        ['ИКОНА', 3525, 1500],
        ['ЛЕГЕНДА', 3850, 1800],
        ['MAYHEM', 4200, 2200],
      ],
    );
    expect(thresholds.map((item) => item.rank.label).toSet(), hasLength(16));
  });

  test('rating rises and falls while low-pressure mode softens losses', () {
    const policy = RatingUpdatePolicy();
    final win = policy.update(
      currentScore: 1200,
      outcome: AttemptOutcome.completed,
      felt: FeltComparedToExpected.harderThanExpected,
      route: ChallengeRouteType.advanced,
      intensity: 5,
      repeatMultiplierPercent: 100,
    );
    final loss = policy.update(
      currentScore: win.score,
      outcome: AttemptOutcome.attempted,
      felt: FeltComparedToExpected.stoppedEarly,
      route: ChallengeRouteType.normal,
      intensity: 5,
      repeatMultiplierPercent: 100,
    );
    final protectedLoss = policy.update(
      currentScore: win.score,
      outcome: AttemptOutcome.attempted,
      felt: FeltComparedToExpected.stoppedEarly,
      route: ChallengeRouteType.lowPressure,
      intensity: 5,
      repeatMultiplierPercent: 100,
    );

    expect(win.delta, 41);
    expect(loss.delta, -22);
    expect(protectedLoss.delta, -11);
    expect(policy.algorithmRevision, 'rating_model_dev_v1');
  });

  test('difficulty development model matches every frozen signal vector', () {
    const policy = DifficultyUpdatePolicy();
    final vectors = <(DifficultyObservation, double)>[
      (
        const DifficultyObservation(
          intensity: 3,
          outcome: AttemptOutcome.completed,
          felt: FeltComparedToExpected.easierThanExpected,
        ),
        0.30,
      ),
      (
        const DifficultyObservation(
          intensity: 3,
          outcome: AttemptOutcome.attempted,
          felt: FeltComparedToExpected.easierThanExpected,
        ),
        0.15,
      ),
      (
        const DifficultyObservation(
          intensity: 3,
          outcome: AttemptOutcome.completed,
          felt: FeltComparedToExpected.aboutAsExpected,
        ),
        0.15,
      ),
      (
        const DifficultyObservation(
          intensity: 3,
          outcome: AttemptOutcome.attempted,
          felt: FeltComparedToExpected.aboutAsExpected,
        ),
        0.05,
      ),
      (
        const DifficultyObservation(
          intensity: 3,
          outcome: AttemptOutcome.completed,
          felt: FeltComparedToExpected.harderThanExpected,
        ),
        0.05,
      ),
      (
        const DifficultyObservation(
          intensity: 3,
          outcome: AttemptOutcome.attempted,
          felt: FeltComparedToExpected.harderThanExpected,
        ),
        -0.15,
      ),
      (
        const DifficultyObservation(
          intensity: 3,
          outcome: AttemptOutcome.completed,
          felt: FeltComparedToExpected.stoppedEarly,
        ),
        -0.10,
      ),
      (
        const DifficultyObservation(
          intensity: 3,
          outcome: AttemptOutcome.attempted,
          felt: FeltComparedToExpected.stoppedEarly,
        ),
        -0.30,
      ),
      (
        const DifficultyObservation(
          intensity: 3,
          skipReason: DifficultySkipReason.tooEasy,
        ),
        0.25,
      ),
      (
        const DifficultyObservation(
          intensity: 3,
          skipReason: DifficultySkipReason.tooIntense,
        ),
        -0.40,
      ),
      (
        const DifficultyObservation(
          intensity: 3,
          skipReason: DifficultySkipReason.notInterested,
        ),
        0.0,
      ),
      (
        const DifficultyObservation(
          intensity: 3,
          skipReason: DifficultySkipReason.unsafeOrUncomfortable,
        ),
        0.0,
      ),
    ];
    final base = DifficultyState(
      trait: Trait.presence,
      rating: 3,
      confidence: 0,
      observations: 0,
      recommendedIntensity: 3,
      updatedAt: DateTime.utc(2026, 7, 12),
    );

    for (final (observation, delta) in vectors) {
      final updated = policy.update(
        base,
        observation,
        DateTime.utc(2026, 7, 13),
      );
      expect(updated.rating, closeTo(3 + delta, 0.0001));
    }

    final upper = policy.update(
      DifficultyState(
        trait: Trait.presence,
        rating: 4.9,
        confidence: 1,
        observations: 10,
        recommendedIntensity: 5,
        updatedAt: DateTime.utc(2026, 7, 12),
      ),
      vectors.first.$1,
      DateTime.utc(2026, 7, 13),
    );
    expect(upper.rating, 5);
    expect(upper.confidence, 1);
  });

  test('legacy checkpoint without difficulty restores inside valid range', () {
    final projection = SqliteProjectionMapper.progressFromRow({
      'snapshot_json': '{"totalXp":20}',
      'updated_at': '2026-07-13T00:00:00.000Z',
    });

    for (final difficulty in projection.difficulty.values) {
      expect(difficulty.rating, 2);
      expect(difficulty.recommendedIntensity, 2);
    }
    expect(projection.ratingScore, DevelopmentRankConfig.startingRating);
    expect(projection.peakRatingScore, DevelopmentRankConfig.startingRating);
  });

  test('legacy rank checkpoint maps to the equivalent v2 score', () {
    final projection = SqliteProjectionMapper.progressFromRow({
      'snapshot_json':
          '{"totalXp":600,"rankProgress":0.5,'
          '"rank":{"family":"spark","tier":3,'
          '"configRevision":"rank_config_dev_v1"}}',
      'updated_at': '2026-07-13T00:00:00.000Z',
    });

    expect(projection.rank.stableId, 'spark.3');
    expect(projection.ratingScore, 1325);
    expect(projection.peakRatingScore, 1325);
  });
}
