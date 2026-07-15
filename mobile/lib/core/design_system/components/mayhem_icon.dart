import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';

enum MayhemGlyph { feed, journey, profile, close, arrowRight, refresh }

class MayhemIcon extends StatelessWidget {
  const MayhemIcon(
    this.glyph, {
    super.key,
    required this.semanticLabel,
    this.size = 24,
    this.color = MayhemColors.textPrimary,
    this.decorative = false,
  });

  final MayhemGlyph glyph;
  final String semanticLabel;
  final double size;
  final Color color;
  final bool decorative;

  @override
  Widget build(BuildContext context) {
    final icon = SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _MayhemIconPainter(glyph, color)),
    );
    if (decorative) return ExcludeSemantics(child: icon);
    return Semantics(image: true, label: semanticLabel, child: icon);
  }
}

class _MayhemIconPainter extends CustomPainter {
  const _MayhemIconPainter(this.glyph, this.color);

  final MayhemGlyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 24;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.save();
    canvas.scale(scale, scale);
    switch (glyph) {
      case MayhemGlyph.feed:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(4, 4, 16, 5),
            const Radius.circular(2),
          ),
          paint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(4, 12, 16, 8),
            const Radius.circular(2),
          ),
          paint,
        );
      case MayhemGlyph.journey:
        final path = Path()
          ..moveTo(5, 18)
          ..lineTo(9, 8)
          ..lineTo(15, 14)
          ..lineTo(19, 5);
        canvas.drawPath(path, paint);
        for (final point in const [
          Offset(5, 18),
          Offset(9, 8),
          Offset(15, 14),
          Offset(19, 5),
        ]) {
          canvas.drawCircle(point, 1.5, paint);
        }
      case MayhemGlyph.profile:
        canvas.drawCircle(const Offset(12, 8), 3.5, paint);
        canvas.drawArc(
          const Rect.fromLTWH(5, 13, 14, 8),
          math.pi,
          math.pi,
          false,
          paint,
        );
      case MayhemGlyph.close:
        canvas.drawLine(const Offset(6, 6), const Offset(18, 18), paint);
        canvas.drawLine(const Offset(18, 6), const Offset(6, 18), paint);
      case MayhemGlyph.arrowRight:
        canvas.drawLine(const Offset(5, 12), const Offset(19, 12), paint);
        canvas.drawLine(const Offset(14, 7), const Offset(19, 12), paint);
        canvas.drawLine(const Offset(19, 12), const Offset(14, 17), paint);
      case MayhemGlyph.refresh:
        canvas.drawArc(
          const Rect.fromLTWH(4, 4, 16, 16),
          math.pi * 0.15,
          math.pi * 1.55,
          false,
          paint,
        );
        canvas.drawLine(const Offset(18, 4), const Offset(20, 9), paint);
        canvas.drawLine(const Offset(20, 9), const Offset(15, 8), paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MayhemIconPainter oldDelegate) {
    return oldDelegate.glyph != glyph || oldDelegate.color != color;
  }
}
