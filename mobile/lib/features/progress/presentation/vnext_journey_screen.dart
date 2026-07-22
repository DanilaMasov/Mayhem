import 'package:flutter/material.dart';

import '../../../core/design_system/components/components.dart';
import '../../../core/design_system/tokens/tokens.dart';
import '../../../core/localization/mayhem_strings.dart';
import '../../challenge/domain/challenge_models.dart';
import '../../season/application/season_experience_controller.dart';
import '../../season/domain/season_experience_state.dart';
import '../../streak/domain/momentum_state.dart';
import '../application/journey_controller.dart';
import '../domain/progress_models.dart';

abstract final class JourneyRoutes {
  static const root = '/journey';
  static const ranks = '/journey/ranks';
  static const traits = '/journey/traits';
  static const momentum = '/journey/momentum';
  static const history = '/journey/history';
  static const season = '/journey/season';
}

class VNextJourneyScreen extends StatelessWidget {
  const VNextJourneyScreen({
    super.key,
    required this.controller,
    required this.season,
  });

  final JourneyController controller;
  final SeasonExperienceController season;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([controller, season]),
      builder: (context, child) {
        if (controller.loading) {
          return Center(
            child: MayhemText(
              context.strings.loading,
              variant: MayhemTextVariant.bodyLarge,
            ),
          );
        }
        final snapshot = controller.snapshot;
        if (snapshot == null || controller.error != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(MayhemSpacing.x6),
              child: MayhemSecondaryButton(
                label: context.strings.retry,
                onPressed: controller.initialize,
                expand: false,
              ),
            ),
          );
        }
        return _JourneyContent(snapshot: snapshot, season: season.state);
      },
    );
  }
}

class _JourneyContent extends StatelessWidget {
  const _JourneyContent({required this.snapshot, required this.season});

  final JourneySnapshot snapshot;
  final SeasonExperienceState season;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final signals = traitSignals(snapshot.projection);
    final strongest = strongestTrait(snapshot.projection.traitXp);
    return SafeArea(
      bottom: false,
      child: ListView(
        key: const PageStorageKey('journey-scroll'),
        padding: const EdgeInsets.only(bottom: 132),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              MayhemSpacing.x5,
              MayhemSpacing.x5,
              MayhemSpacing.x5,
              MayhemSpacing.x3,
            ),
            child: MayhemText(
              strings.journeyTitle,
              variant: MayhemTextVariant.labelMicro,
            ),
          ),
          _JourneyTopScene(snapshot: snapshot),
          if (season.visible)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                MayhemSpacing.x5,
                MayhemSpacing.x6,
                MayhemSpacing.x5,
                0,
              ),
              child: _SeasonSummary(state: season),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              MayhemSpacing.x5,
              MayhemSpacing.x8,
              MayhemSpacing.x5,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MayhemText(
                  snapshot.projection.totalXp == 0
                      ? strings.journeyInsightEmpty
                      : strings.journeyInsightStrongest(
                          strings.traitName(strongest),
                        ),
                  variant: MayhemTextVariant.headlineSmall,
                ),
                const SizedBox(height: MayhemSpacing.x10),
                _SectionHeader(
                  title: strings.traitsTitle,
                  onPressed: () =>
                      Navigator.of(context).pushNamed(JourneyRoutes.traits),
                ),
                const SizedBox(height: MayhemSpacing.x4),
                Center(
                  child: TraitConstellation(
                    values: signals,
                    semanticLabel: traitSemanticLabel(strings, signals),
                    onPressed: () =>
                        Navigator.of(context).pushNamed(JourneyRoutes.traits),
                    size: 230,
                  ),
                ),
                const SizedBox(height: MayhemSpacing.x2),
                Center(
                  child: MayhemText(
                    strings.traitsAccessibleHint,
                    variant: MayhemTextVariant.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: MayhemSpacing.x10),
                _SectionHeader(
                  title: strings.momentumTitle,
                  onPressed: () =>
                      Navigator.of(context).pushNamed(JourneyRoutes.momentum),
                ),
                const SizedBox(height: MayhemSpacing.x4),
                _MomentumSummary(snapshot: snapshot),
                const SizedBox(height: MayhemSpacing.x10),
                _SectionHeader(
                  title: strings.historyTitle,
                  onPressed: () =>
                      Navigator.of(context).pushNamed(JourneyRoutes.history),
                ),
                const SizedBox(height: MayhemSpacing.x3),
                if (snapshot.history.isEmpty)
                  MayhemText(strings.historyEmpty)
                else
                  for (final entry in snapshot.history.take(3))
                    _HistoryRow(entry: entry),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SeasonSummary extends StatelessWidget {
  const _SeasonSummary({required this.state});

  final SeasonExperienceState state;

  @override
  Widget build(BuildContext context) {
    final package = state.package;
    final strings = context.strings;
    return MayhemPressable(
      semanticLabel: strings.seasonTitle,
      onPressed: () => Navigator.of(context).pushNamed(JourneyRoutes.season),
      borderRadius: MayhemRadii.medium,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: MayhemColors.surfaceBase,
          borderRadius: MayhemRadii.medium,
          border: Border.all(color: MayhemColors.lineStrong),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 112),
          child: Padding(
            padding: const EdgeInsets.all(MayhemSpacing.x4),
            child: Row(
              children: [
                const Icon(
                  Icons.local_fire_department_outlined,
                  color: MayhemColors.brandSignalSoft,
                  size: 30,
                ),
                const SizedBox(width: MayhemSpacing.x4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      MayhemText(
                        strings.seasonTitle,
                        variant: MayhemTextVariant.labelMicro,
                      ),
                      const SizedBox(height: MayhemSpacing.x1),
                      MayhemText(
                        package?.season.title ?? strings.seasonUnavailable,
                        variant: MayhemTextVariant.labelLarge,
                        color: MayhemColors.textPrimary,
                        maxLines: 2,
                      ),
                      if (state.currentDay case final day?) ...[
                        const SizedBox(height: MayhemSpacing.x1),
                        MayhemText(
                          strings.seasonDay(day),
                          variant: MayhemTextVariant.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _JourneyTopScene extends StatelessWidget {
  const _JourneyTopScene({required this.snapshot});

  final JourneySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final rank = snapshot.projection.rank;
    final rankTier = rank.family == RankFamily.spark
        ? RankSigilTier.spark
        : RankSigilTier.mover;
    return MayhemPressable(
      key: const ValueKey('rank-path-preview'),
      semanticLabel: strings.rankPathOpen,
      onPressed: () => Navigator.of(context).pushNamed(JourneyRoutes.ranks),
      borderRadius: BorderRadius.zero,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [MayhemColors.brandVoid, MayhemColors.canvasRaised],
          ),
        ),
        child: SizedBox(
          height: 284,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: MayhemSpacing.x5,
              vertical: MayhemSpacing.x5,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: MayhemText(
                        strings.currentArena,
                        variant: MayhemTextVariant.labelMicro,
                        color: MayhemColors.brandSignalSoft,
                      ),
                    ),
                    Flexible(
                      child: MayhemText(
                        strings.rankPathOpen,
                        variant: MayhemTextVariant.labelMicro,
                        textAlign: TextAlign.end,
                        maxLines: 2,
                      ),
                    ),
                    const SizedBox(width: MayhemSpacing.x2),
                    const Icon(Icons.arrow_upward, size: 18),
                  ],
                ),
                const SizedBox(height: MayhemSpacing.x3),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 370;
                      final rankBlock = Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            RankSigil(
                              tier: rankTier,
                              size: compact ? 82 : 104,
                              showLabel: false,
                            ),
                            const SizedBox(height: MayhemSpacing.x2),
                            MayhemText(
                              rank.label,
                              variant: MayhemTextVariant.headlineMedium,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: MayhemSpacing.x3),
                            SizedBox(
                              width: 120,
                              child: LinearProgressIndicator(
                                value: snapshot.projection.rankProgress,
                                minHeight: 4,
                                borderRadius: MayhemRadii.pill,
                                backgroundColor: MayhemColors.lineStrong,
                                color: MayhemColors.brandSignalSoft,
                              ),
                            ),
                          ],
                        ),
                      );
                      final momentumBlock = Expanded(
                        child: Center(
                          child: MomentumCore(
                            days: snapshot.momentum.currentDays,
                            state: momentumCoreState(snapshot.momentum),
                            size: compact ? 106 : 128,
                          ),
                        ),
                      );
                      return Row(children: [rankBlock, momentumBlock]);
                    },
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

class _MomentumSummary extends StatelessWidget {
  const _MomentumSummary({required this.snapshot});

  final JourneySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return MayhemPressable(
      semanticLabel: strings.momentumTitle,
      onPressed: () => Navigator.of(context).pushNamed(JourneyRoutes.momentum),
      borderRadius: MayhemRadii.medium,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: MayhemColors.surfaceBase,
          borderRadius: MayhemRadii.medium,
          border: Border.all(color: MayhemColors.lineStrong),
        ),
        child: Padding(
          padding: const EdgeInsets.all(MayhemSpacing.x5),
          child: Column(
            children: [
              Row(
                children: [
                  _Metric(
                    label: strings.currentMomentum,
                    value: '${snapshot.momentum.currentDays}',
                  ),
                  _Metric(
                    label: strings.longestMomentum,
                    value: '${snapshot.momentum.longestDays}',
                  ),
                  _Metric(
                    label: strings.shields,
                    value: '${snapshot.momentum.shieldsAvailable}',
                  ),
                ],
              ),
              if (snapshot.momentum.pendingTimezoneReview) ...[
                const SizedBox(height: MayhemSpacing.x4),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule_outlined,
                      size: 18,
                      color: MayhemColors.semanticWarning,
                    ),
                    const SizedBox(width: MayhemSpacing.x2),
                    Expanded(
                      child: MayhemText(
                        strings.momentumPending,
                        variant: MayhemTextVariant.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          MayhemText(value, variant: MayhemTextVariant.numberStatus),
          const SizedBox(height: MayhemSpacing.x1),
          MayhemText(
            label,
            variant: MayhemTextVariant.labelMicro,
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onPressed});

  final String title;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: MayhemText(title, variant: MayhemTextVariant.labelLarge),
        ),
        IconButton(
          onPressed: onPressed,
          tooltip: title,
          icon: const Icon(Icons.arrow_forward, size: 20),
        ),
      ],
    );
  }
}

class VNextTraitsDetailScreen extends StatelessWidget {
  const VNextTraitsDetailScreen({super.key, required this.snapshot});

  final JourneySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final signals = traitSignals(snapshot.projection);
    return _DetailScaffold(
      title: strings.traitsTitle,
      child: ListView(
        padding: const EdgeInsets.all(MayhemSpacing.x5),
        children: [
          Center(
            child: TraitConstellation(
              values: signals,
              semanticLabel: traitSemanticLabel(strings, signals),
              size: 260,
            ),
          ),
          const SizedBox(height: MayhemSpacing.x8),
          for (final trait in Trait.values)
            Padding(
              padding: const EdgeInsets.only(bottom: MayhemSpacing.x5),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MayhemText(
                          strings.traitName(trait),
                          variant: MayhemTextVariant.labelLarge,
                          color: MayhemColors.textPrimary,
                        ),
                        const SizedBox(height: MayhemSpacing.x1),
                        MayhemText(
                          '${snapshot.projection.traitXp[trait] ?? 0} XP',
                          variant: MayhemTextVariant.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  MayhemText(
                    '${signals[trait]}',
                    variant: MayhemTextVariant.numberStatus,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class VNextMomentumDetailScreen extends StatelessWidget {
  const VNextMomentumDetailScreen({super.key, required this.snapshot});

  final JourneySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final fallbackDate = _dateKey(snapshot.projection.updatedAt);
    final anchor = DateTime.parse(
      '${snapshot.momentum.lastEarnedLocalDate ?? fallbackDate}T00:00:00',
    );
    final first = DateTime(anchor.year, anchor.month, 1);
    final days = DateUtils.getDaysInMonth(anchor.year, anchor.month);
    final leading = first.weekday - 1;
    final byDate = {
      for (final entry in snapshot.history) entry.localDate: entry,
    };
    return _DetailScaffold(
      title: strings.momentumTitle,
      child: ListView(
        padding: const EdgeInsets.all(MayhemSpacing.x5),
        children: [
          Center(
            child: MomentumCore(
              days: snapshot.momentum.currentDays,
              state: momentumCoreState(snapshot.momentum),
              size: 164,
            ),
          ),
          const SizedBox(height: MayhemSpacing.x5),
          Row(
            children: [
              _Metric(
                label: strings.longestMomentum,
                value: '${snapshot.momentum.longestDays}',
              ),
              _Metric(
                label: strings.shields,
                value: '${snapshot.momentum.shieldsAvailable}',
              ),
            ],
          ),
          const SizedBox(height: MayhemSpacing.x6),
          MayhemText(
            strings.nextMilestone(snapshot.momentum.nextMilestone),
            variant: MayhemTextVariant.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: MayhemSpacing.x8),
          MayhemText(strings.earnedDays, variant: MayhemTextVariant.labelLarge),
          const SizedBox(height: MayhemSpacing.x4),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: MayhemSpacing.x2,
            crossAxisSpacing: MayhemSpacing.x2,
            children: [
              for (final weekday in strings.weekdaysShort)
                Center(
                  child: MayhemText(
                    weekday,
                    variant: MayhemTextVariant.labelMicro,
                  ),
                ),
              for (var index = 0; index < leading; index++)
                const SizedBox.shrink(),
              for (var day = 1; day <= days; day++)
                _CalendarDay(
                  day: day,
                  entry:
                      byDate[_dateKey(
                        DateTime(anchor.year, anchor.month, day),
                      )],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CalendarDay extends StatelessWidget {
  const _CalendarDay({required this.day, this.entry});

  final int day;
  final JourneyHistoryEntry? entry;

  @override
  Widget build(BuildContext context) {
    final earned = entry != null;
    return Semantics(
      button: earned,
      label: earned ? '$day. ${entry!.title}' : '$day',
      child: GestureDetector(
        onTap: earned ? () => _showQualifyingAction(context, entry!) : null,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: earned
                ? MayhemColors.semanticSuccess.withValues(alpha: 0.18)
                : MayhemColors.surfaceBase,
            borderRadius: MayhemRadii.small,
            border: Border.all(
              color: earned
                  ? MayhemColors.semanticSuccess
                  : MayhemColors.lineSubtle,
            ),
          ),
          child: Center(
            child: MayhemText(
              '$day',
              variant: MayhemTextVariant.labelMedium,
              color: earned
                  ? MayhemColors.textPrimary
                  : MayhemColors.textTertiary,
            ),
          ),
        ),
      ),
    );
  }

  void _showQualifyingAction(BuildContext context, JourneyHistoryEntry entry) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: MayhemColors.surfaceRaised,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(MayhemSpacing.x6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MayhemText(
                context.strings.qualifyingAction,
                variant: MayhemTextVariant.labelMicro,
              ),
              const SizedBox(height: MayhemSpacing.x3),
              MayhemText(entry.title, variant: MayhemTextVariant.headlineSmall),
              const SizedBox(height: MayhemSpacing.x3),
              MayhemText(
                entry.attempt.status == ChallengeAttemptStatus.completed
                    ? context.strings.completed
                    : context.strings.attempted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _HistoryFilter { all, attempted, completed, notes }

class VNextHistoryScreen extends StatefulWidget {
  const VNextHistoryScreen({super.key, required this.snapshot});

  final JourneySnapshot snapshot;

  @override
  State<VNextHistoryScreen> createState() => _VNextHistoryScreenState();
}

class _VNextHistoryScreenState extends State<VNextHistoryScreen> {
  _HistoryFilter _filter = _HistoryFilter.all;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final entries = widget.snapshot.history
        .where((entry) {
          return switch (_filter) {
            _HistoryFilter.all => true,
            _HistoryFilter.attempted =>
              entry.attempt.status == ChallengeAttemptStatus.attempted,
            _HistoryFilter.completed =>
              entry.attempt.status == ChallengeAttemptStatus.completed,
            _HistoryFilter.notes =>
              entry.reflection?.privateNote?.isNotEmpty == true,
          };
        })
        .toList(growable: false);
    return _DetailScaffold(
      title: strings.historyTitle,
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: MayhemSpacing.x5),
            child: Row(
              children: [
                _FilterChoice(
                  label: strings.all,
                  selected: _filter == _HistoryFilter.all,
                  onSelected: () =>
                      setState(() => _filter = _HistoryFilter.all),
                ),
                _FilterChoice(
                  label: strings.attempted,
                  selected: _filter == _HistoryFilter.attempted,
                  onSelected: () =>
                      setState(() => _filter = _HistoryFilter.attempted),
                ),
                _FilterChoice(
                  label: strings.completed,
                  selected: _filter == _HistoryFilter.completed,
                  onSelected: () =>
                      setState(() => _filter = _HistoryFilter.completed),
                ),
                _FilterChoice(
                  label: strings.savedNotes,
                  selected: _filter == _HistoryFilter.notes,
                  onSelected: () =>
                      setState(() => _filter = _HistoryFilter.notes),
                ),
              ],
            ),
          ),
          const SizedBox(height: MayhemSpacing.x3),
          Expanded(
            child: entries.isEmpty
                ? Center(child: MayhemText(strings.historyEmpty))
                : ListView.builder(
                    key: const PageStorageKey('journey-history-scroll'),
                    padding: const EdgeInsets.fromLTRB(
                      MayhemSpacing.x5,
                      0,
                      MayhemSpacing.x5,
                      MayhemSpacing.x8,
                    ),
                    itemCount: entries.length,
                    itemBuilder: (context, index) =>
                        _HistoryRow(entry: entries[index], openDetail: true),
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilterChoice extends StatelessWidget {
  const _FilterChoice({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: MayhemSpacing.x2),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry, this.openDetail = false});

  final JourneyHistoryEntry entry;
  final bool openDetail;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final completed = entry.attempt.status == ChallengeAttemptStatus.completed;
    return Padding(
      padding: const EdgeInsets.only(bottom: MayhemSpacing.x3),
      child: MayhemPressable(
        semanticLabel: entry.title,
        onPressed: openDetail ? () => _open(context) : null,
        borderRadius: MayhemRadii.medium,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: MayhemColors.surfaceBase,
            borderRadius: MayhemRadii.medium,
            border: Border.all(color: MayhemColors.lineSubtle),
          ),
          child: Padding(
            padding: const EdgeInsets.all(MayhemSpacing.x4),
            child: Row(
              children: [
                Icon(
                  completed ? Icons.check_outlined : Icons.bolt_outlined,
                  color: completed
                      ? MayhemColors.semanticSuccess
                      : MayhemColors.brandSignalSoft,
                ),
                const SizedBox(width: MayhemSpacing.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MayhemText(
                        entry.title,
                        variant: MayhemTextVariant.labelLarge,
                        color: MayhemColors.textPrimary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: MayhemSpacing.x1),
                      MayhemText(
                        '${entry.localDate} · '
                        '${completed ? strings.completed : strings.attempted}',
                        variant: MayhemTextVariant.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (entry.attempt.result?.earnedXp case final xp?)
                  MayhemText(
                    strings.xpEarned(xp),
                    variant: MayhemTextVariant.labelMedium,
                    color: MayhemColors.brandSignalSoft,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => VNextHistoryDetailScreen(entry: entry),
      ),
    );
  }
}

class VNextHistoryDetailScreen extends StatelessWidget {
  const VNextHistoryDetailScreen({super.key, required this.entry});

  final JourneyHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final result = entry.attempt.result!;
    return _DetailScaffold(
      title: strings.historyTitle,
      child: ListView(
        padding: const EdgeInsets.all(MayhemSpacing.x5),
        children: [
          MayhemText(entry.title, variant: MayhemTextVariant.headlineLarge),
          const SizedBox(height: MayhemSpacing.x4),
          MayhemText(
            entry.attempt.status == ChallengeAttemptStatus.completed
                ? strings.completed
                : strings.attempted,
            variant: MayhemTextVariant.labelLarge,
            color: MayhemColors.semanticSuccess,
          ),
          const SizedBox(height: MayhemSpacing.x2),
          MayhemText(entry.localDate),
          if (result.earnedXp case final xp?) ...[
            const SizedBox(height: MayhemSpacing.x4),
            MayhemText(
              strings.xpEarned(xp),
              variant: MayhemTextVariant.numberStatus,
              color: MayhemColors.brandSignalSoft,
            ),
          ],
          const SizedBox(height: MayhemSpacing.x8),
          MayhemText(
            strings.privateReflection,
            variant: MayhemTextVariant.labelLarge,
          ),
          const SizedBox(height: MayhemSpacing.x3),
          MayhemText(
            entry.reflection?.privateNote?.isNotEmpty == true
                ? entry.reflection!.privateNote!
                : strings.noPrivateReflection,
            variant: MayhemTextVariant.bodyLarge,
            color: MayhemColors.textPrimary,
          ),
        ],
      ),
    );
  }
}

class _DetailScaffold extends StatelessWidget {
  const _DetailScaffold({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          tooltip: context.strings.back,
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: child,
    );
  }
}

Map<Trait, int> traitSignals(ProgressProjection projection) {
  final maxXp = projection.traitXp.values.fold<int>(0, (max, value) {
    return value > max ? value : max;
  });
  if (maxXp > 0) {
    return {
      for (final trait in Trait.values)
        trait: (((projection.traitXp[trait] ?? 0) / maxXp) * 100).round(),
    };
  }
  return {
    for (final trait in Trait.values)
      trait: ((projection.difficulty[trait]?.rating ?? 2) * 20).round(),
  };
}

Trait strongestTrait(Map<Trait, int> traitXp) => Trait.values.reduce(
  (current, next) =>
      (traitXp[next] ?? 0) > (traitXp[current] ?? 0) ? next : current,
);

String traitSemanticLabel(MayhemStrings strings, Map<Trait, int> values) =>
    Trait.values
        .map((trait) => '${strings.traitName(trait)} ${values[trait] ?? 0}')
        .join(', ');

MomentumCoreState momentumCoreState(MomentumState momentum) {
  if (momentum.pendingTimezoneReview) return MomentumCoreState.available;
  if (momentum.currentDays == 0) return MomentumCoreState.dormant;
  if (momentum.shieldsAvailable > 0 && !momentum.earnedToday) {
    return MomentumCoreState.shielded;
  }
  return momentum.earnedToday
      ? MomentumCoreState.earned
      : MomentumCoreState.available;
}

String _dateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
