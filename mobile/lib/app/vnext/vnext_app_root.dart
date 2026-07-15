import 'dart:developer' as developer;

import 'package:flutter/material.dart';

import '../../application/today_controller.dart';
import '../../core/design_system/accessibility/mayhem_motion_preferences.dart';
import '../../core/design_system/components/components.dart';
import '../../core/design_system/motion/mayhem_durations.dart';
import '../../core/design_system/tokens/tokens.dart';
import '../../core/localization/mayhem_strings.dart';
import '../../features/onboarding/presentation/vnext_onboarding_flow.dart';
import '../../features/progress/domain/progress_models.dart';
import 'vnext_runtime.dart';
import 'vnext_shell.dart';

class VNextAppRoot extends StatefulWidget {
  const VNextAppRoot({
    super.key,
    required this.runtime,
    required this.legacyController,
  });

  final VNextRuntime runtime;
  final TodayController legacyController;

  @override
  State<VNextAppRoot> createState() => _VNextAppRootState();
}

class _VNextAppRootState extends State<VNextAppRoot> {
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.runtime.settings, widget.runtime]),
      builder: (context, child) {
        final preferences = widget.runtime.settings.preferences;
        return MayhemAccessibility(
          preferences: MayhemMotionPreferences(
            reduceMotion: preferences.reduceMotion,
            reduceTransparency: preferences.reduceTransparency,
          ),
          child: Builder(builder: _buildState),
        );
      },
    );
  }

  Widget _buildState(BuildContext context) {
    final reduceMotion = MayhemAccessibility.of(context).reduceMotion;
    return AnimatedSwitcher(
      duration: reduceMotion ? Duration.zero : MayhemDurations.standard,
      child: _loading
          ? _LoadingState(key: const ValueKey('loading'))
          : _error != null
          ? _ErrorState(key: const ValueKey('error'), onRetry: _initialize)
          : !widget.runtime.onboarding.progress.isComplete
          ? VNextOnboardingFlow(
              key: const ValueKey('onboarding'),
              controller: widget.runtime.onboarding,
              onCompleted: _completeOnboarding,
            )
          : Stack(
              key: const ValueKey('shell'),
              fit: StackFit.expand,
              children: [
                VNextShell(
                  runtime: widget.runtime,
                  onResetLocalData: _resetLocalData,
                ),
                if (widget.runtime.pendingRankUp case final rankLabel?)
                  _RankUpOverlay(
                    rankLabel: rankLabel,
                    onDismiss: _dismissRankUp,
                  ),
              ],
            ),
    );
  }

  Future<void> _initialize() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final state = widget.legacyController.state;
      await widget.runtime.initialize(
        legacyUserHasProgress: state.completedCount > 0 || state.totalXp > 0,
        legacySafetyAccepted: state.onboarding.boundariesAcknowledged,
      );
    } catch (error, stackTrace) {
      _error = error;
      developer.log(
        'Failed to initialize vNext root',
        name: 'mayhem.bootstrap',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _completeOnboarding() async {
    setState(() => _loading = true);
    try {
      await widget.runtime.loadProduct();
    } catch (error, stackTrace) {
      _error = error;
      developer.log(
        'Failed to open product after onboarding',
        name: 'mayhem.bootstrap',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetLocalData() async {
    await widget.legacyController.clearLocalData();
    await widget.runtime.reinitializeAfterLocalReset();
    if (mounted) {
      setState(() {
        _error = null;
        _loading = false;
      });
    }
  }

  Future<void> _dismissRankUp() async {
    await widget.runtime.consumeRankUp();
    if (mounted) setState(() {});
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState({super.key});

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: MayhemColors.canvasBase,
    child: Center(
      child: MayhemText(
        context.strings.loading,
        variant: MayhemTextVariant.bodyLarge,
      ),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: MayhemColors.canvasBase,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(MayhemSpacing.x6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MayhemText(
              context.strings.localLoadError,
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
    ),
  );
}

class _RankUpOverlay extends StatelessWidget {
  const _RankUpOverlay({required this.rankLabel, required this.onDismiss});

  final String rankLabel;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final mover = !rankLabel.startsWith(RankFamily.spark.name.toUpperCase());
    return ColoredBox(
      color: MayhemColors.overlayDeep,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(MayhemSpacing.x6),
            child: CompactRankUpScene(
              eyebrow: context.strings.rankUp,
              title: context.strings.rankUnlocked(rankLabel),
              dismissLabel: context.strings.continueLabel,
              tier: mover ? RankSigilTier.mover : RankSigilTier.spark,
              onDismiss: onDismiss,
            ),
          ),
        ),
      ),
    );
  }
}
