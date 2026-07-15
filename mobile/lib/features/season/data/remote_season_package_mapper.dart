import '../../challenge/domain/challenge_models.dart';
import '../../sync/domain/backend_models.dart';
import '../domain/season_models.dart';

abstract final class RemoteSeasonPackageMapper {
  static SeasonPackage fromSnapshot(RemoteSeasonSnapshot snapshot) {
    final payload = snapshot.payload;
    final days = _objectList(payload, 'days')
        .map(
          (day) => SeasonDay(
            day: _integer(day, 'day'),
            title: _string(day, 'title'),
            featuredContentIds: _stringList(day, 'featuredContentIds'),
          ),
        )
        .toList(growable: false);
    final bossJson = _object(payload, 'boss');
    final boss = BossEventDefinition(
      bossEventId: _string(bossJson, 'bossEventId'),
      contentId: _string(bossJson, 'contentId'),
      contentRevision: _integer(bossJson, 'contentRevision'),
      startsAt: _date(bossJson, 'startsAt'),
      endsAt: _date(bossJson, 'endsAt'),
      normalRoute: _route(bossJson, 'normalRoute'),
      lowPressureRoute: _route(bossJson, 'lowPressureRoute'),
      advancedRoute: bossJson['advancedRoute'] == null
          ? null
          : _route(bossJson, 'advancedRoute'),
      advancedRouteSafetyApproved: _boolean(
        bossJson,
        'advancedRouteSafetyApproved',
      ),
    );
    final artifacts = _objectList(payload, 'artifacts')
        .map(
          (artifact) => FounderArtifactDefinition(
            artifactId: _string(artifact, 'artifactId'),
            title: _string(artifact, 'title'),
          ),
        )
        .toList(growable: false);
    final socialJson = payload['socialProof'];
    return SeasonPackage(
      season: Season(
        seasonId: snapshot.seasonId,
        revision: snapshot.revision,
        title: snapshot.title,
        startsAt: snapshot.startsAt,
        endsAt: snapshot.endsAt,
        days: days,
        bossEventId: boss.bossEventId,
        rewardArtifactIds: artifacts
            .map((artifact) => artifact.artifactId)
            .toList(growable: false),
      ),
      boss: boss,
      artifacts: artifacts,
      socialProof: socialJson == null
          ? null
          : _socialProof(_object(payload, 'socialProof')),
    );
  }

  static ChallengeRoute _route(Map<String, dynamic> json, String key) {
    final route = _object(json, key);
    final criteria = route['completionCriteriaOverride'];
    if (criteria != null && (criteria is! String || criteria.trim().isEmpty)) {
      throw FormatException('$key completion criteria is invalid');
    }
    return ChallengeRoute(
      copy: _string(route, 'copy'),
      completionCriteriaOverride: criteria as String?,
    );
  }

  static SocialProofAggregate _socialProof(Map<String, dynamic> json) =>
      SocialProofAggregate(
        aggregateKey: _string(json, 'aggregateKey'),
        value: _integer(json, 'value'),
        threshold: _integer(json, 'threshold'),
        windowStartsAt: _date(json, 'windowStartsAt'),
        windowEndsAt: _date(json, 'windowEndsAt'),
      );
}

Map<String, dynamic> _object(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! Map) throw FormatException('$key must be an object');
  return Map<String, dynamic>.from(value);
}

List<Map<String, dynamic>> _objectList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List) throw FormatException('$key must be an array');
  return value
      .map((item) {
        if (item is! Map) throw FormatException('$key item must be an object');
        return Map<String, dynamic>.from(item);
      })
      .toList(growable: false);
}

List<String> _stringList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List || value.any((item) => item is! String)) {
    throw FormatException('$key must be a string array');
  }
  return value.cast<String>().toList(growable: false);
}

String _string(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key must be a non-empty string');
  }
  return value;
}

int _integer(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! num || !value.isFinite || value.toInt() != value) {
    throw FormatException('$key must be an integer');
  }
  return value.toInt();
}

bool _boolean(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! bool) throw FormatException('$key must be a boolean');
  return value;
}

DateTime _date(Map<String, dynamic> json, String key) {
  final parsed = DateTime.parse(_string(json, key));
  if (!parsed.isUtc) {
    throw FormatException('$key must include an explicit UTC offset');
  }
  return parsed.toUtc();
}
