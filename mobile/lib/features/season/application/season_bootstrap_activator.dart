import '../../../core/feature_flags/feature_flags.dart';
import '../../sync/domain/backend_models.dart';
import 'season_package_store.dart';

enum SeasonActivationStatus { disabled, noActiveSeason, activated }

abstract interface class SeasonBootstrapActivation {
  Future<SeasonActivationStatus> apply({
    required RemoteSeasonSnapshot? snapshot,
    required FeatureFlagSnapshot flags,
  });
}

class SeasonBootstrapActivator implements SeasonBootstrapActivation {
  const SeasonBootstrapActivator({
    required this.localActivationEnabled,
    required this.store,
  });

  final bool localActivationEnabled;
  final SeasonPackageStore store;

  @override
  Future<SeasonActivationStatus> apply({
    required RemoteSeasonSnapshot? snapshot,
    required FeatureFlagSnapshot flags,
  }) async {
    final productEnabled =
        localActivationEnabled &&
        flags.isEnabled(MayhemFeatureFlag.seasonZeroEnabled) &&
        flags.isEnabled(MayhemFeatureFlag.bossRaidEnabled);
    if (!productEnabled) {
      await store.clear();
      return SeasonActivationStatus.disabled;
    }
    if (snapshot == null) {
      await store.clear();
      return SeasonActivationStatus.noActiveSeason;
    }
    final sanitized = flags.isEnabled(MayhemFeatureFlag.socialProofEnabled)
        ? snapshot
        : _withoutSocialProof(snapshot);
    await store.saveValidatedSnapshot(sanitized);
    return SeasonActivationStatus.activated;
  }

  RemoteSeasonSnapshot _withoutSocialProof(RemoteSeasonSnapshot snapshot) {
    final payload = Map<String, dynamic>.from(snapshot.payload)
      ..remove('socialProof');
    return RemoteSeasonSnapshot(
      seasonId: snapshot.seasonId,
      revision: snapshot.revision,
      title: snapshot.title,
      startsAt: snapshot.startsAt,
      endsAt: snapshot.endsAt,
      payload: payload,
    );
  }
}
