import 'package:flutter_test/flutter_test.dart';
import 'package:mayhem_mobile/features/season/application/artifact_ownership_controller.dart';
import 'package:mayhem_mobile/features/season/application/season_package_store.dart';
import 'package:mayhem_mobile/features/season/domain/artifact_ownership.dart';
import 'package:mayhem_mobile/features/season/domain/season_models.dart';
import 'package:mayhem_mobile/features/challenge/domain/challenge_models.dart';
import 'package:mayhem_mobile/features/sync/domain/backend_models.dart';

void main() {
  test(
    'presentation exposes only ownership matching the active package',
    () async {
      final now = DateTime.utc(2026, 7, 14, 12);
      final controller = ArtifactOwnershipController(
        ownership: _Ownership([
          _owned('founder-1', 'season-0', 1),
          _owned('founder-old', 'season-old', 1),
        ]),
        packages: _Packages(_package(now)),
        clock: () => now,
      );

      await controller.initialize();

      expect(controller.error, isNull);
      expect(controller.artifacts, hasLength(1));
      expect(controller.artifacts.single.artifactId, 'founder-1');
      expect(controller.artifacts.single.title, 'Первопроходец');
    },
  );
}

OwnedFounderArtifact _owned(String id, String seasonId, int revision) =>
    OwnedFounderArtifact(
      artifactId: id,
      seasonId: seasonId,
      seasonRevision: revision,
      bossEventId: 'boss-0',
      unlockedAt: DateTime.utc(2026, 7, 14, 10),
    );

SeasonPackage _package(DateTime now) => SeasonPackage(
  season: Season(
    seasonId: 'season-0',
    revision: 1,
    title: 'Нулевая неделя',
    startsAt: now.subtract(const Duration(days: 3)),
    endsAt: now.add(const Duration(days: 4)),
    days: [
      for (var day = 1; day <= 7; day++)
        SeasonDay(day: day, title: 'День $day', featuredContentIds: ['q-$day']),
    ],
    bossEventId: 'boss-0',
    rewardArtifactIds: const ['founder-1'],
  ),
  boss: BossEventDefinition(
    bossEventId: 'boss-0',
    contentId: 'boss-content',
    contentRevision: 1,
    startsAt: now.subtract(const Duration(hours: 1)),
    endsAt: now.add(const Duration(hours: 1)),
    normalRoute: const ChallengeRoute(copy: 'Сделай шаг'),
    lowPressureRoute: const ChallengeRoute(copy: 'Сделай малый шаг'),
  ),
  artifacts: [
    FounderArtifactDefinition(artifactId: 'founder-1', title: 'Первопроходец'),
  ],
);

class _Ownership implements ArtifactOwnershipRepository {
  const _Ownership(this.artifacts);

  final List<OwnedFounderArtifact> artifacts;

  @override
  Future<List<OwnedFounderArtifact>> loadOwnedArtifacts() async => artifacts;
}

class _Packages implements SeasonPackageStore {
  const _Packages(this.package);

  final SeasonPackage? package;

  @override
  Future<void> clear() async {}

  @override
  Future<SeasonPackage?> loadActivePackage(DateTime atUtc) async => package;

  @override
  Future<void> saveValidatedSnapshot(RemoteSeasonSnapshot snapshot) async {}
}
