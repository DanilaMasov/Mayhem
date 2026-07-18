import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../../challenge/domain/challenge_models.dart';
import '../domain/artifact_ownership.dart';
import '../domain/season_action_journal.dart';
import '../domain/season_experience_state.dart';
import '../domain/season_participation_repository.dart';
import 'season_bootstrap_activator.dart';
import 'season_participation_coordinator.dart';
import 'season_package_store.dart';

class SeasonExperienceController extends ChangeNotifier {
  SeasonExperienceController({
    required this.packages,
    required this.participation,
    required this.ownership,
    required this.actions,
    required this.actionStager,
    required this.enabled,
    required this.clock,
  });

  final SeasonPackageStore packages;
  final SeasonParticipationRepository participation;
  final ArtifactOwnershipRepository ownership;
  final SeasonActionJournal actions;
  final SeasonActionStager actionStager;
  final bool Function() enabled;
  final DateTime Function() clock;

  SeasonExperienceState _state = SeasonExperienceState.loading();
  bool _serverConfirmed = false;
  bool _remoteLoading = false;
  bool _remoteUnavailable = false;
  bool _incompatiblePackage = false;
  String? _remoteErrorCode;
  bool _joinInFlight = false;
  bool _dayInFlight = false;
  bool _bossInFlight = false;
  bool _disposed = false;
  SeasonActionRecord? _latestJoin;
  SeasonActionRecord? _latestDay;
  SeasonActionRecord? _latestBoss;
  Future<bool> Function()? _synchronize;

  SeasonExperienceState get state => _state;
  bool get _actionInFlight => _joinInFlight || _dayInFlight || _bossInFlight;
  bool get canRetryRemote =>
      !_disposed && _synchronize != null && !_actionInFlight && !_remoteLoading;
  bool get canJoin =>
      !_disposed &&
      _synchronize != null &&
      !_actionInFlight &&
      _stateAllowsMutation &&
      (state.membership == SeasonMembership.notJoined ||
          state.membership == SeasonMembership.joinFailedRetryable);
  bool get canCompleteDay =>
      !_disposed &&
      _synchronize != null &&
      !_actionInFlight &&
      _stateAllowsMutation &&
      (state.dayPhase == SeasonDayPhase.available ||
          state.dayPhase == SeasonDayPhase.failedRetryable);
  bool get canParticipateBoss =>
      !_disposed &&
      _synchronize != null &&
      !_actionInFlight &&
      _stateAllowsMutation &&
      (state.bossPhase == SeasonBossPhase.open ||
          state.bossPhase == SeasonBossPhase.failedRetryable);
  bool get retriesPendingBoss =>
      _latestBoss?.delivery == SeasonActionDelivery.pending;
  bool get _stateAllowsMutation =>
      !_remoteLoading &&
      (state.availability == SeasonAvailability.ready ||
          state.availability == SeasonAvailability.offlineCached);

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
    _incompatiblePackage = false;
    _remoteErrorCode = null;
    await _reload();
  }

  Future<void> completeRemoteRefresh({required bool succeeded}) async {
    _remoteLoading = false;
    _serverConfirmed =
        succeeded && !_incompatiblePackage && _remoteErrorCode == null;
    _remoteUnavailable = !succeeded;
    await _reload();
  }

  Future<void> markRemoteStateCommitted() async {
    _incompatiblePackage = false;
    _remoteErrorCode = null;
    await _reload();
  }

  Future<void> markRemoteActivationFailure(
    SeasonActivationFailure failure,
  ) async {
    _serverConfirmed = false;
    _remoteUnavailable = false;
    _incompatiblePackage =
        failure == SeasonActivationFailure.incompatiblePackage;
    _remoteErrorCode = failure == SeasonActivationFailure.recoverable
        ? 'season_activation_failed'
        : null;
    await _reload();
  }

  Future<void> retryRemote() async {
    if (!canRetryRemote) return;
    await beginRemoteRefresh();
    var succeeded = false;
    try {
      succeeded = await _synchronize!.call();
    } catch (error, stackTrace) {
      developer.log(
        'Season remote retry failed; cached state remains available',
        name: 'mayhem.season.retry',
        error: error.runtimeType,
        stackTrace: stackTrace,
      );
    } finally {
      if (!_disposed) {
        await completeRemoteRefresh(succeeded: succeeded);
      }
    }
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
        await actionStager.stageJoin();
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

  Future<void> completeDay() async {
    if (!canCompleteDay) return;
    _dayInFlight = true;
    await _reload();
    try {
      final action = _latestDay;
      if (action?.delivery == SeasonActionDelivery.pending) {
        await actions.retryNow(action!.eventId);
      } else {
        final day = action?.delivery == SeasonActionDelivery.rejected
            ? action?.day
            : state.currentDay;
        if (day == null) throw StateError('No available Season day');
        await actionStager.stageDay(day);
      }
      await _synchronize!.call();
    } catch (error, stackTrace) {
      developer.log(
        'Season day submission failed; durable action remains recoverable',
        name: 'mayhem.season.day',
        error: error.runtimeType,
        stackTrace: stackTrace,
      );
    } finally {
      _dayInFlight = false;
      if (!_disposed) await _reload();
    }
  }

  Future<void> participateBoss(ChallengeRouteType route) async {
    if (!canParticipateBoss) return;
    _bossInFlight = true;
    await _reload();
    try {
      final action = _latestBoss;
      if (action?.delivery == SeasonActionDelivery.pending) {
        await actions.retryNow(action!.eventId);
      } else {
        await actionStager.stageBoss(route);
      }
      await _synchronize!.call();
    } catch (error, stackTrace) {
      developer.log(
        'Season Boss submission failed; durable action remains recoverable',
        name: 'mayhem.season.boss',
        error: error.runtimeType,
        stackTrace: stackTrace,
      );
    } finally {
      _bossInFlight = false;
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
      final latestDays = package == null
          ? const <int, SeasonActionRecord>{}
          : await actions.latestDays(package.season.seasonId);
      final latestBoss = package == null
          ? null
          : await actions.latestBoss(
              package.season.seasonId,
              package.boss.bossEventId,
            );
      _latestJoin = latestJoin;
      _latestDay = _recoverableDay(latestDays);
      _latestBoss = latestBoss;
      var joinFailed = false;
      var dayFailed = false;
      var bossFailed = false;
      var conflict = false;
      if (joined != null) {
        if (latestJoin == null && !joined.serverConfirmed) {
          conflict = true;
        } else if (!joined.serverConfirmed &&
            latestJoin?.delivery == SeasonActionDelivery.rejected) {
          await participation.clear(package!.season.seasonId);
          joined = null;
          joinFailed = true;
        } else if (!joined.serverConfirmed &&
            latestJoin?.delivery == SeasonActionDelivery.pending &&
            !_joinInFlight) {
          joinFailed = true;
        }
      }
      final latestDay = _latestDay;
      if (joined != null && latestDay != null) {
        if (latestDay.delivery == SeasonActionDelivery.rejected) {
          await participation.revertDay(
            package!.season.seasonId,
            latestDay.day!,
          );
          joined = await participation.load(package.season.seasonId);
          dayFailed = true;
        } else if (latestDay.delivery == SeasonActionDelivery.pending &&
            !_dayInFlight) {
          dayFailed = true;
        }
      }
      if (joined != null && latestBoss != null) {
        if (latestBoss.delivery == SeasonActionDelivery.rejected) {
          await participation.revertBoss(package!.season.seasonId);
          joined = await participation.load(package.season.seasonId);
          bossFailed = true;
        } else if (latestBoss.delivery == SeasonActionDelivery.pending &&
            !_bossInFlight) {
          bossFailed = true;
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
            : _dayInFlight
            ? SeasonOperation.dayInProgress
            : _bossInFlight
            ? SeasonOperation.bossSubmitting
            : SeasonOperation.none,
        joinFailed: joinFailed,
        dayFailed: dayFailed,
        bossFailed: bossFailed,
        conflict: conflict,
        incompatiblePackage: _incompatiblePackage,
        errorCode: _remoteErrorCode,
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

  SeasonActionRecord? _recoverableDay(Map<int, SeasonActionRecord> latest) {
    for (final action in latest.values) {
      if (action.delivery == SeasonActionDelivery.pending ||
          action.delivery == SeasonActionDelivery.rejected) {
        return action;
      }
    }
    return null;
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
