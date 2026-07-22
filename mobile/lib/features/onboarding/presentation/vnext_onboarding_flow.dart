import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/design_system/accessibility/mayhem_motion_preferences.dart';
import '../../../core/design_system/components/components.dart';
import '../../../core/design_system/motion/mayhem_durations.dart';
import '../../../core/design_system/tokens/tokens.dart';
import '../../../core/localization/mayhem_strings.dart';
import '../../progress/domain/progress_models.dart';
import '../application/onboarding_controller.dart';
import '../domain/onboarding_models.dart';

class VNextOnboardingFlow extends StatefulWidget {
  const VNextOnboardingFlow({
    super.key,
    required this.controller,
    required this.onCompleted,
  });

  final OnboardingController controller;
  final Future<void> Function() onCompleted;

  @override
  State<VNextOnboardingFlow> createState() => _VNextOnboardingFlowState();
}

class _VNextOnboardingFlowState extends State<VNextOnboardingFlow> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, child) {
        final reduceMotion = MayhemAccessibility.of(context).reduceMotion;
        final progress = widget.controller.progress;
        return MayhemScaffold(
          body: AnimatedSwitcher(
            duration: reduceMotion ? Duration.zero : MayhemDurations.standard,
            child: switch (progress.stage) {
              OnboardingStage.opening => _OpeningScene(
                key: const ValueKey('opening'),
                busy: _busy,
                onBegin: _begin,
              ),
              OnboardingStage.calibration => _CalibrationScene(
                key: const ValueKey('calibration'),
                progress: progress,
                busy: _busy,
                onAnswer: _answer,
              ),
              OnboardingStage.safety => _SafetyScene(
                key: const ValueKey('safety'),
                busy: _busy,
                onAccept: _acceptSafety,
              ),
              OnboardingStage.profileReveal => _ProfileRevealScene(
                key: const ValueKey('reveal'),
                signals: widget.controller.initialSignals,
                busy: _busy,
                onContinue: _completeReveal,
              ),
              OnboardingStage.completed => const SizedBox.shrink(
                key: ValueKey('completed'),
              ),
            },
          ),
        );
      },
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _begin() => _run(widget.controller.begin);

  Future<void> _answer(Trait trait, int index) =>
      _run(() => widget.controller.answer(trait, index));

  Future<void> _acceptSafety() => _run(() async {
    final completed = await widget.controller.acceptSafety();
    if (completed) await widget.onCompleted();
  });

  Future<void> _completeReveal() => _run(() async {
    await widget.controller.completeProfileReveal();
    await widget.onCompleted();
  });
}

class _OpeningScene extends StatelessWidget {
  const _OpeningScene({super.key, required this.busy, required this.onBegin});

  final bool busy;
  final VoidCallback onBegin;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return Stack(
      fit: StackFit.expand,
      children: [
        const CustomPaint(painter: _OpeningFieldPainter()),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(MayhemSpacing.x6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const MayhemText(
                  'MAYHEM',
                  variant: MayhemTextVariant.labelLarge,
                  color: MayhemColors.brandSignalSoft,
                ),
                const Spacer(),
                MayhemText(
                  strings.openingTitle,
                  variant: MayhemTextVariant.displayHero,
                  maxLines: 3,
                ),
                const SizedBox(height: MayhemSpacing.x5),
                MayhemText(
                  strings.openingBody,
                  variant: MayhemTextVariant.bodyLarge,
                  maxLines: 4,
                ),
                const SizedBox(height: MayhemSpacing.x8),
                MayhemPrimaryButton(
                  label: strings.begin,
                  onPressed: onBegin,
                  loading: busy,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CalibrationScene extends StatelessWidget {
  const _CalibrationScene({
    super.key,
    required this.progress,
    required this.busy,
    required this.onAnswer,
  });

  final OnboardingProgress progress;
  final bool busy;
  final void Function(Trait trait, int index) onAnswer;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final trait = CalibrationPolicy.traitOrder.firstWhere(
      (item) => !progress.answerIndexByTrait.containsKey(item),
    );
    final current = progress.answerIndexByTrait.length + 1;
    final options = strings.calibrationOptions(trait);
    return SafeArea(
      child: ListView(
        key: ValueKey(trait),
        padding: const EdgeInsets.fromLTRB(
          MayhemSpacing.x5,
          MayhemSpacing.x6,
          MayhemSpacing.x5,
          MayhemSpacing.x10,
        ),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: MayhemText(
                  strings.calibrationLabel,
                  variant: MayhemTextVariant.labelMicro,
                ),
              ),
              MayhemText(
                strings.calibrationProgress(
                  current,
                  CalibrationPolicy.traitOrder.length,
                ),
                variant: MayhemTextVariant.labelMicro,
                color: MayhemColors.brandSignalSoft,
              ),
            ],
          ),
          const SizedBox(height: MayhemSpacing.x12),
          MayhemText(
            strings.calibrationQuestion(trait),
            variant: MayhemTextVariant.headlineLarge,
          ),
          const SizedBox(height: MayhemSpacing.x8),
          for (var index = 0; index < options.length; index++) ...[
            _CalibrationOption(
              index: index,
              label: options[index],
              enabled: !busy,
              onPressed: () => onAnswer(trait, index),
            ),
            const SizedBox(height: MayhemSpacing.x3),
          ],
        ],
      ),
    );
  }
}

class _CalibrationOption extends StatelessWidget {
  const _CalibrationOption({
    required this.index,
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  final int index;
  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return MayhemPressable(
      semanticLabel: label,
      enabled: enabled,
      onPressed: onPressed,
      borderRadius: MayhemRadii.medium,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: MayhemColors.surfaceBase,
          borderRadius: MayhemRadii.medium,
          border: Border.all(color: MayhemColors.lineStrong),
        ),
        child: Padding(
          padding: const EdgeInsets.all(MayhemSpacing.x5),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: MayhemText(
                  String.fromCharCode(65 + index),
                  variant: MayhemTextVariant.labelLarge,
                  color: MayhemColors.brandSignalSoft,
                ),
              ),
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
}

class _SafetyScene extends StatelessWidget {
  const _SafetyScene({super.key, required this.busy, required this.onAccept});

  final bool busy;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(MayhemSpacing.x6),
        children: [
          const SizedBox(height: MayhemSpacing.x8),
          MayhemText(
            strings.boundariesTitle,
            variant: MayhemTextVariant.displayMedium,
          ),
          const SizedBox(height: MayhemSpacing.x4),
          MayhemText(
            strings.boundariesBody,
            variant: MayhemTextVariant.bodyLarge,
          ),
          const SizedBox(height: MayhemSpacing.x8),
          for (final rule in strings.boundariesRules)
            Padding(
              padding: const EdgeInsets.only(bottom: MayhemSpacing.x4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 20,
                    color: MayhemColors.semanticSuccess,
                  ),
                  const SizedBox(width: MayhemSpacing.x3),
                  Expanded(
                    child: MayhemText(
                      rule,
                      variant: MayhemTextVariant.bodyMedium,
                      color: MayhemColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: MayhemSpacing.x6),
          MayhemPrimaryButton(
            label: strings.acceptBoundaries,
            onPressed: onAccept,
            loading: busy,
          ),
        ],
      ),
    );
  }
}

class _ProfileRevealScene extends StatelessWidget {
  const _ProfileRevealScene({
    super.key,
    required this.signals,
    required this.busy,
    required this.onContinue,
  });

  final Map<Trait, int> signals;
  final bool busy;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final semantic = Trait.values
        .map((trait) => '${strings.traitName(trait)} ${signals[trait]}')
        .join(', ');
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(MayhemSpacing.x6),
        children: [
          MayhemText(
            strings.initialSignal,
            variant: MayhemTextVariant.labelMicro,
            color: MayhemColors.brandSignalSoft,
          ),
          const SizedBox(height: MayhemSpacing.x5),
          const Center(child: RankSigil(tier: RankSigilTier.spark, size: 104)),
          const Center(
            child: MayhemText(
              'ИСКРА',
              variant: MayhemTextVariant.headlineMedium,
            ),
          ),
          const SizedBox(height: MayhemSpacing.x5),
          Center(
            child: TraitConstellation(
              values: signals,
              semanticLabel: semantic,
              size: 220,
            ),
          ),
          const SizedBox(height: MayhemSpacing.x4),
          for (final trait in Trait.values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: MayhemSpacing.x1),
              child: Row(
                children: [
                  Expanded(
                    child: MayhemText(
                      strings.traitName(trait),
                      variant: MayhemTextVariant.bodyMedium,
                    ),
                  ),
                  MayhemText(
                    '${signals[trait]}',
                    variant: MayhemTextVariant.numberStatus,
                  ),
                ],
              ),
            ),
          const SizedBox(height: MayhemSpacing.x5),
          MayhemText(
            strings.profileRevealBody,
            variant: MayhemTextVariant.bodySmall,
          ),
          const SizedBox(height: MayhemSpacing.x6),
          MayhemPrimaryButton(
            label: strings.continueLabel,
            onPressed: onContinue,
            loading: busy,
          ),
        ],
      ),
    );
  }
}

class _OpeningFieldPainter extends CustomPainter {
  const _OpeningFieldPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = MayhemColors.canvasDeep,
    );
    final line = Paint()
      ..color = MayhemColors.lineStrong
      ..strokeWidth = 1;
    final signal = Paint()
      ..color = MayhemColors.brandSignal
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (var index = 0; index < 7; index++) {
      final y = size.height * (0.12 + index * 0.09);
      canvas.drawLine(
        Offset(size.width * 0.08, y),
        Offset(size.width * 0.92, y - size.height * 0.08),
        line,
      );
    }
    final center = Offset(size.width * 0.74, size.height * 0.28);
    final path = Path();
    for (var index = 0; index < 6; index++) {
      final angle = -math.pi / 2 + index * math.pi / 3;
      final point = center + Offset.fromDirection(angle, size.width * 0.18);
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(path..close(), signal);
  }

  @override
  bool shouldRepaint(_OpeningFieldPainter oldDelegate) => false;
}
