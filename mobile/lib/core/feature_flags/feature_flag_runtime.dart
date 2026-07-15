import 'package:flutter/foundation.dart';

import 'feature_flags.dart';

class FeatureFlagRuntime {
  FeatureFlagRuntime._({
    required this.snapshot,
    required Set<MayhemFeatureFlag> debugOverrides,
  }) : debugOverrides = Set.unmodifiable(debugOverrides);

  factory FeatureFlagRuntime.safe() => FeatureFlagRuntime._(
    snapshot: FeatureFlagSnapshot.safeDefaults(),
    debugOverrides: const {},
  );

  factory FeatureFlagRuntime.resolve({
    required bool debugBuild,
    Map<MayhemFeatureFlag, bool> requestedDebugOverrides = const {},
  }) {
    final applied = debugBuild
        ? requestedDebugOverrides.entries
              .where((entry) => entry.value)
              .map((entry) => entry.key)
              .toSet()
        : <MayhemFeatureFlag>{};
    return FeatureFlagRuntime._(
      snapshot: FeatureFlagSnapshot(
        values: {for (final flag in applied) flag: true},
      ),
      debugOverrides: applied,
    );
  }

  factory FeatureFlagRuntime.fromEnvironment() => FeatureFlagRuntime.resolve(
    debugBuild: kDebugMode,
    requestedDebugOverrides: const {
      MayhemFeatureFlag.newFeedEnabled: bool.fromEnvironment(
        'MAYHEM_NEW_FEED_ENABLED',
      ),
      MayhemFeatureFlag.advancedMotionEnabled: bool.fromEnvironment(
        'MAYHEM_ADVANCED_MOTION_ENABLED',
      ),
    },
  );

  final FeatureFlagSnapshot snapshot;
  final Set<MayhemFeatureFlag> debugOverrides;

  bool isEnabled(MayhemFeatureFlag flag) => snapshot.isEnabled(flag);

  bool isDebugOverride(MayhemFeatureFlag flag) => debugOverrides.contains(flag);
}
