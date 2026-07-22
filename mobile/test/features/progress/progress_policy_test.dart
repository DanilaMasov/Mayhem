import 'package:flutter_test/flutter_test.dart';
import 'package:mayhem_mobile/features/challenge/domain/challenge_models.dart';
import 'package:mayhem_mobile/features/progress/domain/difficulty_update_policy.dart';
import 'package:mayhem_mobile/features/progress/domain/development_rank_config.dart';
import 'package:mayhem_mobile/features/progress/domain/progress_models.dart';
import 'package:mayhem_mobile/features/progress/domain/rank_policy.dart';
import 'package:mayhem_mobile/features/progress/domain/rank_visual_style.dart';
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
          totalXp: 0,
          minimumTraitXp: 0,
        ),
        RankThreshold(
          rank: rank(RankFamily.spark, 2),
          totalXp: 100,
          minimumTraitXp: 10,
        ),
      ],
    );

    final oneTrait = policy.resolve(
      totalXp: 500,
      traitXp: const {Trait.initiation: 500},
    );
    expect(oneTrait.rank.label, 'SPARK I');
    expect(oneTrait.progressToNext, 0);
    expect(
      policy
          .resolve(
            totalXp: 100,
            traitXp: const {
              Trait.initiation: 25,
              Trait.expression: 25,
              Trait.connection: 25,
              Trait.presence: 25,
            },
          )
          .rank
          .label,
      'SPARK II',
    );
    expect(
      policy
          .resolve(
            totalXp: 50,
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

  test('development rank config matches the frozen v1.1 ladder', () {
    final thresholds = DevelopmentRankConfig.policy().thresholds;

    expect(DevelopmentRankConfig.revision, 'rank_config_dev_v1');
    expect(
      thresholds
          .map((item) => [item.rank.label, item.totalXp, item.minimumTraitXp])
          .toList(),
      [
        ['SPARK I', 0, 0],
        ['SPARK II', 250, 0],
        ['SPARK III', 600, 0],
        ['MOVER I', 1000, 100],
        ['MOVER II', 1500, 150],
        ['MOVER III', 2200, 200],
        ['CATALYST I', 3000, 300],
        ['CATALYST II', 4000, 400],
        ['CATALYST III', 5200, 500],
        ['MAVERICK I', 6700, 650],
        ['MAVERICK II', 8500, 800],
        ['MAVERICK III', 10500, 1000],
        ['ICON I', 13000, 1200],
        ['ICON II', 16000, 1500],
        ['ICON III', 20000, 1800],
        ['MAYHEM', 25000, 2200],
      ],
    );
  });

  test('rank styles unlock cumulatively and reject a locked selection', () {
    final styles = RankVisualStyleCatalog.styles;
    final mover = PrestigeRank(
      family: RankFamily.mover,
      tier: 1,
      configRevision: DevelopmentRankConfig.revision,
    );

    expect(styles, hasLength(16));
    expect(styles.first.id, 'spark.1');
    expect(styles.last.id, 'mayhem.1');
    expect(RankVisualStyleCatalog.unlockedFor(mover).map((style) => style.id), [
      'spark.1',
      'spark.2',
      'spark.3',
      'mover.1',
    ]);
    expect(
      RankVisualStyleCatalog.resolveSelected(
        selectedId: 'spark.2',
        currentRank: mover,
      ).id,
      'spark.2',
    );
    expect(
      RankVisualStyleCatalog.resolveSelected(
        selectedId: 'mayhem.1',
        currentRank: mover,
      ).id,
      'spark.1',
    );
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
  });
}
