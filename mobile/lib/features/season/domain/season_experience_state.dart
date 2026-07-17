import 'artifact_ownership.dart';
import 'season_models.dart';
import 'season_participation_state.dart';

enum SeasonAvailability {
  disabled,
  loadingCached,
  loadingRemote,
  unavailable,
  offlineCached,
  ready,
  conflictRefreshRequired,
  incompatiblePackage,
  recoverableError,
}

enum SeasonMembership {
  unavailable,
  notJoined,
  joining,
  joinFailedRetryable,
  active,
  expired,
  completed,
}

enum SeasonDayPhase { unavailable, available, inProgress, completed }

enum SeasonBossPhase {
  locked,
  upcoming,
  open,
  submitting,
  alreadyParticipated,
  completed,
}

enum SeasonOperation { none, joining, dayInProgress, bossSubmitting }

enum SeasonDataFreshness { none, cached, serverConfirmed }

class SeasonExperienceState {
  const SeasonExperienceState({
    required this.availability,
    required this.membership,
    required this.dayPhase,
    required this.bossPhase,
    required this.freshness,
    this.package,
    this.participation,
    this.currentDay,
    this.socialProofCount,
    this.errorCode,
  });

  factory SeasonExperienceState.loading() => const SeasonExperienceState(
    availability: SeasonAvailability.loadingCached,
    membership: SeasonMembership.unavailable,
    dayPhase: SeasonDayPhase.unavailable,
    bossPhase: SeasonBossPhase.locked,
    freshness: SeasonDataFreshness.none,
  );

  factory SeasonExperienceState.resolve({
    required bool enabled,
    required DateTime now,
    required SeasonPackage? package,
    required SeasonParticipationState? participation,
    required List<OwnedFounderArtifact> ownedArtifacts,
    required SeasonDataFreshness freshness,
    SeasonOperation operation = SeasonOperation.none,
    bool remoteLoading = false,
    bool remoteUnavailable = false,
    bool joinFailed = false,
    bool conflict = false,
    bool incompatiblePackage = false,
    String? errorCode,
  }) {
    if (!enabled) {
      return const SeasonExperienceState(
        availability: SeasonAvailability.disabled,
        membership: SeasonMembership.unavailable,
        dayPhase: SeasonDayPhase.unavailable,
        bossPhase: SeasonBossPhase.locked,
        freshness: SeasonDataFreshness.none,
      );
    }
    final availability = conflict
        ? SeasonAvailability.conflictRefreshRequired
        : incompatiblePackage
        ? SeasonAvailability.incompatiblePackage
        : errorCode != null
        ? SeasonAvailability.recoverableError
        : remoteLoading
        ? SeasonAvailability.loadingRemote
        : package == null
        ? SeasonAvailability.unavailable
        : remoteUnavailable || freshness == SeasonDataFreshness.cached
        ? SeasonAvailability.offlineCached
        : SeasonAvailability.ready;
    if (package == null) {
      return SeasonExperienceState(
        availability: availability,
        membership: joinFailed
            ? SeasonMembership.joinFailedRetryable
            : SeasonMembership.unavailable,
        dayPhase: SeasonDayPhase.unavailable,
        bossPhase: SeasonBossPhase.locked,
        freshness: freshness,
        errorCode: errorCode,
      );
    }

    final at = now.toUtc();
    final season = package.season;
    final joined =
        participation != null &&
        participation.seasonId == season.seasonId &&
        participation.seasonRevision == season.revision;
    final ownsReward = ownedArtifacts.any(
      (artifact) =>
          artifact.seasonId == season.seasonId &&
          artifact.seasonRevision == season.revision &&
          artifact.bossEventId == package.boss.bossEventId &&
          season.rewardArtifactIds.contains(artifact.artifactId),
    );
    final allDaysCompleted = joined && participation.completedDays.length == 7;
    final seasonEnded = !at.isBefore(season.endsAt.toUtc());
    final currentDay = _currentDay(season, at);

    final membership = operation == SeasonOperation.joining
        ? SeasonMembership.joining
        : joinFailed
        ? SeasonMembership.joinFailedRetryable
        : allDaysCompleted && ownsReward
        ? SeasonMembership.completed
        : seasonEnded
        ? SeasonMembership.expired
        : joined
        ? SeasonMembership.active
        : SeasonMembership.notJoined;

    final dayPhase = operation == SeasonOperation.dayInProgress
        ? SeasonDayPhase.inProgress
        : currentDay != null &&
              joined &&
              participation.completedDays.contains(currentDay)
        ? SeasonDayPhase.completed
        : currentDay != null && joined && !seasonEnded
        ? SeasonDayPhase.available
        : SeasonDayPhase.unavailable;

    final boss = package.boss;
    final bossPhase = ownsReward
        ? SeasonBossPhase.completed
        : joined && participation.bossParticipatedAt != null
        ? SeasonBossPhase.alreadyParticipated
        : operation == SeasonOperation.bossSubmitting
        ? SeasonBossPhase.submitting
        : !joined || seasonEnded || !at.isBefore(boss.endsAt.toUtc())
        ? SeasonBossPhase.locked
        : at.isBefore(boss.startsAt.toUtc())
        ? SeasonBossPhase.upcoming
        : SeasonBossPhase.open;

    return SeasonExperienceState(
      availability: availability,
      membership: membership,
      dayPhase: dayPhase,
      bossPhase: bossPhase,
      freshness: freshness,
      package: package,
      participation: participation,
      currentDay: currentDay,
      socialProofCount: package.socialProof?.qualifiedValueAt(at),
      errorCode: errorCode,
    );
  }

  final SeasonAvailability availability;
  final SeasonMembership membership;
  final SeasonDayPhase dayPhase;
  final SeasonBossPhase bossPhase;
  final SeasonDataFreshness freshness;
  final SeasonPackage? package;
  final SeasonParticipationState? participation;
  final int? currentDay;
  final int? socialProofCount;
  final String? errorCode;

  bool get visible => availability != SeasonAvailability.disabled;

  static int? _currentDay(Season season, DateTime at) {
    final startsAt = season.startsAt.toUtc();
    if (at.isBefore(startsAt) || !at.isBefore(season.endsAt.toUtc())) {
      return null;
    }
    return at.difference(startsAt).inDays + 1;
  }
}
