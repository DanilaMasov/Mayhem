import '../../challenge/domain/challenge_models.dart';

class SeasonDay {
  SeasonDay({
    required this.day,
    required this.title,
    required List<String> featuredContentIds,
  }) : featuredContentIds = List.unmodifiable(featuredContentIds) {
    if (day < 1 || day > 7 || title.trim().isEmpty) {
      throw const FormatException('Season day is invalid');
    }
    if (featuredContentIds.isEmpty ||
        featuredContentIds.any((id) => id.trim().isEmpty) ||
        featuredContentIds.toSet().length != featuredContentIds.length) {
      throw const FormatException('Season day content is invalid');
    }
  }

  final int day;
  final String title;
  final List<String> featuredContentIds;
}

class Season {
  Season({
    required this.seasonId,
    required this.revision,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    required List<SeasonDay> days,
    required this.bossEventId,
    required List<String> rewardArtifactIds,
  }) : days = List.unmodifiable(days),
       rewardArtifactIds = List.unmodifiable(rewardArtifactIds) {
    if (seasonId.trim().isEmpty ||
        revision < 1 ||
        title.trim().isEmpty ||
        bossEventId.trim().isEmpty ||
        !endsAt.isAfter(startsAt)) {
      throw const FormatException('Season identity or schedule is invalid');
    }
    final dayNumbers = days.map((day) => day.day).toSet();
    if (days.length != 7 ||
        dayNumbers.length != 7 ||
        !dayNumbers.containsAll(const {1, 2, 3, 4, 5, 6, 7}) ||
        days.asMap().entries.any((entry) => entry.value.day != entry.key + 1)) {
      throw const FormatException('Season must contain days one through seven');
    }
    if (rewardArtifactIds.isEmpty ||
        rewardArtifactIds.any((id) => id.trim().isEmpty) ||
        rewardArtifactIds.toSet().length != rewardArtifactIds.length) {
      throw const FormatException('Season reward artifacts are invalid');
    }
  }

  final String seasonId;
  final int revision;
  final String title;
  final DateTime startsAt;
  final DateTime endsAt;
  final List<SeasonDay> days;
  final String bossEventId;
  final List<String> rewardArtifactIds;
}

class BossEventDefinition {
  BossEventDefinition({
    required this.bossEventId,
    required this.contentId,
    required this.contentRevision,
    required this.startsAt,
    required this.endsAt,
    required this.normalRoute,
    required this.lowPressureRoute,
    this.advancedRoute,
    this.advancedRouteSafetyApproved = false,
  }) {
    if (bossEventId.trim().isEmpty ||
        contentId.trim().isEmpty ||
        contentRevision < 1 ||
        !endsAt.isAfter(startsAt) ||
        normalRoute.copy.trim().isEmpty ||
        lowPressureRoute.copy.trim().isEmpty) {
      throw const FormatException('Boss event definition is invalid');
    }
    if (advancedRoute != null && !advancedRouteSafetyApproved) {
      throw const FormatException(
        'Boss advanced route requires explicit safety approval',
      );
    }
    if (advancedRouteSafetyApproved && advancedRoute == null) {
      throw const FormatException(
        'Boss advanced route approval requires an advanced route',
      );
    }
  }

  final String bossEventId;
  final String contentId;
  final int contentRevision;
  final DateTime startsAt;
  final DateTime endsAt;
  final ChallengeRoute normalRoute;
  final ChallengeRoute lowPressureRoute;
  final ChallengeRoute? advancedRoute;
  final bool advancedRouteSafetyApproved;

  bool supportsRoute(ChallengeRouteType type) => switch (type) {
    ChallengeRouteType.normal => true,
    ChallengeRouteType.lowPressure => true,
    ChallengeRouteType.advanced =>
      advancedRouteSafetyApproved && advancedRoute != null,
  };
}

class FounderArtifactDefinition {
  FounderArtifactDefinition({required this.artifactId, required this.title}) {
    if (artifactId.trim().isEmpty || title.trim().isEmpty) {
      throw const FormatException('Founder artifact is invalid');
    }
  }

  final String artifactId;
  final String title;
}

class SocialProofAggregate {
  SocialProofAggregate({
    required this.aggregateKey,
    required int value,
    required this.threshold,
    required this.windowStartsAt,
    required this.windowEndsAt,
  }) : _value = value {
    if (aggregateKey.trim().isEmpty ||
        value < 0 ||
        threshold < 1 ||
        !windowEndsAt.isAfter(windowStartsAt)) {
      throw const FormatException('Social proof aggregate is invalid');
    }
  }

  final String aggregateKey;
  final int _value;
  final int threshold;
  final DateTime windowStartsAt;
  final DateTime windowEndsAt;

  int? qualifiedValueAt(DateTime atUtc) {
    final at = atUtc.toUtc();
    final insideWindow =
        !at.isBefore(windowStartsAt.toUtc()) &&
        at.isBefore(windowEndsAt.toUtc());
    return insideWindow && _value >= threshold ? _value : null;
  }
}

class SeasonPackage {
  SeasonPackage({
    required this.season,
    required this.boss,
    required List<FounderArtifactDefinition> artifacts,
    this.socialProof,
  }) : artifacts = List.unmodifiable(artifacts) {
    if (season.bossEventId != boss.bossEventId ||
        boss.startsAt.isBefore(season.startsAt) ||
        boss.endsAt.isAfter(season.endsAt)) {
      throw const FormatException('Boss event is outside the season contract');
    }
    final expected = season.rewardArtifactIds.toSet();
    final actual = artifacts.map((artifact) => artifact.artifactId).toSet();
    if (artifacts.length != actual.length ||
        expected.length != actual.length ||
        !expected.containsAll(actual)) {
      throw const FormatException('Season artifact contract does not match');
    }
  }

  final Season season;
  final BossEventDefinition boss;
  final List<FounderArtifactDefinition> artifacts;
  final SocialProofAggregate? socialProof;
}
