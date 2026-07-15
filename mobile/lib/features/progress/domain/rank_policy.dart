import 'progress_models.dart';

class RankThreshold {
  const RankThreshold({
    required this.rank,
    required this.totalXp,
    required this.minimumTraitXp,
  });

  final PrestigeRank rank;
  final int totalXp;
  final int minimumTraitXp;
}

class RankResolution {
  const RankResolution({
    required this.rank,
    required this.progressToNext,
    required this.next,
  });

  final PrestigeRank rank;
  final double progressToNext;
  final PrestigeRank? next;
}

class RankPolicy {
  RankPolicy({required List<RankThreshold> thresholds})
    : thresholds = List.unmodifiable(thresholds) {
    if (thresholds.isEmpty || thresholds.first.totalXp != 0) {
      throw const FormatException('Rank ladder must start at zero XP');
    }
    for (var index = 0; index < thresholds.length; index += 1) {
      final item = thresholds[index];
      if (item.totalXp < 0 || item.minimumTraitXp < 0) {
        throw const FormatException('Rank threshold must not be negative');
      }
      if (index > 0 && item.totalXp <= thresholds[index - 1].totalXp) {
        throw const FormatException('Rank thresholds must increase');
      }
    }
  }

  final List<RankThreshold> thresholds;

  RankResolution resolve({
    required int totalXp,
    required Map<Trait, int> traitXp,
  }) {
    if (totalXp < 0) throw const FormatException('Total XP is invalid');
    var unlockedIndex = 0;
    for (var index = 1; index < thresholds.length; index += 1) {
      final threshold = thresholds[index];
      final balanced = Trait.values.every(
        (trait) => (traitXp[trait] ?? 0) >= threshold.minimumTraitXp,
      );
      if (totalXp < threshold.totalXp || !balanced) break;
      unlockedIndex = index;
    }
    final unlocked = thresholds[unlockedIndex];
    final next = unlockedIndex + 1 < thresholds.length
        ? thresholds[unlockedIndex + 1]
        : null;
    final progress = next == null
        ? 1.0
        : _progressToNext(
            totalXp: totalXp,
            traitXp: traitXp,
            unlocked: unlocked,
            next: next,
          );
    return RankResolution(
      rank: unlocked.rank,
      progressToNext: progress,
      next: next?.rank,
    );
  }

  double _progressToNext({
    required int totalXp,
    required Map<Trait, int> traitXp,
    required RankThreshold unlocked,
    required RankThreshold next,
  }) {
    final xpProgress =
        ((totalXp - unlocked.totalXp) / (next.totalXp - unlocked.totalXp))
            .clamp(0.0, 1.0);
    if (next.minimumTraitXp == 0) return xpProgress;
    final balanceProgress = Trait.values
        .map(
          (trait) =>
              ((traitXp[trait] ?? 0) / next.minimumTraitXp).clamp(0.0, 1.0),
        )
        .reduce((lowest, value) => value < lowest ? value : lowest);
    return xpProgress < balanceProgress ? xpProgress : balanceProgress;
  }
}
