import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import 'app/composition/app_composition_root.dart';
import 'app/composition/app_remote_orchestrator.dart';
import 'app/vnext/vnext_runtime.dart';
import 'application/today_controller.dart';
import 'data/catalog/bundled_quest_catalog.dart';
import 'data/catalog/bundled_guide_catalog.dart';
import 'data/catalog/bundled_dialog_catalog.dart';
import 'data/catalog/bundled_modifier_catalog.dart';
import 'domain/services/game_engine.dart';
import 'content/data/bundled_vnext_content_adapter.dart';
import 'core/clock/mayhem_clock.dart';
import 'core/clock/platform_timezone_id.dart';
import 'core/feature_flags/feature_flag_runtime.dart';
import 'infrastructure/sqlite/sqflite_game_store.dart';
import 'infrastructure/security/flutter_secure_session_store.dart';
import 'presentation/theme/mayhem_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  try {
    final catalog = await BundledQuestCatalog.load(rootBundle);
    final guides = await BundledGuideCatalog.load(rootBundle);
    final dialogs = await BundledDialogCatalog.load(rootBundle);
    final modifiers = await BundledModifierCatalog.load(rootBundle);
    guides.validateCoverage([
      ...catalog.quests.map((quest) => quest.id),
      ...catalog.bosses.map((quest) => quest.id),
    ]);
    dialogs.validateCoverage([
      ...catalog.quests
          .where((quest) => !quest.isShadow && quest.level >= 2)
          .map((quest) => quest.id),
      ...catalog.bosses.map((quest) => quest.id),
    ]);
    final store = await SqfliteGameStore.open();
    await store.getOrCreateInstallationId(const Uuid().v4);
    final controller = TodayController(
      store,
      catalog,
      guides,
      dialogs,
      modifiers,
      GameEngine(const Uuid().v4),
    );
    await controller.initialize();
    final featureFlags = FeatureFlagRuntime.fromEnvironment();
    final secureSessions = FlutterSecureSessionStore(
      storage: FlutterSecureKeyValueStore(),
      environment: const String.fromEnvironment(
        'MAYHEM_ENVIRONMENT',
        defaultValue: 'development',
      ),
    );
    VNextRuntime? vnextRuntime;
    try {
      final timezoneId = await PlatformTimezoneId.load();
      vnextRuntime = VNextRuntime(
        store: store.createVNextStore(),
        bundled: const BundledVNextContentAdapter().adapt(
          catalog,
          publishedAt: DateTime.utc(2026, 7, 1),
          guides: guides,
          dialogs: dialogs,
        ),
        featureFlags: featureFlags,
        idGenerator: const Uuid().v4,
        clock: SystemMayhemClock(timezoneIdProvider: () => timezoneId),
      );
    } catch (error, stackTrace) {
      developer.log(
        'vNext local runtime unavailable; legacy Today remains active',
        name: 'mayhem.composition',
        error: error.runtimeType,
        stackTrace: stackTrace,
      );
    }
    final composition = AppCompositionRoot(
      legacyController: controller,
      featureFlags: featureFlags,
      vnextRuntime: vnextRuntime,
      secureSessions: secureSessions,
      remote: const DisabledAppRemoteOrchestrator(
        'supabase_remote_not_composed',
      ),
      closeLocalStore: store.close,
    );
    runApp(composition.buildApp());
    unawaited(composition.startRemoteBootstrap());
  } catch (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'mayhem bootstrap',
      ),
    );
    runApp(const _BootstrapFailureApp());
  }
}

class _BootstrapFailureApp extends StatelessWidget {
  const _BootstrapFailureApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: MayhemTheme.dark,
      home: const Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Не удалось запустить локальное хранилище. Перезапусти приложение.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
