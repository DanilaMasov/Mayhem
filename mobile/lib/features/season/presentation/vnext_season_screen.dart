import 'package:flutter/material.dart';

import '../../../core/design_system/components/components.dart';
import '../../../core/design_system/tokens/tokens.dart';
import '../../../core/localization/mayhem_strings.dart';
import '../application/season_experience_controller.dart';
import '../domain/season_experience_state.dart';

class VNextSeasonScreen extends StatelessWidget {
  const VNextSeasonScreen({super.key, required this.controller});

  final SeasonExperienceController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.strings.seasonTitle),
        leading: IconButton(
          tooltip: context.strings.back,
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, child) => _SeasonBody(
          state: controller.state,
          onRetry: controller.initialize,
        ),
      ),
    );
  }
}

class _SeasonBody extends StatelessWidget {
  const _SeasonBody({required this.state, required this.onRetry});

  final SeasonExperienceState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final package = state.package;
    if (state.availability == SeasonAvailability.loadingCached ||
        (state.availability == SeasonAvailability.loadingRemote &&
            package == null)) {
      return Center(child: MayhemText(context.strings.loading));
    }
    if (package == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(MayhemSpacing.x6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.event_busy_outlined,
                size: 38,
                color: MayhemColors.textSecondary,
              ),
              const SizedBox(height: MayhemSpacing.x4),
              MayhemText(
                context.strings.seasonUnavailable,
                variant: MayhemTextVariant.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: MayhemSpacing.x5),
              MayhemSecondaryButton(
                label: context.strings.retry,
                onPressed: onRetry,
                expand: false,
              ),
            ],
          ),
        ),
      );
    }

    final strings = context.strings;
    final completedDays = state.participation?.completedDays.length ?? 0;
    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          MayhemSpacing.x5,
          MayhemSpacing.x5,
          MayhemSpacing.x5,
          MayhemSpacing.x8,
        ),
        children: [
          MayhemText(
            package.season.title,
            variant: MayhemTextVariant.headlineMedium,
          ),
          const SizedBox(height: MayhemSpacing.x2),
          _FreshnessLine(state: state),
          const SizedBox(height: MayhemSpacing.x8),
          if (state.currentDay case final day?) ...[
            MayhemText(
              strings.seasonDay(day),
              variant: MayhemTextVariant.labelMicro,
            ),
            const SizedBox(height: MayhemSpacing.x2),
            MayhemText(
              package.season.days[day - 1].title,
              variant: MayhemTextVariant.headlineSmall,
            ),
            const SizedBox(height: MayhemSpacing.x4),
          ],
          LinearProgressIndicator(
            value: completedDays / 7,
            minHeight: 4,
            backgroundColor: MayhemColors.lineStrong,
            color: MayhemColors.brandSignalSoft,
          ),
          const SizedBox(height: MayhemSpacing.x2),
          MayhemText(
            strings.seasonDaysCompleted(completedDays, 7),
            variant: MayhemTextVariant.bodySmall,
          ),
          const SizedBox(height: MayhemSpacing.x8),
          _StatusPanel(
            icon: Icons.flag_outlined,
            label: _membershipLabel(strings, state.membership),
          ),
          const SizedBox(height: MayhemSpacing.x3),
          _StatusPanel(
            icon: Icons.bolt_outlined,
            label: _bossLabel(strings, state.bossPhase),
          ),
          if (state.socialProofCount case final count?) ...[
            const SizedBox(height: MayhemSpacing.x3),
            _StatusPanel(
              icon: Icons.groups_2_outlined,
              label: strings.seasonParticipants(count),
            ),
          ],
        ],
      ),
    );
  }

  String _membershipLabel(MayhemStrings strings, SeasonMembership membership) =>
      switch (membership) {
        SeasonMembership.notJoined => strings.seasonNotJoined,
        SeasonMembership.expired => strings.seasonExpired,
        SeasonMembership.completed => strings.seasonCompleted,
        SeasonMembership.joining => strings.loading,
        SeasonMembership.joinFailedRetryable => strings.remoteSyncFailed,
        SeasonMembership.active =>
          state.currentDay == null
              ? strings.seasonTitle
              : strings.seasonDay(state.currentDay!),
        SeasonMembership.unavailable => strings.seasonUnavailable,
      };

  String _bossLabel(MayhemStrings strings, SeasonBossPhase phase) =>
      switch (phase) {
        SeasonBossPhase.locked => strings.bossLocked,
        SeasonBossPhase.upcoming => strings.bossUpcoming,
        SeasonBossPhase.open => strings.bossOpen,
        SeasonBossPhase.submitting => strings.bossSubmitting,
        SeasonBossPhase.alreadyParticipated => strings.bossAlreadyParticipated,
        SeasonBossPhase.completed => strings.bossCompleted,
      };
}

class _FreshnessLine extends StatelessWidget {
  const _FreshnessLine({required this.state});

  final SeasonExperienceState state;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final (icon, color, label) = switch (state.availability) {
      SeasonAvailability.loadingRemote => (
        Icons.sync_outlined,
        MayhemColors.textSecondary,
        strings.seasonRefreshing,
      ),
      SeasonAvailability.conflictRefreshRequired => (
        Icons.sync_problem_outlined,
        MayhemColors.semanticWarning,
        strings.seasonConflict,
      ),
      SeasonAvailability.incompatiblePackage ||
      SeasonAvailability.recoverableError => (
        Icons.error_outline,
        MayhemColors.semanticError,
        strings.seasonStateError,
      ),
      _ when state.freshness == SeasonDataFreshness.serverConfirmed => (
        Icons.cloud_done_outlined,
        MayhemColors.semanticSuccess,
        strings.seasonConfirmed,
      ),
      _ => (
        Icons.offline_pin_outlined,
        MayhemColors.semanticWarning,
        strings.seasonCached,
      ),
    };
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: MayhemSpacing.x2),
        Expanded(
          child: MayhemText(label, variant: MayhemTextVariant.bodySmall),
        ),
      ],
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: MayhemColors.surfaceBase,
      border: Border.all(color: MayhemColors.lineStrong),
      borderRadius: MayhemRadii.medium,
    ),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 72),
      child: Padding(
        padding: const EdgeInsets.all(MayhemSpacing.x4),
        child: Row(
          children: [
            Icon(icon, color: MayhemColors.textSecondary),
            const SizedBox(width: MayhemSpacing.x3),
            Expanded(
              child: MayhemText(
                label,
                variant: MayhemTextVariant.bodyMedium,
                color: MayhemColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
