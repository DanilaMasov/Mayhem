import 'package:flutter/material.dart';

import '../../../core/design_system/components/components.dart';
import '../../../core/design_system/tokens/tokens.dart';
import '../../../core/localization/mayhem_strings.dart';
import '../../settings/application/settings_controller.dart';
import '../application/journey_controller.dart';
import '../domain/progress_models.dart';
import '../domain/rank_visual_style.dart';
import 'rank_style_surface.dart';

class VNextRankStyleCollectionScreen extends StatefulWidget {
  const VNextRankStyleCollectionScreen({
    super.key,
    required this.snapshot,
    required this.settings,
  });

  final JourneySnapshot snapshot;
  final SettingsController settings;

  @override
  State<VNextRankStyleCollectionScreen> createState() =>
      _VNextRankStyleCollectionScreenState();
}

class _VNextRankStyleCollectionScreenState
    extends State<VNextRankStyleCollectionScreen> {
  String? _savingStyleId;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final currentRank = widget.snapshot.projection.rank;
    final styles = RankVisualStyleCatalog.styles;
    final unlocked = RankVisualStyleCatalog.unlockedFor(currentRank);
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.rankStylesTitle),
        leading: IconButton(
          tooltip: strings.back,
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: AnimatedBuilder(
        animation: widget.settings,
        builder: (context, child) {
          final selected = RankVisualStyleCatalog.resolveSelected(
            selectedId: widget.settings.preferences.rankStyleId,
            currentRank: currentRank,
          );
          return ListView(
            key: const PageStorageKey('rank-style-collection-scroll'),
            padding: const EdgeInsets.fromLTRB(
              MayhemSpacing.x4,
              MayhemSpacing.x4,
              MayhemSpacing.x4,
              MayhemSpacing.x10,
            ),
            children: [
              _CollectionHeader(
                selected: selected,
                unlocked: unlocked.length,
                total: styles.length,
              ),
              const SizedBox(height: MayhemSpacing.x5),
              for (final style in styles)
                Padding(
                  padding: const EdgeInsets.only(bottom: MayhemSpacing.x3),
                  child: _RankStyleCard(
                    style: style,
                    unlocked: RankVisualStyleCatalog.isUnlocked(
                      style,
                      currentRank,
                    ),
                    selected: style.id == selected.id,
                    saving: style.id == _savingStyleId,
                    onPressed: () => _select(style),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _select(RankVisualStyle style) async {
    final currentRank = widget.snapshot.projection.rank;
    if (_savingStyleId != null ||
        !RankVisualStyleCatalog.isUnlocked(style, currentRank)) {
      return;
    }
    final current = RankVisualStyleCatalog.resolveSelected(
      selectedId: widget.settings.preferences.rankStyleId,
      currentRank: currentRank,
    );
    if (current.id == style.id) return;
    setState(() => _savingStyleId = style.id);
    try {
      await widget.settings.update(
        widget.settings.preferences.copyWith(rankStyleId: style.id),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.strings.rankStyleApplyError)),
        );
      }
    } finally {
      if (mounted) setState(() => _savingStyleId = null);
    }
  }
}

class _CollectionHeader extends StatelessWidget {
  const _CollectionHeader({
    required this.selected,
    required this.unlocked,
    required this.total,
  });

  final RankVisualStyle selected;
  final int unlocked;
  final int total;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final palette = rankStylePalette(selected);
    return RankStyleSurface(
      style: selected,
      borderRadius: MayhemRadii.large,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: MayhemRadii.large,
          border: Border.all(color: palette.accent.withValues(alpha: 0.62)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(MayhemSpacing.x5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MayhemText(
                strings.rankStylesUnlocked(unlocked, total),
                variant: MayhemTextVariant.labelMicro,
                color: palette.accent,
              ),
              const SizedBox(height: MayhemSpacing.x2),
              MayhemText(
                selected.unlockRank.label,
                variant: MayhemTextVariant.headlineLarge,
              ),
              const SizedBox(height: MayhemSpacing.x3),
              MayhemText(
                strings.rankStylesBody,
                variant: MayhemTextVariant.bodyMedium,
                color: MayhemColors.textPrimary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RankStyleCard extends StatelessWidget {
  const _RankStyleCard({
    required this.style,
    required this.unlocked,
    required this.selected,
    required this.saving,
    required this.onPressed,
  });

  final RankVisualStyle style;
  final bool unlocked;
  final bool selected;
  final bool saving;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final palette = rankStylePalette(style);
    final status = selected
        ? strings.rankStyleSelected
        : unlocked
        ? strings.rankStyleAvailable
        : strings.rankStyleLocked(style.unlockRank.label);
    return MayhemPressable(
      key: ValueKey('rank-style-${style.id}'),
      semanticLabel: '${style.unlockRank.label}. $status',
      onPressed: unlocked && !saving ? onPressed : null,
      borderRadius: MayhemRadii.large,
      child: RankStyleSurface(
        style: style,
        borderRadius: MayhemRadii.large,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: unlocked
                ? Colors.transparent
                : MayhemColors.canvasDeep.withValues(alpha: 0.62),
            borderRadius: MayhemRadii.large,
            border: Border.all(
              color: selected
                  ? palette.accent
                  : unlocked
                  ? palette.accent.withValues(alpha: 0.36)
                  : MayhemColors.lineSubtle,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(MayhemSpacing.x4),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: palette.accent.withValues(
                      alpha: unlocked ? 0.14 : 0.06,
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: unlocked
                          ? palette.accent
                          : MayhemColors.textTertiary,
                    ),
                  ),
                  child: Icon(
                    _rankIcon(style.unlockRank.family),
                    color: unlocked
                        ? palette.accent
                        : MayhemColors.textTertiary,
                  ),
                ),
                const SizedBox(width: MayhemSpacing.x4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MayhemText(
                        style.unlockRank.label,
                        variant: MayhemTextVariant.headlineSmall,
                        color: unlocked
                            ? MayhemColors.textPrimary
                            : MayhemColors.textSecondary,
                      ),
                      const SizedBox(height: MayhemSpacing.x1),
                      MayhemText(
                        status,
                        variant: MayhemTextVariant.labelMicro,
                        color: selected || unlocked
                            ? palette.accent
                            : MayhemColors.textTertiary,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: MayhemSpacing.x3),
                if (saving)
                  SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: palette.accent,
                    ),
                  )
                else
                  Icon(
                    selected
                        ? Icons.check_circle
                        : unlocked
                        ? Icons.radio_button_unchecked
                        : Icons.lock_outline,
                    color: selected || unlocked
                        ? palette.accent
                        : MayhemColors.textTertiary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

IconData _rankIcon(RankFamily family) => switch (family) {
  RankFamily.spark => Icons.bolt,
  RankFamily.mover => Icons.arrow_upward,
  RankFamily.catalyst => Icons.change_history,
  RankFamily.maverick => Icons.explore_outlined,
  RankFamily.icon => Icons.star_outline,
  RankFamily.mayhem => Icons.flare,
};
