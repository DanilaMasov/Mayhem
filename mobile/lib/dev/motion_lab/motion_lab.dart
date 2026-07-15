import 'package:flutter/material.dart';

import '../../app/routing/route_names.dart';
import '../../core/design_system/accessibility/mayhem_motion_preferences.dart';
import '../../core/design_system/components/components.dart';
import '../../core/design_system/motion/mayhem_curves.dart';
import '../../core/design_system/motion/mayhem_durations.dart';
import '../../core/design_system/tokens/tokens.dart';

enum _LabSection { foundation, feed, objects, actions }

class MotionLab extends StatefulWidget {
  const MotionLab({super.key});

  static const routeName = RouteNames.motionLab;

  @override
  State<MotionLab> createState() => _MotionLabState();
}

class _MotionLabState extends State<MotionLab> {
  _LabSection _section = _LabSection.foundation;
  MayhemMotionPreferences _preferences = const MayhemMotionPreferences();
  int _selectedNavigation = 0;
  int _holdRun = 0;
  int _rewardRun = 0;
  bool _holdAccepted = false;
  String _holdStatus = 'Ready';
  RewardStageKind _rewardKind = RewardStageKind.completion;

  @override
  Widget build(BuildContext context) {
    return MayhemAccessibility(
      preferences: _preferences,
      child: MayhemScaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _LabHeader(onClose: () => Navigator.maybePop(context)),
              _PreferenceBar(
                preferences: _preferences,
                onChanged: (preferences) {
                  setState(() => _preferences = preferences);
                },
              ),
              _SectionSelector(
                section: _section,
                onSelected: (section) => setState(() => _section = section),
              ),
              Expanded(child: _buildSection()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection() => switch (_section) {
    _LabSection.foundation => const _FoundationGallery(),
    _LabSection.feed => const _FeedGallery(),
    _LabSection.objects => _ObjectsGallery(
      selectedNavigation: _selectedNavigation,
      onNavigationSelected: (index) {
        setState(() => _selectedNavigation = index);
      },
    ),
    _LabSection.actions => _ActionsGallery(
      holdKey: ValueKey(_holdRun),
      holdAccepted: _holdAccepted,
      holdStatus: _holdStatus,
      onHoldCanceled: () => setState(() => _holdStatus = 'Canceled safely'),
      onHoldCompleted: () {
        setState(() {
          _holdAccepted = true;
          _holdStatus = 'Committed once';
        });
      },
      onResetHold: () {
        setState(() {
          _holdRun += 1;
          _holdAccepted = false;
          _holdStatus = 'Ready';
        });
      },
      rewardRun: _rewardRun,
      rewardKind: _rewardKind,
      onRewardKindChanged: (kind) => setState(() => _rewardKind = kind),
      onReplayReward: () => setState(() => _rewardRun += 1),
    ),
  };
}

class _LabHeader extends StatelessWidget {
  const _LabHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        MayhemSpacing.x4,
        MayhemSpacing.x3,
        MayhemSpacing.x2,
        MayhemSpacing.x2,
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MayhemText(
                  'INTERNAL',
                  variant: MayhemTextVariant.labelMicro,
                  color: MayhemColors.semanticWarning,
                ),
                SizedBox(height: MayhemSpacing.x1),
                MayhemText(
                  'Motion Lab',
                  variant: MayhemTextVariant.headlineMedium,
                ),
              ],
            ),
          ),
          Tooltip(
            message: 'Close Motion Lab',
            child: MayhemPressable(
              semanticLabel: 'Close Motion Lab',
              onPressed: onClose,
              borderRadius: MayhemRadii.pill,
              child: const SizedBox.square(
                dimension: 44,
                child: Center(
                  child: MayhemIcon(
                    MayhemGlyph.close,
                    semanticLabel: '',
                    decorative: true,
                    color: MayhemColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreferenceBar extends StatelessWidget {
  const _PreferenceBar({required this.preferences, required this.onChanged});

  final MayhemMotionPreferences preferences;
  final ValueChanged<MayhemMotionPreferences> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MayhemSpacing.x4),
      child: MayhemGlassControl(
        borderRadius: MayhemRadii.large,
        padding: const EdgeInsets.symmetric(
          horizontal: MayhemSpacing.x3,
          vertical: MayhemSpacing.x1,
        ),
        child: Row(
          children: [
            Expanded(
              child: _PreferenceToggle(
                label: 'Reduce motion',
                value: preferences.reduceMotion,
                onChanged: (value) =>
                    onChanged(preferences.copyWith(reduceMotion: value)),
              ),
            ),
            const SizedBox(
              height: MayhemSpacing.x8,
              child: VerticalDivider(color: MayhemColors.lineSubtle),
            ),
            Expanded(
              child: _PreferenceToggle(
                label: 'Opaque',
                value: preferences.reduceTransparency,
                onChanged: (value) =>
                    onChanged(preferences.copyWith(reduceTransparency: value)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreferenceToggle extends StatelessWidget {
  const _PreferenceToggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MayhemAccessibility.of(context).reduceMotion;
    return Semantics(
      toggled: value,
      label: label,
      onTap: () => onChanged(!value),
      child: ExcludeSemantics(
        child: MayhemPressable(
          semanticLabel: label,
          onPressed: () => onChanged(!value),
          borderRadius: MayhemRadii.pill,
          child: SizedBox(
            height: 44,
            child: Row(
              children: [
                Expanded(
                  child: MayhemText(
                    label,
                    variant: MayhemTextVariant.labelMedium,
                  ),
                ),
                const SizedBox(width: MayhemSpacing.x2),
                Container(
                  width: 42,
                  height: 26,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: value
                        ? MayhemColors.brandSignal
                        : MayhemColors.surfaceHigh,
                    borderRadius: MayhemRadii.pill,
                    border: Border.all(color: MayhemColors.lineStrong),
                  ),
                  child: AnimatedAlign(
                    alignment: value
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    duration: reduceMotion
                        ? Duration.zero
                        : MayhemDurations.fast,
                    curve: MayhemCurves.enter,
                    child: const SizedBox.square(
                      dimension: 18,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: MayhemColors.textPrimary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionSelector extends StatelessWidget {
  const _SectionSelector({required this.section, required this.onSelected});

  final _LabSection section;
  final ValueChanged<_LabSection> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(
        MayhemSpacing.x4,
        MayhemSpacing.x3,
        MayhemSpacing.x4,
        MayhemSpacing.x3,
      ),
      child: Row(
        children: [
          for (final item in _LabSection.values) ...[
            _SectionTab(
              label: item.name.toUpperCase(),
              selected: item == section,
              onPressed: () => onSelected(item),
            ),
            if (item != _LabSection.values.last)
              const SizedBox(width: MayhemSpacing.x2),
          ],
        ],
      ),
    );
  }
}

class _SectionTab extends StatelessWidget {
  const _SectionTab({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return MayhemPressable(
      semanticLabel: '$label section',
      onPressed: onPressed,
      borderRadius: MayhemRadii.pill,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected
              ? MayhemColors.brandColdLight
              : MayhemColors.surfaceBase,
          borderRadius: MayhemRadii.pill,
          border: Border.all(color: MayhemColors.lineStrong),
        ),
        child: SizedBox(
          height: 44,
          width: 104,
          child: Center(
            child: MayhemText(
              label,
              variant: MayhemTextVariant.labelMicro,
              color: selected
                  ? MayhemColors.textInverse
                  : MayhemColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _FoundationGallery extends StatelessWidget {
  const _FoundationGallery();

  static const _swatches = <(String, Color)>[
    ('Canvas', MayhemColors.canvasBase),
    ('Surface', MayhemColors.surfaceRaised),
    ('Signal', MayhemColors.brandSignal),
    ('Initiation', MayhemColors.traitInitiation),
    ('Expression', MayhemColors.traitExpression),
    ('Connection', MayhemColors.traitConnection),
    ('Presence', MayhemColors.traitPresence),
    ('Success', MayhemColors.semanticSuccess),
    ('Warning', MayhemColors.semanticWarning),
    ('Error', MayhemColors.semanticError),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const PageStorageKey('motion-lab-foundation'),
      padding: const EdgeInsets.fromLTRB(
        MayhemSpacing.x4,
        MayhemSpacing.x2,
        MayhemSpacing.x4,
        MayhemSpacing.x12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _GalleryHeading(index: '01', label: 'TOKEN PALETTE'),
          const SizedBox(height: MayhemSpacing.x4),
          Wrap(
            spacing: MayhemSpacing.x2,
            runSpacing: MayhemSpacing.x2,
            children: [
              for (final swatch in _swatches)
                _ColorSwatch(label: swatch.$1, color: swatch.$2),
            ],
          ),
          const SizedBox(height: MayhemSpacing.x10),
          const _GalleryHeading(index: '02', label: 'TYPOGRAPHY'),
          const SizedBox(height: MayhemSpacing.x5),
          const MayhemText(
            'Do the thing you keep avoiding.',
            variant: MayhemTextVariant.displayMedium,
          ),
          const SizedBox(height: MayhemSpacing.x4),
          const MayhemText(
            'Precision under pressure. One action, then evidence.',
            variant: MayhemTextVariant.bodyLarge,
          ),
          const SizedBox(height: MayhemSpacing.x4),
          const Row(
            children: [
              MayhemText('24', variant: MayhemTextVariant.numberStatus),
              SizedBox(width: MayhemSpacing.x3),
              MayhemText(
                'MOMENTUM DAYS',
                variant: MayhemTextVariant.labelMicro,
              ),
            ],
          ),
          const SizedBox(height: MayhemSpacing.x10),
          const _GalleryHeading(index: '03', label: 'MATERIAL'),
          const SizedBox(height: MayhemSpacing.x4),
          const MayhemGlass(
            padding: EdgeInsets.all(MayhemSpacing.x5),
            child: Row(
              children: [
                MayhemOfflineBadge(),
                SizedBox(width: MayhemSpacing.x3),
                Expanded(
                  child: MayhemText(
                    'Control glass keeps content readable.',
                    variant: MayhemTextVariant.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: MayhemSpacing.x4),
          MayhemPrimaryButton(label: 'Primary action', onPressed: () {}),
          const SizedBox(height: MayhemSpacing.x3),
          MayhemSecondaryButton(label: 'Secondary action', onPressed: () {}),
        ],
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label color',
      child: SizedBox(
        width: 104,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: MayhemSpacing.x12,
              decoration: BoxDecoration(
                color: color,
                borderRadius: MayhemRadii.small,
                border: Border.all(color: MayhemColors.lineStrong),
              ),
            ),
            const SizedBox(height: MayhemSpacing.x2),
            MayhemText(label, variant: MayhemTextVariant.labelMedium),
          ],
        ),
      ),
    );
  }
}

class _FeedGallery extends StatelessWidget {
  const _FeedGallery();

  static const items = [
    FeedFixtureItem(
      kind: FeedFixtureKind.challenge,
      eyebrow: 'Field challenge',
      statement: 'Ask for the thing you actually want.',
      detail: 'No apology before the request. No explanation after it.',
      energy: MayhemColors.traitInitiation,
    ),
    FeedFixtureItem(
      kind: FeedFixtureKind.training,
      eyebrow: 'Training',
      statement: 'Hold the silence for three full seconds.',
      detail: 'Let the other person decide what fills the space.',
      energy: MayhemColors.traitPresence,
    ),
    FeedFixtureItem(
      kind: FeedFixtureKind.scenario,
      eyebrow: 'Scenario',
      statement: 'Would you send the direct version?',
      detail: 'Choose before seeing how everyone else answered.',
      energy: MayhemColors.traitExpression,
    ),
    FeedFixtureItem(
      kind: FeedFixtureKind.season,
      eyebrow: 'Season signal',
      statement: 'Your next threshold is built from real attempts.',
      detail: 'Seven days remain in the current path.',
      energy: MayhemColors.traitConnection,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(color: MayhemColors.lineSubtle),
        ),
      ),
      child: FeedPager(items: items),
    );
  }
}

class _ObjectsGallery extends StatelessWidget {
  const _ObjectsGallery({
    required this.selectedNavigation,
    required this.onNavigationSelected,
  });

  final int selectedNavigation;
  final ValueChanged<int> onNavigationSelected;

  @override
  Widget build(BuildContext context) {
    const coreStates = MomentumCoreState.values;
    return SingleChildScrollView(
      key: const PageStorageKey('motion-lab-objects'),
      padding: const EdgeInsets.fromLTRB(
        MayhemSpacing.x4,
        MayhemSpacing.x2,
        MayhemSpacing.x4,
        MayhemSpacing.x12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _GalleryHeading(index: '01', label: 'MOMENTUM CORE'),
          const SizedBox(height: MayhemSpacing.x4),
          Wrap(
            alignment: WrapAlignment.spaceEvenly,
            spacing: MayhemSpacing.x3,
            runSpacing: MayhemSpacing.x6,
            children: [
              for (var index = 0; index < coreStates.length; index++)
                SizedBox(
                  width: 104,
                  child: Column(
                    children: [
                      MomentumCore(
                        days: index == 0 ? 0 : 7 + index,
                        state: coreStates[index],
                        size: 92,
                      ),
                      const SizedBox(height: MayhemSpacing.x2),
                      MayhemText(
                        coreStates[index].name.toUpperCase(),
                        variant: MayhemTextVariant.labelMicro,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: MayhemSpacing.x10),
          const _GalleryHeading(index: '02', label: 'RANK SIGILS'),
          const SizedBox(height: MayhemSpacing.x4),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              RankSigil(tier: RankSigilTier.spark, size: 112),
              RankSigil(tier: RankSigilTier.mover, size: 112),
            ],
          ),
          const SizedBox(height: MayhemSpacing.x10),
          const _GalleryHeading(index: '03', label: 'NAVIGATION'),
          const SizedBox(height: MayhemSpacing.x4),
          MayhemBottomNavigation(
            destinations: const [
              MayhemNavigationDestination(
                icon: MayhemGlyph.feed,
                label: 'Feed',
              ),
              MayhemNavigationDestination(
                icon: MayhemGlyph.journey,
                label: 'Journey',
              ),
              MayhemNavigationDestination(
                icon: MayhemGlyph.profile,
                label: 'You',
              ),
            ],
            selectedIndex: selectedNavigation,
            onSelected: onNavigationSelected,
          ),
        ],
      ),
    );
  }
}

class _ActionsGallery extends StatelessWidget {
  const _ActionsGallery({
    required this.holdKey,
    required this.holdAccepted,
    required this.holdStatus,
    required this.onHoldCanceled,
    required this.onHoldCompleted,
    required this.onResetHold,
    required this.rewardRun,
    required this.rewardKind,
    required this.onRewardKindChanged,
    required this.onReplayReward,
  });

  final Key holdKey;
  final bool holdAccepted;
  final String holdStatus;
  final VoidCallback onHoldCanceled;
  final VoidCallback onHoldCompleted;
  final VoidCallback onResetHold;
  final int rewardRun;
  final RewardStageKind rewardKind;
  final ValueChanged<RewardStageKind> onRewardKindChanged;
  final VoidCallback onReplayReward;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const PageStorageKey('motion-lab-actions'),
      padding: const EdgeInsets.fromLTRB(
        MayhemSpacing.x4,
        MayhemSpacing.x2,
        MayhemSpacing.x4,
        MayhemSpacing.x12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _GalleryHeading(index: '01', label: 'HOLD TO ACCEPT'),
          const SizedBox(height: MayhemSpacing.x4),
          MayhemHoldButton(
            key: holdKey,
            label: 'HOLD TO ACCEPT',
            onCanceled: onHoldCanceled,
            onCompleted: onHoldCompleted,
          ),
          const SizedBox(height: MayhemSpacing.x3),
          Row(
            children: [
              Expanded(
                child: MayhemText(
                  holdStatus,
                  variant: MayhemTextVariant.bodySmall,
                  color: holdAccepted
                      ? MayhemColors.semanticSuccess
                      : MayhemColors.textTertiary,
                ),
              ),
              MayhemSecondaryButton(
                label: 'Reset',
                onPressed: onResetHold,
                expand: false,
              ),
            ],
          ),
          const SizedBox(height: MayhemSpacing.x10),
          const _GalleryHeading(index: '02', label: 'REWARD STAGE'),
          const SizedBox(height: MayhemSpacing.x4),
          Row(
            children: [
              Expanded(
                child: _ModeChoice(
                  label: 'Attempt',
                  selected: rewardKind == RewardStageKind.attempt,
                  onPressed: () => onRewardKindChanged(RewardStageKind.attempt),
                ),
              ),
              const SizedBox(width: MayhemSpacing.x2),
              Expanded(
                child: _ModeChoice(
                  label: 'Complete',
                  selected: rewardKind == RewardStageKind.completion,
                  onPressed: () =>
                      onRewardKindChanged(RewardStageKind.completion),
                ),
              ),
            ],
          ),
          const SizedBox(height: MayhemSpacing.x4),
          SizedBox(
            height: 300,
            child: RewardStage(
              playId: '$rewardKind-$rewardRun',
              kind: rewardKind,
              xp: rewardKind == RewardStageKind.completion ? 120 : 72,
              traitLabel: 'Expression',
              momentumDays: rewardKind == RewardStageKind.completion ? 8 : 7,
            ),
          ),
          const SizedBox(height: MayhemSpacing.x4),
          MayhemSecondaryButton(
            label: 'Replay reward',
            onPressed: onReplayReward,
          ),
          const SizedBox(height: MayhemSpacing.x10),
          const _GalleryHeading(index: '03', label: 'SHEET'),
          const SizedBox(height: MayhemSpacing.x4),
          const MayhemSheet(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MayhemText(
                  'Prepare the first sentence.',
                  variant: MayhemTextVariant.headlineSmall,
                ),
                SizedBox(height: MayhemSpacing.x3),
                MayhemText(
                  'Short enough to say before your brain negotiates it away.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeChoice extends StatelessWidget {
  const _ModeChoice({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return MayhemPressable(
      semanticLabel: label,
      onPressed: onPressed,
      borderRadius: MayhemRadii.medium,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? MayhemColors.surfaceHigh : MayhemColors.surfaceBase,
          borderRadius: MayhemRadii.medium,
          border: Border.all(
            color: selected
                ? MayhemColors.brandSignalSoft
                : MayhemColors.lineSubtle,
          ),
        ),
        child: SizedBox(
          height: 52,
          child: Center(
            child: MayhemText(label, variant: MayhemTextVariant.labelLarge),
          ),
        ),
      ),
    );
  }
}

class _GalleryHeading extends StatelessWidget {
  const _GalleryHeading({required this.index, required this.label});

  final String index;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        MayhemText(
          index,
          variant: MayhemTextVariant.labelMicro,
          color: MayhemColors.brandSignalSoft,
        ),
        const SizedBox(width: MayhemSpacing.x3),
        Expanded(
          child: MayhemText(label, variant: MayhemTextVariant.labelMicro),
        ),
        const Expanded(child: Divider(color: MayhemColors.lineSubtle)),
      ],
    );
  }
}
