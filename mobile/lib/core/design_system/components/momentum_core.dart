import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../accessibility/mayhem_motion_preferences.dart';
import '../motion/mayhem_curves.dart';
import '../motion/mayhem_durations.dart';
import '../tokens/tokens.dart';
import 'mayhem_text.dart';

enum MomentumCoreState { dormant, available, earned, shielded, atRisk }

class MomentumCore extends StatelessWidget {
  const MomentumCore({
    super.key,
    required this.days,
    required this.state,
    this.size = 144,
  });

  final int days;
  final MomentumCoreState state;
  final double size;

  String get _stateLabel => switch (state) {
    MomentumCoreState.dormant => 'not active',
    MomentumCoreState.available => 'available today',
    MomentumCoreState.earned => 'earned today',
    MomentumCoreState.shielded => 'protected by a shield',
    MomentumCoreState.atRisk => 'at risk today',
  };

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MayhemAccessibility.of(context).reduceMotion;
    return Semantics(
      container: true,
      image: true,
      label: 'Momentum $days days, $_stateLabel',
      child: ExcludeSemantics(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: reduceMotion ? Duration.zero : MayhemDurations.emphasis,
          curve: MayhemCurves.enter,
          builder: (context, progress, child) {
            return SizedBox.square(
              dimension: size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _MomentumCorePainter(
                        state: state,
                        progress: progress,
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MayhemText(
                        '$days',
                        variant: size >= 120
                            ? MayhemTextVariant.numberStatus
                            : MayhemTextVariant.labelLarge,
                      ),
                      if (size >= 120)
                        const MayhemText(
                          'MOMENTUM',
                          variant: MayhemTextVariant.labelMicro,
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MomentumCorePainter extends CustomPainter {
  const _MomentumCorePainter({required this.state, required this.progress});

  final MomentumCoreState state;
  final double progress;

  Color get _energy => switch (state) {
    MomentumCoreState.dormant => MayhemColors.textTertiary,
    MomentumCoreState.available => MayhemColors.brandSignalSoft,
    MomentumCoreState.earned => MayhemColors.semanticSuccess,
    MomentumCoreState.shielded => MayhemColors.brandColdLight,
    MomentumCoreState.atRisk => MayhemColors.semanticWarning,
  };

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final energy = _energy;
    final shellPaint = Paint()
      ..color = MayhemColors.surfaceRaised
      ..style = PaintingStyle.fill;
    final ringPaint = Paint()
      ..color = energy
      ..strokeWidth = math.max(2, radius * 0.035)
      ..style = PaintingStyle.stroke;
    final subtlePaint = Paint()
      ..color = MayhemColors.lineStrong
      ..strokeWidth = math.max(1, radius * 0.016)
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, radius * 0.82 * progress, shellPaint);
    canvas.drawCircle(center, radius * 0.72 * progress, subtlePaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.88),
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      ringPaint,
    );

    final segments = state == MomentumCoreState.shielded ? 6 : 4;
    for (var index = 0; index < segments; index++) {
      final angle = (math.pi * 2 / segments) * index - math.pi / 2;
      final inner = center + Offset.fromDirection(angle, radius * 0.58);
      final outer = center + Offset.fromDirection(angle, radius * 0.72);
      canvas.drawLine(inner, outer, ringPaint);
    }

    if (state == MomentumCoreState.atRisk) {
      final warningPaint = Paint()
        ..color = MayhemColors.canvasBase
        ..strokeWidth = math.max(4, radius * 0.07)
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius * 0.88),
        math.pi * 0.16,
        math.pi * 0.22,
        false,
        warningPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_MomentumCorePainter oldDelegate) {
    return oldDelegate.state != state || oldDelegate.progress != progress;
  }
}
