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
  String? _scenarioSubmittingAssignmentId;

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
    if (snapshot != null && snapshot.items.isNotEmpty) {
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
        if (snapshot.items.isEmpty) {
          _impressionTimer?.cancel();
          _visibleAssignmentId = null;
          return _FeedStatus(message: context.strings.feedComplete);
        }
        _pageController ??= PageController(
          initialPage: widget.controller.currentIndex,
        );
        _synchronizePageController();
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
                scenarioBusy:
                    _scenarioSubmittingAssignmentId ==
                    snapshot.items[index].assignment.assignmentId,
                onScenarioChoice:
                    snapshot.items[index].revision.type ==
                        ContentItemType.scenarioPoll
                    ? (choiceIndex) => unawaited(
                        _answerScenario(snapshot.items[index], choiceIndex),
                      )
                    : null,
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

  void _synchronizePageController() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = _pageController;
      final items = widget.controller.snapshot?.items;
      if (controller == null ||
          !controller.hasClients ||
          items == null ||
          items.isEmpty ||
          !controller.position.hasPixels) {
        return;
      }
      final target = widget.controller.currentIndex;
      final page = controller.page?.round();
      if (page != target) controller.jumpToPage(target);
    });
  }

  Future<void> _answerScenario(FeedSessionItem item, int choiceIndex) async {
    final assignmentId = item.assignment.assignmentId;
    if (_scenarioSubmittingAssignmentId != null) return;
    setState(() => _scenarioSubmittingAssignmentId = assignmentId);
    try {
      final index =
          widget.controller.snapshot?.items.indexWhere(
            (candidate) => candidate.assignment.assignmentId == assignmentId,
          ) ??
          -1;
      if (index >= 0) {
        await widget.controller.answerScenario(index, choiceIndex);
      }
    } finally {
      if (mounted && _scenarioSubmittingAssignmentId == assignmentId) {
        setState(() => _scenarioSubmittingAssignmentId = null);
      }
    }
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
    required this.onScenarioChoice,
    required this.scenarioBusy,
  });

  final FeedSessionItem item;
  final int current;
  final int total;
  final VoidCallback? onPreparation;
  final VoidCallback? onSkip;
  final ValueChanged<int>? onScenarioChoice;
  final bool scenarioBusy;

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
          explicitChildNodes: true,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: _FeedFieldPainter(
                  energy: energy,
                  variant: _fieldVariant(revision),
                ),
              ),
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
                                    copy: item.challenge!.lowPressureRoute.copy,
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
                                    busy: scenarioBusy,
                                    onSelected: onScenarioChoice,
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

  _FeedFieldVariant _fieldVariant(ContentItemRevision revision) {
    var hash = 0x811C9DC5;
    for (final codeUnit
        in '${revision.contentId}@${revision.revision}'.codeUnits) {
      hash = ((hash ^ codeUnit) * 0x01000193) & 0x7FFFFFFF;
    }
    return _FeedFieldVariant.values[hash % _FeedFieldVariant.values.length];
  }
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
  const _ScenarioOptions({
    required this.options,
    required this.onSelected,
    required this.busy,
  });

  final List<String> options;
  final ValueChanged<int>? onSelected;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MayhemText(
          context.strings.scenarioChoose,
          variant: MayhemTextVariant.labelMicro,
          color: MayhemColors.textSecondary,
        ),
        const SizedBox(height: MayhemSpacing.x2),
        for (var index = 0; index < options.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: MayhemSpacing.x2),
            child: MayhemPressable(
              key: ValueKey('scenario-option-$index'),
              semanticLabel:
                  '${String.fromCharCode(65 + index)}. ${options[index]}',
              enabled: onSelected != null,
              loading: busy,
              onPressed: onSelected == null ? null : () => onSelected!(index),
              borderRadius: MayhemRadii.medium,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: MayhemColors.surfaceRaised.withValues(alpha: 0.88),
                  borderRadius: MayhemRadii.medium,
                  border: Border.all(
                    color: MayhemColors.lineStrong.withValues(alpha: 0.9),
                  ),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 56),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: MayhemSpacing.x4,
                      vertical: MayhemSpacing.x3,
                    ),
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
                            color: MayhemColors.textPrimary,
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: MayhemColors.textTertiary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
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

enum _FeedFieldVariant { orbit, classic, horizon, shards, pulse }

class _FeedFieldPainter extends CustomPainter {
  const _FeedFieldPainter({required this.energy, required this.variant});

  final Color energy;
  final _FeedFieldVariant variant;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              energy.withValues(alpha: 0.16),
              MayhemColors.canvasDeep,
            ),
            MayhemColors.canvasDeep,
            MayhemColors.canvasBase,
          ],
          stops: const [0, 0.52, 1],
        ).createShader(bounds),
    );

    final glowBounds = Rect.fromCircle(
      center: Offset(size.width * 0.83, size.height * 0.18),
      radius: size.longestSide * 0.48,
    );
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = RadialGradient(
          colors: [
            energy.withValues(alpha: 0.38),
            energy.withValues(alpha: 0.08),
            const Color(0x00000000),
          ],
          stops: const [0, 0.46, 1],
        ).createShader(glowBounds),
    );

    switch (variant) {
      case _FeedFieldVariant.orbit:
        _paintOrbit(canvas, size);
      case _FeedFieldVariant.classic:
        _paintClassic(canvas, size);
      case _FeedFieldVariant.horizon:
        _paintHorizon(canvas, size);
      case _FeedFieldVariant.shards:
        _paintShards(canvas, size);
      case _FeedFieldVariant.pulse:
        _paintPulse(canvas, size);
    }

    final dust = Paint()..color = energy.withValues(alpha: 0.34);
    for (var index = 0; index < 24; index += 1) {
      final x = ((index * 67 + 13) % 101) / 101 * size.width;
      final y = ((index * 43 + 17) % 97) / 97 * size.height * 0.74;
      canvas.drawCircle(Offset(x, y), index % 3 == 0 ? 1.4 : 0.7, dust);
    }

    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00050608), Color(0xE6050608)],
          stops: [0.48, 1],
        ).createShader(bounds),
    );
  }

  void _paintOrbit(Canvas canvas, Size size) {
    final ring = Paint()
      ..color = energy.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final center = Offset(size.width * 0.83, size.height * 0.18);
    for (final radius in [0.18, 0.28, 0.4]) {
      canvas.drawCircle(center, size.width * radius, ring);
      ring.color = energy.withValues(alpha: ring.color.a * 0.64);
    }
    canvas.drawLine(
      Offset(size.width * 0.08, size.height * 0.74),
      Offset(size.width * 0.92, size.height * 0.18),
      ring..color = energy.withValues(alpha: 0.18),
    );
  }

  void _paintClassic(Canvas canvas, Size size) {
    final monolith = Path()
      ..moveTo(size.width * 0.58, -size.height * 0.04)
      ..lineTo(size.width * 1.04, size.height * 0.08)
      ..lineTo(size.width * 0.84, size.height * 0.62)
      ..lineTo(size.width * 0.48, size.height * 0.48)
      ..close();
    canvas.drawPath(monolith, Paint()..color = energy.withValues(alpha: 0.055));
    canvas.drawPath(
      monolith,
      Paint()
        ..color = energy.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    final line = Paint()
      ..color = energy.withValues(alpha: 0.18)
      ..strokeWidth = 1;
    for (var index = -2; index < 8; index += 1) {
      final x = size.width * (index * 0.16);
      canvas.drawLine(
        Offset(x, size.height * 0.78),
        Offset(x + size.width * 0.52, size.height * 0.08),
        line,
      );
    }

    final ring = Paint()
      ..color = energy.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(
      Offset(size.width * 0.83, size.height * 0.18),
      size.width * 0.23,
      ring,
    );
    canvas.drawCircle(
      Offset(size.width * 0.83, size.height * 0.18),
      size.width * 0.31,
      ring..color = energy.withValues(alpha: 0.08),
    );
  }

  void _paintHorizon(Canvas canvas, Size size) {
    final line = Paint()
      ..color = energy.withValues(alpha: 0.16)
      ..strokeWidth = 1;
    for (var index = 0; index < 9; index += 1) {
      final y = size.height * (0.14 + index * 0.065);
      final inset = size.width * (index * 0.035);
      canvas.drawLine(Offset(inset, y), Offset(size.width - inset, y), line);
    }
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.38, size.width, 2),
      Paint()..color = energy.withValues(alpha: 0.48),
    );
  }

  void _paintShards(Canvas canvas, Size size) {
    for (var index = 0; index < 5; index += 1) {
      final x = size.width * (0.18 + index * 0.17);
      final shard = Path()
        ..moveTo(x, -size.height * 0.04)
        ..lineTo(x + size.width * 0.22, size.height * 0.05)
        ..lineTo(x - size.width * 0.08, size.height * (0.56 + index * 0.025))
        ..close();
      canvas.drawPath(
        shard,
        Paint()..color = energy.withValues(alpha: index.isEven ? 0.07 : 0.035),
      );
      canvas.drawPath(
        shard,
        Paint()
          ..color = energy.withValues(alpha: 0.14)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  void _paintPulse(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.16, size.height * 0.34);
    final pulse = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    for (var index = 1; index <= 5; index += 1) {
      pulse.color = energy.withValues(alpha: 0.25 / index);
      canvas.drawCircle(center, size.width * 0.12 * index, pulse);
    }
    for (var index = 0; index < 7; index += 1) {
      final angle = index * math.pi / 3.5;
      final end =
          center + Offset(math.cos(angle), math.sin(angle)) * size.width;
      canvas.drawLine(
        center,
        end,
        pulse..color = energy.withValues(alpha: 0.08),
      );
    }
  }

  @override
  bool shouldRepaint(_FeedFieldPainter oldDelegate) =>
      oldDelegate.energy != energy || oldDelegate.variant != variant;
}
