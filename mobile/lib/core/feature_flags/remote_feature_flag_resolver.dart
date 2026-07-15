import '../../features/sync/domain/backend_models.dart';
import 'feature_flags.dart';

abstract final class RemoteFeatureFlagResolver {
  static FeatureFlagSnapshot resolve({
    required Iterable<RemoteFlagRecord> records,
    required CapabilityRevisionSet capabilities,
  }) {
    final values = <MayhemFeatureFlag, bool>{};
    final seen = <MayhemFeatureFlag>{};
    final duplicated = <MayhemFeatureFlag>{};
    for (final record in records) {
      if (!seen.add(record.flag)) {
        duplicated.add(record.flag);
        values[record.flag] = false;
        continue;
      }
      final requirementKey = record.requiredCapabilityKey;
      final requirementRevision = record.requiredCapabilityRevision;
      final capabilitySatisfied =
          requirementKey != null &&
          requirementRevision != null &&
          capabilities.supports(requirementKey, requirementRevision);
      values[record.flag] = record.enabled && capabilitySatisfied;
    }
    for (final flag in duplicated) {
      values[flag] = false;
    }
    return FeatureFlagSnapshot(values: values);
  }
}
