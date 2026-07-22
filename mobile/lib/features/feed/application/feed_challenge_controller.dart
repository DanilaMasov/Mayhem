import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../../../core/clock/mayhem_clock.dart';
import '../../challenge/application/challenge_flow_coordinator.dart';
import '../../challenge/domain/challenge_models.dart';
import '../../progress/domain/progress_models.dart';
import 'feed_session_coordinator.dart';

class FeedRewardPresentation {
  const FeedRewardPresentation({
    required this.attemptId,
    required this.outcome,
    required this.xp,
    required this.trait,
    required this.momentumDays,
  });

  final String attemptId;
  final AttemptOutcome outcome;
  final int xp;
  final Trait trait;
  final int momentumDays;
}

class FeedChallengeController extends ChangeNotifier {
  FeedChallengeController({
    required this.flow,
    required this.clock,
    required this.onActiveChanged,
    required this.onProjectionChanged,
    this.timezoneOffsetMinutes,
  });

  final ChallengeFlowCoordinator flow;
  final MayhemClock clock;
  final void Function(
    ChallengeAttempt? attempt,
    ChallengeDefinition? definition,
  )
  onActiveChanged;
  final Future<void> Function() onProjectionChanged;
  final int Function()? timezoneOffsetMinutes;

  ChallengeAttempt? _activeAttempt;
  ChallengeDefinition? _activeDefinition;
  FeedRewardPresentation? _reward;
  bool _busy = false;
  String? _error;
  int _operationRevision = 0;

  ChallengeAttempt? get activeAttempt => _activeAttempt;
  ChallengeDefinition? get activeDefinition => _activeDefinition;
  FeedRewardPresentation? get reward => _reward;
  bool get busy => _busy;
  String? get error => _error;
  int get operationRevision => _operationRevision;

  bool get hasActiveChallenge => _activeAttempt != null;

  void initialize(FeedSessionSnapshot snapshot) {
    _activeAttempt = snapshot.activeAttempt;
    _activeDefinition = snapshot.activeChallenge;
    _reward = null;
    _error = snapshot.activeAttempt != null && snapshot.activeChallenge == null
        ? 'active_challenge_content_unavailable'
        : null;
    notifyListeners();
  }

  Future<bool> accept({
    required FeedSessionItem item,
    required ChallengeRouteType route,
  }) async {
    if (_busy) return false;
    if (hasActiveChallenge) {
      _error = 'active_challenge_exists';
      notifyListeners();
      return false;
    }
    final definition = item.challenge;
    if (definition == null || !definition.supportsRoute(route)) {
      _error = 'challenge_route_unavailable';
      notifyListeners();
      return false;
    }
    _beginOperation();
    try {
      final acceptedAt = clock.utcNow();
      final acceptance = await flow.accept(
        assignment: item.assignment,
        definition: definition,
        route: route,
        acceptedAt: acceptedAt,
        timezoneId: clock.timezoneId,
        timezoneOffsetMinutes: _offsetMinutes(),
      );
      _activeAttempt = acceptance.attempt;
      _activeDefinition = definition;
      onActiveChanged(_activeAttempt, _activeDefinition);
      return true;
    } catch (error, stackTrace) {
      _recordFailure('accept', error, stackTrace);
      return false;
    } finally {
      _finishOperation();
    }
  }

  Future<bool> resolve({
    required AttemptOutcome outcome,
    required FeltComparedToExpected felt,
    ReflectionInput reflection = const ReflectionInput(),
  }) async {
    if (_busy) return false;
    final attempt = _activeAttempt;
    final definition = _activeDefinition;
    if (attempt == null || definition == null) {
      _error = 'active_challenge_unavailable';
      notifyListeners();
      return false;
    }
    _beginOperation();
    try {
      final localNow = clock.localNow();
      final resolution = await flow.resolve(
        attemptId: attempt.attemptId,
        definition: definition,
        outcome: outcome,
        felt: felt,
        resolvedAt: clock.utcNow(),
        localDate: _localDate(localNow),
        timezoneOffsetMinutes: _offsetMinutes(localNow),
        reflection: reflection,
      );
      final committed =
          resolution.applied ||
          resolution.attempt.isTerminal &&
              resolution.attempt.rewardAppliedLocally;
      if (!committed) return false;
      _activeAttempt = null;
      _activeDefinition = null;
      onActiveChanged(null, null);
      final earnedXp =
          resolution.reward?.xp ?? resolution.attempt.result?.earnedXp;
      if (earnedXp != null) {
        _reward = FeedRewardPresentation(
          attemptId: resolution.attempt.attemptId,
          outcome: resolution.attempt.result?.outcome ?? outcome,
          xp: earnedXp,
          trait: definition.primaryTrait,
          momentumDays: resolution.momentum.currentDays,
        );
      }
      await _refreshProjectionSafely();
      return true;
    } catch (error, stackTrace) {
      _recordFailure('resolve', error, stackTrace);
      return false;
    } finally {
      _finishOperation();
    }
  }

  void dismissReward() {
    if (_reward == null) return;
    _reward = null;
    notifyListeners();
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  void _beginOperation() {
    _busy = true;
    _error = null;
    notifyListeners();
  }

  void _finishOperation() {
    _busy = false;
    _operationRevision += 1;
    notifyListeners();
  }

  void _recordFailure(String operation, Object error, StackTrace stackTrace) {
    _error = 'challenge_action_failed';
    developer.log(
      'Local challenge $operation failed',
      name: 'mayhem.feed.action',
      error: error.runtimeType,
      stackTrace: stackTrace,
    );
  }

  Future<void> _refreshProjectionSafely() async {
    try {
      await onProjectionChanged();
    } catch (error, stackTrace) {
      developer.log(
        'Challenge committed but local projection refresh failed',
        name: 'mayhem.feed.action',
        error: error.runtimeType,
        stackTrace: stackTrace,
      );
    }
  }

  int _offsetMinutes([DateTime? localNow]) =>
      timezoneOffsetMinutes?.call() ??
      (localNow ?? clock.localNow()).timeZoneOffset.inMinutes;

  String _localDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
