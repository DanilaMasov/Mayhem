import 'dart:convert';
import 'dart:io';

import 'package:mayhem_mobile/app/vnext/vnext_runtime.dart';
import 'package:mayhem_mobile/content/data/bundled_vnext_content_adapter.dart';
import 'package:mayhem_mobile/core/clock/mayhem_clock.dart';
import 'package:mayhem_mobile/core/feature_flags/feature_flag_runtime.dart';
import 'package:mayhem_mobile/core/feature_flags/feature_flags.dart';
import 'package:mayhem_mobile/data/catalog/bundled_quest_catalog.dart';
import 'package:mayhem_mobile/data/catalog/bundled_guide_catalog.dart';
import 'package:mayhem_mobile/data/catalog/bundled_dialog_catalog.dart';
import 'package:mayhem_mobile/features/onboarding/data/local_onboarding_repository.dart';
import 'package:mayhem_mobile/features/onboarding/domain/onboarding_models.dart';
import 'package:mayhem_mobile/infrastructure/sqlite/sqlite_vnext_store.dart';

import 'memory_vnext_database.dart';

Future<VNextRuntime> buildVNextTestRuntime({
  MemoryVNextDatabase? database,
  FeatureFlagRuntime? featureFlags,
  Map<MayhemFeatureFlag, bool> debugOverrides = const {
    MayhemFeatureFlag.newFeedEnabled: true,
  },
}) async {
  final catalog = BundledQuestCatalog.fromJson(
    jsonDecode(await File('assets/content/quest_catalog.json').readAsString())
        as Map<String, dynamic>,
  );
  final guides = BundledGuideCatalog.fromJson(
    jsonDecode(await File('assets/content/guide_catalog.json').readAsString())
        as Map<String, dynamic>,
  );
  final dialogs = BundledDialogCatalog.fromJson(
    jsonDecode(await File('assets/content/dialog_catalog.json').readAsString())
        as Map<String, dynamic>,
  );
  final store = SqliteVNextStore(
    database ?? buildVNextTestDatabase(),
    clock: () => DateTime.utc(2026, 7, 13, 9),
  );
  var id = 0;
  final runtime = VNextRuntime(
    store: store,
    bundled: const BundledVNextContentAdapter().adapt(
      catalog,
      publishedAt: DateTime.utc(2026, 7, 1),
      guides: guides,
      dialogs: dialogs,
    ),
    featureFlags:
        featureFlags ??
        FeatureFlagRuntime.resolve(
          debugBuild: true,
          requestedDebugOverrides: debugOverrides,
        ),
    idGenerator: () => 'phase4-${++id}',
    clock: FixedMayhemClock(
      now: DateTime.utc(2026, 7, 13, 9),
      timezoneId: 'Europe/Moscow',
    ),
    timezoneOffsetMinutes: () => 180,
  );
  await runtime.initialize(
    legacyUserHasProgress: false,
    legacySafetyAccepted: false,
  );
  return runtime;
}

MemoryVNextDatabase buildVNextTestDatabase({bool onboardingComplete = true}) =>
    MemoryVNextDatabase(
      seed: {
        'user_identity': [
          {
            'local_user_id': 'local-user-phase-4',
            'installation_id': 'installation-phase-4',
            'remote_user_id': null,
          },
        ],
        'app_metadata': [
          {
            'key': 'client_sequence:installation-phase-4',
            'value': '0',
            'updated_at': '2026-07-13T09:00:00.000Z',
          },
          if (onboardingComplete)
            {
              'key': LocalOnboardingRepository.metadataKey,
              'value': jsonEncode(
                OnboardingProgress.migrated(safetyAccepted: true).toJson(),
              ),
              'updated_at': '2026-07-13T09:00:00.000Z',
            },
        ],
      },
    );
