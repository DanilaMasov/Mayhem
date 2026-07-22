import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../content/domain/content_item_revision.dart';
import '../../../core/design_system/components/components.dart';
import '../../../core/design_system/accessibility/mayhem_motion_preferences.dart';
import '../../../core/design_system/motion/mayhem_durations.dart';
import '../../../core/design_system/tokens/tokens.dart';
import '../../../core/localization/mayhem_strings.dart';
import '../../challenge/application/challenge_flow_coordinator.dart';
import '../../challenge/domain/challenge_models.dart';
import '../../challenge/domain/challenge_preparation.dart';
import '../../progress/domain/progress_models.dart';
import '../application/feed_challenge_controller.dart';
import '../application/feed_session_coordinator.dart';
import '../application/feed_view_controller.dart';
import '../domain/feed_models.dart';

class VNextFeedScreen extends StatefulWidget {
  const VNextFeedScreen({
    super.key,
    required this.controller,
    required this.challengeController,
  });

  final FeedViewController controller;
  final FeedChallengeController challengeController;

  @override
  State<VNextFeedScreen> createState() => _VNextFeedScreenState();
}

class _VNextFeedScreenState extends State<VNextFeedScreen>
    with WidgetsBindingObserver {
  PageController? _pageController;
  final Map<String, ChallengeRouteType> _selectedRoutes = {};
  Timer? _impressionTimer;
  String? _visibleAssignmentId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _impressionTimer?.cancel();
    _pageController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _impressionTimer?.cancel();
      _visibleAssignmentId = null;
      return;
    }
    final snapshot = widget.controller.snapshot;
    if (snapshot != null) {
      _scheduleImpression(
        snapshot.items[widget.controller.currentIndex],
        widget.controller.currentIndex,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.controller,
        widget.challengeController,
      ]),
      builder: (context, child) {
        if (widget.controller.loading) {
          return _FeedStatus(message: context.strings.loading);
        }
        final snapshot = widget.controller.snapshot;
        if (widget.controller.error != null || snapshot == null) {
          return _FeedStatus(
            message: context.strings.localLoadError,
            actionLabel: context.strings.retry,
            onAction: widget.controller.initialize,
          );
        }
        _pageController ??= PageController(
          initialPage: widget.controller.currentIndex,
        );
        final action = widget.challengeController;
        final currentItem = snapshot.items[widget.controller.currentIndex];
        _scheduleImpression(currentItem, widget.controller.currentIndex);
        final selectedRoute = _selectedRoutes.putIfAbsent(
          currentItem.assignment.assignmentId,
          () => ChallengeRouteType.normal,
        );
        return Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              key: const PageStorageKey('vnext-feed'),
              controller: _pageController,
              scrollDirection: Axis.vertical,
              physics: action.busy
                  ? const NeverScrollableScrollPhysics()
                  : null,
              itemCount: snapshot.items.length,
              onPageChanged: (index) {
                unawaited(widget.controller.setCurrentIndex(index));
                _scheduleImpression(snapshot.items[index], index);
              },
              itemBuilder: (context, index) => _FeedItemScene(
                item: snapshot.items[index],
                current: index + 1,
                total: snapshot.items.length,
                onPreparation: snapshot.items[index].preparation == null
                    ? null
                    : () => _showPreparation(snapshot.items[index], index),
                onSkip: action.busy ? null : () => _showSkipReasons(index),
              ),
            ),
            if (!action.hasActiveChallenge && currentItem.challenge != null)
              Positioned(
                left: MayhemSpacing.x4,
                right: MayhemSpacing.x4,
                bottom: 100,
                child: _ChallengeAcceptPanel(
                  key: ValueKey(
                    '${currentItem.assignment.assignmentId}-'
                    '${action.operationRevision}',
                  ),
                  selectedRoute: selectedRoute,
                  busy: action.busy,
                  onRouteChanged: (route) => setState(() {
                    _selectedRoutes[currentItem.assignment.assignmentId] =
                        route;
                  }),
                  onAccept: () => _accept(currentItem, selectedRoute),
                ),
              ),
            if (action.hasActiveChallenge)
              Positioned(
                left: MayhemSpacing.x4,
                right: MayhemSpacing.x4,
                bottom: 100,
                child: SizedBox(
                  key: const ValueKey('active-challenge-capsule'),
                  height: 104,
                  child: _ActiveChallengeCapsule(
                    title: action.activeDefinition?.title,
                    busy: action.busy || action.activeDefinition == null,
                    onPressed: _showChallengeResult,
                  ),
                ),
              ),
            if (action.error != null)
              Positioned(
                left: MayhemSpacing.x4,
                right: MayhemSpacing.x4,
                top: MediaQuery.paddingOf(context).top + MayhemSpacing.x3,
                child: GestureDetector(
                  onTap: action.clearError,
                  child: MayhemToast(
                    message: context.strings.challengeActionFailed,
                  ),
                ),
              ),
            if (widget.controller.interactionError != null)
              Positioned(
                left: MayhemSpacing.x4,
                right: MayhemSpacing.x4,
                top: MediaQuery.paddingOf(context).top + MayhemSpacing.x20,
                child: GestureDetector(
                  onTap: widget.controller.clearInteractionError,
                  child: MayhemToast(
                    message: context.strings.feedInteractionFailed,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _scheduleImpression(FeedSessionItem item, int index) {
    final assignmentId = item.assignment.assignmentId;
    if (_visibleAssignmentId == assignmentId) return;
    _impressionTimer?.cancel();
    _visibleAssignmentId = assignmentId;
    if (WidgetsBinding.instance.lifecycleState case final state?
        when state != AppLifecycleState.resumed) {
      return;
    }
    _impressionTimer = Timer(const Duration(milliseconds: 600), () {
      if (!mounted ||
          widget.controller.currentIndex != index ||
          _visibleAssignmentId != assignmentId) {
        return;
      }
      unawaited(widget.controller.impress(index));
    });
  }

  Future<bool> _accept(FeedSessionItem item, ChallengeRouteType route) async {
    final index = widget.controller.snapshot?.items.indexOf(item) ?? -1;
    if (index < 0 || !await widget.controller.open(index)) return false;
    return widget.challengeController.accept(item: item, route: route);
  }

  Future<void> _showPreparation(FeedSessionItem item, int index) async {
    final preparation = item.preparation;
    if (preparation == null) return;
    if (!await widget.controller.open(index) || !mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PreparationSheet(
        title: item.challenge?.title ?? item.revision.contentId,
        preparation: preparation,
      ),
    );
  }

  Future<void> _showSkipReasons(int index) async {
    if (!await widget.controller.impress(index) || !mounted) return;
    final reason = await showModalBottomSheet<FeedSkipReason>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _SkipReasonSheet(),
    );
    if (reason == null || !mounted) return;
    final saved = await widget.controller.skip(index, reason);
    if (!saved || !mounted) return;
    final snapshot = widget.controller.snapshot;
    final nextIndex = index + 1;
    if (snapshot == null || nextIndex >= snapshot.items.length) return;
    final pageController = _pageController;
    if (pageController == null || !pageController.hasClients) return;
    if (MayhemAccessibility.of(context).reduceMotion) {
      pageController.jumpToPage(nextIndex);
    } else {
      await pageController.animateToPage(
        nextIndex,
        duration: MayhemDurations.standard,
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _showChallengeResult() async {
    if (widget.challengeController.busy) return;
    final applied = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _ChallengeResultSheet(controller: widget.challengeController),
    );
    if (applied == true && mounted) await _showReward();
  }

  Future<void> _showReward() async {
    final reward = widget.challengeController.reward;
    if (reward == null) return;
    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (context) => _RewardDialog(
        reward: reward,
        onContinue: () => Navigator.of(context).pop(),
      ),
    );
    widget.challengeController.dismissReward();
  }
}

class _FeedStatus extends StatelessWidget {
  const _FeedStatus({required this.message, this.actionLabel, this.onAction});

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(MayhemSpacing.x6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MayhemText(
                message,
                variant: MayhemTextVariant.bodyLarge,
                textAlign: TextAlign.center,
              ),
              if (onAction != null && actionLabel != null) ...[
                const SizedBox(height: MayhemSpacing.x5),
                MayhemSecondaryButton(
                  label: actionLabel!,
                  onPressed: onAction,
                  expand: false,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedItemScene extends StatelessWidget {
  const _FeedItemScene({
    required this.item,
    required this.current,
    required this.total,
    required this.onPreparation,
    required this.onSkip,
  });

  final FeedSessionItem item;
  final int current;
  final int total;
  final VoidCallback? onPreparation;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final revision = item.revision;
    final title =
        item.challenge?.title ??
        revision.payload['title'] as String? ??
        revision.contentId;
    final detail =
        item.challenge?.supportingCopy ??
        revision.payload['supportingCopy'] as String? ??
        '';
    final trait = item.challenge?.primaryTrait ?? _payloadTrait(revision);
    final energy = _traitColor(trait);
    final typeLabel = switch (revision.type) {
      ContentItemType.challenge => strings.challenge,
      ContentItemType.microTraining => strings.training,
      ContentItemType.scenarioPoll => strings.scenario,
      ContentItemType.seasonUpdate => strings.season,
      _ => strings.feed,
    };
    final semantic =
        '$typeLabel. $title. $detail. '
        '${strings.feedPosition(current, total)}';
    return Stack(
      fit: StackFit.expand,
      children: [
        Semantics(
          container: true,
          label: semantic,
          child: ExcludeSemantics(
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(painter: _FeedFieldPainter(energy: energy)),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      MayhemSpacing.x5,
                      MayhemSpacing.x5,
                      MayhemSpacing.x5,
                      236,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(
                            right: onPreparation == null ? 48 : 96,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: MayhemText(
                                  typeLabel,
                                  variant: MayhemTextVariant.labelMicro,
                                  color: energy,
                                ),
                              ),
                              const Icon(
                                Icons.cloud_off_outlined,
                                size: 16,
                                color: MayhemColors.textTertiary,
                              ),
                              const SizedBox(width: MayhemSpacing.x2),
                              Flexible(
                                child: MayhemText(
                                  strings.offlineReady,
                                  variant: MayhemTextVariant.labelMicro,
                                  textAlign: TextAlign.end,
                                  maxLines: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: MayhemSpacing.x4),
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomLeft,
                            child: SingleChildScrollView(
                              primary: false,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  MayhemText(
                                    title,
                                    variant: MayhemTextVariant.displayMedium,
                                    maxLines: 5,
                                  ),
                                  if (detail.isNotEmpty) ...[
                                    const SizedBox(height: MayhemSpacing.x4),
                                    MayhemText(
                                      detail,
                                      variant: MayhemTextVariant.bodyLarge,
                                      maxLines: 3,
                                    ),
                                  ],
                                  const SizedBox(height: MayhemSpacing.x6),
                                  if (item.challenge != null)
                                    _LowPressureRoute(
                                      copy:
                                          item.challenge!.lowPressureRoute.copy,
                                    )
                                  else if (revision.type ==
                                      ContentItemType.microTraining)
                                    MayhemText(
                                      revision.payload['instruction']
                                              as String? ??
                                          '',
                                      variant: MayhemTextVariant.bodyMedium,
                                      color: MayhemColors.textPrimary,
                                      maxLines: 4,
                                    )
                                  else if (revision.type ==
                                      ContentItemType.scenarioPoll)
                                    _ScenarioOptions(
                                      options:
                                          (revision.payload['options']
                                                      as List<dynamic>? ??
                                                  const [])
                                              .whereType<String>()
                                              .take(3)
                                              .toList(growable: false),
                                    ),
                                  const SizedBox(height: MayhemSpacing.x4),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: MayhemText(
                                      strings.feedPosition(current, total),
                                      variant: MayhemTextVariant.labelMicro,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.only(
                top: MayhemSpacing.x2,
                right: MayhemSpacing.x3,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onPreparation != null)
                    IconButton(
                      tooltip: strings.preparation,
                      onPressed: onPreparation,
                      icon: const Icon(Icons.menu_book_outlined),
                    ),
                  IconButton(
                    tooltip: strings.skipFeedItem,
                    onPressed: onSkip,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Trait? _payloadTrait(ContentItemRevision revision) {
    final value = revision.payload['primaryTrait'] as String?;
    return value == null ? null : Trait.values.asNameMap()[value];
  }

  Color _traitColor(Trait? trait) => switch (trait) {
    Trait.initiation => MayhemColors.traitInitiation,
    Trait.expression => MayhemColors.traitExpression,
    Trait.connection => MayhemColors.traitConnection,
    Trait.presence => MayhemColors.traitPresence,
    null => MayhemColors.brandSignalSoft,
  };
}

class _LowPressureRoute extends StatelessWidget {
  const _LowPressureRoute({required this.copy});

  final String copy;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: MayhemColors.surfaceBase,
        borderRadius: MayhemRadii.medium,
        border: Border.all(color: MayhemColors.lineStrong),
      ),
      child: Padding(
        padding: const EdgeInsets.all(MayhemSpacing.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MayhemText(
              context.strings.lowPressureRoute,
              variant: MayhemTextVariant.labelMicro,
              color: MayhemColors.semanticSuccess,
            ),
            const SizedBox(height: MayhemSpacing.x2),
            MayhemText(
              copy,
              variant: MayhemTextVariant.bodyMedium,
              color: MayhemColors.textPrimary,
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }
}

class _ScenarioOptions extends StatelessWidget {
  const _ScenarioOptions({required this.options});

  final List<String> options;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < options.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: MayhemSpacing.x2),
            child: Row(
              children: [
                MayhemText(
                  String.fromCharCode(65 + index),
                  variant: MayhemTextVariant.labelLarge,
                  color: MayhemColors.brandSignalSoft,
                ),
                const SizedBox(width: MayhemSpacing.x3),
                Expanded(
                  child: MayhemText(
                    options[index],
                    variant: MayhemTextVariant.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SkipReasonSheet extends StatelessWidget {
  const _SkipReasonSheet();

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final options = [
      (FeedSkipReason.notNow, strings.skipNotNow, Icons.schedule_outlined),
      (FeedSkipReason.tooIntense, strings.skipTooIntense, Icons.speed_outlined),
      (
        FeedSkipReason.wrongContext,
        strings.skipWrongContext,
        Icons.location_off_outlined,
      ),
      (
        FeedSkipReason.notRelevant,
        strings.skipNotRelevant,
        Icons.remove_circle_outline,
      ),
    ];
    return MayhemSheet(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MayhemText(
            strings.skipReasonTitle,
            variant: MayhemTextVariant.headlineSmall,
          ),
          const SizedBox(height: MayhemSpacing.x4),
          for (final option in options)
            Padding(
              padding: const EdgeInsets.only(bottom: MayhemSpacing.x1),
              child: MayhemPressable(
                semanticLabel: option.$2,
                onPressed: () => Navigator.of(context).pop(option.$1),
                borderRadius: MayhemRadii.small,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 52),
                  child: Row(
                    children: [
                      Icon(option.$3, color: MayhemColors.textSecondary),
                      const SizedBox(width: MayhemSpacing.x3),
                      Expanded(
                        child: MayhemText(
                          option.$2,
                          variant: MayhemTextVariant.bodyMedium,
                          color: MayhemColors.textPrimary,
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PreparationSheet extends StatefulWidget {
  const _PreparationSheet({required this.title, required this.preparation});

  final String title;
  final ChallengePreparation preparation;

  @override
  State<_PreparationSheet> createState() => _PreparationSheetState();
}

class _PreparationSheetState extends State<_PreparationSheet> {
  late String? _rehearsalNodeId = widget.preparation.rehearsal?.startNodeId;

  @override
  Widget build(BuildContext context) {
    final rehearsal = widget.preparation.rehearsal;
    final tabCount = rehearsal == null ? 1 : 2;
    return DefaultTabController(
      length: tabCount,
      child: MayhemSheet(
        padding: const EdgeInsets.fromLTRB(
          MayhemSpacing.x5,
          MayhemSpacing.x3,
          MayhemSpacing.x5,
          MayhemSpacing.x3,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.78,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MayhemText(
                context.strings.preparation,
                variant: MayhemTextVariant.labelMicro,
                color: MayhemColors.brandSignalSoft,
              ),
              const SizedBox(height: MayhemSpacing.x2),
              MayhemText(
                widget.title,
                variant: MayhemTextVariant.headlineSmall,
                maxLines: 3,
              ),
              const SizedBox(height: MayhemSpacing.x4),
              TabBar(
                tabs: [
                  Tab(text: context.strings.guide),
                  if (rehearsal != null) Tab(text: context.strings.rehearsal),
                ],
              ),
              const SizedBox(height: MayhemSpacing.x3),
              Expanded(
                child: TabBarView(
                  children: [
                    _PreparationGuide(preparation: widget.preparation),
                    if (rehearsal != null)
                      _PreparationRehearsal(
                        rehearsal: rehearsal,
                        nodeId: _rehearsalNodeId!,
                        onNodeChanged: (nodeId) =>
                            setState(() => _rehearsalNodeId = nodeId),
                        onRestart: () => setState(
                          () => _rehearsalNodeId = rehearsal.startNodeId,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreparationGuide extends StatelessWidget {
  const _PreparationGuide({required this.preparation});

  final ChallengePreparation preparation;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return ListView(
      key: const PageStorageKey('feed-preparation-guide'),
      padding: const EdgeInsets.only(bottom: MayhemSpacing.x5),
      children: [
        _PreparationLabel(strings.route),
        const SizedBox(height: MayhemSpacing.x3),
        for (final step in preparation.steps.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: MayhemSpacing.x3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox.square(
                  dimension: 28,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: MayhemColors.brandSignal,
                      borderRadius: MayhemRadii.small,
                    ),
                    child: Center(
                      child: MayhemText(
                        '${step.$1 + 1}',
                        variant: MayhemTextVariant.labelMicro,
                        color: MayhemColors.canvasBase,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: MayhemSpacing.x3),
                Expanded(
                  child: MayhemText(
                    step.$2,
                    variant: MayhemTextVariant.bodyMedium,
                    color: MayhemColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: MayhemSpacing.x3),
        _PreparationLabel(strings.workingPhrases),
        const SizedBox(height: MayhemSpacing.x3),
        Wrap(
          spacing: MayhemSpacing.x2,
          runSpacing: MayhemSpacing.x2,
          children: [
            for (final phrase in preparation.phrases)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: MayhemColors.surfaceHigh,
                  borderRadius: MayhemRadii.small,
                  border: Border.all(color: MayhemColors.lineStrong),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: MayhemSpacing.x3,
                    vertical: MayhemSpacing.x2,
                  ),
                  child: MayhemText(
                    phrase,
                    variant: MayhemTextVariant.bodySmall,
                    color: MayhemColors.textPrimary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: MayhemSpacing.x5),
        _PreparationSection(
          label: strings.otherRoute,
          text: preparation.alternateRoute,
        ),
        _PreparationSection(
          label: strings.advancedRoute,
          text: preparation.advancedRoute,
        ),
        _PreparationSection(
          label: strings.safeExit,
          text: preparation.exitScript,
          accent: true,
        ),
      ],
    );
  }
}

class _PreparationRehearsal extends StatelessWidget {
  const _PreparationRehearsal({
    required this.rehearsal,
    required this.nodeId,
    required this.onNodeChanged,
    required this.onRestart,
  });

  final ChallengeRehearsal rehearsal;
  final String nodeId;
  final ValueChanged<String> onNodeChanged;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final node = rehearsal.node(nodeId);
    return ListView(
      key: const PageStorageKey('feed-preparation-rehearsal'),
      padding: const EdgeInsets.only(bottom: MayhemSpacing.x5),
      children: [
        _PreparationLabel(
          node.speaker == RehearsalSpeaker.coach
              ? context.strings.coach
              : context.strings.partner,
          accent: node.speaker == RehearsalSpeaker.coach,
        ),
        const SizedBox(height: MayhemSpacing.x3),
        MayhemText(
          node.text,
          variant: MayhemTextVariant.headlineSmall,
          color: MayhemColors.textPrimary,
        ),
        const SizedBox(height: MayhemSpacing.x5),
        if (node.success) ...[
          MayhemToast(message: context.strings.rehearsalComplete),
          const SizedBox(height: MayhemSpacing.x4),
          MayhemSecondaryButton(
            label: context.strings.restart,
            onPressed: onRestart,
          ),
        ] else
          for (final option in node.options)
            Padding(
              padding: const EdgeInsets.only(bottom: MayhemSpacing.x3),
              child: MayhemSecondaryButton(
                label: option.label,
                onPressed: () => onNodeChanged(option.nextNodeId),
              ),
            ),
      ],
    );
  }
}

class _PreparationLabel extends StatelessWidget {
  const _PreparationLabel(this.label, {this.accent = false});

  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) => MayhemText(
    label,
    variant: MayhemTextVariant.labelMicro,
    color: accent ? MayhemColors.semanticSuccess : MayhemColors.textSecondary,
  );
}

class _PreparationSection extends StatelessWidget {
  const _PreparationSection({
    required this.label,
    required this.text,
    this.accent = false,
  });

  final String label;
  final String text;
  final bool accent;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: MayhemSpacing.x4),
    child: DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: accent
                ? MayhemColors.semanticSuccess
                : MayhemColors.lineStrong,
            width: accent ? 3 : 1,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: MayhemSpacing.x3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PreparationLabel(label, accent: accent),
            const SizedBox(height: MayhemSpacing.x2),
            MayhemText(
              text,
              variant: MayhemTextVariant.bodyMedium,
              color: MayhemColors.textPrimary,
            ),
          ],
        ),
      ),
    ),
  );
}

class _ActiveChallengeCapsule extends StatelessWidget {
  const _ActiveChallengeCapsule({
    required this.onPressed,
    required this.busy,
    this.title,
  });

  final String? title;
  final VoidCallback onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return MayhemPressable(
      semanticLabel: '${strings.activeChallenge}. ${strings.recordResult}',
      enabled: !busy,
      onPressed: busy ? null : onPressed,
      borderRadius: MayhemRadii.medium,
      child: MayhemGlassControl(
        borderRadius: MayhemRadii.medium,
        padding: const EdgeInsets.all(MayhemSpacing.x4),
        child: Row(
          children: [
            const Icon(
              Icons.bolt_outlined,
              color: MayhemColors.brandSignalSoft,
            ),
            const SizedBox(width: MayhemSpacing.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MayhemText(
                    strings.activeChallenge,
                    variant: MayhemTextVariant.labelMicro,
                  ),
                  const SizedBox(height: MayhemSpacing.x1),
                  MayhemText(
                    title ?? strings.activeChallengeBody,
                    variant: MayhemTextVariant.bodySmall,
                    color: MayhemColors.textPrimary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: MayhemSpacing.x3),
            Flexible(
              child: MayhemText(
                strings.recordResult,
                variant: MayhemTextVariant.labelMicro,
                color: MayhemColors.brandSignalSoft,
                textAlign: TextAlign.end,
                maxLines: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChallengeAcceptPanel extends StatelessWidget {
  const _ChallengeAcceptPanel({
    super.key,
    required this.selectedRoute,
    required this.busy,
    required this.onRouteChanged,
    required this.onAccept,
  });

  final ChallengeRouteType selectedRoute;
  final bool busy;
  final ValueChanged<ChallengeRouteType> onRouteChanged;
  final Future<bool> Function() onAccept;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return MayhemGlassControl(
      borderRadius: MayhemRadii.medium,
      padding: const EdgeInsets.all(MayhemSpacing.x3),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: _SelectionButton(
                  label: strings.primaryRoute,
                  selected: selectedRoute == ChallengeRouteType.normal,
                  onPressed: () => onRouteChanged(ChallengeRouteType.normal),
                ),
              ),
              const SizedBox(width: MayhemSpacing.x2),
              Expanded(
                child: _SelectionButton(
                  label: strings.lowPressureRoute,
                  selected: selectedRoute == ChallengeRouteType.lowPressure,
                  onPressed: () =>
                      onRouteChanged(ChallengeRouteType.lowPressure),
                ),
              ),
            ],
          ),
          const SizedBox(height: MayhemSpacing.x3),
          MayhemHoldButton(
            label: strings.acceptChallenge,
            completedLabel: strings.challengeAccepted,
            semanticHint: strings.holdToAcceptHint,
            enabled: !busy,
            onCompleted: () => unawaited(onAccept()),
          ),
        ],
      ),
    );
  }
}

class _SelectionButton extends StatelessWidget {
  const _SelectionButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: MayhemPressable(
        semanticLabel: label,
        onPressed: onPressed,
        borderRadius: MayhemRadii.small,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected
                ? MayhemColors.surfaceHigh
                : MayhemColors.surfaceBase,
            borderRadius: MayhemRadii.small,
            border: Border.all(
              color: selected
                  ? MayhemColors.brandSignalSoft
                  : MayhemColors.lineStrong,
            ),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: MayhemSpacing.x2,
                vertical: MayhemSpacing.x2,
              ),
              child: Center(
                child: MayhemText(
                  label,
                  variant: MayhemTextVariant.labelMicro,
                  color: selected
                      ? MayhemColors.textPrimary
                      : MayhemColors.textSecondary,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChallengeResultSheet extends StatefulWidget {
  const _ChallengeResultSheet({required this.controller});

  final FeedChallengeController controller;

  @override
  State<_ChallengeResultSheet> createState() => _ChallengeResultSheetState();
}

class _ChallengeResultSheetState extends State<_ChallengeResultSheet> {
  final _noteController = TextEditingController();
  var _outcome = AttemptOutcome.completed;
  var _felt = FeltComparedToExpected.aboutAsExpected;
  var _includeReflection = false;
  var _fearBefore = 5;
  var _feelAfter = 5;
  var _wantRepeat = false;
  var _submitting = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final viewInsets = MediaQuery.viewInsetsOf(context);
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const sheetChromeHeight = 92.0;
          final availableContentHeight = math.max(
            0.0,
            constraints.maxHeight - sheetChromeHeight,
          );
          final preferredContentHeight =
              MediaQuery.sizeOf(context).height * 0.82;
          return MayhemSheet(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: math.min(
                  preferredContentHeight,
                  availableContentHeight,
                ),
              ),
              child: SingleChildScrollView(
                key: const ValueKey('challenge-result-scroll'),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MayhemText(
                      strings.challengeResult,
                      variant: MayhemTextVariant.headlineSmall,
                    ),
                    const SizedBox(height: MayhemSpacing.x4),
                    Row(
                      children: [
                        Expanded(
                          child: _SelectionButton(
                            label: strings.attempted,
                            selected: _outcome == AttemptOutcome.attempted,
                            onPressed: () => setState(
                              () => _outcome = AttemptOutcome.attempted,
                            ),
                          ),
                        ),
                        const SizedBox(width: MayhemSpacing.x2),
                        Expanded(
                          child: _SelectionButton(
                            label: strings.completed,
                            selected: _outcome == AttemptOutcome.completed,
                            onPressed: () => setState(
                              () => _outcome = AttemptOutcome.completed,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: MayhemSpacing.x4),
                    _FeltGrid(
                      selected: _felt,
                      onSelected: (felt) => setState(() => _felt = felt),
                    ),
                    const SizedBox(height: MayhemSpacing.x4),
                    Row(
                      children: [
                        Expanded(
                          child: MayhemText(
                            strings.optionalReflection,
                            variant: MayhemTextVariant.labelMicro,
                          ),
                        ),
                        Switch.adaptive(
                          value: _includeReflection,
                          onChanged: (value) =>
                              setState(() => _includeReflection = value),
                        ),
                      ],
                    ),
                    if (_includeReflection) ...[
                      _ScaleInput(
                        label: strings.fearBefore,
                        value: _fearBefore,
                        onChanged: (value) =>
                            setState(() => _fearBefore = value),
                      ),
                      _ScaleInput(
                        label: strings.feelAfter,
                        value: _feelAfter,
                        onChanged: (value) =>
                            setState(() => _feelAfter = value),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: MayhemText(
                              strings.wantRepeat,
                              variant: MayhemTextVariant.bodyMedium,
                            ),
                          ),
                          Switch.adaptive(
                            value: _wantRepeat,
                            onChanged: (value) =>
                                setState(() => _wantRepeat = value),
                          ),
                        ],
                      ),
                      TextField(
                        controller: _noteController,
                        maxLength: 2000,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: strings.privateNoteHint,
                        ),
                      ),
                    ],
                    if (widget.controller.error != null) ...[
                      const SizedBox(height: MayhemSpacing.x3),
                      MayhemToast(message: strings.challengeActionFailed),
                    ],
                    const SizedBox(height: MayhemSpacing.x4),
                    MayhemPrimaryButton(
                      label: strings.saveResult,
                      loading: _submitting,
                      enabled: !_submitting,
                      onPressed: _submit,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    final applied = await widget.controller.resolve(
      outcome: _outcome,
      felt: _felt,
      reflection: _includeReflection
          ? ReflectionInput(
              fearBefore: _fearBefore,
              feelAfter: _feelAfter,
              wantRepeat: _wantRepeat,
              privateNote: _noteController.text,
            )
          : const ReflectionInput(),
    );
    if (!mounted) return;
    if (applied) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _submitting = false);
    }
  }
}

class _FeltGrid extends StatelessWidget {
  const _FeltGrid({required this.selected, required this.onSelected});

  final FeltComparedToExpected selected;
  final ValueChanged<FeltComparedToExpected> onSelected;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final options = <FeltComparedToExpected, String>{
      FeltComparedToExpected.easierThanExpected: strings.feltEasier,
      FeltComparedToExpected.aboutAsExpected: strings.feltExpected,
      FeltComparedToExpected.harderThanExpected: strings.feltHarder,
      FeltComparedToExpected.stoppedEarly: strings.feltStopped,
    };
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - MayhemSpacing.x2) / 2;
        return Wrap(
          spacing: MayhemSpacing.x2,
          runSpacing: MayhemSpacing.x2,
          children: [
            for (final option in options.entries)
              SizedBox(
                width: width,
                child: _SelectionButton(
                  label: option.value,
                  selected: selected == option.key,
                  onPressed: () => onSelected(option.key),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ScaleInput extends StatelessWidget {
  const _ScaleInput({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      value: '$value из 10',
      child: Row(
        children: [
          Expanded(
            child: MayhemText(label, variant: MayhemTextVariant.bodyMedium),
          ),
          Expanded(
            flex: 2,
            child: Slider(
              value: value.toDouble(),
              min: 1,
              max: 10,
              divisions: 9,
              label: '$value',
              onChanged: (value) => onChanged(value.round()),
            ),
          ),
          SizedBox(
            width: MayhemSpacing.x8,
            child: MayhemText(
              '$value',
              variant: MayhemTextVariant.numberStatus,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardDialog extends StatelessWidget {
  const _RewardDialog({required this.reward, required this.onContinue});

  final FeedRewardPresentation reward;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(MayhemSpacing.x5),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: RewardStage(
                  kind: reward.outcome == AttemptOutcome.completed
                      ? RewardStageKind.completion
                      : RewardStageKind.attempt,
                  playId: reward.attemptId,
                  xp: reward.xp,
                  traitLabel: context.strings.traitName(reward.trait),
                  momentumDays: reward.momentumDays,
                  completionLabel: context.strings.rewardCompleted,
                  attemptLabel: context.strings.rewardAttempted,
                ),
              ),
              const SizedBox(height: MayhemSpacing.x3),
              MayhemPrimaryButton(
                label: context.strings.continueLabel,
                onPressed: onContinue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedFieldPainter extends CustomPainter {
  const _FeedFieldPainter({required this.energy});

  final Color energy;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = MayhemColors.canvasDeep,
    );
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.62, 0, size.width * 0.38, size.height),
      Paint()..color = energy.withValues(alpha: 0.12),
    );
    final line = Paint()
      ..color = energy.withValues(alpha: 0.32)
      ..strokeWidth = 1;
    for (var index = 0; index < 6; index++) {
      final x = size.width * (0.12 + index * 0.14);
      canvas.drawLine(
        Offset(x, size.height * 0.18),
        Offset(x + size.width * 0.2, size.height * 0.62),
        line,
      );
    }
  }

  @override
  bool shouldRepaint(_FeedFieldPainter oldDelegate) =>
      oldDelegate.energy != energy;
}
