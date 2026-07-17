import 'package:flutter_test/flutter_test.dart';
import 'package:mayhem_mobile/features/challenge/domain/challenge_models.dart';
import 'package:mayhem_mobile/features/season/domain/artifact_ownership.dart';
import 'package:mayhem_mobile/features/season/domain/season_experience_state.dart';
import 'package:mayhem_mobile/features/season/domain/season_models.dart';
import 'package:mayhem_mobile/features/season/domain/season_participation_state.dart';

void main() {
  final package = _package();

  test('disabled and unavailable loading states are explicit', () {
    expect(
      SeasonExperienceState.loading().availability,
      SeasonAvailability.loadingCached,
    );
    expect(
      _resolve(package: null, enabled: false).availability,
      SeasonAvailability.disabled,
    );
    expect(
      _resolve(package: null).availability,
      SeasonAvailability.unavailable,
    );
    expect(
      _resolve(package: package, remoteLoading: true).availability,
      SeasonAvailability.loadingRemote,
    );
  });

  test('cached Season is distinguishable from server-confirmed state', () {
    final cached = _resolve(package: package);
    final confirmed = _resolve(
      package: package,
      freshness: SeasonDataFreshness.serverConfirmed,
    );

    expect(cached.availability, SeasonAvailability.offlineCached);
    expect(cached.membership, SeasonMembership.notJoined);
    expect(cached.currentDay, 3);
    expect(confirmed.availability, SeasonAvailability.ready);
  });

  test('day states resolve from participation and current day', () {
    final joined = _participation();
    expect(
      _resolve(package: package, participation: joined).dayPhase,
      SeasonDayPhase.available,
    );
    expect(
      _resolve(
        package: package,
        participation: _participation(completedDays: const {3}),
      ).dayPhase,
      SeasonDayPhase.completed,
    );
    expect(
      _resolve(
        package: package,
        participation: joined,
        operation: SeasonOperation.dayInProgress,
      ).dayPhase,
      SeasonDayPhase.inProgress,
    );
  });

  test('joining and retryable failure are modeled without fake membership', () {
    expect(
      _resolve(package: package, operation: SeasonOperation.joining).membership,
      SeasonMembership.joining,
    );
    expect(
      _resolve(package: package, joinFailed: true).membership,
      SeasonMembership.joinFailedRetryable,
    );
  });

  test('Boss window, submission and server-owned completion are explicit', () {
    final joined = _participation();
    expect(
      _resolve(
        package: package,
        participation: joined,
        now: DateTime.utc(2026, 8, 3),
      ).bossPhase,
      SeasonBossPhase.upcoming,
    );
    expect(
      _resolve(
        package: package,
        participation: joined,
        now: DateTime.utc(2026, 8, 7, 13),
      ).bossPhase,
      SeasonBossPhase.open,
    );
    expect(
      _resolve(
        package: package,
        participation: joined,
        now: DateTime.utc(2026, 8, 7, 13),
        operation: SeasonOperation.bossSubmitting,
      ).bossPhase,
      SeasonBossPhase.submitting,
    );
    expect(
      _resolve(
        package: package,
        participation: _participation(
          bossParticipatedAt: DateTime.utc(2026, 8, 7, 13),
        ),
        now: DateTime.utc(2026, 8, 7, 14),
      ).bossPhase,
      SeasonBossPhase.alreadyParticipated,
    );
    final completed = _resolve(
      package: package,
      participation: _participation(
        completedDays: const {1, 2, 3, 4, 5, 6, 7},
        bossParticipatedAt: DateTime.utc(2026, 8, 7, 13),
      ),
      now: DateTime.utc(2026, 8, 7, 14),
      artifacts: [_artifact()],
    );
    expect(completed.bossPhase, SeasonBossPhase.completed);
  });

  test('expired and completed Seasons remain visible from cache', () {
    expect(
      _resolve(
        package: package,
        participation: _participation(),
        now: DateTime.utc(2026, 8, 9),
      ).membership,
      SeasonMembership.expired,
    );
    expect(
      _resolve(
        package: package,
        participation: _participation(
          completedDays: const {1, 2, 3, 4, 5, 6, 7},
        ),
        now: DateTime.utc(2026, 8, 9),
        artifacts: [_artifact()],
      ).membership,
      SeasonMembership.completed,
    );
  });

  test('conflict, malformed and recoverable failures do not collapse', () {
    expect(
      _resolve(package: package, conflict: true).availability,
      SeasonAvailability.conflictRefreshRequired,
    );
    expect(
      _resolve(package: package, incompatiblePackage: true).availability,
      SeasonAvailability.incompatiblePackage,
    );
    expect(
      _resolve(package: package, errorCode: 'network').availability,
      SeasonAvailability.recoverableError,
    );
  });

  test('social proof is exposed only above the package threshold', () {
    expect(_resolve(package: package).socialProofCount, 24);
    expect(
      _resolve(package: _package(socialValue: 19)).socialProofCount,
      isNull,
    );
  });
}

SeasonExperienceState _resolve({
  required SeasonPackage? package,
  bool enabled = true,
  DateTime? now,
  SeasonParticipationState? participation,
  List<OwnedFounderArtifact> artifacts = const [],
  SeasonDataFreshness freshness = SeasonDataFreshness.cached,
  SeasonOperation operation = SeasonOperation.none,
  bool remoteLoading = false,
  bool joinFailed = false,
  bool conflict = false,
  bool incompatiblePackage = false,
  String? errorCode,
}) => SeasonExperienceState.resolve(
  enabled: enabled,
  now: now ?? DateTime.utc(2026, 8, 3, 12),
  package: package,
  participation: participation,
  ownedArtifacts: artifacts,
  freshness: freshness,
  operation: operation,
  remoteLoading: remoteLoading,
  joinFailed: joinFailed,
  conflict: conflict,
  incompatiblePackage: incompatiblePackage,
  errorCode: errorCode,
);

SeasonParticipationState _participation({
  Set<int> completedDays = const {},
  DateTime? bossParticipatedAt,
}) => SeasonParticipationState(
  seasonId: 'season-0',
  seasonRevision: 1,
  joinedAt: DateTime.utc(2026, 8, 1),
  completedDays: completedDays,
  bossParticipatedAt: bossParticipatedAt,
);

OwnedFounderArtifact _artifact() => OwnedFounderArtifact(
  artifactId: 'founder-0',
  seasonId: 'season-0',
  seasonRevision: 1,
  bossEventId: 'boss-0',
  unlockedAt: DateTime.utc(2026, 8, 7, 13),
);

SeasonPackage _package({int socialValue = 24}) => SeasonPackage(
  season: Season(
    seasonId: 'season-0',
    revision: 1,
    title: 'Нулевая неделя',
    startsAt: DateTime.utc(2026, 8, 1),
    endsAt: DateTime.utc(2026, 8, 8),
    days: [
      for (var day = 1; day <= 7; day++)
        SeasonDay(day: day, title: 'День $day', featuredContentIds: ['q-$day']),
    ],
    bossEventId: 'boss-0',
    rewardArtifactIds: const ['founder-0'],
  ),
  boss: BossEventDefinition(
    bossEventId: 'boss-0',
    contentId: 'boss-content',
    contentRevision: 1,
    startsAt: DateTime.utc(2026, 8, 7, 12),
    endsAt: DateTime.utc(2026, 8, 8),
    normalRoute: const ChallengeRoute(copy: 'Сделай шаг'),
    lowPressureRoute: const ChallengeRoute(copy: 'Сделай малый шаг'),
  ),
  artifacts: [
    FounderArtifactDefinition(artifactId: 'founder-0', title: 'Основатель'),
  ],
  socialProof: SocialProofAggregate(
    aggregateKey: 'season-0-participants',
    value: socialValue,
    threshold: 20,
    windowStartsAt: DateTime.utc(2026, 8, 1),
    windowEndsAt: DateTime.utc(2026, 8, 8),
  ),
);
