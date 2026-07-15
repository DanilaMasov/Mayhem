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
  static const displayHero = TextStyle(
    color: MayhemColors.textPrimary,
    fontSize: 48,
    height: 0.96,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
  );
  static const displayLarge = TextStyle(
    color: MayhemColors.textPrimary,
    fontSize: 40,
    height: 1,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
  );
  static const displayMedium = TextStyle(
    color: MayhemColors.textPrimary,
    fontSize: 32,
    height: 1.05,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
  );
  static const headlineLarge = TextStyle(
    color: MayhemColors.textPrimary,
    fontSize: 28,
    height: 1.1,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );
  static const headlineMedium = TextStyle(
    color: MayhemColors.textPrimary,
    fontSize: 24,
    height: 1.15,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );
  static const headlineSmall = TextStyle(
    color: MayhemColors.textPrimary,
    fontSize: 20,
    height: 1.2,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );
  static const bodyLarge = TextStyle(
    color: MayhemColors.textSecondary,
    fontSize: 17,
    height: 1.45,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
  );
  static const bodyMedium = TextStyle(
    color: MayhemColors.textSecondary,
    fontSize: 15,
    height: 1.45,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
  );
  static const bodySmall = TextStyle(
    color: MayhemColors.textSecondary,
    fontSize: 13,
    height: 1.4,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
  );
  static const labelLarge = TextStyle(
    color: MayhemColors.textPrimary,
    fontSize: 14,
    height: 1.15,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );
  static const labelMedium = TextStyle(
    color: MayhemColors.textSecondary,
    fontSize: 12,
    height: 1.15,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );
  static const labelMicro = TextStyle(
    color: MayhemColors.textTertiary,
    fontSize: 10,
    height: 1.1,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
  );
  static const numberHero = TextStyle(
    color: MayhemColors.textPrimary,
    fontSize: 56,
    height: 0.9,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const numberStatus = TextStyle(
    color: MayhemColors.textPrimary,
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
