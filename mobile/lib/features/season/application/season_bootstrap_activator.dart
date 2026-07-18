import '../../../core/feature_flags/feature_flags.dart';
import '../data/remote_season_package_mapper.dart';
import '../domain/season_action_journal.dart';
import '../domain/season_participation_repository.dart';
import '../domain/season_participation_state.dart';
import '../../sync/domain/backend_models.dart';
import 'season_package_store.dart';

enum SeasonActivationStatus { disabled, noActiveSeason, activated }

enum SeasonActivationFailure { incompatiblePackage, recoverable }

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
    required this.participation,
    required this.actions,
  });

  final bool localActivationEnabled;
  final SeasonPackageStore store;
  final SeasonParticipationRepository participation;
  final SeasonActionJournal actions;

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
    final package = RemoteSeasonPackageMapper.fromSnapshot(sanitized);
    final reconciled = await _reconcileParticipation(
      sanitized,
      package.boss.bossEventId,
    );
    await participation.replaceAuthoritative(sanitized.seasonId, reconciled);
    await store.saveValidatedSnapshot(sanitized);
    return SeasonActivationStatus.activated;
  }

  Future<SeasonParticipationState?> _reconcileParticipation(
    RemoteSeasonSnapshot snapshot,
    String bossEventId,
  ) async {
    final remote = snapshot.participation;
    final authoritative = remote == null
        ? null
        : SeasonParticipationState(
            seasonId: remote.seasonId,
            seasonRevision: remote.seasonRevision,
            joinedAt: remote.joinedAt,
            completedDays: remote.completedDays,
            bossParticipatedAt: remote.bossParticipatedAt,
            serverConfirmed: true,
          );
    final local = await participation.load(snapshot.seasonId);
    final sameRevision = local?.seasonRevision == snapshot.revision;
    final latestJoin = await actions.latestJoin(snapshot.seasonId);
    final latestDays = await actions.latestDays(snapshot.seasonId);
    final latestBoss = await actions.latestBoss(snapshot.seasonId, bossEventId);
    final pendingJoin = _pendingForRevision(latestJoin, snapshot.revision);
    final pendingDays = latestDays.values
        .where((action) => _pendingForRevision(action, snapshot.revision))
        .map((action) => action.day!)
        .toSet();
    final pendingBoss = _pendingForRevision(latestBoss, snapshot.revision);

    if (authoritative == null) {
      if (!sameRevision ||
          local == null ||
          (!pendingJoin && pendingDays.isEmpty && !pendingBoss)) {
        return null;
      }
      return local.copyWith(serverConfirmed: false);
    }
    if (!sameRevision || local == null) return authoritative;
    return authoritative.copyWith(
      completedDays: {
        ...authoritative.completedDays,
        for (final day in pendingDays)
          if (local.completedDays.contains(day)) day,
      },
      bossParticipatedAt: pendingBoss
          ? local.bossParticipatedAt
          : authoritative.bossParticipatedAt,
    );
  }

  bool _pendingForRevision(SeasonActionRecord? action, int revision) =>
      action?.seasonRevision == revision &&
      action?.delivery == SeasonActionDelivery.pending;

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
      participation: snapshot.participation,
    );
  }
}
