import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../../features/progress/domain/progress_models.dart';
import '../tokens/tokens.dart';

class TraitConstellation extends StatelessWidget {
  const TraitConstellation({
    super.key,
    required this.values,
    required this.semanticLabel,
    this.onPressed,
    this.size = 240,
  });

  final Map<Trait, int> values;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final visual = SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _TraitConstellationPainter(values)),
    );
    return Semantics(
      button: onPressed != null,
      image: onPressed == null,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: onPressed == null
            ? visual
            : GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onPressed,
                child: visual,
              ),
      ),
    );
  }
}

class _TraitConstellationPainter extends CustomPainter {
  const _TraitConstellationPainter(this.values);

  final Map<Trait, int> values;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * 0.39;
    final guide = Paint()
      ..color = MayhemColors.lineSubtle
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final connection = Paint()
      ..color = MayhemColors.brandColdLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (final factor in const [0.35, 0.7, 1.0]) {
      canvas.drawCircle(center, radius * factor, guide);
    }
    canvas.drawLine(
      center.translate(-radius, 0),
      center.translate(radius, 0),
      guide,
    );
    canvas.drawLine(
      center.translate(0, -radius),
      center.translate(0, radius),
      guide,
    );

    final points = <Trait, Offset>{};
    for (var index = 0; index < Trait.values.length; index += 1) {
      final trait = Trait.values[index];
      final normalized = ((values[trait] ?? 0) / 100).clamp(0.12, 1.0);
      final angle = -math.pi / 2 + index * math.pi / 2;
      points[trait] = center + Offset.fromDirection(angle, radius * normalized);
    }
    final path = Path();
    for (var index = 0; index < Trait.values.length; index += 1) {
      final point = points[Trait.values[index]]!;
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = MayhemColors.brandSignal.withValues(alpha: 0.13)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(path, connection);

    for (var index = 0; index < Trait.values.length; index += 1) {
      final trait = Trait.values[index];
      _drawNode(canvas, points[trait]!, index, _color(trait));
    }
  }

  void _drawNode(Canvas canvas, Offset point, int index, Color color) {
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    const node = 6.0;
    switch (index) {
      case 0:
        canvas.drawCircle(point, node, fill);
      case 1:
        canvas.drawRect(
          Rect.fromCenter(center: point, width: node * 2, height: node * 2),
          fill,
        );
      case 2:
        final path = Path()
          ..moveTo(point.dx, point.dy - node)
          ..lineTo(point.dx + node, point.dy + node)
          ..lineTo(point.dx - node, point.dy + node)
          ..close();
        canvas.drawPath(path, fill);
      case 3:
        final path = Path()
          ..moveTo(point.dx, point.dy - node)
          ..lineTo(point.dx + node, point.dy)
          ..lineTo(point.dx, point.dy + node)
          ..lineTo(point.dx - node, point.dy)
          ..close();
        canvas.drawPath(path, fill);
    }
  }

  Color _color(Trait trait) => switch (trait) {
    Trait.initiation => MayhemColors.traitInitiation,
    Trait.expression => MayhemColors.traitExpression,
    Trait.connection => MayhemColors.traitConnection,
    Trait.presence => MayhemColors.traitPresence,
  };

  @override
  bool shouldRepaint(_TraitConstellationPainter oldDelegate) =>
      !mapEquals(oldDelegate.values, values);
}
