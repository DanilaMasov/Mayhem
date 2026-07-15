import 'package:flutter_test/flutter_test.dart';
import 'package:mayhem_mobile/core/feature_flags/feature_flags.dart';
import 'package:mayhem_mobile/features/season/application/season_bootstrap_activator.dart';
import 'package:mayhem_mobile/features/sync/domain/backend_models.dart';
import 'package:mayhem_mobile/infrastructure/sqlite/sqlite_season_package_store.dart';
import 'package:mayhem_mobile/infrastructure/sqlite/sqlite_vnext_context.dart';

import '../../support/memory_vnext_database.dart';

void main() {
  test('local or remote kill switch removes the cached package', () async {
    final store = _store();
    await store.saveValidatedSnapshot(_snapshot());
    final activator = SeasonBootstrapActivator(
      localActivationEnabled: false,
      store: store,
    );

    final result = await activator.apply(
      snapshot: _snapshot(),
      flags: _flags(season: true, boss: true, social: true),
    );

    expect(result, SeasonActivationStatus.disabled);
    expect(await store.loadActivePackage(DateTime.utc(2026, 8, 4)), isNull);

    await store.saveValidatedSnapshot(_snapshot());
    final remoteKillSwitch = SeasonBootstrapActivator(
      localActivationEnabled: true,
      store: store,
    );
    expect(
      await remoteKillSwitch.apply(
        snapshot: _snapshot(),
        flags: _flags(season: true, boss: false, social: true),
      ),
      SeasonActivationStatus.disabled,
    );
    expect(await store.loadActivePackage(DateTime.utc(2026, 8, 4)), isNull);
  });

  test(
    'activation caches a validated package without disabled social data',
    () async {
      final store = _store();
      final activator = SeasonBootstrapActivator(
        localActivationEnabled: true,
        store: store,
      );

      final result = await activator.apply(
        snapshot: _snapshot(),
        flags: _flags(season: true, boss: true, social: false),
      );
      final package = await store.loadActivePackage(DateTime.utc(2026, 8, 4));

      expect(result, SeasonActivationStatus.activated);
      expect(package?.season.seasonId, 'season_social_reset_0');
      expect(package?.socialProof, isNull);
    },
  );

  test(
    'qualified social data survives only when its flag is enabled',
    () async {
      final store = _store();
      final activator = SeasonBootstrapActivator(
        localActivationEnabled: true,
        store: store,
      );

      await activator.apply(
        snapshot: _snapshot(),
        flags: _flags(season: true, boss: true, social: true),
      );
      final package = await store.loadActivePackage(DateTime.utc(2026, 8, 4));

      expect(
        package?.socialProof?.qualifiedValueAt(DateTime.utc(2026, 8, 4)),
        24,
      );
      expect(await store.loadActivePackage(DateTime.utc(2026, 8, 8)), isNull);
    },
  );

  test('invalid replacement cannot overwrite the last valid cache', () async {
    final database = MemoryVNextDatabase();
    final store = SqliteSeasonPackageStore(SqliteVNextContext(database));
    final activator = SeasonBootstrapActivator(
      localActivationEnabled: true,
      store: store,
    );
    final valid = _snapshot();
    await activator.apply(
      snapshot: valid,
      flags: _flags(season: true, boss: true, social: true),
    );
    final payload = Map<String, dynamic>.from(valid.payload)
      ..['days'] = (valid.payload['days'] as List).take(6).toList();

    await expectLater(
      () => activator.apply(
        snapshot: _copy(valid, payload),
        flags: _flags(season: true, boss: true, social: true),
      ),
      throwsFormatException,
    );

    final restored = await store.loadActivePackage(DateTime.utc(2026, 8, 4));
    expect(restored?.season.seasonId, valid.seasonId);
    expect(database.executor.rows('app_metadata'), hasLength(1));
  });

  test('corrupt cached snapshot is deleted fail-closed', () async {
    final database = MemoryVNextDatabase(
      seed: {
        'app_metadata': [
          {
            'key': 'season.active_package.v1',
            'value': '{broken-json',
            'updated_at': '2026-07-14T00:00:00.000Z',
          },
        ],
      },
    );
    final store = SqliteSeasonPackageStore(SqliteVNextContext(database));

    expect(await store.loadActivePackage(DateTime.utc(2026, 8, 4)), isNull);
    expect(database.executor.rows('app_metadata'), isEmpty);
  });
}

SqliteSeasonPackageStore _store() => SqliteSeasonPackageStore(
  SqliteVNextContext(
    MemoryVNextDatabase(),
    clock: () => DateTime.utc(2026, 7, 14),
  ),
);

FeatureFlagSnapshot _flags({
  required bool season,
  required bool boss,
  required bool social,
}) => FeatureFlagSnapshot(
  values: {
    MayhemFeatureFlag.seasonZeroEnabled: season,
    MayhemFeatureFlag.bossRaidEnabled: boss,
    MayhemFeatureFlag.socialProofEnabled: social,
  },
);

RemoteSeasonSnapshot _snapshot() => RemoteSeasonSnapshot(
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
      'value': 24,
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
