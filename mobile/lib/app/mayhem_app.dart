import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../application/today_controller.dart';
import '../core/design_system/accessibility/mayhem_motion_preferences.dart';
import '../core/feature_flags/feature_flag_runtime.dart';
import '../core/feature_flags/feature_flags.dart';
import '../core/localization/mayhem_strings.dart';
import '../dev/motion_lab/motion_lab.dart';
import '../presentation/onboarding/boundaries_screen.dart';
import '../presentation/onboarding/onboarding_quest_screen.dart';
import '../presentation/theme/mayhem_theme.dart';
import '../presentation/today/today_screen.dart';
import 'vnext/vnext_app_root.dart';
import 'vnext/vnext_runtime.dart';

class MayhemApp extends StatelessWidget {
  const MayhemApp({
    super.key,
    required this.controller,
    this.featureFlags,
    this.vnextRuntime,
  });

  final TodayController controller;
  final FeatureFlagRuntime? featureFlags;
  final VNextRuntime? vnextRuntime;

  @override
  Widget build(BuildContext context) {
    final flags = featureFlags ?? FeatureFlagRuntime.safe();
    final newFeedEnabled = flags.isEnabled(MayhemFeatureFlag.newFeedEnabled);
    assert(!newFeedEnabled || vnextRuntime != null);
    return MaterialApp(
      title: 'MAYHEM',
      debugShowCheckedModeBanner: false,
      theme: MayhemTheme.dark,
      builder: (context, child) => MayhemStringsScope(
        strings: const MayhemStringsRu(),
        child: MayhemAccessibility(
          preferences: const MayhemMotionPreferences(),
          child: child ?? const SizedBox.shrink(),
        ),
      ),
      routes: mayhemInternalRoutes(debug: kDebugMode),
      home: newFeedEnabled && vnextRuntime != null
          ? VNextAppRoot(runtime: vnextRuntime!, legacyController: controller)
          : _MayhemRoot(controller: controller),
    );
  }
}

Map<String, WidgetBuilder> mayhemInternalRoutes({required bool debug}) {
  return {if (debug) MotionLab.routeName: (_) => const MotionLab()};
}

class _MayhemRoot extends StatelessWidget {
  const _MayhemRoot({required this.controller});

  final TodayController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        if (controller.loading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (controller.error.isNotEmpty) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(controller.error, textAlign: TextAlign.center),
              ),
            ),
          );
        }
        if (controller.shouldShowBoundaries) {
          return BoundariesScreen(controller: controller);
        }
        if (!controller.state.onboardingComplete) {
          return OnboardingQuestScreen(controller: controller);
        }
        return TodayScreen(controller: controller);
      },
    );
  }
}
