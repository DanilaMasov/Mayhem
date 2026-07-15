import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../../../content/data/bundled_vnext_content_adapter.dart';
import '../../challenge/domain/challenge_attempt_repository.dart';
import '../../challenge/domain/challenge_models.dart';
import '../../reflection/domain/private_reflection.dart';
import '../../reflection/domain/reflection_repository.dart';
import '../../streak/domain/momentum_repository.dart';
import '../../streak/domain/momentum_state.dart';
import '../domain/development_rank_config.dart';
import '../domain/progress_models.dart';
import '../domain/progress_repository.dart';

class JourneyHistoryEntry {
  const JourneyHistoryEntry({
    required this.attempt,
    required this.title,
    required this.localDate,
    this.reflection,
  });

  final ChallengeAttempt attempt;
  final String title;
  final String localDate;
  final PrivateReflection? reflection;
}

class JourneySnapshot {
  JourneySnapshot({
    required this.projection,
    required this.momentum,
    required List<JourneyHistoryEntry> history,
  }) : history = List.unmodifiable(history);

  final ProgressProjection projection;
  final MomentumState momentum;
  final List<JourneyHistoryEntry> history;

  Set<String> get earnedLocalDates => history
      .where((entry) => entry.attempt.result != null)
      .map((entry) => entry.localDate)
      .toSet();
}

class JourneyController extends ChangeNotifier {
  JourneyController({
    required this.progress,
    required this.momentum,
    required this.attempts,
    required this.reflections,
    required this.bundled,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final ProgressRepository progress;
  final MomentumRepository momentum;
  final ChallengeAttemptRepository attempts;
  final ReflectionRepository reflections;
  final BundledVNextContent bundled;
  final DateTime Function() _clock;

  JourneySnapshot? _snapshot;
  bool _loading = true;
  String? _error;

  JourneySnapshot? get snapshot => _snapshot;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> initialize() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final momentumState = await momentum.loadMomentum();
      final projection = await progress.loadProjection();
      final normalized = _normalizeProjection(
        projection ?? _emptyProjection(momentumState),
        momentumState,
      );
      if (projection == null ||
          projection.rank.configRevision != DevelopmentRankConfig.revision ||
          projection.momentum != momentumState) {
        await progress.saveProjection(normalized);
      }
      final attemptHistory = await attempts.history(limit: 500);
      final entries = <JourneyHistoryEntry>[];
      for (final attempt in attemptHistory.where(
        (item) => item.result != null,
      )) {
        final reflection = await reflections.findForAttempt(attempt.attemptId);
        final resolvedAt = attempt.resolvedAt?.toUtc();
        entries.add(
          JourneyHistoryEntry(
            attempt: attempt,
            title:
                bundled.challenges[attempt.contentId]?.title ??
                attempt.contentId,
            localDate:
                attempt.result?.effectiveLocalDate ??
                _dateKey(resolvedAt ?? attempt.acceptedAt.toUtc()),
            reflection: reflection,
          ),
        );
      }
      _snapshot = JourneySnapshot(
        projection: normalized,
        momentum: momentumState,
        history: entries,
      );
      developer.log(
        'Journey ready with ${entries.length} history entries',
        name: 'mayhem.journey',
      );
    } catch (error, stackTrace) {
      _error = 'journey_load_failed';
      developer.log(
        'Failed to build Journey projection',
        name: 'mayhem.journey',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  ProgressProjection _normalizeProjection(
    ProgressProjection current,
    MomentumState momentumState,
  ) {
    final rank = DevelopmentRankConfig.policy().resolve(
      totalXp: current.totalXp,
      traitXp: current.traitXp,
    );
    return ProgressProjection(
      totalXp: current.totalXp,
      traitXp: current.traitXp,
      rank: rank.rank,
      rankProgress: rank.progressToNext,
      momentum: momentumState,
      difficulty: current.difficulty,
      completedCount: current.completedCount,
      attemptedCount: current.attemptedCount,
      updatedAt: current.updatedAt,
      source: current.source,
    );
  }

  ProgressProjection _emptyProjection(MomentumState momentumState) {
    final now = _clock().toUtc();
    final traitXp = {for (final trait in Trait.values) trait: 0};
    final rank = DevelopmentRankConfig.policy().resolve(
      totalXp: 0,
      traitXp: traitXp,
    );
    return ProgressProjection(
      totalXp: 0,
      traitXp: traitXp,
      rank: rank.rank,
      rankProgress: rank.progressToNext,
      momentum: momentumState,
      difficulty: {
        for (final trait in Trait.values)
          trait: DifficultyState(
            trait: trait,
            rating: 2,
            confidence: 0,
            observations: 0,
            recommendedIntensity: 2,
            updatedAt: now,
          ),
      },
      completedCount: 0,
      attemptedCount: 0,
      updatedAt: now,
      source: ProjectionSource.localCheckpoint,
    );
  }

  static String _dateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
