import 'package:flutter/material.dart';

import '../tokens/tokens.dart';
import 'mayhem_icon.dart';
import 'mayhem_pressable.dart';
import 'mayhem_text.dart';

enum MayhemButtonTone { primary, secondary }

class MayhemButton extends StatelessWidget {
  const MayhemButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.tone = MayhemButtonTone.primary,
    this.icon,
    this.loading = false,
    this.enabled = true,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final MayhemButtonTone tone;
  final MayhemGlyph? icon;
  final bool loading;
  final bool enabled;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final interactive = enabled && !loading && onPressed != null;
    final primary = tone == MayhemButtonTone.primary;
    final foreground = interactive
        ? (primary ? MayhemColors.textInverse : MayhemColors.textPrimary)
        : MayhemColors.textDisabled;
    final fill = primary
        ? (interactive ? MayhemColors.brandColdLight : MayhemColors.surfaceHigh)
        : MayhemColors.surfaceBase;

    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56, minWidth: 56),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fill,
          borderRadius: MayhemRadii.medium,
          border: primary
              ? null
              : const Border.fromBorderSide(
                  BorderSide(color: MayhemColors.lineStrong),
                ),
          boxShadow: interactive ? MayhemShadows.control : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MayhemSpacing.x5,
            vertical: MayhemSpacing.x4,
          ),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading) ...[
                _LoadingMark(color: foreground),
                const SizedBox(width: MayhemSpacing.x3),
              ] else if (icon != null) ...[
                MayhemIcon(
                  icon!,
                  semanticLabel: '',
                  decorative: true,
                  size: 20,
                  color: foreground,
                ),
                const SizedBox(width: MayhemSpacing.x3),
              ],
              Flexible(
                child: MayhemText(
                  label,
                  variant: MayhemTextVariant.labelLarge,
                  color: foreground,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return MayhemPressable(
      semanticLabel: label,
      onPressed: onPressed,
      enabled: enabled,
      loading: loading,
      borderRadius: MayhemRadii.medium,
      child: expand
          ? SizedBox(width: double.infinity, child: content)
          : content,
    );
  }
}

class MayhemPrimaryButton extends MayhemButton {
  const MayhemPrimaryButton({
    super.key,
    required super.label,
    required super.onPressed,
    super.icon,
    super.loading,
    super.enabled,
    super.expand,
  }) : super(tone: MayhemButtonTone.primary);
}

class MayhemSecondaryButton extends MayhemButton {
  const MayhemSecondaryButton({
    super.key,
    required super.label,
    required super.onPressed,
    super.icon,
    super.loading,
    super.enabled,
    super.expand,
  }) : super(tone: MayhemButtonTone.secondary);
}

class _LoadingMark extends StatelessWidget {
  const _LoadingMark({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 18,
      child: CustomPaint(painter: _LoadingMarkPainter(color)),
    );
  }
}

class _LoadingMarkPainter extends CustomPainter {
  const _LoadingMarkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawArc(Offset.zero & size, 0, 4.6, false, paint);
  }

  @override
  bool shouldRepaint(_LoadingMarkPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
