import 'progress_models.dart';
import 'rank_policy.dart';

abstract final class DevelopmentRankConfig {
  static const revision = 'rank_config_dev_v2';
  static const startingRating = 1000;

  static RankPolicy policy() => RankPolicy(
    thresholds: [
      _threshold(RankFamily.spark, 1, 1000, 0),
      _threshold(RankFamily.spark, 2, 1125, 0),
      _threshold(RankFamily.spark, 3, 1250, 0),
      _threshold(RankFamily.mover, 1, 1400, 100),
      _threshold(RankFamily.mover, 2, 1550, 150),
      _threshold(RankFamily.mover, 3, 1700, 200),
      _threshold(RankFamily.catalyst, 1, 1875, 300),
      _threshold(RankFamily.catalyst, 2, 2050, 400),
      _threshold(RankFamily.catalyst, 3, 2250, 500),
      _threshold(RankFamily.maverick, 1, 2475, 650),
      _threshold(RankFamily.maverick, 2, 2700, 800),
      _threshold(RankFamily.maverick, 3, 2950, 1000),
      _threshold(RankFamily.icon, 1, 3225, 1200),
      _threshold(RankFamily.icon, 2, 3525, 1500),
      _threshold(RankFamily.icon, 3, 3850, 1800),
      _threshold(RankFamily.mayhem, 1, 4200, 2200),
    ],
  );

  static int rankIndex(PrestigeRank rank) => policy().thresholds.indexWhere(
    (threshold) => threshold.rank.stableId == rank.stableId,
  );

  /// Maps a v1 XP rank snapshot onto the equivalent point in the v2 rating
  /// ladder. The old family/tier stays intact while subsequent results can
  /// promote or demote it using the competitive score.
  static int migrateLegacyRating({
    required PrestigeRank rank,
    required double rankProgress,
  }) {
    final thresholds = policy().thresholds;
    final index = rankIndex(rank);
    if (index < 0) return startingRating;
    final current = thresholds[index];
    if (index == thresholds.length - 1) return current.ratingScore;
    final next = thresholds[index + 1];
    return (current.ratingScore +
            (next.ratingScore - current.ratingScore) *
                rankProgress.clamp(0.0, 1.0))
        .round();
  }

  static RankThreshold _threshold(
    RankFamily family,
    int tier,
    int ratingScore,
    int minimumTraitXp,
  ) => RankThreshold(
    rank: PrestigeRank(family: family, tier: tier, configRevision: revision),
    ratingScore: ratingScore,
    minimumTraitXp: minimumTraitXp,
  );
}
