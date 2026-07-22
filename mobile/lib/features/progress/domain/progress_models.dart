import '../../streak/domain/momentum_state.dart';

enum Trait { initiation, expression, connection, presence }

enum RankFamily { spark, mover, catalyst, maverick, icon, mayhem }

enum ProjectionSource { localCheckpoint, localRebuild, serverReconciled }

class DifficultyState {
  const DifficultyState({
    required this.trait,
    required this.rating,
    required this.confidence,
    required this.observations,
    required this.recommendedIntensity,
    required this.updatedAt,
  });

  final Trait trait;
  final double rating;
  final double confidence;
  final int observations;
  final int recommendedIntensity;
  final DateTime updatedAt;
}

class PrestigeRank {
  PrestigeRank({
    required this.family,
    required this.tier,
    required this.configRevision,
  }) {
    final validTier = family == RankFamily.mayhem
        ? tier == 1
        : tier >= 1 && tier <= 3;
    if (!validTier || configRevision.trim().isEmpty) {
      throw const FormatException('Prestige rank configuration is invalid');
    }
  }

  final RankFamily family;
  final int tier;
  final String configRevision;

  String get stableId => '${family.name}.$tier';

  String get label => switch ((family, tier)) {
    (RankFamily.spark, 1) => 'ИСКРА',
    (RankFamily.spark, 2) => 'ИМПУЛЬС',
    (RankFamily.spark, 3) => 'РАЗРЯД',
    (RankFamily.mover, 1) => 'ВЕКТОР',
    (RankFamily.mover, 2) => 'ДРАЙВЕР',
    (RankFamily.mover, 3) => 'ПРОРЫВ',
    (RankFamily.catalyst, 1) => 'КАТАЛИЗАТОР',
    (RankFamily.catalyst, 2) => 'РЕЗОНАНС',
    (RankFamily.catalyst, 3) => 'СИНЕРГИЯ',
    (RankFamily.maverick, 1) => 'МАВЕРИК',
    (RankFamily.maverick, 2) => 'АВАНГАРД',
    (RankFamily.maverick, 3) => 'ПЕРВОПРОХОДЕЦ',
    (RankFamily.icon, 1) => 'МАГНИТ',
    (RankFamily.icon, 2) => 'ИКОНА',
    (RankFamily.icon, 3) => 'ЛЕГЕНДА',
    (RankFamily.mayhem, 1) => 'MAYHEM',
    _ => throw StateError('Unsupported prestige rank'),
  };
}

class ProgressProjection {
  ProgressProjection({
    required this.totalXp,
    required this.ratingScore,
    required int peakRatingScore,
    required Map<Trait, int> traitXp,
    required this.rank,
    required this.rankProgress,
    required this.momentum,
    required Map<Trait, DifficultyState> difficulty,
    required this.completedCount,
    required this.attemptedCount,
    required this.updatedAt,
    required this.source,
  }) : peakRatingScore = peakRatingScore,
       traitXp = Map.unmodifiable(traitXp),
       difficulty = Map.unmodifiable(difficulty) {
    if (totalXp < 0 ||
        ratingScore < 0 ||
        peakRatingScore < ratingScore ||
        completedCount < 0 ||
        attemptedCount < 0) {
      throw const FormatException('Progress values must not be negative');
    }
    if (rankProgress < 0 || rankProgress > 1) {
      throw const FormatException('Rank progress must be between zero and one');
    }
  }

  final int totalXp;
  final int ratingScore;
  final int peakRatingScore;
  final Map<Trait, int> traitXp;
  final PrestigeRank rank;
  final double rankProgress;
  final MomentumState momentum;
  final Map<Trait, DifficultyState> difficulty;
  final int completedCount;
  final int attemptedCount;
  final DateTime updatedAt;
  final ProjectionSource source;
}
