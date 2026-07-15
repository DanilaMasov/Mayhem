import '../../../core/feature_flags/feature_flags.dart';
import 'backend_models.dart';

class CachedRemoteFlags {
  const CachedRemoteFlags({
    required this.snapshot,
    required this.fetchedAt,
    required this.expiresAt,
  });

  final FeatureFlagSnapshot snapshot;
  final DateTime fetchedAt;
  final DateTime expiresAt;
}

abstract interface class RemoteFlagCache {
  Future<CachedRemoteFlags?> load({
    required DateTime now,
    required CapabilityRevisionSet capabilities,
  });

  Future<void> save({
    required Iterable<RemoteFlagRecord> records,
    required DateTime fetchedAt,
    required DateTime expiresAt,
  });
}
