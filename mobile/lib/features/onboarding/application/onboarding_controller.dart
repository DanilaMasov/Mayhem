import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../../progress/domain/development_rank_config.dart';
import '../../progress/domain/progress_models.dart';
import '../../progress/domain/progress_repository.dart';
import '../../streak/domain/momentum_state.dart';
import '../domain/onboarding_models.dart';
import '../domain/onboarding_repository.dart';

class OnboardingController extends ChangeNotifier {
  OnboardingController({
    required this.repository,
    required this.progressRepository,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final OnboardingRepository repository;
  final ProgressRepository progressRepository;
  final DateTime Function() _clock;

  OnboardingProgress _progress = OnboardingProgress.fresh();
  bool _loading = true;
  String? _error;

  OnboardingProgress get progress => _progress;
  bool get loading => _loading;
  String? get error => _error;

  Map<Trait, int> get initialSignals => {
    for (final trait in CalibrationPolicy.traitOrder)
      trait: CalibrationPolicy.signalFor(
        _progress.answerIndexByTrait[trait] ?? 2,
      ),
  };

  Future<void> initialize({
    required bool legacyUserHasProgress,
    required bool legacySafetyAccepted,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final stored = await repository.load();
      if (stored != null) {
        _progress = stored;
      } else if (legacyUserHasProgress) {
        _progress = OnboardingProgress.migrated(
          safetyAccepted: legacySafetyAccepted,
        );
        await repository.save(_progress);
      } else {
        _progress = OnboardingProgress.fresh();
        await repository.save(_progress);
      }
      developer.log(
        'Onboarding restored at ${_progress.stage.name}',
        name: 'mayhem.onboarding',
      );
    } catch (error, stackTrace) {
      _error = 'onboarding_load_failed';
      developer.log(
        'Failed to restore onboarding',
        name: 'mayhem.onboarding',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> begin() => _save(
    _progress.copyWith(stage: OnboardingStage.calibration),
    logMessage: 'Opening completed',
  );

  Future<void> answer(Trait trait, int answerIndex) async {
    if (_progress.stage != OnboardingStage.calibration ||
        !CalibrationPolicy.traitOrder.contains(trait)) {
      throw StateError('Calibration answer is not expected');
    }
    CalibrationPolicy.ratingFor(answerIndex);
    final answers = Map<Trait, int>.from(_progress.answerIndexByTrait)
      ..[trait] = answerIndex;
    final complete = CalibrationPolicy.traitOrder.every(answers.containsKey);
    await _save(
      _progress.copyWith(
        stage: complete ? OnboardingStage.safety : OnboardingStage.calibration,
        answerIndexByTrait: answers,
      ),
      logMessage: 'Calibration answer saved for ${trait.name}',
    );
  }

  Future<bool> acceptSafety() async {
    if (_progress.stage != OnboardingStage.safety) {
      throw StateError('Safety acceptance is not expected');
    }
    final safetyOnly =
        _progress.migratedFromLegacy &&
        _progress.answerIndexByTrait.length <
            CalibrationPolicy.traitOrder.length;
    await _save(
      _progress.copyWith(
        stage: safetyOnly
            ? OnboardingStage.completed
            : OnboardingStage.profileReveal,
        acceptedSafetyRevision: CalibrationPolicy.safetyRevision,
      ),
      logMessage: 'Safety revision accepted',
    );
    return safetyOnly;
  }

  Future<void> completeProfileReveal() async {
    if (_progress.stage != OnboardingStage.profileReveal) {
      throw StateError('Profile reveal is not active');
    }
    await _seedInitialProjectionIfNeeded();
    await _save(
      _progress.copyWith(stage: OnboardingStage.completed),
      logMessage: 'Onboarding completed',
    );
  }

  Future<void> _seedInitialProjectionIfNeeded() async {
    if (await progressRepository.loadProjection() != null) return;
    final now = _clock().toUtc();
    final traitXp = {for (final trait in Trait.values) trait: 0};
    final rank = DevelopmentRankConfig.policy().resolve(
      ratingScore: DevelopmentRankConfig.startingRating,
      traitXp: traitXp,
    );
    await progressRepository.saveProjection(
      ProgressProjection(
        totalXp: 0,
        ratingScore: DevelopmentRankConfig.startingRating,
        peakRatingScore: DevelopmentRankConfig.startingRating,
        traitXp: traitXp,
        rank: rank.rank,
        rankProgress: rank.progressToNext,
        momentum: MomentumState.empty(),
        difficulty: CalibrationPolicy.difficulty(
          _progress.answerIndexByTrait,
          now,
        ),
        completedCount: 0,
        attemptedCount: 0,
        updatedAt: now,
        source: ProjectionSource.localCheckpoint,
      ),
    );
  }

  Future<void> _save(
    OnboardingProgress next, {
    required String logMessage,
  }) async {
    await repository.save(next);
    _progress = next;
    _error = null;
    developer.log(logMessage, name: 'mayhem.onboarding');
    notifyListeners();
  }
}
