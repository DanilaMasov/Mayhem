import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../../../content/data/bundled_vnext_content_adapter.dart';
import '../../../core/clock/mayhem_clock.dart';
import '../../../core/metadata/local_metadata_repository.dart';
import '../../challenge/domain/challenge_models.dart';
import '../domain/feed_models.dart';
import 'feed_interaction_coordinator.dart';
import 'feed_session_coordinator.dart';

class FeedViewController extends ChangeNotifier {
  FeedViewController({
    required this.coordinator,
    required this.bundled,
    required this.metadata,
    required this.interactions,
    required this.interactionClock,
    this.timezoneOffsetMinutes,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  static const currentAssignmentKey = 'feed_current_assignment_v1';

  final FeedSessionCoordinator coordinator;
  final BundledVNextContent bundled;
  final LocalMetadataRepository metadata;
  final FeedInteractionCoordinator interactions;
  final MayhemClock interactionClock;
  final int Function()? timezoneOffsetMinutes;
  final DateTime Function() _clock;

  FeedSessionSnapshot? _snapshot;
  bool _loading = true;
  String? _error;
  String? _interactionError;
  int _currentIndex = 0;

  FeedSessionSnapshot? get snapshot => _snapshot;
  bool get loading => _loading;
  String? get error => _error;
  String? get interactionError => _interactionError;
  int get currentIndex => _currentIndex;

  Future<void> initialize() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final snapshot = await coordinator.initialize(
        bundled: bundled,
        nowUtc: _clock().toUtc(),
      );
      final restoredAssignmentId = await metadata.read(currentAssignmentKey);
      final restoredIndex = restoredAssignmentId == null
          ? -1
          : snapshot.items.indexWhere(
              (item) => item.assignment.assignmentId == restoredAssignmentId,
            );
      _snapshot = snapshot;
      _currentIndex = restoredIndex >= 0 ? restoredIndex : 0;
      await _persistCurrentAssignment();
      developer.log(
        'Feed ready with ${snapshot.items.length} items at index $_currentIndex',
        name: 'mayhem.feed',
      );
    } catch (error, stackTrace) {
      _error = 'feed_load_failed';
      developer.log(
        'Failed to initialize local Feed',
        name: 'mayhem.feed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> setCurrentIndex(int index) async {
    final items = _snapshot?.items;
    if (items == null || index < 0 || index >= items.length) return;
    _currentIndex = index;
    notifyListeners();
    await _persistCurrentAssignment();
  }

  Future<bool> impress(int index) => _runInteraction(
    operation: 'impress',
    index: index,
    commit: (assignment, now) => interactions.impress(
      assignment: assignment,
      atUtc: now,
      timezoneId: interactionClock.timezoneId,
      timezoneOffsetMinutes: _offsetMinutes(),
    ),
  );

  Future<bool> open(int index) async {
    if (!await impress(index)) return false;
    return _runInteraction(
      operation: 'open',
      index: index,
      commit: (assignment, now) => interactions.open(
        assignment: assignment,
        atUtc: now,
        timezoneId: interactionClock.timezoneId,
        timezoneOffsetMinutes: _offsetMinutes(),
      ),
    );
  }

  Future<bool> skip(int index, FeedSkipReason reason) async {
    if (!await impress(index)) return false;
    return _runInteraction(
      operation: 'skip',
      index: index,
      commit: (assignment, now) => interactions.skip(
        assignment: assignment,
        reason: reason,
        atUtc: now,
        timezoneId: interactionClock.timezoneId,
        timezoneOffsetMinutes: _offsetMinutes(),
      ),
    );
  }

  void clearInteractionError() {
    if (_interactionError == null) return;
    _interactionError = null;
    notifyListeners();
  }

  void setActiveChallenge(
    ChallengeAttempt? attempt,
    ChallengeDefinition? definition,
  ) {
    final current = _snapshot;
    if (current == null) return;
    _snapshot = FeedSessionSnapshot(
      batch: current.batch,
      items: current.items,
      generatedLocally: current.generatedLocally,
      activeAttempt: attempt,
      activeChallenge: definition,
    );
    notifyListeners();
  }

  Future<void> _persistCurrentAssignment() async {
    final items = _snapshot?.items;
    if (items == null || items.isEmpty) return;
    await metadata.write(
      currentAssignmentKey,
      items[_currentIndex].assignment.assignmentId,
    );
  }

  Future<bool> _runInteraction({
    required String operation,
    required int index,
    required Future<bool> Function(FeedAssignment assignment, DateTime nowUtc)
    commit,
  }) async {
    final items = _snapshot?.items;
    if (items == null || index < 0 || index >= items.length) return false;
    try {
      await commit(items[index].assignment, interactionClock.utcNow());
      if (_interactionError != null) {
        _interactionError = null;
        notifyListeners();
      }
      return true;
    } catch (error, stackTrace) {
      _interactionError = 'feed_interaction_failed';
      developer.log(
        'Feed $operation commit failed',
        name: 'mayhem.feed.interaction',
        error: error.runtimeType,
        stackTrace: stackTrace,
      );
      notifyListeners();
      return false;
    }
  }

  int _offsetMinutes() =>
      timezoneOffsetMinutes?.call() ??
      interactionClock.localNow().timeZoneOffset.inMinutes;
}
