import 'package:flutter/material.dart';

import '../tokens/tokens.dart';

class MayhemText extends StatelessWidget {
  const MayhemText(
    this.data, {
    super.key,
    this.variant = MayhemTextVariant.bodyMedium,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.semanticsLabel,
  });

  final String data;
  final MayhemTextVariant variant;
  final Color? color;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final themedStyle = Theme.of(context).textTheme.bodyMedium;
    return Text(
      data,
      style: MayhemTypography.resolve(variant).copyWith(
        color: color,
        fontFamily: themedStyle?.fontFamily,
        fontFamilyFallback: themedStyle?.fontFamilyFallback,
      ),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      semanticsLabel: semanticsLabel,
    );
  }
}
