import 'package:flutter_test/flutter_test.dart';
import 'package:mayhem_mobile/features/challenge/domain/challenge_models.dart';
import 'package:mayhem_mobile/features/season/data/remote_season_package_mapper.dart';
import 'package:mayhem_mobile/features/sync/domain/backend_models.dart';

void main() {
  test('valid seven-day package exposes only approved Boss routes', () {
    final package = RemoteSeasonPackageMapper.fromSnapshot(_snapshot());

    expect(package.season.days.map((day) => day.day), [1, 2, 3, 4, 5, 6, 7]);
    expect(package.boss.supportsRoute(ChallengeRouteType.normal), isTrue);
    expect(package.boss.supportsRoute(ChallengeRouteType.lowPressure), isTrue);
    expect(package.boss.supportsRoute(ChallengeRouteType.advanced), isTrue);
    expect(package.artifacts.single.artifactId, 'founder_social_reset');
  });

  test('social number stays unavailable below threshold or outside window', () {
    final belowThreshold = RemoteSeasonPackageMapper.fromSnapshot(
      _snapshot(socialValue: 19),
    ).socialProof!;
    final qualified = RemoteSeasonPackageMapper.fromSnapshot(
      _snapshot(socialValue: 20),
    ).socialProof!;

    expect(belowThreshold.qualifiedValueAt(DateTime.utc(2026, 8, 4)), isNull);
    expect(qualified.qualifiedValueAt(DateTime.utc(2026, 8, 4)), 20);
    expect(qualified.qualifiedValueAt(DateTime.utc(2026, 8, 9)), isNull);
  });

  test('incomplete seven-day package is rejected', () {
    final snapshot = _snapshot();
    final payload = Map<String, dynamic>.from(snapshot.payload)
      ..['days'] = (snapshot.payload['days'] as List).take(6).toList();

    expect(
      () => RemoteSeasonPackageMapper.fromSnapshot(_copy(snapshot, payload)),
      throwsFormatException,
    );
  });

  test('out-of-order season days are rejected', () {
    final snapshot = _snapshot();
    final payload = Map<String, dynamic>.from(snapshot.payload)
      ..['days'] = (snapshot.payload['days'] as List).reversed.toList();

    expect(
      () => RemoteSeasonPackageMapper.fromSnapshot(_copy(snapshot, payload)),
      throwsFormatException,
    );
  });

  test('unapproved advanced Boss route is rejected', () {
    final snapshot = _snapshot();
    final payload = Map<String, dynamic>.from(snapshot.payload);
    final boss = Map<String, dynamic>.from(payload['boss'] as Map)
      ..['advancedRouteSafetyApproved'] = false;
    payload['boss'] = boss;

    expect(
      () => RemoteSeasonPackageMapper.fromSnapshot(_copy(snapshot, payload)),
      throwsFormatException,
    );
  });
}

RemoteSeasonSnapshot _snapshot({int socialValue = 24}) => RemoteSeasonSnapshot(
  seasonId: 'season_social_reset_0',
  revision: 1,
  title: 'Social Reset',
  startsAt: DateTime.utc(2026, 8, 1),
  endsAt: DateTime.utc(2026, 8, 8),
  payload: {
    'days': [
      for (var day = 1; day <= 7; day++)
        {
          'day': day,
          'title': 'Day $day',
          'featuredContentIds': ['season_day_$day'],
        },
    ],
    'boss': {
      'bossEventId': 'boss_social_reset',
      'contentId': 'boss_social_reset_content',
      'contentRevision': 1,
      'startsAt': '2026-08-07T12:00:00.000Z',
      'endsAt': '2026-08-08T00:00:00.000Z',
      'normalRoute': {'copy': 'Complete the public route'},
      'lowPressureRoute': {'copy': 'Complete the private route'},
      'advancedRoute': {'copy': 'Complete the advanced route'},
      'advancedRouteSafetyApproved': true,
    },
    'artifacts': [
      {'artifactId': 'founder_social_reset', 'title': 'Founder'},
    ],
    'socialProof': {
      'aggregateKey': 'season_social_reset_participants',
      'value': socialValue,
      'threshold': 20,
      'windowStartsAt': '2026-08-01T00:00:00.000Z',
      'windowEndsAt': '2026-08-08T00:00:00.000Z',
    },
  },
);

RemoteSeasonSnapshot _copy(
  RemoteSeasonSnapshot source,
  Map<String, dynamic> payload,
) => RemoteSeasonSnapshot(
  seasonId: source.seasonId,
  revision: source.revision,
  title: source.title,
  startsAt: source.startsAt,
  endsAt: source.endsAt,
  payload: payload,
);
