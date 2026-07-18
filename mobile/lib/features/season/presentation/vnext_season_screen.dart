import 'package:flutter/material.dart';

import '../../../core/design_system/components/components.dart';
import '../../../core/design_system/tokens/tokens.dart';
import '../../../core/localization/mayhem_strings.dart';
import '../../challenge/domain/challenge_models.dart';
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
          onRetry: controller.retryRemote,
          canRetry: controller.canRetryRemote,
          canJoin: controller.canJoin,
          onJoin: controller.join,
          canCompleteDay: controller.canCompleteDay,
          onCompleteDay: controller.completeDay,
          canParticipateBoss: controller.canParticipateBoss,
          retriesPendingBoss: controller.retriesPendingBoss,
          onParticipateBoss: controller.participateBoss,
        ),
      ),
    );
  }
}

class _SeasonBody extends StatelessWidget {
  const _SeasonBody({
    required this.state,
    required this.onRetry,
    required this.canRetry,
    required this.canJoin,
    required this.onJoin,
    required this.canCompleteDay,
    required this.onCompleteDay,
    required this.canParticipateBoss,
    required this.retriesPendingBoss,
    required this.onParticipateBoss,
  });

  final SeasonExperienceState state;
  final VoidCallback onRetry;
  final bool canRetry;
  final bool canJoin;
  final VoidCallback onJoin;
  final bool canCompleteDay;
  final VoidCallback onCompleteDay;
  final bool canParticipateBoss;
  final bool retriesPendingBoss;
  final ValueChanged<ChallengeRouteType> onParticipateBoss;

  @override
  Widget build(BuildContext context) {
    final package = state.package;
    if (state.availability == SeasonAvailability.loadingCached ||
        (state.availability == SeasonAvailability.loadingRemote &&
            package == null)) {
      return Center(child: MayhemText(context.strings.loading));
    }
    if (package == null) {
      final strings = context.strings;
      final (icon, color, message) = switch (state.availability) {
        SeasonAvailability.incompatiblePackage => (
          Icons.extension_off_outlined,
          MayhemColors.semanticError,
          strings.seasonPackageIncompatible,
        ),
        SeasonAvailability.recoverableError => (
          Icons.error_outline,
          MayhemColors.semanticError,
          strings.seasonRecoverableError,
        ),
        SeasonAvailability.conflictRefreshRequired => (
          Icons.sync_problem_outlined,
          MayhemColors.semanticWarning,
          strings.seasonConflict,
        ),
        _ => (
          Icons.event_busy_outlined,
          MayhemColors.textSecondary,
          strings.seasonUnavailable,
        ),
      };
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(MayhemSpacing.x6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 38, color: color),
              const SizedBox(height: MayhemSpacing.x4),
              MayhemText(
                message,
                variant: MayhemTextVariant.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: MayhemSpacing.x5),
              MayhemSecondaryButton(
                label: strings.retry,
                onPressed: canRetry ? onRetry : null,
                enabled: canRetry,
                loading: state.availability == SeasonAvailability.loadingRemote,
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
        key: const PageStorageKey('season-scroll'),
        padding: const EdgeInsets.fromLTRB(
          MayhemSpacing.x5,
          MayhemSpacing.x5,
          MayhemSpacing.x5,
          MayhemSpacing.x20 + MayhemSpacing.x10,
        ),
        children: [
          MayhemText(
            package.season.title,
            variant: MayhemTextVariant.headlineMedium,
          ),
          const SizedBox(height: MayhemSpacing.x2),
          _FreshnessLine(state: state),
          if (state.availability ==
                  SeasonAvailability.conflictRefreshRequired ||
              state.availability == SeasonAvailability.incompatiblePackage ||
              state.availability == SeasonAvailability.recoverableError) ...[
            const SizedBox(height: MayhemSpacing.x4),
            MayhemSecondaryButton(
              label: strings.retry,
              onPressed: canRetry ? onRetry : null,
              enabled: canRetry,
            ),
          ],
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
          if (state.membership == SeasonMembership.notJoined ||
              state.membership == SeasonMembership.joining ||
              state.membership == SeasonMembership.joinFailedRetryable) ...[
            const SizedBox(height: MayhemSpacing.x3),
            MayhemText(
              canJoin || state.membership == SeasonMembership.joining
                  ? strings.seasonJoinExplanation
                  : strings.seasonJoinRemoteRequired,
              variant: MayhemTextVariant.bodySmall,
            ),
            const SizedBox(height: MayhemSpacing.x4),
            MayhemPrimaryButton(
              label: state.membership == SeasonMembership.joinFailedRetryable
                  ? strings.seasonJoinRetry
                  : strings.seasonJoin,
              onPressed: canJoin ? onJoin : null,
              enabled: canJoin,
              loading: state.membership == SeasonMembership.joining,
            ),
          ],
          const SizedBox(height: MayhemSpacing.x3),
          _StatusPanel(
            icon: Icons.today_outlined,
            label: _dayLabel(strings, state.dayPhase),
          ),
          if (state.dayPhase == SeasonDayPhase.available ||
              state.dayPhase == SeasonDayPhase.inProgress ||
              state.dayPhase == SeasonDayPhase.failedRetryable) ...[
            const SizedBox(height: MayhemSpacing.x3),
            MayhemPrimaryButton(
              label: state.dayPhase == SeasonDayPhase.failedRetryable
                  ? strings.seasonRetryDay
                  : strings.seasonCompleteDay(state.currentDay ?? 1),
              onPressed: canCompleteDay ? onCompleteDay : null,
              enabled: canCompleteDay,
              loading: state.dayPhase == SeasonDayPhase.inProgress,
            ),
            if (!canCompleteDay &&
                state.dayPhase != SeasonDayPhase.inProgress) ...[
              const SizedBox(height: MayhemSpacing.x2),
              MayhemText(
                strings.seasonActionRemoteRequired,
                variant: MayhemTextVariant.bodySmall,
              ),
            ],
          ],
          const SizedBox(height: MayhemSpacing.x3),
          _StatusPanel(
            icon: Icons.bolt_outlined,
            label: _bossLabel(strings, state.bossPhase),
          ),
          if (state.bossPhase == SeasonBossPhase.open ||
              state.bossPhase == SeasonBossPhase.submitting ||
              state.bossPhase == SeasonBossPhase.failedRetryable) ...[
            const SizedBox(height: MayhemSpacing.x3),
            MayhemSecondaryButton(
              label: retriesPendingBoss
                  ? strings.bossRetry
                  : strings.bossChooseRoute,
              onPressed: canParticipateBoss
                  ? retriesPendingBoss
                        ? () => onParticipateBoss(ChallengeRouteType.normal)
                        : () => _chooseBossRoute(context)
                  : null,
              enabled: canParticipateBoss,
              loading: state.bossPhase == SeasonBossPhase.submitting,
            ),
            if (!canParticipateBoss &&
                state.bossPhase != SeasonBossPhase.submitting) ...[
              const SizedBox(height: MayhemSpacing.x2),
              MayhemText(
                strings.seasonActionRemoteRequired,
                variant: MayhemTextVariant.bodySmall,
              ),
            ],
          ],
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
        SeasonMembership.joining => strings.seasonJoining,
        SeasonMembership.joinFailedRetryable => strings.seasonJoinFailed,
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
        SeasonBossPhase.failedRetryable => strings.bossFailed,
        SeasonBossPhase.alreadyParticipated => strings.bossAlreadyParticipated,
        SeasonBossPhase.completed => strings.bossCompleted,
      };

  String _dayLabel(MayhemStrings strings, SeasonDayPhase phase) =>
      switch (phase) {
        SeasonDayPhase.unavailable => strings.seasonUnavailable,
        SeasonDayPhase.available => strings.seasonDayAvailable,
        SeasonDayPhase.inProgress => strings.seasonDaySubmitting,
        SeasonDayPhase.failedRetryable => strings.seasonDayFailed,
        SeasonDayPhase.completed => strings.seasonDayCompleted,
      };

  Future<void> _chooseBossRoute(BuildContext context) async {
    final boss = state.package!.boss;
    final strings = context.strings;
    final routes = <(ChallengeRouteType, String, String)>[
      (
        ChallengeRouteType.normal,
        strings.bossNormalRoute,
        boss.normalRoute.copy,
      ),
      (
        ChallengeRouteType.lowPressure,
        strings.bossLowPressureRoute,
        boss.lowPressureRoute.copy,
      ),
      if (boss.advancedRouteSafetyApproved && boss.advancedRoute != null)
        (
          ChallengeRouteType.advanced,
          strings.bossAdvancedRoute,
          boss.advancedRoute!.copy,
        ),
    ];
    final selected = await showModalBottomSheet<ChallengeRouteType>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: MayhemSpacing.x4),
          children: [
            for (final route in routes)
              ListTile(
                title: MayhemText(
                  route.$2,
                  variant: MayhemTextVariant.bodyLarge,
                ),
                subtitle: MayhemText(
                  route.$3,
                  variant: MayhemTextVariant.bodySmall,
                ),
                onTap: () => Navigator.of(context).pop(route.$1),
              ),
          ],
        ),
      ),
    );
    if (selected != null) onParticipateBoss(selected);
  }
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
        state.availability == SeasonAvailability.incompatiblePackage
            ? strings.seasonPackageIncompatible
            : strings.seasonRecoverableError,
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
