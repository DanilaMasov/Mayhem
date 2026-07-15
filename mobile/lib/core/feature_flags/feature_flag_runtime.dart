import 'dart:async';

import 'package:flutter/foundation.dart';

import 'feature_flags.dart';

enum FeatureFlagSnapshotSource { safeDefaults, cached, server }

class FeatureFlagRuntime extends ChangeNotifier {
  FeatureFlagRuntime._({
    required this._snapshot,
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

  FeatureFlagSnapshot _snapshot;
  final Set<MayhemFeatureFlag> debugOverrides;
  FeatureFlagSnapshotSource _source = FeatureFlagSnapshotSource.safeDefaults;
  DateTime? _expiresAt;
  Timer? _expiryTimer;

  FeatureFlagSnapshot get snapshot => FeatureFlagSnapshot(
    values: {
      for (final flag in MayhemFeatureFlag.values)
        if (isEnabled(flag)) flag: true,
    },
  );

  FeatureFlagSnapshotSource get source => _source;

  DateTime? get expiresAt => _expiresAt;

  bool isEnabled(MayhemFeatureFlag flag) =>
      debugOverrides.contains(flag) || _snapshot.isEnabled(flag);

  bool isDebugOverride(MayhemFeatureFlag flag) => debugOverrides.contains(flag);

  bool applySnapshot({
    required FeatureFlagSnapshot snapshot,
    required FeatureFlagSnapshotSource source,
    required DateTime fetchedAt,
    required DateTime expiresAt,
    required DateTime now,
  }) {
    if (source == FeatureFlagSnapshotSource.safeDefaults ||
        !expiresAt.toUtc().isAfter(fetchedAt.toUtc()) ||
        !expiresAt.toUtc().isAfter(now.toUtc())) {
      resetToSafeDefaults();
      return false;
    }
    _expiryTimer?.cancel();
    _expiryTimer = Timer(
      expiresAt.toUtc().difference(now.toUtc()),
      resetToSafeDefaults,
    );
    _commit(snapshot: snapshot, source: source, expiresAt: expiresAt.toUtc());
    return true;
  }

  bool expireIfNeeded(DateTime now) {
    final expiry = _expiresAt;
    if (expiry == null || expiry.isAfter(now.toUtc())) return false;
    resetToSafeDefaults();
    return true;
  }

  void resetToSafeDefaults() {
    _expiryTimer?.cancel();
    _expiryTimer = null;
    _commit(
      snapshot: FeatureFlagSnapshot.safeDefaults(),
      source: FeatureFlagSnapshotSource.safeDefaults,
      expiresAt: null,
    );
  }

  void _commit({
    required FeatureFlagSnapshot snapshot,
    required FeatureFlagSnapshotSource source,
    required DateTime? expiresAt,
  }) {
    final previous = this.snapshot;
    final metadataChanged = _source != source || _expiresAt != expiresAt;
    _snapshot = snapshot;
    _source = source;
    _expiresAt = expiresAt;
    if (metadataChanged || !_sameValues(previous, this.snapshot)) {
      notifyListeners();
    }
  }

  static bool _sameValues(
    FeatureFlagSnapshot left,
    FeatureFlagSnapshot right,
  ) => MayhemFeatureFlag.values.every(
    (flag) => left.isEnabled(flag) == right.isEnabled(flag),
  );

  @override
  void dispose() {
    _expiryTimer?.cancel();
    super.dispose();
  }
}
