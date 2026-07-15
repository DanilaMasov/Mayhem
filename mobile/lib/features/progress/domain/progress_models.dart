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

  String get label => family == RankFamily.mayhem
      ? 'MAYHEM'
      : '${family.name.toUpperCase()} ${_roman(tier)}';

  static String _roman(int value) => switch (value) {
    1 => 'I',
    2 => 'II',
    _ => 'III',
  };
}

class ProgressProjection {
  ProgressProjection({
    required this.totalXp,
    required Map<Trait, int> traitXp,
    required this.rank,
    required this.rankProgress,
    required this.momentum,
    required Map<Trait, DifficultyState> difficulty,
    required this.completedCount,
    required this.attemptedCount,
    required this.updatedAt,
    required this.source,
  }) : traitXp = Map.unmodifiable(traitXp),
       difficulty = Map.unmodifiable(difficulty) {
    if (totalXp < 0 || completedCount < 0 || attemptedCount < 0) {
      throw const FormatException('Progress values must not be negative');
    }
    if (rankProgress < 0 || rankProgress > 1) {
      throw const FormatException('Rank progress must be between zero and one');
    }
  }

  final int totalXp;
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
