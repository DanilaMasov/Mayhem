import '../../../core/sync/event_envelope_v2.dart';
import '../../challenge/domain/challenge_models.dart';
import '../../progress/domain/development_rank_config.dart';
import '../../progress/domain/difficulty_update_policy.dart';
import '../../progress/domain/progress_models.dart';
import '../../progress/domain/rating_update_policy.dart';
import '../../season/domain/artifact_ownership.dart';
import '../../streak/domain/momentum_policy.dart';
import '../domain/backend_models.dart';
import '../domain/reconciliation_models.dart';

class ProjectionReconciler {
  const ProjectionReconciler({
    this.difficultyPolicy = const DifficultyUpdatePolicy(),
    this.momentumPolicy = const MomentumPolicy(),
    this.ratingPolicy = const RatingUpdatePolicy(),
  });

  final DifficultyUpdatePolicy difficultyPolicy;
  final MomentumPolicy momentumPolicy;
  final RatingUpdatePolicy ratingPolicy;

  ReconciledState reconcile({
    required ProgressProjection local,
    required ServerProjectionSnapshot server,
    required int lastServerProjectionRevision,
    required Iterable<EventEnvelopeV2> pendingEvents,
    required Map<String, PendingChallengeDescriptor> challengeDescriptors,
    required DateTime now,
  }) {
    if (server.projectionRevision <= lastServerProjectionRevision) {
      return ReconciledState(
        projection: local,
        momentum: local.momentum,
        serverProjectionRevision: lastServerProjectionRevision,
        applied: false,
      );
    }

    final ordered = pendingEvents.toList(growable: false)
      ..sort(
        (left, right) => left.clientSequence.compareTo(right.clientSequence),
      );
    var totalXp = server.projection.totalXp;
    var ratingScore = server.projection.ratingScore;
    var peakRatingScore = server.projection.peakRatingScore;
    final traitXp = Map<Trait, int>.from(server.projection.traitXp);
    final difficulty = Map<Trait, DifficultyState>.from(
      server.projection.difficulty,
    );
    var completedCount = server.projection.completedCount;
    var attemptedCount = server.projection.attemptedCount;
    var momentum = server.momentum.toLocal(previous: local.momentum);
    var updatedAt = server.projection.updatedAt;

    for (final event in ordered) {
      if (event.eventType == CanonicalEventTypeV2.challengeAttempted ||
          event.eventType == CanonicalEventTypeV2.challengeCompleted) {
        final descriptor = challengeDescriptors[_contentKey(event)];
        if (descriptor == null) {
          throw StateError('Pending challenge content is unavailable');
        }
        final reward = event.payload['rewardXp'];
        final felt = event.payload['felt'];
        final route = event.payload['route'];
        final repeatMultiplier = event.payload['rewardRepeatMultiplierPercent'];
        if (reward is! int ||
            reward < 0 ||
            reward > 10000 ||
            felt is! String ||
            route is! String ||
            repeatMultiplier is! int) {
          throw const FormatException('Pending reward event is invalid');
        }
        final outcome =
            event.eventType == CanonicalEventTypeV2.challengeCompleted
            ? AttemptOutcome.completed
            : AttemptOutcome.attempted;
        totalXp += reward;
        traitXp[descriptor.primaryTrait] =
            (traitXp[descriptor.primaryTrait] ?? 0) + reward;
        for (final entry in descriptor.secondaryTraitWeights.entries) {
          traitXp[entry.key] =
              (traitXp[entry.key] ?? 0) + (reward * entry.value).round();
        }
        final currentDifficulty =
            difficulty[descriptor.primaryTrait] ??
            DifficultyState(
              trait: descriptor.primaryTrait,
              rating: 2,
              confidence: 0,
              observations: 0,
              recommendedIntensity: 2,
              updatedAt: updatedAt,
            );
        difficulty[descriptor.primaryTrait] = difficultyPolicy.update(
          currentDifficulty,
          DifficultyObservation(
            intensity: descriptor.intensity,
            outcome: outcome,
            felt: FeltComparedToExpected.values.byName(felt),
          ),
          event.occurredAtUtc,
        );
        final rating = ratingPolicy.update(
          currentScore: ratingScore,
          outcome: outcome,
          felt: FeltComparedToExpected.values.byName(felt),
          route: ChallengeRouteType.values.byName(route),
          intensity: descriptor.intensity,
          repeatMultiplierPercent: repeatMultiplier,
        );
        ratingScore = rating.score;
        if (ratingScore > peakRatingScore) peakRatingScore = ratingScore;
        if (outcome == AttemptOutcome.completed) {
          completedCount += 1;
        } else {
          attemptedCount += 1;
        }
        updatedAt = event.occurredAtUtc;
      } else if (event.eventType == CanonicalEventTypeV2.momentumDayEarned) {
        final localDate = event.payload['localDate'];
        if (localDate is! String) {
          throw const FormatException('Pending Momentum date is invalid');
        }
        momentum = momentumPolicy
            .earnDay(
              momentum,
              localDate: localDate,
              earnedAtUtc: event.occurredAtUtc,
              timezoneId: event.timezoneId,
            )
            .state;
      }
    }

    final rank = DevelopmentRankConfig.policy().resolve(
      ratingScore: ratingScore,
      traitXp: traitXp,
    );
    final projection = ProgressProjection(
      totalXp: totalXp,
      ratingScore: ratingScore,
      peakRatingScore: peakRatingScore,
      traitXp: traitXp,
      rank: rank.rank,
      rankProgress: rank.progressToNext,
      momentum: momentum,
      difficulty: difficulty,
      completedCount: completedCount,
      attemptedCount: attemptedCount,
      updatedAt: updatedAt,
      source: ProjectionSource.serverReconciled,
    );
    final reasons = <CorrectionReason>{};
    if (projection.totalXp != local.totalXp ||
        projection.ratingScore != local.ratingScore) {
      reasons.add(CorrectionReason.serverProjectionCorrected);
    }
    if (projection.rank.label != local.rank.label) {
      reasons.add(CorrectionReason.rankCorrected);
    }
    if (momentum.currentDays != local.momentum.currentDays ||
        momentum.pendingTimezoneReview !=
            local.momentum.pendingTimezoneReview) {
      reasons.add(CorrectionReason.timezoneCorrection);
    }
    final notice = reasons.isEmpty
        ? null
        : CorrectionNotice(
            noticeId:
                'projection:${server.projectionRevision}:'
                '${(reasons.map((reason) => reason.wireName).toList()..sort()).join(',')}',
            reasons: reasons,
            createdAt: now.toUtc(),
          );
    return ReconciledState(
      projection: projection,
      momentum: momentum,
      serverProjectionRevision: server.projectionRevision,
      applied: true,
      ownedArtifacts: [
        for (final artifact in server.ownedArtifacts)
          OwnedFounderArtifact(
            artifactId: artifact.artifactId,
            seasonId: artifact.seasonId,
            seasonRevision: artifact.seasonRevision,
            bossEventId: artifact.bossEventId,
            unlockedAt: artifact.unlockedAt,
          ),
      ],
      correctionNotice: notice,
    );
  }

  String _contentKey(EventEnvelopeV2 event) {
    final contentId = event.contentId;
    final revision = event.contentRevision;
    if (contentId == null || revision == null) {
      throw const FormatException(
        'Pending challenge content identity is missing',
      );
    }
    return '$contentId@$revision';
  }
}
