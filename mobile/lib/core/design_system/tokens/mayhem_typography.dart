import 'package:flutter/material.dart';

import 'mayhem_colors.dart';

enum MayhemTextVariant {
  displayHero,
  displayLarge,
  displayMedium,
  headlineLarge,
  headlineMedium,
  headlineSmall,
  bodyLarge,
  bodyMedium,
  bodySmall,
  labelLarge,
  labelMedium,
  labelMicro,
  numberHero,
  numberStatus,
}

abstract final class MayhemTypography {
  static const bodyFontFamily = 'MayhemBody';
  static const displayFontFamily = 'MayhemDisplay';

  static const displayHero = TextStyle(
    color: MayhemColors.textPrimary,
    fontFamily: displayFontFamily,
    fontFamilyFallback: [bodyFontFamily],
    fontSize: 48,
    height: 0.96,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
  );
  static const displayLarge = TextStyle(
    color: MayhemColors.textPrimary,
    fontFamily: displayFontFamily,
    fontFamilyFallback: [bodyFontFamily],
    fontSize: 40,
    height: 1,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
  );
  static const displayMedium = TextStyle(
    color: MayhemColors.textPrimary,
    fontFamily: displayFontFamily,
    fontFamilyFallback: [bodyFontFamily],
    fontSize: 32,
    height: 1.05,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
  );
  static const headlineLarge = TextStyle(
    color: MayhemColors.textPrimary,
    fontFamily: displayFontFamily,
    fontFamilyFallback: [bodyFontFamily],
    fontSize: 28,
    height: 1.1,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );
  static const headlineMedium = TextStyle(
    color: MayhemColors.textPrimary,
    fontFamily: displayFontFamily,
    fontFamilyFallback: [bodyFontFamily],
    fontSize: 24,
    height: 1.15,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );
  static const headlineSmall = TextStyle(
    color: MayhemColors.textPrimary,
    fontFamily: displayFontFamily,
    fontFamilyFallback: [bodyFontFamily],
    fontSize: 20,
    height: 1.2,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );
  static const navigationTitle = TextStyle(
    color: MayhemColors.textPrimary,
    fontFamily: bodyFontFamily,
    fontSize: 18,
    height: 1.15,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.2,
  );
  static const bodyLarge = TextStyle(
    color: MayhemColors.textSecondary,
    fontFamily: bodyFontFamily,
    fontSize: 17,
    height: 1.45,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
  );
  static const bodyMedium = TextStyle(
    color: MayhemColors.textSecondary,
    fontFamily: bodyFontFamily,
    fontSize: 15,
    height: 1.45,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
  );
  static const bodySmall = TextStyle(
    color: MayhemColors.textSecondary,
    fontFamily: bodyFontFamily,
    fontSize: 13,
    height: 1.4,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
  );
  static const labelLarge = TextStyle(
    color: MayhemColors.textPrimary,
    fontFamily: bodyFontFamily,
    fontSize: 14,
    height: 1.15,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.35,
  );
  static const labelMedium = TextStyle(
    color: MayhemColors.textSecondary,
    fontFamily: bodyFontFamily,
    fontSize: 12,
    height: 1.15,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.55,
  );
  static const labelMicro = TextStyle(
    color: MayhemColors.textTertiary,
    fontFamily: bodyFontFamily,
    fontSize: 10,
    height: 1.1,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.1,
  );
  static const numberHero = TextStyle(
    color: MayhemColors.textPrimary,
    fontFamily: displayFontFamily,
    fontFamilyFallback: [bodyFontFamily],
    fontSize: 56,
    height: 0.9,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const numberStatus = TextStyle(
    color: MayhemColors.textPrimary,
    fontFamily: displayFontFamily,
    fontFamilyFallback: [bodyFontFamily],
    fontSize: 24,
    height: 1,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static TextStyle resolve(MayhemTextVariant variant) => switch (variant) {
    MayhemTextVariant.displayHero => displayHero,
    MayhemTextVariant.displayLarge => displayLarge,
    MayhemTextVariant.displayMedium => displayMedium,
    MayhemTextVariant.headlineLarge => headlineLarge,
    MayhemTextVariant.headlineMedium => headlineMedium,
    MayhemTextVariant.headlineSmall => headlineSmall,
    MayhemTextVariant.bodyLarge => bodyLarge,
    MayhemTextVariant.bodyMedium => bodyMedium,
    MayhemTextVariant.bodySmall => bodySmall,
    MayhemTextVariant.labelLarge => labelLarge,
    MayhemTextVariant.labelMedium => labelMedium,
    MayhemTextVariant.labelMicro => labelMicro,
    MayhemTextVariant.numberHero => numberHero,
    MayhemTextVariant.numberStatus => numberStatus,
  };
}
