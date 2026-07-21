import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mayhem_mobile/app/composition/remote_runtime_diagnostics.dart';
import 'package:mayhem_mobile/core/feature_flags/feature_flag_runtime.dart';
import 'package:mayhem_mobile/core/localization/mayhem_strings.dart';
import 'package:mayhem_mobile/core/metadata/local_metadata_repository.dart';
import 'package:mayhem_mobile/core/support/support_contact.dart';
import 'package:mayhem_mobile/core/support/support_contact_scope.dart';
import 'package:mayhem_mobile/features/settings/application/settings_controller.dart';
import 'package:mayhem_mobile/features/settings/application/remote_account_controller.dart';
import 'package:mayhem_mobile/features/settings/data/local_user_preferences_repository.dart';
import 'package:mayhem_mobile/features/settings/presentation/vnext_settings_screen.dart';
import 'package:mayhem_mobile/presentation/theme/mayhem_theme.dart';

void main() {
  testWidgets('release settings exposes only controls with a real effect', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final metadata = _MemoryMetadata()
      ..values[LocalUserPreferencesRepository.metadataKey] = jsonEncode({
        'reduceMotion': false,
        'reduceTransparency': false,
        'hapticsEnabled': false,
        'soundEnabled': false,
        'ceremoniesEnabled': false,
        'locale': 'ru-RU',
      });
    final controller = SettingsController(
      LocalUserPreferencesRepository(metadata),
    );
    await controller.initialize();
    final flags = FeatureFlagRuntime.safe();
    addTearDown(flags.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: MayhemTheme.dark,
        builder: (context, child) =>
            MayhemStringsScope(strings: const MayhemStringsRu(), child: child!),
        home: VNextSettingsScreen(
          controller: controller,
          featureFlags: flags,
          onResetLocalData: () async {},
        ),
      ),
    );

    expect(controller.preferences.hapticsEnabled, isFalse);
    expect(controller.preferences.soundEnabled, isFalse);
    expect(controller.preferences.ceremoniesEnabled, isFalse);
    expect(find.byType(SwitchListTile), findsNWidgets(2));
    expect(find.text('ОТКЛИК'), findsNothing);
    expect(find.text('Тактильный отклик'), findsNothing);
    expect(find.text('Звук'), findsNothing);
    expect(find.text('Сцены награды'), findsNothing);
    expect(find.text('Уведомления'), findsNothing);
    expect(find.text('СВЯЗАТЬСЯ С ПОДДЕРЖКОЙ'), findsNothing);

    await tester.tap(find.text('Уменьшить движение'));
    await tester.pump();

    expect(controller.preferences.reduceMotion, isTrue);
    final persisted =
        jsonDecode(metadata.values[LocalUserPreferencesRepository.metadataKey]!)
            as Map<String, dynamic>;
    expect(persisted['reduceMotion'], isTrue);
  });

  testWidgets('configured support contact opens the exact validated URI', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = SettingsController(
      LocalUserPreferencesRepository(_MemoryMetadata()),
    );
    await controller.initialize();
    final flags = FeatureFlagRuntime.safe();
    addTearDown(flags.dispose);
    final contact = SupportContact.resolve(
      'https://support.example.com/mayhem',
    )!;
    Uri? opened;

    await tester.pumpWidget(
      MaterialApp(
        theme: MayhemTheme.dark,
        builder: (context, child) => MayhemStringsScope(
          strings: const MayhemStringsRu(),
          child: MayhemSupportContactScope(
            contact: contact,
            opener: (uri) async {
              opened = uri;
              return true;
            },
            child: child!,
          ),
        ),
        home: VNextSettingsScreen(
          controller: controller,
          featureFlags: flags,
          onResetLocalData: () async {},
        ),
      ),
    );

    const label = 'СВЯЗАТЬСЯ С ПОДДЕРЖКОЙ';
    await tester.scrollUntilVisible(find.text(label), 300);
    expect(
      find.text('Откроется внешний канал поддержки: support.example.com.'),
      findsOneWidget,
    );
    await tester.tap(find.text(label));
    await tester.pump();

    expect(opened, contact.uri);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('support launch failure remains recoverable and explicit', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = SettingsController(
      LocalUserPreferencesRepository(_MemoryMetadata()),
    );
    await controller.initialize();
    final flags = FeatureFlagRuntime.safe();
    addTearDown(flags.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: MayhemTheme.dark,
        builder: (context, child) => MayhemStringsScope(
          strings: const MayhemStringsRu(),
          child: MayhemSupportContactScope(
            contact: SupportContact.resolve('help@example.com'),
            opener: (_) async => false,
            child: child!,
          ),
        ),
        home: VNextSettingsScreen(
          controller: controller,
          featureFlags: flags,
          onResetLocalData: () async {},
        ),
      ),
    );

    const label = 'СВЯЗАТЬСЯ С ПОДДЕРЖКОЙ';
    await tester.scrollUntilVisible(find.text(label), 300);
    await tester.tap(find.text(label));
    await tester.pump();

    expect(
      find.text('Не удалось открыть канал поддержки на этом устройстве.'),
      findsOneWidget,
    );
  });

  testWidgets('privacy section discloses thresholded social aggregates', (
    tester,
  ) async {
    final controller = SettingsController(
      LocalUserPreferencesRepository(_MemoryMetadata()),
    );
    await controller.initialize();
    final flags = FeatureFlagRuntime.safe();
    addTearDown(flags.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: MayhemTheme.dark,
        builder: (context, child) =>
            MayhemStringsScope(strings: const MayhemStringsRu(), child: child!),
        home: VNextSettingsScreen(
          controller: controller,
          featureFlags: flags,
          onResetLocalData: () async {},
        ),
      ),
    );

    final disclosure = const MayhemStringsRu().socialAggregatePrivacy;
    await tester.scrollUntilVisible(find.text(disclosure), 300);

    expect(find.text(disclosure), findsOneWidget);
  });

  testWidgets('successful device reset always leaves loading state', (
    tester,
  ) async {
    final controller = SettingsController(
      LocalUserPreferencesRepository(_MemoryMetadata()),
    );
    await controller.initialize();
    final flags = FeatureFlagRuntime.safe();
    addTearDown(flags.dispose);
    var resetCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: MayhemTheme.dark,
        builder: (context, child) =>
            MayhemStringsScope(strings: const MayhemStringsRu(), child: child!),
        home: VNextSettingsScreen(
          controller: controller,
          featureFlags: flags,
          onResetLocalData: () async => resetCalls += 1,
        ),
      ),
    );

    const resetLabel = 'СБРОСИТЬ ДАННЫЕ НА ЭТОМ УСТРОЙСТВЕ';
    await tester.scrollUntilVisible(find.text(resetLabel), 300);
    await tester.tap(find.text(resetLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.text('СБРОСИТЬ').last);
    await tester.pumpAndSettle();

    expect(resetCalls, 1);
    expect(find.text(resetLabel), findsOneWidget);

    await tester.tap(find.text(resetLabel));
    await tester.pumpAndSettle();
    expect(find.text('Сбросить данные на устройстве?'), findsOneWidget);
  });

  testWidgets('diagnostics renders live remote and session state', (
    tester,
  ) async {
    final flags = FeatureFlagRuntime.safe();
    final runtime = _RemoteDiagnostics();
    final account = _AccountDiagnostics();
    addTearDown(flags.dispose);
    addTearDown(runtime.dispose);
    addTearDown(account.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: MayhemTheme.dark,
        builder: (context, child) =>
            MayhemStringsScope(strings: const MayhemStringsRu(), child: child!),
        home: VNextDiagnosticsScreen(
          featureFlags: flags,
          remoteDiagnostics: runtime,
          remoteAccount: account,
        ),
      ),
    );

    await tester.scrollUntilVisible(find.text('remote.config'), 300);
    expect(find.text('configured'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('remote.runtime'), 120);
    expect(find.text('bootstrapping'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('remote.session'), 120);
    expect(find.text('unavailable'), findsAtLeastNWidgets(1));

    runtime.update(AppRemoteRuntimeStatus.ready);
    account.update(RemoteAccountStatus.ready, sessionAvailable: true);
    await tester.pump();
    expect(find.text('ready'), findsNWidgets(2));
    expect(find.text('available'), findsOneWidget);

    runtime.update(
      AppRemoteRuntimeStatus.degraded,
      errorCode: 'network_timeout',
    );
    await tester.pump();
    expect(find.text('degraded'), findsOneWidget);
    expect(find.text('network_timeout'), findsOneWidget);
  });
}

class _MemoryMetadata implements LocalMetadataRepository {
  final Map<String, String> values = {};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

class _RemoteDiagnostics extends ChangeNotifier
    implements RemoteRuntimeDiagnostics {
  @override
  bool get remoteConfigured => true;

  AppRemoteRuntimeStatus _status = AppRemoteRuntimeStatus.bootstrapping;
  String? _errorCode;

  @override
  String? get remoteErrorCode => _errorCode;

  @override
  AppRemoteRuntimeStatus get remoteStatus => _status;

  void update(AppRemoteRuntimeStatus status, {String? errorCode}) {
    _status = status;
    _errorCode = errorCode;
    notifyListeners();
  }
}

class _AccountDiagnostics extends ChangeNotifier
    implements RemoteAccountDiagnostics {
  RemoteAccountStatus _status = RemoteAccountStatus.unavailable;
  bool _sessionAvailable = false;

  @override
  String? get errorCode => null;

  @override
  bool get sessionAvailable => _sessionAvailable;

  @override
  RemoteAccountStatus get status => _status;

  void update(RemoteAccountStatus status, {required bool sessionAvailable}) {
    _status = status;
    _sessionAvailable = sessionAvailable;
    notifyListeners();
  }
}
