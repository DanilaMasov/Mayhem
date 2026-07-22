import 'package:flutter/material.dart';

import '../../../core/design_system/components/components.dart';
import '../../../core/design_system/tokens/tokens.dart';
import '../../../core/localization/mayhem_strings.dart';
import '../application/journey_controller.dart';
import '../domain/development_rank_config.dart';
import '../domain/progress_models.dart';
import '../domain/rank_policy.dart';
import 'vnext_journey_screen.dart';

class VNextRankPathScreen extends StatefulWidget {
  const VNextRankPathScreen({super.key, required this.snapshot});

  final JourneySnapshot snapshot;

  @override
  State<VNextRankPathScreen> createState() => _VNextRankPathScreenState();
}

class _VNextRankPathScreenState extends State<VNextRankPathScreen> {
  final _currentRankKey = GlobalKey();
  var _positionedAtCurrentRank = false;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final thresholds = DevelopmentRankConfig.policy().thresholds;
    final currentIndex = thresholds.indexWhere(
      (threshold) =>
          threshold.rank.label == widget.snapshot.projection.rank.label,
    );
    final resolvedCurrentIndex = currentIndex < 0 ? 0 : currentIndex;
    final ordered = thresholds.reversed.toList(growable: false);

    if (!_positionedAtCurrentRank) {
      _positionedAtCurrentRank = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final currentContext = _currentRankKey.currentContext;
        if (!mounted || currentContext == null) return;
        Scrollable.ensureVisible(
          currentContext,
          alignment: 0.72,
          duration: Duration.zero,
        );
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.rankPathTitle),
        leading: IconButton(
          tooltip: strings.back,
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [MayhemColors.canvasRaised, MayhemColors.canvasDeep],
          ),
        ),
        child: SingleChildScrollView(
          key: const PageStorageKey('rank-path-scroll'),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              MayhemSpacing.x4,
              MayhemSpacing.x5,
              MayhemSpacing.x4,
              MayhemSpacing.x10,
            ),
            child: Column(
              children: [
                _RankPathHeader(
                  currentRank: widget.snapshot.projection.rank,
                  totalXp: widget.snapshot.projection.totalXp,
                ),
                const SizedBox(height: MayhemSpacing.x8),
                for (
                  var displayIndex = 0;
                  displayIndex < ordered.length;
                  displayIndex += 1
                )
                  _RankArenaNode(
                    key:
                        thresholds.indexOf(ordered[displayIndex]) ==
                            resolvedCurrentIndex
                        ? _currentRankKey
                        : ValueKey(
                            'rank-node-${ordered[displayIndex].rank.label}',
                          ),
                    threshold: ordered[displayIndex],
                    thresholdIndex: thresholds.indexOf(ordered[displayIndex]),
                    currentIndex: resolvedCurrentIndex,
                    isFirst: displayIndex == 0,
                    isLast: displayIndex == ordered.length - 1,
                    snapshot: widget.snapshot,
                    nextThreshold: resolvedCurrentIndex + 1 < thresholds.length
                        ? thresholds[resolvedCurrentIndex + 1]
                        : null,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RankPathHeader extends StatelessWidget {
  const _RankPathHeader({required this.currentRank, required this.totalXp});

  final PrestigeRank currentRank;
  final int totalXp;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return Semantics(
      header: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: MayhemColors.surfaceBase.withValues(alpha: 0.86),
          borderRadius: MayhemRadii.large,
          border: Border.all(color: MayhemColors.lineStrong),
        ),
        child: Padding(
          padding: const EdgeInsets.all(MayhemSpacing.x5),
          child: Row(
            children: [
              _RankFamilyMark(family: currentRank.family, size: 54),
              const SizedBox(width: MayhemSpacing.x4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MayhemText(
                      strings.rankPathHint,
                      variant: MayhemTextVariant.labelMicro,
                    ),
                    const SizedBox(height: MayhemSpacing.x1),
                    MayhemText(
                      currentRank.label,
                      variant: MayhemTextVariant.headlineSmall,
                      color: MayhemColors.textPrimary,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: MayhemSpacing.x3),
              MayhemText(
                strings.rankXpRequirement(totalXp),
                variant: MayhemTextVariant.numberStatus,
                color: MayhemColors.brandSignalSoft,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RankArenaNode extends StatelessWidget {
  const _RankArenaNode({
    super.key,
    required this.threshold,
    required this.thresholdIndex,
    required this.currentIndex,
    required this.isFirst,
    required this.isLast,
    required this.snapshot,
    required this.nextThreshold,
  });

  final RankThreshold threshold;
  final int thresholdIndex;
  final int currentIndex;
  final bool isFirst;
  final bool isLast;
  final JourneySnapshot snapshot;
  final RankThreshold? nextThreshold;

  bool get _isCurrent => thresholdIndex == currentIndex;
  bool get _isUnlocked => thresholdIndex < currentIndex;

  @override
  Widget build(BuildContext context) {
    final accent = rankFamilyColor(threshold.rank.family);
    final activeRail = thresholdIndex <= currentIndex;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 46,
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    width: 2,
                    color: isFirst
                        ? Colors.transparent
                        : activeRail
                        ? accent.withValues(alpha: 0.7)
                        : MayhemColors.lineStrong,
                  ),
                ),
                Container(
                  width: _isCurrent ? 20 : 14,
                  height: _isCurrent ? 20 : 14,
                  decoration: BoxDecoration(
                    color: activeRail ? accent : MayhemColors.surfaceHigh,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _isCurrent
                          ? MayhemColors.textPrimary
                          : MayhemColors.canvasRaised,
                      width: _isCurrent ? 3 : 2,
                    ),
                    boxShadow: _isCurrent
                        ? [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.45),
                              blurRadius: 18,
                              spreadRadius: 3,
                            ),
                          ]
                        : null,
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast
                        ? Colors.transparent
                        : thresholdIndex <= currentIndex
                        ? accent.withValues(alpha: 0.7)
                        : MayhemColors.lineStrong,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left: thresholdIndex.isEven ? 0 : MayhemSpacing.x3,
                bottom: MayhemSpacing.x4,
              ),
              child: _RankArenaCard(
                threshold: threshold,
                current: _isCurrent,
                unlocked: _isUnlocked,
                snapshot: snapshot,
                nextThreshold: _isCurrent ? nextThreshold : null,
                accent: accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RankArenaCard extends StatelessWidget {
  const _RankArenaCard({
    required this.threshold,
    required this.current,
    required this.unlocked,
    required this.snapshot,
    required this.nextThreshold,
    required this.accent,
  });

  final RankThreshold threshold;
  final bool current;
  final bool unlocked;
  final JourneySnapshot snapshot;
  final RankThreshold? nextThreshold;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final recent = snapshot.history
        .where((entry) => (entry.attempt.result?.earnedXp ?? 0) > 0)
        .toList(growable: false);
    final shownRecent = recent.take(5).toList(growable: false);
    final status = current
        ? strings.currentArena
        : unlocked
        ? strings.unlockedArena
        : strings.lockedArena;
    final remainingXp = nextThreshold == null
        ? 0
        : (nextThreshold!.totalXp - snapshot.projection.totalXp)
              .clamp(0, nextThreshold!.totalXp)
              .toInt();
    final remainingTraitXp = nextThreshold == null
        ? 0
        : Trait.values.fold<int>(0, (largestDeficit, trait) {
            final deficit =
                nextThreshold!.minimumTraitXp -
                (snapshot.projection.traitXp[trait] ?? 0);
            return deficit > largestDeficit ? deficit : largestDeficit;
          });

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: current
              ? [accent.withValues(alpha: 0.26), MayhemColors.surfaceBase]
              : [
                  MayhemColors.surfaceRaised.withValues(
                    alpha: unlocked ? 0.96 : 0.68,
                  ),
                  MayhemColors.surfaceBase.withValues(
                    alpha: unlocked ? 0.96 : 0.66,
                  ),
                ],
        ),
        borderRadius: MayhemRadii.large,
        border: Border.all(
          color: current
              ? accent.withValues(alpha: 0.9)
              : unlocked
              ? accent.withValues(alpha: 0.32)
              : MayhemColors.lineSubtle,
          width: current ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(MayhemSpacing.x5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RankFamilyMark(family: threshold.rank.family, size: 48),
                const SizedBox(width: MayhemSpacing.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MayhemText(
                        status,
                        variant: MayhemTextVariant.labelMicro,
                        color: current || unlocked
                            ? accent
                            : MayhemColors.textTertiary,
                      ),
                      const SizedBox(height: MayhemSpacing.x1),
                      MayhemText(
                        threshold.rank.label,
                        variant: MayhemTextVariant.headlineSmall,
                        color: current || unlocked
                            ? MayhemColors.textPrimary
                            : MayhemColors.textSecondary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: MayhemSpacing.x2),
                Icon(
                  current
                      ? Icons.my_location
                      : unlocked
                      ? Icons.check_circle_outline
                      : Icons.lock_outline,
                  color: current || unlocked
                      ? accent
                      : MayhemColors.textTertiary,
                  size: 22,
                ),
              ],
            ),
            const SizedBox(height: MayhemSpacing.x4),
            Wrap(
              spacing: MayhemSpacing.x2,
              runSpacing: MayhemSpacing.x2,
              children: [
                _RequirementChip(
                  icon: Icons.bolt,
                  label: strings.rankXpRequirement(threshold.totalXp),
                  active: current || unlocked,
                  accent: accent,
                ),
                if (threshold.minimumTraitXp > 0)
                  _RequirementChip(
                    icon: Icons.hub_outlined,
                    label: strings.rankTraitRequirement(
                      threshold.minimumTraitXp,
                    ),
                    active: current || unlocked,
                    accent: accent,
                  ),
              ],
            ),
            if (current) ...[
              const SizedBox(height: MayhemSpacing.x5),
              if (nextThreshold case final next?) ...[
                MayhemText(
                  strings.rankNext(next.rank.label),
                  variant: MayhemTextVariant.labelMicro,
                  color: accent,
                ),
                const SizedBox(height: MayhemSpacing.x1),
                Wrap(
                  spacing: MayhemSpacing.x3,
                  runSpacing: MayhemSpacing.x1,
                  children: [
                    if (remainingXp > 0)
                      MayhemText(
                        strings.rankXpRemaining(remainingXp),
                        variant: MayhemTextVariant.labelMedium,
                        color: MayhemColors.textPrimary,
                      ),
                    if (remainingTraitXp > 0)
                      MayhemText(
                        strings.rankTraitRemaining(remainingTraitXp),
                        variant: MayhemTextVariant.labelMedium,
                        color: MayhemColors.textPrimary,
                      ),
                    if (remainingXp == 0 && remainingTraitXp == 0)
                      MayhemText(
                        strings.rankXpRemaining(0),
                        variant: MayhemTextVariant.labelMedium,
                        color: MayhemColors.textPrimary,
                      ),
                  ],
                ),
                const SizedBox(height: MayhemSpacing.x2),
                LinearProgressIndicator(
                  value: snapshot.projection.rankProgress,
                  minHeight: 7,
                  borderRadius: MayhemRadii.pill,
                  backgroundColor: MayhemColors.lineStrong,
                  color: accent,
                ),
              ],
              const SizedBox(height: MayhemSpacing.x6),
              MayhemText(
                strings.rankRecentActions,
                variant: MayhemTextVariant.labelMicro,
              ),
              if (recent.isNotEmpty) ...[
                const SizedBox(height: MayhemSpacing.x1),
                MayhemText(
                  strings.rankRecentActionCount(
                    shownRecent.length,
                    recent.length,
                  ),
                  variant: MayhemTextVariant.bodySmall,
                ),
              ],
              const SizedBox(height: MayhemSpacing.x3),
              if (shownRecent.isEmpty)
                MayhemText(
                  strings.rankNoRecentActions,
                  variant: MayhemTextVariant.bodyMedium,
                )
              else
                for (final entry in shownRecent) _RankActionRow(entry: entry),
              if (recent.length > shownRecent.length) ...[
                const SizedBox(height: MayhemSpacing.x2),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () =>
                        Navigator.of(context).pushNamed(JourneyRoutes.history),
                    icon: const Icon(Icons.history, size: 18),
                    label: Text(strings.historyTitle),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _RequirementChip extends StatelessWidget {
  const _RequirementChip({
    required this.icon,
    required this.label,
    required this.active,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final bool active;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 244),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: active
              ? accent.withValues(alpha: 0.1)
              : MayhemColors.canvasRaised,
          borderRadius: MayhemRadii.pill,
          border: Border.all(
            color: active
                ? accent.withValues(alpha: 0.28)
                : MayhemColors.lineSubtle,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MayhemSpacing.x3,
            vertical: MayhemSpacing.x2,
          ),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: active ? accent : MayhemColors.textTertiary,
              ),
              const SizedBox(width: MayhemSpacing.x1),
              MayhemText(
                label,
                variant: MayhemTextVariant.labelMicro,
                color: active
                    ? MayhemColors.textSecondary
                    : MayhemColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RankActionRow extends StatelessWidget {
  const _RankActionRow({required this.entry});

  final JourneyHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final xp = entry.attempt.result?.earnedXp ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: MayhemSpacing.x2),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: MayhemColors.brandSignalSoft,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: MayhemSpacing.x3),
          Expanded(
            child: MayhemText(
              entry.title,
              variant: MayhemTextVariant.bodySmall,
              color: MayhemColors.textSecondary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: MayhemSpacing.x2),
          MayhemText(
            context.strings.xpEarned(xp),
            variant: MayhemTextVariant.labelMedium,
            color: MayhemColors.brandSignalSoft,
          ),
        ],
      ),
    );
  }
}

class _RankFamilyMark extends StatelessWidget {
  const _RankFamilyMark({required this.family, required this.size});

  final RankFamily family;
  final double size;

  @override
  Widget build(BuildContext context) {
    final accent = rankFamilyColor(family);
    return Semantics(
      image: true,
      label: family.name,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [accent.withValues(alpha: 0.3), MayhemColors.surfaceHigh],
          ),
          shape: BoxShape.circle,
          border: Border.all(color: accent.withValues(alpha: 0.8)),
          boxShadow: [
            BoxShadow(color: accent.withValues(alpha: 0.18), blurRadius: 16),
          ],
        ),
        child: Icon(rankFamilyIcon(family), color: accent, size: size * 0.46),
      ),
    );
  }
}

@visibleForTesting
Color rankFamilyColor(RankFamily family) => switch (family) {
  RankFamily.spark => MayhemColors.brandSignalSoft,
  RankFamily.mover => MayhemColors.traitConnection,
  RankFamily.catalyst => MayhemColors.traitInitiation,
  RankFamily.maverick => MayhemColors.semanticWarning,
  RankFamily.icon => MayhemColors.brandColdLight,
  RankFamily.mayhem => MayhemColors.traitExpression,
};

@visibleForTesting
IconData rankFamilyIcon(RankFamily family) => switch (family) {
  RankFamily.spark => Icons.bolt,
  RankFamily.mover => Icons.arrow_upward,
  RankFamily.catalyst => Icons.change_history,
  RankFamily.maverick => Icons.explore_outlined,
  RankFamily.icon => Icons.star_outline,
  RankFamily.mayhem => Icons.flare,
};
