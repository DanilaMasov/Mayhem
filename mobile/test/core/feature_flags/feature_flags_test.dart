import 'package:flutter_test/flutter_test.dart';
import 'package:mayhem_mobile/core/feature_flags/feature_flags.dart';
import 'package:mayhem_mobile/core/feature_flags/feature_flag_runtime.dart';

void main() {
  test('all new product features default to disabled', () {
    final flags = FeatureFlagSnapshot.safeDefaults();

    for (final flag in MayhemFeatureFlag.values) {
      expect(flags.isEnabled(flag), isFalse, reason: flag.wireName);
    }
    expect(
      FeatureFlagSnapshot(
        values: const {MayhemFeatureFlag.newFeedEnabled: true},
      ).isEnabled(MayhemFeatureFlag.newFeedEnabled),
      isTrue,
    );
  });

  test('release runtime ignores every requested debug override', () {
    final runtime = FeatureFlagRuntime.resolve(
      debugBuild: false,
      requestedDebugOverrides: const {
        MayhemFeatureFlag.newFeedEnabled: true,
        MayhemFeatureFlag.advancedMotionEnabled: true,
      },
    );

    for (final flag in MayhemFeatureFlag.values) {
      expect(runtime.isEnabled(flag), isFalse, reason: flag.wireName);
      expect(runtime.isDebugOverride(flag), isFalse, reason: flag.wireName);
    }
  });

  test('debug runtime exposes only explicit true overrides', () {
    final runtime = FeatureFlagRuntime.resolve(
      debugBuild: true,
      requestedDebugOverrides: const {
        MayhemFeatureFlag.newFeedEnabled: true,
        MayhemFeatureFlag.advancedMotionEnabled: false,
      },
    );

    expect(runtime.isEnabled(MayhemFeatureFlag.newFeedEnabled), isTrue);
    expect(runtime.isDebugOverride(MayhemFeatureFlag.newFeedEnabled), isTrue);
    expect(runtime.isEnabled(MayhemFeatureFlag.advancedMotionEnabled), isFalse);
  });
}
