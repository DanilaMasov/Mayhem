import '../../../core/sync/event_envelope_v2.dart';
import '../../feed/domain/feed_models.dart';
import '../../progress/domain/difficulty_update_policy.dart';
import '../../progress/domain/progress_models.dart';
import '../../progress/domain/progress_repository.dart';
import '../../progress/domain/rank_policy.dart';
import '../../reflection/domain/private_reflection.dart';
import '../../streak/domain/momentum_policy.dart';
import '../../streak/domain/momentum_repository.dart';
import '../../streak/domain/momentum_state.dart';
import '../domain/challenge_attempt_repository.dart';
import '../domain/challenge_models.dart';
import '../domain/challenge_transition_service.dart';
import '../domain/local_challenge_commit_repository.dart';
import '../domain/reward_policy.dart';

class ChallengeAcceptance {
  const ChallengeAcceptance({required this.attempt, required this.applied});

  final ChallengeAttempt attempt;
  final bool applied;
}

class ChallengeResolution {
  const ChallengeResolution({
    required this.attempt,
    required this.projection,
    required this.momentum,
    required this.applied,
    this.reward,
  });

  final ChallengeAttempt attempt;
  final ProgressProjection projection;
  final MomentumState momentum;
  final ChallengeReward? reward;
  final bool applied;
}

class ReflectionInput {
  const ReflectionInput({
    this.fearBefore,
    this.feelAfter,
    this.wantRepeat,
    this.privateNote,
  });

  final int? fearBefore;
  final int? feelAfter;
  final bool? wantRepeat;
  final String? privateNote;

  bool get hasValue =>
      fearBefore != null ||
      feelAfter != null ||
      wantRepeat != null ||
      privateNote?.trim().isNotEmpty == true;
}

/// Coordinates the local vertical slice without depending on Flutter state.
class ChallengeFlowCoordinator {
  const ChallengeFlowCoordinator({
    required this.attempts,
    required this.progress,
    required this.momentum,
    required this.commits,
    required this.rewardPolicy,
    required this.rankPolicy,
    required this.idGenerator,
    this.transitions = const ChallengeTransitionService(),
    this.momentumPolicy = const MomentumPolicy(),
    this.difficultyPolicy = const DifficultyUpdatePolicy(),
  });

  final ChallengeAttemptRepository attempts;
  final ProgressRepository progress;
  final MomentumRepository momentum;
  final LocalChallengeCommitRepository commits;
  final RewardPolicy rewardPolicy;
  final RankPolicy rankPolicy;
  final String Function() idGenerator;
  final ChallengeTransitionService transitions;
  final MomentumPolicy momentumPolicy;
  final DifficultyUpdatePolicy difficultyPolicy;

  Future<ChallengeAttempt?> restoreActiveAttempt() => attempts.activeAttempt();

  Future<ChallengeAcceptance> accept({
    required FeedAssignment assignment,
    required ChallengeDefinition definition,
    required ChallengeRouteType route,
    required DateTime acceptedAt,
    required String timezoneId,
    required int timezoneOffsetMinutes,
  }) async {
    final attempt = transitions.accept(
      assignment: assignment,
      definition: definition,
      route: route,
      attemptId: idGenerator(),
      acceptedAt: acceptedAt,
      timezoneId: timezoneId,
    );
    final applied = await commits.commitAccepted(
      attempt: attempt,
      event: _event(
        eventType: CanonicalEventTypeV2.challengeAccepted,
        attempt: attempt,
        occurredAtUtc: acceptedAt,
        timezoneOffsetMinutes: timezoneOffsetMinutes,
        payload: {'route': route.name},
      ),
    );
    if (applied) return ChallengeAcceptance(attempt: attempt, applied: true);
    final existing = await attempts.findByAssignment(assignment.assignmentId);
    if (existing == null) {
      throw StateError('Acceptance was not applied and no attempt was found');
    }
    return ChallengeAcceptance(attempt: existing, applied: false);
  }

  Future<ChallengeResolution> resolve({
    required String attemptId,
    required ChallengeDefinition definition,
    required AttemptOutcome outcome,
    required FeltComparedToExpected felt,
    required DateTime resolvedAt,
    required String localDate,
    required int timezoneOffsetMinutes,
    ReflectionInput reflection = const ReflectionInput(),
  }) async {
    final currentAttempt = await attempts.findById(attemptId);
    if (currentAttempt == null) throw StateError('Unknown challenge attempt');
    _requireDefinition(currentAttempt, definition);

    final currentMomentum = await momentum.loadMomentum();
    final currentProjection =
        await progress.loadProjection() ??
        _emptyProjection(resolvedAt, currentMomentum);
    if (currentAttempt.rewardAppliedLocally || currentAttempt.isTerminal) {
      return ChallengeResolution(
        attempt: currentAttempt,
        projection: currentProjection,
        momentum: currentMomentum,
        applied: false,
      );
    }

    final reflectionId = reflection.hasValue ? idGenerator() : null;
    final result = AttemptResult(
      outcome: outcome,
      felt: felt,
      fearBefore: reflection.fearBefore,
      feelAfter: reflection.feelAfter,
      wantRepeat: reflection.wantRepeat,
      privateNoteId: reflectionId,
    );
    var resolvedAttempt = transitions
        .resolve(
          attempt: currentAttempt,
          result: result,
          resolvedAt: resolvedAt,
        )
        .copyWith(rewardAppliedLocally: true);
    final privateReflection = reflectionId == null
        ? null
        : PrivateReflection(
            reflectionId: reflectionId,
            attemptId: attemptId,
            fearBefore: reflection.fearBefore,
            feelAfter: reflection.feelAfter,
            wantRepeat: reflection.wantRepeat,
            privateNote: switch (reflection.privateNote?.trim()) {
              final note? when note.isNotEmpty => note,
              _ => null,
            },
            createdAt: resolvedAt.toUtc(),
            updatedAt: resolvedAt.toUtc(),
          );
    privateReflection?.validate();

    final repeatWindowStart = resolvedAt.toUtc().subtract(
      const Duration(days: 7),
    );
    final priorTerminalAttempts = (await attempts.history(limit: 500))
        .where(
          (attempt) =>
              attempt.attemptId != currentAttempt.attemptId &&
              attempt.contentId == currentAttempt.contentId &&
              attempt.contentRevision == currentAttempt.contentRevision &&
              attempt.rewardAppliedLocally &&
              attempt.resolvedAt != null &&
              !attempt.resolvedAt!.toUtc().isBefore(repeatWindowStart) &&
              !attempt.resolvedAt!.toUtc().isAfter(resolvedAt.toUtc()),
        )
        .length;
    final reward = rewardPolicy.calculate(
      definition: definition,
      outcome: outcome,
      route: currentAttempt.selectedRoute,
      reflectionSubmitted: privateReflection != null,
      priorTerminalAttemptsWithinRollingSevenDays: priorTerminalAttempts,
    );
    final rewardedResult = result.copyWith(
      earnedXp: reward.xp,
      effectiveLocalDate: localDate,
    );
    resolvedAttempt = resolvedAttempt.copyWith(result: rewardedResult);
    final momentumUpdate = definition.momentumEligible
        ? momentumPolicy.earnDay(
            currentMomentum,
            localDate: localDate,
            earnedAtUtc: resolvedAt,
            timezoneId: currentAttempt.timezoneId,
          )
        : MomentumUpdate(
            state: momentumPolicy.refreshForDate(currentMomentum, localDate),
            shieldConsumed: false,
            shieldGranted: false,
            reset: false,
          );
    final projection = _applyProgress(
      current: currentProjection,
      definition: definition,
      result: rewardedResult,
      reward: reward,
      momentum: momentumUpdate.state,
      updatedAt: resolvedAt,
    );
    final events = _resolutionEvents(
      attempt: resolvedAttempt,
      result: rewardedResult,
      reflection: privateReflection,
      previousProjection: currentProjection,
      projection: projection,
      previousMomentum: currentMomentum,
      momentumUpdate: momentumUpdate,
      timezoneOffsetMinutes: timezoneOffsetMinutes,
      occurredAtUtc: resolvedAt,
      rewardPolicyRevision: reward.policyRevision,
      rewardRepeatMultiplierPercent: reward.repeatMultiplierPercent,
      difficultyModelRevision: difficultyPolicy.algorithmRevision,
    );
    final applied = await commits.commitResolution(
      attempt: resolvedAttempt,
      projection: projection,
      momentum: momentumUpdate.state,
      events: events,
      reflection: privateReflection,
    );
    if (!applied) {
      final storedAttempt = await attempts.findById(attemptId);
      final storedProjection = await progress.loadProjection();
      return ChallengeResolution(
        attempt: storedAttempt ?? resolvedAttempt,
        projection: storedProjection ?? currentProjection,
        momentum: await momentum.loadMomentum(),
        applied: false,
      );
    }
    return ChallengeResolution(
      attempt: resolvedAttempt,
      projection: projection,
      momentum: momentumUpdate.state,
      reward: reward,
      applied: true,
    );
  }

  ProgressProjection _applyProgress({
    required ProgressProjection current,
    required ChallengeDefinition definition,
    required AttemptResult result,
    required ChallengeReward reward,
    required MomentumState momentum,
    required DateTime updatedAt,
  }) {
    final traitXp = Map<Trait, int>.from(current.traitXp);
    traitXp[definition.primaryTrait] =
        (traitXp[definition.primaryTrait] ?? 0) + reward.xp;
    for (final entry in definition.secondaryTraitWeights.entries) {
      final secondaryXp = (reward.xp * entry.value).round();
      traitXp[entry.key] = (traitXp[entry.key] ?? 0) + secondaryXp;
    }
    final difficulty = Map<Trait, DifficultyState>.from(current.difficulty);
    final currentDifficulty =
        difficulty[definition.primaryTrait] ??
        _initialDifficulty(definition.primaryTrait, updatedAt);
    difficulty[definition.primaryTrait] = difficultyPolicy.update(
      currentDifficulty,
      DifficultyObservation(
        intensity: definition.intensity,
        outcome: result.outcome,
        felt: result.felt,
      ),
      updatedAt,
    );
    final totalXp = current.totalXp + reward.xp;
    final rank = rankPolicy.resolve(totalXp: totalXp, traitXp: traitXp);
    return ProgressProjection(
      totalXp: totalXp,
      traitXp: traitXp,
      rank: rank.rank,
      rankProgress: rank.progressToNext,
      momentum: momentum,
      difficulty: difficulty,
      completedCount:
          current.completedCount +
          (result.outcome == AttemptOutcome.completed ? 1 : 0),
      attemptedCount:
          current.attemptedCount +
          (result.outcome == AttemptOutcome.attempted ? 1 : 0),
      updatedAt: updatedAt.toUtc(),
      source: ProjectionSource.localCheckpoint,
    );
  }

  ProgressProjection _emptyProjection(DateTime at, MomentumState momentum) {
    final traitXp = {for (final trait in Trait.values) trait: 0};
    final rank = rankPolicy.resolve(totalXp: 0, traitXp: traitXp);
    return ProgressProjection(
      totalXp: 0,
      traitXp: traitXp,
      rank: rank.rank,
      rankProgress: rank.progressToNext,
      momentum: momentum,
      difficulty: {
        for (final trait in Trait.values) trait: _initialDifficulty(trait, at),
      },
      completedCount: 0,
      attemptedCount: 0,
      updatedAt: at.toUtc(),
      source: ProjectionSource.localCheckpoint,
    );
  }

  DifficultyState _initialDifficulty(Trait trait, DateTime at) =>
      DifficultyState(
        trait: trait,
        rating: 2,
        confidence: 0,
        observations: 0,
        recommendedIntensity: 2,
        updatedAt: at.toUtc(),
      );

  List<EventDraftV2> _resolutionEvents({
    required ChallengeAttempt attempt,
    required AttemptResult result,
    required PrivateReflection? reflection,
    required ProgressProjection previousProjection,
    required ProgressProjection projection,
    required MomentumState previousMomentum,
    required MomentumUpdate momentumUpdate,
    required int timezoneOffsetMinutes,
    required DateTime occurredAtUtc,
    required String rewardPolicyRevision,
    required int rewardRepeatMultiplierPercent,
    required String difficultyModelRevision,
  }) {
    final events = <EventDraftV2>[
      _event(
        eventType: result.outcome == AttemptOutcome.completed
            ? CanonicalEventTypeV2.challengeCompleted
            : CanonicalEventTypeV2.challengeAttempted,
        attempt: attempt,
        occurredAtUtc: occurredAtUtc,
        timezoneOffsetMinutes: timezoneOffsetMinutes,
        payload: {
          'outcome': result.outcome.name,
          'felt': result.felt.name,
          'route': attempt.selectedRoute.name,
          'rewardPolicyRevision': rewardPolicyRevision,
          'rewardRepeatMultiplierPercent': rewardRepeatMultiplierPercent,
          'rewardXp': result.earnedXp,
          'difficultyModelRevision': difficultyModelRevision,
          'momentumPolicyRevision': momentumUpdate.state.policyRevision,
          'momentumPendingTimezoneReview':
              momentumUpdate.state.pendingTimezoneReview,
        },
      ),
    ];
    if (reflection != null) {
      events.add(
        _event(
          eventType: CanonicalEventTypeV2.reflectionSubmitted,
          attempt: attempt,
          occurredAtUtc: occurredAtUtc,
          timezoneOffsetMinutes: timezoneOffsetMinutes,
          payload: {
            'fearBefore': reflection.fearBefore,
            'feelAfter': reflection.feelAfter,
            'wantRepeat': reflection.wantRepeat,
            'hasPrivateNote': reflection.privateNote?.isNotEmpty == true,
          },
        ),
      );
    }
    if (momentumUpdate.state.lastEarnedLocalDate !=
        previousMomentum.lastEarnedLocalDate) {
      events.add(
        _event(
          eventType: CanonicalEventTypeV2.momentumDayEarned,
          attempt: attempt,
          occurredAtUtc: occurredAtUtc,
          timezoneOffsetMinutes: timezoneOffsetMinutes,
          payload: {
            'localDate': momentumUpdate.state.lastEarnedLocalDate,
            'currentDays': momentumUpdate.state.currentDays,
            'policyRevision': momentumUpdate.state.policyRevision,
          },
        ),
      );
    }
    if (projection.rank.label != previousProjection.rank.label) {
      events.add(
        _event(
          eventType: CanonicalEventTypeV2.rankUnlocked,
          attempt: attempt,
          occurredAtUtc: occurredAtUtc,
          timezoneOffsetMinutes: timezoneOffsetMinutes,
          payload: {
            'rankFamily': projection.rank.family.name,
            'rankTier': projection.rank.tier,
            'rankConfigRevision': projection.rank.configRevision,
          },
        ),
      );
    }
    return events;
  }

  EventDraftV2 _event({
    required CanonicalEventTypeV2 eventType,
    required ChallengeAttempt attempt,
    required DateTime occurredAtUtc,
    required int timezoneOffsetMinutes,
    required Map<String, Object?> payload,
  }) => EventDraftV2(
    eventId: idGenerator(),
    eventType: eventType,
    occurredAtUtc: occurredAtUtc.toUtc(),
    timezoneId: attempt.timezoneId,
    timezoneOffsetMinutes: timezoneOffsetMinutes,
    assignmentId: attempt.assignmentId,
    attemptId: attempt.attemptId,
    contentId: attempt.contentId,
    contentRevision: attempt.contentRevision,
    payload: payload,
  );

  static void _requireDefinition(
    ChallengeAttempt attempt,
    ChallengeDefinition definition,
  ) {
    if (attempt.contentId != definition.contentId ||
        attempt.contentRevision != definition.revision) {
      throw const FormatException('Attempt definition does not match');
    }
  }
}
