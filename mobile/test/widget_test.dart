import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mayhem_mobile/app/mayhem_app.dart';
import 'package:mayhem_mobile/application/today_controller.dart';
import 'package:mayhem_mobile/core/feature_flags/feature_flag_runtime.dart';
import 'package:mayhem_mobile/core/feature_flags/feature_flags.dart';
import 'package:mayhem_mobile/domain/models/game_event.dart';
import 'package:mayhem_mobile/domain/models/game_state.dart';
import 'package:mayhem_mobile/domain/services/game_engine.dart';

import 'support/fakes.dart';
import 'support/vnext_runtime_harness.dart';

void main() {
  testWidgets('mobile daily flow opens and starts the main challenge', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = MemoryGameStore();
    store.state = GameState.initial(DateTime(2026, 7, 11, 13)).copyWith(
      completedCount: 3,
      onboarding: const OnboardingState(boundariesAcknowledged: true),
    );
    final controller = TodayController(
      store,
      buildTestCatalog(),
      buildTestGuideCatalog(),
      buildTestDialogCatalog(),
      buildTestModifierCatalog(),
      GameEngine(() => 'event_widget'),
      clock: () => DateTime(2026, 7, 11, 13),
    );
    await controller.initialize();

    await tester.pumpWidget(MayhemApp(controller: controller));
    expect(find.text('MAYHEM'), findsOneWidget);
    expect(find.text('ВЫЗОВ ДНЯ'), findsOneWidget);
    expect(find.text('BACKUP RUNS'), findsOneWidget);

    await tester.tap(find.text('Предложи знакомому конкретный план.'));
    await tester.pumpAndSettle();
    expect(find.text('ПРИНЯТЬ ВЫЗОВ'), findsOneWidget);

    await tester.tap(find.text('ОТКРЫТЬ РАЗБОР'));
    await tester.pumpAndSettle();
    expect(find.text('МАРШРУТ'), findsOneWidget);
    expect(find.text('ЧИСТЫЙ ВЫХОД'), findsOneWidget);
    expect(store.events.last.type, GameEventType.guideOpened);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('НАЧАТЬ РЕПЕТИЦИЮ'));
    await tester.pumpAndSettle();
    expect(find.text('Что ты скажешь?'), findsOneWidget);
    await tester.tap(find.text('Сказать прямо'));
    await tester.pumpAndSettle();
    expect(find.text('ЗАВЕРШИТЬ РЕПЕТИЦИЮ'), findsOneWidget);
    await tester.tap(find.text('ЗАВЕРШИТЬ РЕПЕТИЦИЮ'));
    await tester.pumpAndSettle();
    expect(find.text('РЕПЕТИЦИЯ ГОТОВА'), findsOneWidget);
    expect(store.events.last.type, GameEventType.npcTrainingCompleted);

    await tester.tap(find.textContaining('БРОСИТЬ КУБИК'));
    await tester.pumpAndSettle();
    expect(find.text('БРОСОК ИСПОЛЬЗОВАН'), findsOneWidget);
    expect(store.events.last.type, GameEventType.diceRolled);
    expect(controller.state.preparedModifierIds, contains('boss_1'));

    await tester.tap(find.text('ПРИНЯТЬ ВЫЗОВ'));
    await tester.pumpAndSettle();
    expect(find.text('ЗАКРЫТЬ'), findsOneWidget);
    expect(find.text('СОЙТИ'), findsOneWidget);

    await tester.tap(find.text('ЗАКРЫТЬ'));
    await tester.pumpAndSettle();
    expect(find.text('КАК ПРОШЛО?'), findsOneWidget);
    expect(find.text('Пропустить'), findsOneWidget);

    await tester.tap(find.text('Пропустить'));
    await tester.pumpAndSettle();
    expect(find.text('ВЫЗОВ ДНЯ'), findsOneWidget);
    expect(controller.state.energy, 50);
    expect(controller.state.totalXp, 308);
    expect(store.reflections, isEmpty);
  });

  testWidgets('onboarding completes three guided quests before Today', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final catalog = buildOnboardingTestCatalog();
    final store = MemoryGameStore();
    final controller = TodayController(
      store,
      catalog,
      buildTestGuideCatalog(catalog),
      buildTestDialogCatalog(catalog),
      buildTestModifierCatalog(),
      GameEngine(() => 'onboarding_${store.events.length}'),
      clock: () => DateTime(2026, 7, 12, 13),
    );
    await controller.initialize();
    await tester.pumpWidget(MayhemApp(controller: controller));

    expect(find.text('ЗАДАНИЕ 1'), findsOneWidget);
    await _completeOnboardingQuest(tester);
    expect(find.text('ТВОИ ГРАНИЦЫ ВАЖНЕЕ ЗАДАНИЯ'), findsOneWidget);
    await tester.tap(find.text('ПОНЯТНО, ПРОДОЛЖИТЬ'));
    await tester.pumpAndSettle();
    expect(find.text('ЗАДАНИЕ 2'), findsOneWidget);

    await _completeOnboardingQuest(tester);
    expect(find.text('ЗАДАНИЕ 3'), findsOneWidget);
    await _completeOnboardingQuest(tester);
    expect(find.text('ВЫЗОВ ДНЯ'), findsOneWidget);
    expect(controller.state.completedCount, 3);
    expect(controller.state.onboarding.boundariesAcknowledged, true);

    await tester.tap(find.byTooltip('Профиль'));
    await tester.pumpAndSettle();
    expect(find.text('ПРОФИЛЬ'), findsOneWidget);
    expect(find.text('Выполнено офлайн-вызовов: 3'), findsOneWidget);
    expect(find.text('ИСТОРИЯ'), findsOneWidget);

    await tester.tap(find.byTooltip('Настройки'));
    await tester.pumpAndSettle();
    expect(find.text('НАСТРОЙКИ'), findsOneWidget);
    expect(find.text('ДАННЫЕ НА УСТРОЙСТВЕ'), findsOneWidget);
    await tester.tap(find.text('УДАЛИТЬ ЛОКАЛЬНЫЕ ДАННЫЕ'));
    await tester.pumpAndSettle();
    expect(find.text('Удалить прогресс?'), findsOneWidget);
    await tester.tap(find.text('УДАЛИТЬ'));
    await tester.pumpAndSettle();

    expect(find.text('ЗАДАНИЕ 1'), findsOneWidget);
    expect(controller.state.completedCount, 0);
    expect(controller.loadSource, 'fresh');
    expect(store.clearCount, 1);
    expect(store.events, isEmpty);
    expect(store.reflections, isEmpty);
  });

  testWidgets('valid runtime flag switches legacy Today and vNext live', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = MemoryGameStore();
    store.state = GameState.initial(DateTime(2026, 7, 15, 13)).copyWith(
      completedCount: 3,
      onboarding: const OnboardingState(boundariesAcknowledged: true),
    );
    final legacy = TodayController(
      store,
      buildTestCatalog(),
      buildTestGuideCatalog(),
      buildTestDialogCatalog(),
      buildTestModifierCatalog(),
      GameEngine(() => 'runtime_flag_event'),
      clock: () => DateTime(2026, 7, 15, 13),
    );
    await legacy.initialize();
    final flags = FeatureFlagRuntime.safe();
    final vnext = (await tester.runAsync(
      () =>
          buildVNextTestRuntime(featureFlags: flags, debugOverrides: const {}),
    ))!;
    addTearDown(vnext.dispose);
    final now = DateTime.utc(2026, 7, 15, 10);

    await tester.pumpWidget(
      MayhemApp(controller: legacy, featureFlags: flags, vnextRuntime: vnext),
    );
    expect(find.text('ВЫЗОВ ДНЯ'), findsOneWidget);

    flags.applySnapshot(
      snapshot: FeatureFlagSnapshot(
        values: const {MayhemFeatureFlag.newFeedEnabled: true},
      ),
      source: FeatureFlagSnapshotSource.server,
      fetchedAt: now,
      expiresAt: now.add(const Duration(hours: 1)),
      now: now,
    );
    await tester.pumpAndSettle();
    expect(find.text('Лента'), findsOneWidget);
    expect(find.text('ВЫЗОВ ДНЯ'), findsNothing);

    await tester.pump(const Duration(hours: 1));
    await tester.pumpAndSettle();
    expect(find.text('ВЫЗОВ ДНЯ'), findsOneWidget);
    expect(find.text('Лента'), findsNothing);
  });
}

Future<void> _completeOnboardingQuest(WidgetTester tester) async {
  await tester.tap(find.text('ОТКРЫТЬ ВЫЗОВ'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('ПРИНЯТЬ ВЫЗОВ'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('ЗАКРЫТЬ'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Пропустить'));
  await tester.pumpAndSettle();
}
