import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../accessibility/mayhem_motion_preferences.dart';
import '../motion/mayhem_curves.dart';
import '../motion/mayhem_durations.dart';
import '../tokens/tokens.dart';
import 'mayhem_text.dart';

enum RankSigilTier { spark, mover }

class RankSigil extends StatelessWidget {
  const RankSigil({
    super.key,
    required this.tier,
    this.size = 132,
    this.showLabel = true,
  });

  final RankSigilTier tier;
  final double size;
  final bool showLabel;

  String get _label => switch (tier) {
    RankSigilTier.spark => 'Spark',
    RankSigilTier.mover => 'Mover',
  };

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MayhemAccessibility.of(context).reduceMotion;
    return Semantics(
      container: true,
      image: true,
      label: 'Rank $_label',
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: reduceMotion ? Duration.zero : MayhemDurations.emphasis,
              curve: MayhemCurves.enter,
              builder: (context, progress, child) {
                return SizedBox.square(
                  dimension: size,
                  child: CustomPaint(
                    painter: _RankSigilPainter(tier: tier, progress: progress),
                  ),
                );
              },
            ),
            if (showLabel) ...[
              const SizedBox(height: MayhemSpacing.x2),
              MayhemText(_label, variant: MayhemTextVariant.labelLarge),
            ],
          ],
        ),
      ),
    );
  }
}

class _RankSigilPainter extends CustomPainter {
  const _RankSigilPainter({required this.tier, required this.progress});

  final RankSigilTier tier;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * 0.42 * progress;
    final outline = Paint()
      ..color = tier == RankSigilTier.spark
          ? MayhemColors.traitInitiation
          : MayhemColors.brandColdLight
      ..strokeWidth = math.max(2, size.shortestSide * 0.025)
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final structure = Paint()
      ..color = MayhemColors.surfaceHigh
      ..style = PaintingStyle.fill;

    final points = tier == RankSigilTier.spark ? 3 : 4;
    final outer = _polygon(center, radius, points, -math.pi / 2);
    canvas.drawPath(outer, structure);
    canvas.drawPath(outer, outline);

    final innerRotation = tier == RankSigilTier.spark
        ? math.pi / 2
        : math.pi / 4;
    final inner = _polygon(center, radius * 0.48, points, innerRotation);
    canvas.drawPath(inner, outline);

    if (tier == RankSigilTier.mover) {
      final line = Paint()
        ..color = MayhemColors.traitConnection
        ..strokeWidth = math.max(1.5, size.shortestSide * 0.015)
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        center.translate(-radius * 0.62, 0),
        center.translate(radius * 0.62, 0),
        line,
      );
      canvas.drawLine(
        center.translate(0, -radius * 0.62),
        center.translate(0, radius * 0.62),
        line,
      );
    }
  }

  Path _polygon(Offset center, double radius, int sides, double rotation) {
    final path = Path();
    for (var index = 0; index < sides; index++) {
      final angle = rotation + (math.pi * 2 * index / sides);
      final point = center + Offset.fromDirection(angle, radius);
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path..close();
  }

  @override
  bool shouldRepaint(_RankSigilPainter oldDelegate) {
    return oldDelegate.tier != tier || oldDelegate.progress != progress;
  }
}
