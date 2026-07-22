import 'development_rank_config.dart';
import 'progress_models.dart';

class RankVisualStyle {
  const RankVisualStyle({required this.id, required this.unlockRank});

  final String id;
  final PrestigeRank unlockRank;
}

abstract final class RankVisualStyleCatalog {
  static List<RankVisualStyle> get styles => DevelopmentRankConfig.policy()
      .thresholds
      .map(
        (threshold) => RankVisualStyle(
          id: idFor(threshold.rank),
          unlockRank: threshold.rank,
        ),
      )
      .toList(growable: false);

  static String idFor(PrestigeRank rank) => '${rank.family.name}.${rank.tier}';

  static int rankIndex(PrestigeRank rank) => styles.indexWhere(
    (style) =>
        style.unlockRank.family == rank.family &&
        style.unlockRank.tier == rank.tier,
  );

  static List<RankVisualStyle> unlockedFor(PrestigeRank currentRank) {
    final currentIndex = rankIndex(currentRank);
    final lastUnlocked = currentIndex < 0 ? 0 : currentIndex;
    return styles.take(lastUnlocked + 1).toList(growable: false);
  }

  static bool isUnlocked(RankVisualStyle style, PrestigeRank currentRank) =>
      unlockedFor(currentRank).any((candidate) => candidate.id == style.id);

  static RankVisualStyle resolveSelected({
    required String? selectedId,
    required PrestigeRank currentRank,
  }) {
    final unlocked = unlockedFor(currentRank);
    for (final style in unlocked) {
      if (style.id == selectedId) return style;
    }
    return unlocked.first;
  }
}
