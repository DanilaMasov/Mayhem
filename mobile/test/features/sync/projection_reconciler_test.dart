import 'package:flutter_test/flutter_test.dart';
import 'package:mayhem_mobile/core/sync/event_envelope_v2.dart';
import 'package:mayhem_mobile/features/progress/domain/development_rank_config.dart';
import 'package:mayhem_mobile/features/progress/domain/progress_models.dart';
import 'package:mayhem_mobile/features/streak/domain/momentum_state.dart';
import 'package:mayhem_mobile/features/sync/application/projection_reconciler.dart';
import 'package:mayhem_mobile/features/sync/domain/backend_models.dart';
import 'package:mayhem_mobile/features/sync/domain/reconciliation_models.dart';

void main() {
  const reconciler = ProjectionReconciler();

  test('server base is reconciled with still-pending optimistic rewards', () {
    final local = _localProjection(
      totalXp: 100,
      ratingScore: 1025,
      currentDays: 2,
      longestDays: 8,
    );
    final server = ServerProjectionSnapshot.fromJson(
      _serverProjectionJson(
        totalXp: 80,
        revision: 2,
        currentDays: 2,
        longestDays: 6,
      ),
    );
    final pending = _terminalEvent(rewardXp: 20);

    final result = reconciler.reconcile(
      local: local,
      server: server,
      lastServerProjectionRevision: 1,
      pendingEvents: [pending],
      challengeDescriptors: {
        'challenge@1': PendingChallengeDescriptor(
          primaryTrait: Trait.presence,
          intensity: 3,
          secondaryTraitWeights: const {},
        ),
      },
      now: DateTime.utc(2026, 7, 13, 13),
    );

    expect(result.applied, isTrue);
    expect(result.projection.totalXp, 100);
    expect(result.projection.traitXp[Trait.presence], 100);
    expect(result.projection.completedCount, 1);
    expect(result.momentum.longestDays, 8);
    expect(result.correctionNotice, isNull);
  });

  test(
    'material server correction carries deterministic one-time reason codes',
    () {
      final local = _localProjection(
        totalXp: 300,
        ratingScore: 1250,
        currentDays: 4,
        longestDays: 9,
      );
      final server = ServerProjectionSnapshot.fromJson(
        _serverProjectionJson(
          totalXp: 80,
          revision: 4,
          currentDays: 2,
          longestDays: 6,
        ),
      );

      final result = reconciler.reconcile(
        local: local,
        server: server,
        lastServerProjectionRevision: 3,
        pendingEvents: const [],
        challengeDescriptors: const {},
        now: DateTime.utc(2026, 7, 13, 13),
      );

      expect(result.projection.totalXp, 80);
      expect(result.momentum.currentDays, 2);
      expect(result.momentum.longestDays, 9);
      expect(
        result.correctionNotice?.reasons,
        containsAll({
          CorrectionReason.serverProjectionCorrected,
          CorrectionReason.rankCorrected,
          CorrectionReason.timezoneCorrection,
        }),
      );
      expect(result.correctionNotice?.noticeId, startsWith('projection:4:'));
    },
  );

  test(
    'stale server projection cannot overwrite a newer reconciled checkpoint',
    () {
      final local = _localProjection(
        totalXp: 300,
        ratingScore: 1250,
        currentDays: 4,
        longestDays: 9,
      );
      final server = ServerProjectionSnapshot.fromJson(
        _serverProjectionJson(
          totalXp: 80,
          revision: 4,
          currentDays: 2,
          longestDays: 6,
        ),
      );

      final result = reconciler.reconcile(
        local: local,
        server: server,
        lastServerProjectionRevision: 4,
        pendingEvents: const [],
        challengeDescriptors: const {},
        now: DateTime.utc(2026, 7, 13, 13),
      );

      expect(result.applied, isFalse);
      expect(result.projection, same(local));
    },
  );

  test(
    'pending event without immutable content metadata blocks reconciliation',
    () {
      final local = _localProjection(
        totalXp: 100,
        currentDays: 2,
        longestDays: 8,
      );
      final server = ServerProjectionSnapshot.fromJson(
        _serverProjectionJson(
          totalXp: 80,
          revision: 2,
          currentDays: 2,
          longestDays: 6,
        ),
      );

      expect(
        () => reconciler.reconcile(
          local: local,
          server: server,
          lastServerProjectionRevision: 1,
          pendingEvents: [_terminalEvent(rewardXp: 20)],
          challengeDescriptors: const {},
          now: DateTime.utc(2026, 7, 13, 13),
        ),
        throwsStateError,
      );
    },
  );

  test('fresh server projection carries server-owned artifact snapshot', () {
    final local = _localProjection(totalXp: 80, currentDays: 2, longestDays: 2);
    final json =
        _serverProjectionJson(
            totalXp: 80,
            revision: 5,
            currentDays: 2,
            longestDays: 2,
          )
          ..['ownedArtifacts'] = [
            {
              'artifactId': 'founder-1',
              'seasonId': 'season-0',
              'seasonRevision': 1,
              'bossEventId': 'boss-0',
              'unlockedAt': '2026-07-13T12:30:00.000Z',
            },
          ];

    final result = reconciler.reconcile(
      local: local,
      server: ServerProjectionSnapshot.fromJson(json),
      lastServerProjectionRevision: 4,
      pendingEvents: const [],
      challengeDescriptors: const {},
      now: DateTime.utc(2026, 7, 13, 13),
    );

    expect(result.ownedArtifacts, hasLength(1));
    expect(result.ownedArtifacts.single.artifactId, 'founder-1');
    expect(result.ownedArtifacts.single.seasonId, 'season-0');
  });

  test('server projection accepts only the frozen dynamic-rating revision', () {
    final json = _serverProjectionJson(
      totalXp: 120,
      revision: 6,
      currentDays: 2,
      longestDays: 2,
    );
    json
      ..['ratingScore'] = 1125
      ..['peakRatingScore'] = 1180
      ..['ratingModelRevision'] = 'rating_model_dev_v1'
      ..['rank'] = {
        'family': 'spark',
        'tier': 2,
        'configRevision': 'rank_config_dev_v2',
      };

    final snapshot = ServerProjectionSnapshot.fromJson(json);
    expect(snapshot.projection.ratingScore, 1125);
    expect(snapshot.projection.peakRatingScore, 1180);
    expect(snapshot.projection.rank.label, 'ИМПУЛЬС');

    json['ratingModelRevision'] = 'rating_model_unknown';
    expect(
      () => ServerProjectionSnapshot.fromJson(json),
      throwsFormatException,
    );
  });
}

ProgressProjection _localProjection({
  required int totalXp,
  required int currentDays,
  required int longestDays,
  int ratingScore = DevelopmentRankConfig.startingRating,
}) {
  final traitXp = {
    Trait.initiation: 0,
    Trait.expression: 0,
    Trait.connection: 0,
    Trait.presence: totalXp,
  };
  final rank = DevelopmentRankConfig.policy().resolve(
    ratingScore: ratingScore,
    traitXp: traitXp,
  );
  final momentum = MomentumState(
    currentDays: currentDays,
    longestDays: longestDays,
    earnedToday: true,
    shieldsAvailable: 0,
    lastEarnedLocalDate: '2026-07-13',
    protectedLocalDates: const {},
    nextMilestone: 7,
  );
  return ProgressProjection(
    totalXp: totalXp,
    ratingScore: ratingScore,
    peakRatingScore: ratingScore,
    traitXp: traitXp,
    rank: rank.rank,
    rankProgress: rank.progressToNext,
    momentum: momentum,
    difficulty: {
      for (final trait in Trait.values)
        trait: DifficultyState(
          trait: trait,
          rating: 2,
          confidence: 0,
          observations: 0,
          recommendedIntensity: 2,
          updatedAt: DateTime.utc(2026, 7, 13),
        ),
    },
    completedCount: totalXp > 0 ? 1 : 0,
    attemptedCount: 0,
    updatedAt: DateTime.utc(2026, 7, 13, 12),
    source: ProjectionSource.localCheckpoint,
  );
}

EventEnvelopeV2 _terminalEvent({required int rewardXp}) => EventEnvelopeV2(
  eventId: 'event-id',
  eventType: CanonicalEventTypeV2.challengeCompleted,
  localUserId: 'local-user',
  installationId: 'installation-id',
  clientSequence: 1,
  occurredAtUtc: DateTime.utc(2026, 7, 13, 12, 30),
  timezoneId: 'Europe/Moscow',
  timezoneOffsetMinutes: 180,
  assignmentId: 'assignment-id',
  attemptId: 'attempt-id',
  contentId: 'challenge',
  contentRevision: 1,
  payload: {
    'rewardXp': rewardXp,
    'felt': 'aboutAsExpected',
    'route': 'normal',
    'rewardRepeatMultiplierPercent': 100,
  },
);

Map<String, dynamic> _serverProjectionJson({
  required int totalXp,
  required int revision,
  required int currentDays,
  required int longestDays,
}) => {
  'totalXp': totalXp,
  'traitXp': {
    'initiation': 0,
    'expression': 0,
    'connection': 0,
    'presence': totalXp,
  },
  'rank': {
    'family': 'spark',
    'tier': 1,
    'configRevision': 'rank_config_dev_v1',
  },
  'rewardPolicyRevision': 'reward_policy_dev_v1',
  'completedCount': 0,
  'attemptedCount': 0,
  'projectionRevision': revision,
  'updatedAt': '2026-07-13T12:00:00.000Z',
  'difficulty': <String, Object?>{},
  'momentum': {
    'currentDays': currentDays,
    'longestDays': longestDays,
    'shieldsAvailable': 0,
    'lastEarnedLocalDate': '2026-07-13',
    'protectedLocalDates': <String>[],
    'policyRevision': 'momentum_policy_dev_v1',
    'projectionRevision': revision,
  },
};
