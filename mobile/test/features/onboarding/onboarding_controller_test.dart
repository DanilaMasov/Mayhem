import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mayhem_mobile/core/metadata/local_metadata_repository.dart';
import 'package:mayhem_mobile/features/onboarding/application/onboarding_controller.dart';
import 'package:mayhem_mobile/features/onboarding/data/local_onboarding_repository.dart';
import 'package:mayhem_mobile/features/onboarding/domain/onboarding_models.dart';
import 'package:mayhem_mobile/features/progress/domain/development_rank_config.dart';
import 'package:mayhem_mobile/features/progress/domain/progress_models.dart';
import 'package:mayhem_mobile/features/progress/domain/progress_repository.dart';

void main() {
  test(
    'fresh onboarding persists calibration and seeds initial projection',
    () async {
      final metadata = _MemoryMetadata();
      final progress = _MemoryProgress();
      final controller = OnboardingController(
        repository: LocalOnboardingRepository(metadata),
        progressRepository: progress,
        clock: () => DateTime.utc(2026, 7, 13),
      );

      await controller.initialize(
        legacyUserHasProgress: false,
        legacySafetyAccepted: false,
      );
      expect(controller.progress.stage, OnboardingStage.opening);
      await controller.begin();
      for (
        var index = 0;
        index < CalibrationPolicy.traitOrder.length;
        index++
      ) {
        await controller.answer(CalibrationPolicy.traitOrder[index], index);
      }
      expect(controller.progress.stage, OnboardingStage.safety);
      expect(await controller.acceptSafety(), isFalse);
      expect(controller.progress.stage, OnboardingStage.profileReveal);
      await controller.completeProfileReveal();

      expect(controller.progress.isComplete, isTrue);
      expect(
        progress.value?.rank.configRevision,
        DevelopmentRankConfig.revision,
      );
      expect(progress.value?.rank.label, 'ИСКРА');
      expect(
        progress.value?.difficulty[CalibrationPolicy.traitOrder.first]?.rating,
        3.5,
      );
      expect(
        jsonDecode(metadata.values[LocalOnboardingRepository.metadataKey]!)
            as Map<String, dynamic>,
        containsPair(
          'acceptedSafetyRevision',
          CalibrationPolicy.safetyRevision,
        ),
      );
    },
  );

  test('migrated user with accepted safety bypasses full onboarding', () async {
    final controller = OnboardingController(
      repository: LocalOnboardingRepository(_MemoryMetadata()),
      progressRepository: _MemoryProgress(),
    );

    await controller.initialize(
      legacyUserHasProgress: true,
      legacySafetyAccepted: true,
    );

    expect(controller.progress.isComplete, isTrue);
    expect(controller.progress.migratedFromLegacy, isTrue);
    expect(controller.progress.answerIndexByTrait, isEmpty);
  });

  test('stale accepted revision shows only the new safety step', () async {
    final metadata = _MemoryMetadata()
      ..values[LocalOnboardingRepository.metadataKey] = jsonEncode({
        'stage': 'completed',
        'calibrationRevision': CalibrationPolicy.revision,
        'answerIndexByTrait': const <String, int>{},
        'acceptedSafetyRevision': 0,
        'migratedFromLegacy': true,
      });
    final controller = OnboardingController(
      repository: LocalOnboardingRepository(metadata),
      progressRepository: _MemoryProgress(),
    );

    await controller.initialize(
      legacyUserHasProgress: true,
      legacySafetyAccepted: true,
    );

    expect(controller.progress.stage, OnboardingStage.safety);
    expect(await controller.acceptSafety(), isTrue);
    expect(controller.progress.isComplete, isTrue);
  });
}

class _MemoryMetadata implements LocalMetadataRepository {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

class _MemoryProgress implements ProgressRepository {
  ProgressProjection? value;

  @override
  Future<ProgressProjection?> loadProjection() async => value;

  @override
  Future<void> saveProjection(ProgressProjection projection) async {
    value = projection;
  }
}
