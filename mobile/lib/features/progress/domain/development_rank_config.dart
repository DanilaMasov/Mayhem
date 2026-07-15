import 'progress_models.dart';
import 'rank_policy.dart';

abstract final class DevelopmentRankConfig {
  static const revision = 'rank_config_dev_v1';

  static RankPolicy policy() => RankPolicy(
    thresholds: [
      _threshold(RankFamily.spark, 1, 0, 0),
      _threshold(RankFamily.spark, 2, 250, 0),
      _threshold(RankFamily.spark, 3, 600, 0),
      _threshold(RankFamily.mover, 1, 1000, 100),
      _threshold(RankFamily.mover, 2, 1500, 150),
      _threshold(RankFamily.mover, 3, 2200, 200),
      _threshold(RankFamily.catalyst, 1, 3000, 300),
      _threshold(RankFamily.catalyst, 2, 4000, 400),
      _threshold(RankFamily.catalyst, 3, 5200, 500),
      _threshold(RankFamily.maverick, 1, 6700, 650),
      _threshold(RankFamily.maverick, 2, 8500, 800),
      _threshold(RankFamily.maverick, 3, 10500, 1000),
      _threshold(RankFamily.icon, 1, 13000, 1200),
      _threshold(RankFamily.icon, 2, 16000, 1500),
      _threshold(RankFamily.icon, 3, 20000, 1800),
      _threshold(RankFamily.mayhem, 1, 25000, 2200),
    ],
  );

  static RankThreshold _threshold(
    RankFamily family,
    int tier,
    int totalXp,
    int minimumTraitXp,
  ) => RankThreshold(
    rank: PrestigeRank(family: family, tier: tier, configRevision: revision),
    totalXp: totalXp,
    minimumTraitXp: minimumTraitXp,
  );
}
