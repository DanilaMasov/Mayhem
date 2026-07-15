import 'package:flutter/material.dart';

import 'tokens/tokens.dart';

abstract final class MayhemTheme {
  static const background = MayhemColors.canvasBase;
  static const surface = MayhemColors.surfaceBase;
  static const raised = MayhemColors.surfaceRaised;
  static const line = MayhemColors.lineStrong;
  static const ink = MayhemColors.textPrimary;
  static const muted = MayhemColors.textSecondary;
  static const signal = MayhemColors.brandSignal;
  static const safety = MayhemColors.semanticWarning;

  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      primary: MayhemColors.brandSignal,
      onPrimary: MayhemColors.textInverse,
      secondary: MayhemColors.traitConnection,
      onSecondary: MayhemColors.textInverse,
      surface: MayhemColors.surfaceBase,
      onSurface: MayhemColors.textPrimary,
      error: MayhemColors.semanticError,
      onError: MayhemColors.textInverse,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: MayhemColors.canvasBase,
      dividerColor: MayhemColors.lineSubtle,
      splashFactory: NoSplash.splashFactory,
      textTheme: const TextTheme(
        displayLarge: MayhemTypography.displayLarge,
        headlineLarge: MayhemTypography.headlineLarge,
        headlineMedium: MayhemTypography.headlineMedium,
        headlineSmall: MayhemTypography.headlineSmall,
        titleMedium: MayhemTypography.labelLarge,
        bodyLarge: MayhemTypography.bodyLarge,
        bodyMedium: MayhemTypography.bodyMedium,
        bodySmall: MayhemTypography.bodySmall,
        labelLarge: MayhemTypography.labelLarge,
        labelMedium: MayhemTypography.labelMedium,
        labelSmall: MayhemTypography.labelMicro,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: MayhemColors.canvasBase,
        foregroundColor: MayhemColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          backgroundColor: MayhemColors.brandColdLight,
          foregroundColor: MayhemColors.textInverse,
          disabledBackgroundColor: MayhemColors.surfaceHigh,
          disabledForegroundColor: MayhemColors.textDisabled,
          shape: const RoundedRectangleBorder(borderRadius: MayhemRadii.medium),
          textStyle: MayhemTypography.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          foregroundColor: MayhemColors.textPrimary,
          disabledForegroundColor: MayhemColors.textDisabled,
          side: const BorderSide(color: MayhemColors.lineStrong),
          shape: const RoundedRectangleBorder(borderRadius: MayhemRadii.medium),
          textStyle: MayhemTypography.labelLarge,
        ),
      ),
    );
  }
}
