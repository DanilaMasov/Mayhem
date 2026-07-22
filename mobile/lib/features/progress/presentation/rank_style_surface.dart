import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/design_system/tokens/tokens.dart';
import '../domain/progress_models.dart';
import '../domain/rank_visual_style.dart';

class RankStylePalette {
  const RankStylePalette({
    required this.accent,
    required this.secondary,
    required this.backgroundStart,
    required this.backgroundEnd,
  });

  final Color accent;
  final Color secondary;
  final Color backgroundStart;
  final Color backgroundEnd;
}

RankStylePalette rankStylePalette(RankVisualStyle style) {
  final rank = style.unlockRank;
  final accent = switch (rank.family) {
    RankFamily.spark => MayhemColors.brandSignalSoft,
    RankFamily.mover => MayhemColors.traitConnection,
    RankFamily.catalyst => MayhemColors.traitInitiation,
    RankFamily.maverick => MayhemColors.semanticWarning,
    RankFamily.icon => MayhemColors.brandColdLight,
    RankFamily.mayhem => MayhemColors.traitExpression,
  };
  final secondary = switch (rank.tier) {
    1 => MayhemColors.brandColdLight,
    2 => MayhemColors.semanticInfo,
    _ => MayhemColors.traitInitiation,
  };
  final intensity = rank.family == RankFamily.mayhem
      ? 0.32
      : 0.16 + rank.tier * 0.04;
  return RankStylePalette(
    accent: accent,
    secondary: secondary,
    backgroundStart: Color.alphaBlend(
      accent.withValues(alpha: intensity),
      MayhemColors.canvasRaised,
    ),
    backgroundEnd: Color.alphaBlend(
      secondary.withValues(alpha: intensity * 0.42),
      MayhemColors.canvasDeep,
    ),
  );
}

class RankStyleSurface extends StatelessWidget {
  const RankStyleSurface({
    super.key,
    required this.style,
    required this.child,
    this.borderRadius = BorderRadius.zero,
  });

  final RankVisualStyle style;
  final Widget child;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final palette = rankStylePalette(style);
    return ClipRRect(
      borderRadius: borderRadius,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [palette.backgroundStart, palette.backgroundEnd],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _RankStylePatternPainter(
                  family: style.unlockRank.family,
                  tier: style.unlockRank.tier,
                  palette: palette,
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _RankStylePatternPainter extends CustomPainter {
  const _RankStylePatternPainter({
    required this.family,
    required this.tier,
    required this.palette,
  });

  final RankFamily family;
  final int tier;
  final RankStylePalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = palette.accent.withValues(alpha: 0.16 + tier * 0.025)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    switch (family) {
      case RankFamily.spark:
        for (var x = -size.height; x < size.width; x += 54) {
          canvas.drawLine(
            Offset(x.toDouble(), size.height),
            Offset(x + size.height * 0.42, 0),
            paint,
          );
        }
      case RankFamily.mover:
        for (var index = 0; index < 4; index += 1) {
          final y = size.height - 28 - index * 42;
          final center = size.width * (0.68 + index * 0.035);
          final path = Path()
            ..moveTo(center - 28, y)
            ..lineTo(center, y - 24)
            ..lineTo(center + 28, y);
          canvas.drawPath(path, paint);
        }
      case RankFamily.catalyst:
        for (var index = 0; index < 4; index += 1) {
          final radius = 22.0 + index * 28;
          final center = Offset(size.width * 0.78, size.height * 0.52);
          final path = Path();
          for (var point = 0; point < 3; point += 1) {
            final angle = -math.pi / 2 + point * math.pi * 2 / 3;
            final offset = center + Offset.fromDirection(angle, radius);
            if (point == 0) {
              path.moveTo(offset.dx, offset.dy);
            } else {
              path.lineTo(offset.dx, offset.dy);
            }
          }
          path.close();
          canvas.drawPath(path, paint);
        }
      case RankFamily.maverick:
        final center = Offset(size.width * 0.78, size.height * 0.52);
        for (var index = 1; index <= 4; index += 1) {
          canvas.drawArc(
            Rect.fromCircle(center: center, radius: index * 24),
            -math.pi * 0.85,
            math.pi * 1.35,
            false,
            paint,
          );
        }
      case RankFamily.icon:
        for (var index = 0; index < 18; index += 1) {
          final x = (index * 83 % 100) / 100 * size.width;
          final y = (index * 47 % 100) / 100 * size.height;
          canvas.drawCircle(Offset(x, y), index.isEven ? 1.8 : 1, paint);
        }
      case RankFamily.mayhem:
        final center = size.center(Offset.zero);
        for (var index = 0; index < 12; index += 1) {
          final angle = index * math.pi / 6;
          canvas.drawLine(
            center + Offset.fromDirection(angle, 28),
            center + Offset.fromDirection(angle, size.longestSide),
            paint,
          );
        }
    }
  }

  @override
  bool shouldRepaint(_RankStylePatternPainter oldDelegate) =>
      oldDelegate.family != family ||
      oldDelegate.tier != tier ||
      oldDelegate.palette.accent != palette.accent;
}
