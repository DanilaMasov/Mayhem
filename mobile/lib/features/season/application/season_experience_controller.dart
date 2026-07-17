import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../domain/artifact_ownership.dart';
import '../domain/season_action_journal.dart';
import '../domain/season_experience_state.dart';
import '../domain/season_participation_repository.dart';
import 'season_participation_coordinator.dart';
import 'season_package_store.dart';

class SeasonExperienceController extends ChangeNotifier {
  SeasonExperienceController({
    required this.packages,
    required this.participation,
    required this.ownership,
    required this.actions,
    required this.joinStager,
    required this.enabled,
    required this.clock,
  });

  final SeasonPackageStore packages;
  final SeasonParticipationRepository participation;
  final ArtifactOwnershipRepository ownership;
  final SeasonActionJournal actions;
  final SeasonJoinStager joinStager;
  final bool Function() enabled;
  final DateTime Function() clock;

  SeasonExperienceState _state = SeasonExperienceState.loading();
  bool _serverConfirmed = false;
  bool _remoteLoading = false;
  bool _remoteUnavailable = false;
  bool _joinInFlight = false;
  bool _disposed = false;
  SeasonActionRecord? _latestJoin;
  Future<bool> Function()? _synchronize;

  SeasonExperienceState get state => _state;
  bool get canJoin =>
      !_disposed &&
      _synchronize != null &&
      !_joinInFlight &&
      (state.membership == SeasonMembership.notJoined ||
          state.membership == SeasonMembership.joinFailedRetryable);

  void attachRemote({required Future<bool> Function() synchronize}) {
    if (_disposed) throw StateError('Season experience is disposed');
    if (_synchronize != null) {
      throw StateError('Season remote actions are already attached');
    }
    _synchronize = synchronize;
    _notify();
  }

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

  Future<void> join() async {
    if (!canJoin) return;
    _joinInFlight = true;
    await _reload();
    try {
      final action = _latestJoin;
      if (action?.delivery == SeasonActionDelivery.pending) {
        await actions.retryNow(action!.eventId);
      } else {
        await joinStager.stageJoin();
      }
      await _synchronize!.call();
    } catch (error, stackTrace) {
      developer.log(
        'Season join submission failed; durable action remains recoverable',
        name: 'mayhem.season.join',
        error: error.runtimeType,
        stackTrace: stackTrace,
      );
    } finally {
      _joinInFlight = false;
      if (!_disposed) await _reload();
    }
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
      _notify();
      return;
    }
    try {
      final package = await packages.loadCachedPackage();
      var joined = package == null
          ? null
          : await participation.load(package.season.seasonId);
      final latestJoin = package == null
          ? null
          : await actions.latestJoin(package.season.seasonId);
      _latestJoin = latestJoin;
      var joinFailed = false;
      var conflict = false;
      if (joined != null) {
        if (latestJoin == null) {
          conflict = true;
        } else if (latestJoin.delivery == SeasonActionDelivery.rejected) {
          await participation.clear(package!.season.seasonId);
          joined = null;
          joinFailed = true;
        } else if (latestJoin.delivery == SeasonActionDelivery.pending &&
            !_joinInFlight) {
          joinFailed = true;
        }
      }
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
        operation: _joinInFlight
            ? SeasonOperation.joining
            : SeasonOperation.none,
        joinFailed: joinFailed,
        conflict: conflict,
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
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
