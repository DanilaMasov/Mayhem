import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../domain/artifact_ownership.dart';
import '../domain/season_experience_state.dart';
import '../domain/season_participation_repository.dart';
import 'season_package_store.dart';

class SeasonExperienceController extends ChangeNotifier {
  SeasonExperienceController({
    required this.packages,
    required this.participation,
    required this.ownership,
    required this.enabled,
    required this.clock,
  });

  final SeasonPackageStore packages;
  final SeasonParticipationRepository participation;
  final ArtifactOwnershipRepository ownership;
  final bool Function() enabled;
  final DateTime Function() clock;

  SeasonExperienceState _state = SeasonExperienceState.loading();
  bool _serverConfirmed = false;
  bool _remoteLoading = false;
  bool _remoteUnavailable = false;

  SeasonExperienceState get state => _state;

  Future<void> initialize() => _reload();

  Future<void> beginRemoteRefresh() async {
    _remoteLoading = true;
    _remoteUnavailable = false;
    await _reload();
  }

  Future<void> completeRemoteRefresh({required bool succeeded}) async {
    _remoteLoading = false;
    _serverConfirmed = succeeded;
    _remoteUnavailable = !succeeded;
    await _reload();
  }

  Future<void> _reload() async {
    if (!enabled()) {
      _state = SeasonExperienceState.resolve(
        enabled: false,
        now: clock(),
        package: null,
        participation: null,
        ownedArtifacts: const [],
        freshness: SeasonDataFreshness.none,
      );
      notifyListeners();
      return;
    }
    try {
      final package = await packages.loadCachedPackage();
      final joined = package == null
          ? null
          : await participation.load(package.season.seasonId);
      final artifacts = package == null
          ? const <OwnedFounderArtifact>[]
          : await ownership.loadOwnedArtifacts();
      _state = SeasonExperienceState.resolve(
        enabled: true,
        now: clock(),
        package: package,
        participation: joined,
        ownedArtifacts: artifacts,
        freshness: _serverConfirmed
            ? SeasonDataFreshness.serverConfirmed
            : package == null
            ? SeasonDataFreshness.none
            : SeasonDataFreshness.cached,
        remoteLoading: _remoteLoading,
        remoteUnavailable: _remoteUnavailable,
      );
    } catch (error, stackTrace) {
      _state = SeasonExperienceState.resolve(
        enabled: true,
        now: clock(),
        package: null,
        participation: null,
        ownedArtifacts: const [],
        freshness: SeasonDataFreshness.none,
        errorCode: 'season_state_load_failed',
      );
      developer.log(
        'Season experience state failed closed',
        name: 'mayhem.season.experience',
        error: error.runtimeType,
        stackTrace: stackTrace,
      );
    }
    notifyListeners();
  }
}
