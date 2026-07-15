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

  test('valid server snapshot updates listeners until it expires', () {
    final runtime = FeatureFlagRuntime.safe();
    var notifications = 0;
    runtime.addListener(() => notifications++);
    final fetchedAt = DateTime.utc(2026, 7, 15, 9);

    final applied = runtime.applySnapshot(
      snapshot: FeatureFlagSnapshot(
        values: const {MayhemFeatureFlag.newFeedEnabled: true},
      ),
      source: FeatureFlagSnapshotSource.server,
      fetchedAt: fetchedAt,
      expiresAt: fetchedAt.add(const Duration(hours: 6)),
      now: fetchedAt,
    );

    expect(applied, isTrue);
    expect(runtime.source, FeatureFlagSnapshotSource.server);
    expect(runtime.isEnabled(MayhemFeatureFlag.newFeedEnabled), isTrue);
    expect(notifications, 1);

    expect(
      runtime.expireIfNeeded(fetchedAt.add(const Duration(hours: 6))),
      isTrue,
    );
    expect(runtime.source, FeatureFlagSnapshotSource.safeDefaults);
    expect(runtime.isEnabled(MayhemFeatureFlag.newFeedEnabled), isFalse);
    expect(notifications, 2);
  });

  test('expired or malformed lifetime fails closed', () {
    final runtime = FeatureFlagRuntime.safe();
    final now = DateTime.utc(2026, 7, 15, 9);

    final applied = runtime.applySnapshot(
      snapshot: FeatureFlagSnapshot(
        values: const {MayhemFeatureFlag.remoteContentEnabled: true},
      ),
      source: FeatureFlagSnapshotSource.cached,
      fetchedAt: now.subtract(const Duration(hours: 2)),
      expiresAt: now,
      now: now,
    );

    expect(applied, isFalse);
    expect(runtime.source, FeatureFlagSnapshotSource.safeDefaults);
    expect(runtime.isEnabled(MayhemFeatureFlag.remoteContentEnabled), isFalse);
  });

  test('debug override survives a false server decision only in debug', () {
    final now = DateTime.utc(2026, 7, 15, 9);
    final debug = FeatureFlagRuntime.resolve(
      debugBuild: true,
      requestedDebugOverrides: const {MayhemFeatureFlag.newFeedEnabled: true},
    );
    final release = FeatureFlagRuntime.resolve(
      debugBuild: false,
      requestedDebugOverrides: const {MayhemFeatureFlag.newFeedEnabled: true},
    );
    addTearDown(debug.dispose);
    addTearDown(release.dispose);

    for (final runtime in [debug, release]) {
      runtime.applySnapshot(
        snapshot: FeatureFlagSnapshot.safeDefaults(),
        source: FeatureFlagSnapshotSource.server,
        fetchedAt: now,
        expiresAt: now.add(const Duration(hours: 1)),
        now: now,
      );
    }

    expect(debug.isEnabled(MayhemFeatureFlag.newFeedEnabled), isTrue);
    expect(release.isEnabled(MayhemFeatureFlag.newFeedEnabled), isFalse);
  });
}
