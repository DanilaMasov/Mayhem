import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mayhem_mobile/app/composition/app_composition_root.dart';
import 'package:mayhem_mobile/app/composition/app_remote_orchestrator.dart';
import 'package:mayhem_mobile/app/composition/app_telemetry.dart';
import 'package:mayhem_mobile/application/today_controller.dart';
import 'package:mayhem_mobile/core/feature_flags/feature_flag_runtime.dart';
import 'package:mayhem_mobile/domain/models/game_state.dart';
import 'package:mayhem_mobile/domain/services/game_engine.dart';

import '../support/fakes.dart';

void main() {
  testWidgets('local Today renders while remote bootstrap is pending', (
    tester,
  ) async {
    final gate = Completer<void>();
    final remote = _RemoteOrchestrator(bootstrapGate: gate);
    final harness = await _buildHarness(remote);

    await tester.pumpWidget(harness.root.buildApp());
    expect(find.text('ВЫЗОВ ДНЯ'), findsOneWidget);

    final bootstrap = harness.root.startRemoteBootstrap();
    expect(harness.root.remoteStatus, AppRemoteRuntimeStatus.bootstrapping);
    await tester.pump();
    expect(find.text('ВЫЗОВ ДНЯ'), findsOneWidget);

    gate.complete();
    expect(await bootstrap, AppRemoteRuntimeStatus.ready);
    expect(find.text('ВЫЗОВ ДНЯ'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await harness.root.shutdown();
    expect(harness.localCloseCalls, 1);
  });

  testWidgets('remote failure degrades without replacing local UI', (
    tester,
  ) async {
    final telemetry = _Telemetry();
    final remote = _RemoteOrchestrator(
      bootstrapError: StateError('access-token-must-not-leak'),
    );
    final harness = await _buildHarness(remote, telemetry: telemetry);

    await tester.pumpWidget(harness.root.buildApp());
    final status = await harness.root.startRemoteBootstrap();
    await tester.pump();

    expect(status, AppRemoteRuntimeStatus.degraded);
    expect(harness.root.remoteErrorCode, 'remote_bootstrap_StateError');
    expect(find.text('ВЫЗОВ ДНЯ'), findsOneWidget);
    expect(telemetry.serialized, isNot(contains('access-token-must-not-leak')));

    await tester.pumpWidget(const SizedBox.shrink());
    await harness.root.shutdown();
  });

  testWidgets('foreground orchestration runs only when app resumes', (
    tester,
  ) async {
    final remote = _RemoteOrchestrator();
    final harness = await _buildHarness(remote);
    await tester.pumpWidget(harness.root.buildApp());
    expect(
      await harness.root.startRemoteBootstrap(),
      AppRemoteRuntimeStatus.ready,
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(remote.foregroundCalls, 0);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(remote.foregroundCalls, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await harness.root.shutdown();
  });

  testWidgets('shutdown cancels pending bootstrap and closes local state', (
    tester,
  ) async {
    final gate = Completer<void>();
    final remote = _RemoteOrchestrator(
      bootstrapGate: gate,
      completeBootstrapOnClose: true,
    );
    final harness = await _buildHarness(remote);
    await tester.pumpWidget(harness.root.buildApp());
    final bootstrap = harness.root.startRemoteBootstrap();

    await tester.pumpWidget(const SizedBox.shrink());
    await harness.root.shutdown();

    expect(await bootstrap, AppRemoteRuntimeStatus.disposed);
    expect(remote.cancellation?.isCancelled, isTrue);
    expect(remote.closeCalls, 1);
    expect(harness.localCloseCalls, 1);
    expect(harness.root.remoteStatus, AppRemoteRuntimeStatus.disposed);
  });

  testWidgets('disabled remote bootstrap is idempotent and honest', (
    tester,
  ) async {
    final telemetry = _Telemetry();
    final harness = await _buildHarness(
      const DisabledAppRemoteOrchestrator('secure_store_unavailable'),
      telemetry: telemetry,
    );
    await tester.pumpWidget(harness.root.buildApp());

    final first = harness.root.startRemoteBootstrap();
    final second = harness.root.startRemoteBootstrap();

    expect(identical(first, second), isTrue);
    expect(await first, AppRemoteRuntimeStatus.disabled);
    expect(harness.root.remoteErrorCode, 'secure_store_unavailable');
    expect(telemetry.events, ['remote_runtime_disabled']);
    expect(find.text('ВЫЗОВ ДНЯ'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await harness.root.shutdown();
  });
}

Future<_Harness> _buildHarness(
  AppRemoteOrchestrator remote, {
  AppTelemetry telemetry = const NoOpAppTelemetry(),
}) async {
  final store = MemoryGameStore();
  store.state = GameState.initial(DateTime(2026, 7, 15, 13)).copyWith(
    completedCount: 3,
    onboarding: const OnboardingState(boundariesAcknowledged: true),
  );
  final controller = TodayController(
    store,
    buildTestCatalog(),
    buildTestGuideCatalog(),
    buildTestDialogCatalog(),
    buildTestModifierCatalog(),
    GameEngine(() => 'composition-event'),
    clock: () => DateTime(2026, 7, 15, 13),
  );
  await controller.initialize();
  var localCloseCalls = 0;
  late final _Harness harness;
  final root = AppCompositionRoot(
    legacyController: controller,
    featureFlags: FeatureFlagRuntime.safe(),
    vnextRuntime: null,
    remote: remote,
    telemetry: telemetry,
    closeLocalStore: () async {
      localCloseCalls += 1;
      harness.localCloseCalls = localCloseCalls;
    },
  );
  harness = _Harness(root);
  return harness;
}

class _Harness {
  _Harness(this.root);

  final AppCompositionRoot root;
  int localCloseCalls = 0;
}

class _RemoteOrchestrator implements AppRemoteOrchestrator {
  _RemoteOrchestrator({
    this.bootstrapGate,
    this.bootstrapError,
    this.completeBootstrapOnClose = false,
  });

  final Completer<void>? bootstrapGate;
  final Object? bootstrapError;
  final bool completeBootstrapOnClose;
  AppCancellationSignal? cancellation;
  int bootstrapCalls = 0;
  int foregroundCalls = 0;
  int closeCalls = 0;

  @override
  bool get enabled => true;

  @override
  String? get disabledReason => null;

  @override
  Future<void> bootstrap(AppCancellationSignal cancellation) async {
    bootstrapCalls += 1;
    this.cancellation = cancellation;
    if (bootstrapError != null) throw bootstrapError!;
    await bootstrapGate?.future;
    cancellation.throwIfCancelled();
  }

  @override
  Future<void> onForeground(AppCancellationSignal cancellation) async {
    cancellation.throwIfCancelled();
    foregroundCalls += 1;
  }

  @override
  Future<void> close() async {
    closeCalls += 1;
    if (completeBootstrapOnClose && bootstrapGate?.isCompleted == false) {
      bootstrapGate!.complete();
    }
  }
}

class _Telemetry implements AppTelemetry {
  final List<String> events = [];
  final List<Map<String, Object?>> fields = [];

  String get serialized => '$events $fields';

  @override
  void record(String event, {Map<String, Object?> fields = const {}}) {
    events.add(event);
    this.fields.add(Map.unmodifiable(fields));
  }
}
