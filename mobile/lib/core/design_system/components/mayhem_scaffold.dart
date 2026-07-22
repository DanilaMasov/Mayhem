import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';

class MayhemScaffold extends StatelessWidget {
  const MayhemScaffold({
    super.key,
    required this.body,
    this.bottomNavigation,
    this.backgroundColor = MayhemColors.canvasBase,
    this.resizeToAvoidBottomInset = true,
  });

  final Widget body;
  final Widget? bottomNavigation;
  final Color backgroundColor;
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    final bottomInset = resizeToAvoidBottomInset
        ? MediaQuery.viewInsetsOf(context).bottom
        : 0.0;
    return ColoredBox(
      color: backgroundColor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _MayhemAtmospherePainter(base: backgroundColor),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: body,
          ),
          if (bottomNavigation != null)
            Positioned(
              left: MayhemSpacing.x4,
              right: MayhemSpacing.x4,
              bottom: MediaQuery.paddingOf(context).bottom + MayhemSpacing.x3,
              child: bottomNavigation!,
            ),
        ],
      ),
    );
  }
}

class _MayhemAtmospherePainter extends CustomPainter {
  const _MayhemAtmospherePainter({required this.base});

  final Color base;

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
              MayhemColors.brandVoid.withValues(alpha: 0.54),
              base,
            ),
            base,
            MayhemColors.canvasDeep,
          ],
          stops: const [0, 0.48, 1],
        ).createShader(bounds),
    );

    final glowBounds = Rect.fromCircle(
      center: Offset(size.width * 0.88, size.height * 0.12),
      radius: size.longestSide * 0.42,
    );
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          colors: [
            MayhemColors.brandSignal.withValues(alpha: 0.16),
            MayhemColors.brandSignal.withValues(alpha: 0.035),
            const Color(0x00000000),
          ],
          stops: const [0, 0.48, 1],
        ).createShader(glowBounds),
    );

    final line = Paint()
      ..color = MayhemColors.brandSignalSoft.withValues(alpha: 0.045)
      ..strokeWidth = 1;
    for (var index = -3; index < 10; index += 1) {
      final x = index * size.width * 0.18;
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height * 0.36, 0),
        line,
      );
    }

    final dust = Paint()
      ..color = MayhemColors.textPrimary.withValues(alpha: 0.1);
    for (var index = 0; index < 18; index += 1) {
      final x = ((index * 47 + 11) % 101) / 101 * size.width;
      final y = ((index * 73 + 19) % 103) / 103 * size.height;
      canvas.drawCircle(Offset(x, y), index.isEven ? 0.7 : 1.1, dust);
    }
  }

  @override
  bool shouldRepaint(_MayhemAtmospherePainter oldDelegate) =>
      oldDelegate.base != base;
}
