import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mayhem_mobile/app/vnext/vnext_runtime.dart';
import 'package:mayhem_mobile/app/vnext/vnext_shell.dart';
import 'package:mayhem_mobile/content/domain/content_item_revision.dart';
import 'package:mayhem_mobile/core/design_system/accessibility/mayhem_motion_preferences.dart';
import 'package:mayhem_mobile/core/design_system/components/components.dart';
import 'package:mayhem_mobile/core/localization/mayhem_strings.dart';
import 'package:mayhem_mobile/features/challenge/domain/challenge_models.dart';
import 'package:mayhem_mobile/core/feature_flags/feature_flags.dart';
import 'package:mayhem_mobile/features/season/domain/artifact_ownership.dart';
import 'package:mayhem_mobile/features/season/domain/season_experience_state.dart';
import 'package:mayhem_mobile/features/feed/domain/feed_models.dart';
import 'package:mayhem_mobile/features/onboarding/domain/onboarding_models.dart';
import 'package:mayhem_mobile/features/progress/domain/progress_models.dart';
import 'package:mayhem_mobile/features/sync/domain/backend_models.dart';
import 'package:mayhem_mobile/features/sync/domain/reconciliation_models.dart';
import 'package:mayhem_mobile/presentation/theme/mayhem_theme.dart';

import '../support/vnext_runtime_harness.dart';

void main() {
  test('cold runtime restores Feed assignment and detects rank-up', () async {
    final database = buildVNextTestDatabase();
    final first = await buildVNextTestRuntime(database: database);
    await first.feed.setCurrentIndex(3);
    final current = first.journey.snapshot!.projection;
    await first.store.progress.saveProjection(
      ProgressProjection(
        totalXp: 250,
        traitXp: current.traitXp,
        rank: current.rank,
        rankProgress: current.rankProgress,
        momentum: current.momentum,
        difficulty: current.difficulty,
        completedCount: current.completedCount,
        attemptedCount: current.attemptedCount,
        updatedAt: DateTime.utc(2026, 7, 13, 10),
        source: ProjectionSource.localCheckpoint,
      ),
    );

    final restored = await buildVNextTestRuntime(database: database);

    expect(restored.feed.currentIndex, 3);
    expect(
      restored.feed.snapshot!.items[3].assignment.assignmentId,
      first.feed.snapshot!.items[3].assignment.assignmentId,
    );
    expect(restored.journey.snapshot!.projection.rank.label, 'SPARK II');
    expect(restored.pendingRankUp, 'SPARK II');
  });

  test('fresh onboarding opens the first bundled challenge offline', () async {
    final runtime = await buildVNextTestRuntime(
      database: buildVNextTestDatabase(onboardingComplete: false),
    );
    expect(runtime.onboarding.progress.stage, OnboardingStage.opening);
    expect(runtime.identity.remoteUserId, isNull);

    await runtime.onboarding.begin();
    for (final trait in CalibrationPolicy.traitOrder) {
      await runtime.onboarding.answer(trait, 0);
    }
    expect(await runtime.onboarding.acceptSafety(), isFalse);
    await runtime.onboarding.completeProfileReveal();
    await runtime.loadProduct();

    final feed = runtime.feed.snapshot!;
    expect(feed.generatedLocally, isTrue);
    expect(feed.batch.source, FeedBatchSource.localGenerated);
    expect(feed.items.first.challenge, isNotNull);
  });

  testWidgets('three tab stacks and Feed page survive tab switches', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final runtime = (await tester.runAsync(buildVNextTestRuntime))!;
    final second = runtime.feed.snapshot!.items[1];
    final secondTitle =
        second.challenge?.title ?? second.revision.payload['title'] as String;

    await tester.pumpWidget(_TestApp(runtime: runtime));
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const PageStorageKey('vnext-feed')),
      const Offset(0, -600),
    );
    await tester.pumpAndSettle();
    expect(runtime.feed.currentIndex, 1);
    expect(find.text(secondTitle), findsOneWidget);

    await tester.tap(find.text('Путь'));
    await tester.pumpAndSettle();
    expect(find.text('ТВОЙ ПУТЬ'), findsOneWidget);
    await tester.tap(find.byTooltip('КАРТА НАВЫКОВ'));
    await tester.pumpAndSettle();
    expect(find.text('КАРТА НАВЫКОВ'), findsWidgets);

    await tester.tap(find.text('Ты'));
    await tester.pumpAndSettle();
    expect(find.text('ТВОЁ ПРИСУТСТВИЕ'), findsOneWidget);
    await tester.tap(find.text('Путь'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Назад'), findsOneWidget);

    await tester.tap(find.text('Путь'));
    await tester.pumpAndSettle();
    expect(find.text('ТВОЙ ПУТЬ'), findsOneWidget);

    await tester.tap(find.text('Лента'));
    await tester.pumpAndSettle();
    expect(runtime.feed.currentIndex, 1);
    expect(find.text(secondTitle), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Feed impression requires 600 ms foreground visibility', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = buildVNextTestDatabase();
    final runtime = (await tester.runAsync(
      () => buildVNextTestRuntime(database: database),
    ))!;

    await tester.pumpWidget(_TestApp(runtime: runtime));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      database.executor
          .rows('event_log_v2')
          .where((row) => row['event_type'] == 'feed_item_impressed'),
      isEmpty,
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 599));
    expect(
      database.executor
          .rows('event_log_v2')
          .where((row) => row['event_type'] == 'feed_item_impressed'),
      isEmpty,
    );
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();

    expect(
      database.executor
          .rows('event_log_v2')
          .where((row) => row['event_type'] == 'feed_item_impressed'),
      hasLength(1),
    );
  });

  testWidgets('Feed preparation opens guide and branching rehearsal', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = buildVNextTestDatabase();
    final runtime = (await tester.runAsync(
      () => buildVNextTestRuntime(database: database),
    ))!;
    final index = runtime.feed.snapshot!.items.indexWhere(
      (item) => item.preparation?.rehearsal != null,
    );
    expect(index, greaterThanOrEqualTo(0));
    await runtime.feed.setCurrentIndex(index);
    final item = runtime.feed.snapshot!.items[index];
    final preparation = item.preparation!;
    final rehearsal = preparation.rehearsal!;

    await tester.pumpWidget(_TestApp(runtime: runtime, textScale: 1.6));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('ПОДГОТОВКА'));
    await tester.pumpAndSettle();

    expect(find.text(preparation.steps.first), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('РЕПЕТИЦИЯ'));
    await tester.pumpAndSettle();

    var node = rehearsal.node(rehearsal.startNodeId);
    for (var step = 0; step < rehearsal.nodes.length && !node.success; step++) {
      final option = node.options.first;
      await tester.tap(find.text(option.label));
      await tester.pumpAndSettle();
      node = rehearsal.node(option.nextNodeId);
    }
    expect(node.success, isTrue);
    expect(find.text('РЕПЕТИЦИЯ ПРОЙДЕНА'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(
      database.executor
          .rows('event_log_v2')
          .where((row) => row['event_type'] == 'feed_item_opened'),
      hasLength(1),
    );
    expect(
      database.executor
          .rows('event_log_v2')
          .where(
            (row) =>
                row['event_type'] == 'feed_item_impressed' ||
                row['event_type'] == 'feed_item_opened',
          )
          .map((row) => row['event_type']),
      ['feed_item_impressed', 'feed_item_opened'],
    );
  });

  testWidgets('Feed preparation fails closed when interaction commit fails', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = buildVNextTestDatabase();
    final runtime = (await tester.runAsync(
      () => buildVNextTestRuntime(database: database),
    ))!;
    final index = runtime.feed.snapshot!.items.indexWhere(
      (item) => item.preparation != null,
    );
    expect(index, greaterThanOrEqualTo(0));
    await runtime.feed.setCurrentIndex(index);

    await tester.pumpWidget(_TestApp(runtime: runtime));
    await tester.pump();
    database.executor.failNextInsertInto = 'event_log_v2';
    await tester.tap(find.byTooltip('ПОДГОТОВКА'));
    await tester.pumpAndSettle();

    expect(find.text('МАРШРУТ'), findsNothing);
    expect(
      find.text('Не удалось сохранить действие. Попробуй ещё раз.'),
      findsOneWidget,
    );
    expect(
      database.executor
          .rows('event_log_v2')
          .where((row) => row['event_type'] == 'feed_item_opened'),
      isEmpty,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('typed Feed skip is persisted and advances the page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = buildVNextTestDatabase();
    final runtime = (await tester.runAsync(
      () => buildVNextTestRuntime(database: database),
    ))!;
    final first = runtime.feed.snapshot!.items.first.assignment;

    await tester.pumpWidget(_TestApp(runtime: runtime, textScale: 1.6));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Пропустить'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Слишком интенсивно'));
    await tester.pumpAndSettle();

    expect(runtime.feed.currentIndex, 1);
    final event = database.executor
        .rows('event_log_v2')
        .singleWhere((row) => row['event_type'] == 'feed_item_skipped');
    expect(
      jsonDecode(event['payload_json'] as String),
      containsPair('reason', FeedSkipReason.tooIntense.name),
    );
    expect(
      database.executor
          .rows('event_log_v2')
          .where(
            (row) =>
                row['event_type'] == 'feed_item_impressed' ||
                row['event_type'] == 'feed_item_skipped',
          )
          .map((row) => row['event_type']),
      ['feed_item_impressed', 'feed_item_skipped'],
    );
    final assignment = database.executor
        .rows('feed_assignments')
        .singleWhere((row) => row['assignment_id'] == first.assignmentId);
    expect(
      jsonDecode(assignment['metadata_json'] as String),
      containsPair('_skipReason', FeedSkipReason.tooIntense.name),
    );
    expect(runtime.feedChallenge.activeAttempt, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('scenario choice persists once and removes its Feed card', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = buildVNextTestDatabase();
    final runtime = (await tester.runAsync(
      () => buildVNextTestRuntime(database: database),
    ))!;
    final items = runtime.feed.snapshot!.items;
    final scenarioIndex = items.indexWhere(
      (item) => item.revision.type == ContentItemType.scenarioPoll,
    );
    expect(scenarioIndex, greaterThanOrEqualTo(0));
    final assignmentId = items[scenarioIndex].assignment.assignmentId;
    final itemCount = items.length;
    await runtime.feed.setCurrentIndex(scenarioIndex);

    await tester.pumpWidget(_TestApp(runtime: runtime, textScale: 1.6));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('scenario-option-0')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('scenario-option-0')));
    await tester.pumpAndSettle();

    expect(runtime.feed.snapshot!.items, hasLength(itemCount - 1));
    expect(
      runtime.feed.snapshot!.items.map((item) => item.assignment.assignmentId),
      isNot(contains(assignmentId)),
    );
    final assignment = database.executor
        .rows('feed_assignments')
        .singleWhere((row) => row['assignment_id'] == assignmentId);
    expect(
      jsonDecode(assignment['metadata_json'] as String),
      containsPair('_scenarioChoiceIndex', 0),
    );
    expect(
      database.executor
          .rows('event_log_v2')
          .where((row) => row['event_type'] == 'feed_item_saved'),
      hasLength(1),
    );

    final restored = (await tester.runAsync(
      () => buildVNextTestRuntime(database: database),
    ))!;
    expect(
      restored.feed.snapshot!.items.map((item) => item.assignment.assignmentId),
      isNot(contains(assignmentId)),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings exposes honest deletion and diagnostics states', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final runtime = (await tester.runAsync(buildVNextTestRuntime))!;

    await tester.pumpWidget(_TestApp(runtime: runtime));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ты'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Настройки'));
    await tester.pumpAndSettle();
    const resetLabel = 'СБРОСИТЬ ДАННЫЕ НА ЭТОМ УСТРОЙСТВЕ';
    const deleteLabel = 'УДАЛИТЬ АККАУНТ И ДАННЫЕ ВЕЗДЕ';
    final settingsScroll = find.descendant(
      of: find.byKey(const PageStorageKey('settings-scroll')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text(resetLabel),
      300,
      scrollable: settingsScroll,
    );
    expect(find.text(resetLabel), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text(deleteLabel),
      300,
      scrollable: settingsScroll,
    );

    expect(find.text(deleteLabel), findsOneWidget);
    final unavailable = tester.widget<MayhemSecondaryButton>(
      find
          .ancestor(
            of: find.text(deleteLabel),
            matching: find.byType(MayhemSecondaryButton),
          )
          .first,
    );
    expect(unavailable.enabled, isFalse);

    await tester.scrollUntilVisible(
      find.text('Диагностика'),
      300,
      scrollable: settingsScroll,
    );
    await tester.tap(find.text('Диагностика'));
    await tester.pumpAndSettle();
    expect(find.text('ДИАГНОСТИКА'), findsOneWidget);
    expect(find.text('new_feed_enabled'), findsOneWidget);
    expect(find.text('debug override'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Physical-device performance gate открыт'),
      500,
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Physical-device performance gate открыт'),
      findsOneWidget,
    );
  });

  testWidgets('You shows only a server-owned artifact behind Season gates', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final runtime = (await tester.runAsync(
      () => buildVNextTestRuntime(
        debugOverrides: const {
          MayhemFeatureFlag.newFeedEnabled: true,
          MayhemFeatureFlag.seasonZeroEnabled: true,
          MayhemFeatureFlag.bossRaidEnabled: true,
        },
      ),
    ))!;
    await runtime.store.season.saveValidatedSnapshot(_activeSeason());
    final projection = runtime.journey.snapshot!.projection;
    await runtime.store.reconciliation.commit(
      ReconciledState(
        projection: projection,
        momentum: projection.momentum,
        serverProjectionRevision: 1,
        applied: true,
        ownedArtifacts: [
          OwnedFounderArtifact(
            artifactId: 'founder-1',
            seasonId: 'season-0',
            seasonRevision: 1,
            bossEventId: 'boss-0',
            unlockedAt: DateTime.utc(2026, 7, 13, 8),
          ),
        ],
      ),
    );
    await runtime.artifacts.initialize();

    await tester.pumpWidget(_TestApp(runtime: runtime));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ты'));
    await tester.pumpAndSettle();

    expect(find.text('Первопроходец'), findsOneWidget);
    expect(find.byIcon(Icons.workspace_premium_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Journey exposes cached Season state without fake confirmation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final runtime = (await tester.runAsync(
      () => buildVNextTestRuntime(
        debugOverrides: const {
          MayhemFeatureFlag.newFeedEnabled: true,
          MayhemFeatureFlag.seasonZeroEnabled: true,
          MayhemFeatureFlag.bossRaidEnabled: true,
        },
      ),
    ))!;
    await runtime.store.season.saveValidatedSnapshot(_activeSeason());
    await runtime.season.initialize();

    await tester.pumpWidget(_TestApp(runtime: runtime, textScale: 1.6));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Путь'));
    await tester.pumpAndSettle();

    expect(find.text('ТЕКУЩИЙ SEASON'), findsOneWidget);
    expect(find.text('Нулевая неделя'), findsOneWidget);
    await tester.tap(find.text('Нулевая неделя'));
    await tester.pumpAndSettle();

    expect(find.text('Показана последняя сохранённая версия'), findsOneWidget);
    expect(find.text('Участие ещё не подтверждено'), findsOneWidget);
    expect(find.text('Состояние подтверждено сервером'), findsNothing);
    await tester.scrollUntilVisible(find.text('ВСТУПИТЬ В SEASON'), 300);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<MayhemPrimaryButton>(find.byType(MayhemPrimaryButton))
          .enabled,
      isFalse,
    );

    runtime.season.attachRemote(
      synchronize: () async {
        final pending = await runtime.store.eventSync.loadAllPending();
        await runtime.store.eventSync.applyServerResults(
          results: [
            for (final event in pending)
              RemoteEventResult(
                eventId: event.eventId,
                accepted: true,
                disposition: RemoteEventDisposition.accepted,
              ),
          ],
          receivedAt: DateTime.utc(2026, 7, 13, 9, 1),
        );
        return true;
      },
    );
    await runtime.completeRemoteRefresh(succeeded: true);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Состояние подтверждено сервером'),
      -300,
    );
    await tester.pumpAndSettle();
    expect(find.text('Состояние подтверждено сервером'), findsOneWidget);
    expect(find.text('Показана последняя сохранённая версия'), findsNothing);

    await tester.scrollUntilVisible(find.text('ВСТУПИТЬ В SEASON'), 300);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ВСТУПИТЬ В SEASON'));
    await tester.pumpAndSettle();
    expect(find.text('ВСТУПИТЬ В SEASON'), findsNothing);
    expect(runtime.season.state.membership, SeasonMembership.active);

    await tester.scrollUntilVisible(find.text('ЗАВЕРШИТЬ ДЕНЬ 4'), 300);
    await tester.tap(find.text('ЗАВЕРШИТЬ ДЕНЬ 4'));
    await tester.pumpAndSettle();
    expect(find.text('Дневной вызов подтверждён'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('ВЫБРАТЬ МАРШРУТ BOSS'), 300);
    await tester.drag(
      find.byKey(const PageStorageKey('season-scroll')),
      const Offset(0, -160),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('ВЫБРАТЬ МАРШРУТ BOSS'));
    await tester.pumpAndSettle();
    expect(find.text('Прямой маршрут'), findsOneWidget);
    await tester.tap(find.text('Прямой маршрут'));
    await tester.pumpAndSettle();
    expect(find.text('Участие в Boss уже принято'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Phase 4 primary surfaces support 1.6x text', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final runtime = (await tester.runAsync(buildVNextTestRuntime))!;

    await tester.pumpWidget(_TestApp(runtime: runtime, textScale: 1.6));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Путь'));
    await tester.pumpAndSettle();
    expect(find.text('ТВОЙ ПУТЬ'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Ты'));
    await tester.pumpAndSettle();
    expect(find.text('ТВОЁ ПРИСУТСТВИЕ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Feed Hold to Reward completes the local challenge loop', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final runtime = (await tester.runAsync(buildVNextTestRuntime))!;
    final completedAssignmentId =
        runtime.feed.snapshot!.items.first.assignment.assignmentId;
    final itemCount = runtime.feed.snapshot!.items.length;

    await tester.pumpWidget(_TestApp(runtime: runtime, textScale: 1.6));
    await tester.pumpAndSettle();

    final hold = find.byType(MayhemHoldButton);
    expect(hold, findsOneWidget);
    final gesture = await tester.startGesture(tester.getCenter(hold));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(runtime.feedChallenge.activeAttempt, isNotNull);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('active-challenge-capsule')))
          .height,
      104,
    );
    expect(find.text('ЗАПИСАТЬ РЕЗУЛЬТАТ'), findsOneWidget);
    await tester.tap(find.text('ЗАПИСАТЬ РЕЗУЛЬТАТ'));
    await tester.pumpAndSettle();
    expect(find.text('РЕЗУЛЬТАТ ВЫЗОВА'), findsOneWidget);

    await tester.tap(find.text('ЗАСЧИТАТЬ'));
    await tester.pumpAndSettle();
    expect(find.text('ВЫЗОВ ЗАВЕРШЁН'), findsOneWidget);
    expect(find.textContaining('XP'), findsOneWidget);

    await tester.tap(find.text('ПРОДОЛЖИТЬ'));
    await tester.pumpAndSettle();
    expect(runtime.feedChallenge.activeAttempt, isNull);
    expect(runtime.journey.snapshot!.projection.totalXp, greaterThan(0));
    expect(runtime.feed.snapshot!.items, hasLength(itemCount - 1));
    expect(
      runtime.feed.snapshot!.items.map((item) => item.assignment.assignmentId),
      isNot(contains(completedAssignmentId)),
    );
    expect(find.text('ЗАПИСАТЬ РЕЗУЛЬТАТ'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'challenge result stays scrollable above keyboard at large text',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 330);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final runtime = (await tester.runAsync(buildVNextTestRuntime))!;
      final item = runtime.feed.snapshot!.items.first;
      await tester.runAsync(
        () => runtime.feedChallenge.accept(
          item: item,
          route: ChallengeRouteType.normal,
        ),
      );

      await tester.pumpWidget(_TestApp(runtime: runtime, textScale: 1.6));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ЗАПИСАТЬ РЕЗУЛЬТАТ'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      final scrollable = find
          .descendant(
            of: find.byKey(const ValueKey('challenge-result-scroll')),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('ЗАСЧИТАТЬ'),
        160,
        scrollable: scrollable,
      );
      expect(find.text('ЗАСЧИТАТЬ'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'rank path exposes future arenas and recent actions at large text',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final runtime = (await tester.runAsync(buildVNextTestRuntime))!;
      final item = runtime.feed.snapshot!.items.first;
      await tester.runAsync(() async {
        expect(
          await runtime.feedChallenge.accept(
            item: item,
            route: ChallengeRouteType.normal,
          ),
          isTrue,
        );
        expect(
          await runtime.feedChallenge.resolve(
            outcome: AttemptOutcome.completed,
            felt: FeltComparedToExpected.aboutAsExpected,
          ),
          isTrue,
        );
      });

      await tester.pumpWidget(_TestApp(runtime: runtime, textScale: 1.6));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Путь'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('rank-path-preview')));
      await tester.pumpAndSettle();

      expect(find.text('РЕЙТИНГОВЫЙ ПУТЬ'), findsOneWidget);
      expect(find.text('ПОСЛЕДНИЕ ДЕЙСТВИЯ НА ПУТИ'), findsOneWidget);
      expect(find.text(item.challenge!.title), findsOneWidget);
      expect(find.text('SPARK I'), findsWidgets);

      final scrollable = find
          .descendant(
            of: find.byKey(const PageStorageKey('rank-path-scroll')),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('MAYHEM'),
        -320,
        scrollable: scrollable,
      );
      expect(find.text('MAYHEM'), findsOneWidget);
      expect(find.text('25000 XP'), findsOneWidget);
      expect(find.text('2200 XP в каждом навыке'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('rank path names both XP and weakest-trait deficits', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final runtime = (await tester.runAsync(buildVNextTestRuntime))!;
    final current = runtime.journey.snapshot!.projection;
    await tester.runAsync(() async {
      await runtime.store.progress.saveProjection(
        ProgressProjection(
          totalXp: 1000,
          traitXp: {for (final trait in Trait.values) trait: 100},
          rank: current.rank,
          rankProgress: current.rankProgress,
          momentum: current.momentum,
          difficulty: current.difficulty,
          completedCount: current.completedCount,
          attemptedCount: current.attemptedCount,
          updatedAt: DateTime.utc(2026, 7, 22),
          source: ProjectionSource.localCheckpoint,
        ),
      );
      await runtime.journey.initialize();
    });

    expect(runtime.journey.snapshot!.projection.rank.label, 'MOVER I');
    await tester.pumpWidget(_TestApp(runtime: runtime));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Путь'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rank-path-preview')));
    await tester.pumpAndSettle();

    expect(find.text('ДО MOVER II'), findsOneWidget);
    expect(find.text('Ещё 500 XP'), findsOneWidget);
    expect(find.text('Ещё 50 XP в слабейшем навыке'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('skill map legend explains every node at large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final runtime = (await tester.runAsync(buildVNextTestRuntime))!;

    await tester.pumpWidget(_TestApp(runtime: runtime, textScale: 1.6));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Путь'));
    await tester.pumpAndSettle();
    Navigator.of(
      tester.element(find.byKey(const PageStorageKey('journey-scroll'))),
    ).pushNamed('/journey/traits');
    await tester.pumpAndSettle();

    final scrollable = find
        .descendant(
          of: find.byKey(const PageStorageKey('traits-detail-scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('ЛЕГЕНДА КАРТЫ'),
      240,
      scrollable: scrollable,
    );
    expect(find.text('ЛЕГЕНДА КАРТЫ'), findsOneWidget);
    for (final position in const [
      'Сверху · круг',
      'Справа · квадрат',
      'Снизу · треугольник',
      'Слева · ромб',
    ]) {
      await tester.scrollUntilVisible(
        find.textContaining(position),
        140,
        scrollable: scrollable,
      );
      expect(find.textContaining(position), findsOneWidget);
    }
    expect(find.byType(TraitMarker), findsNWidgets(4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Journey detail bottoms stay above floating navigation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final runtime = (await tester.runAsync(buildVNextTestRuntime))!;

    await tester.pumpWidget(_TestApp(runtime: runtime, textScale: 1.6));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Путь'));
    await tester.pumpAndSettle();
    Navigator.of(
      tester.element(find.text('ТВОЙ ПУТЬ')),
    ).pushNamed('/journey/traits');
    await tester.pumpAndSettle();

    final traitsScroll = find
        .descendant(
          of: find.byKey(const PageStorageKey('traits-detail-scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    for (var step = 0; step < 6; step += 1) {
      await tester.drag(traitsScroll, const Offset(0, -260));
      await tester.pump();
    }
    final traitsState = tester.state<ScrollableState>(traitsScroll);
    traitsState.position.jumpTo(traitsState.position.maxScrollExtent);
    await tester.pumpAndSettle();
    final lastTrait = find.byKey(const ValueKey('trait-legend-presence'));
    expect(lastTrait, findsOneWidget);
    expect(tester.getBottomRight(lastTrait).dy, lessThan(744));

    await tester.tap(find.byTooltip('Назад'));
    await tester.pumpAndSettle();
    Navigator.of(
      tester.element(find.text('ТВОЙ ПУТЬ')),
    ).pushNamed('/journey/ranks');
    await tester.pumpAndSettle();
    final rankScroll = find
        .descendant(
          of: find.byKey(const PageStorageKey('rank-path-scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    final rankState = tester.state<ScrollableState>(rankScroll);
    rankState.position.jumpTo(rankState.position.maxScrollExtent);
    await tester.pumpAndSettle();
    final bottomRank = find.byKey(const ValueKey('rank-card-SPARK I'));
    expect(bottomRank, findsOneWidget);
    expect(tester.getBottomRight(bottomRank).dy, lessThan(744));
    expect(tester.takeException(), isNull);
  });

  testWidgets('rank rail exposes continuous progress to the next title', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final runtime = (await tester.runAsync(buildVNextTestRuntime))!;
    final current = runtime.journey.snapshot!.projection;
    await tester.runAsync(() async {
      await runtime.store.progress.saveProjection(
        ProgressProjection(
          totalXp: 125,
          traitXp: current.traitXp,
          rank: current.rank,
          rankProgress: current.rankProgress,
          momentum: current.momentum,
          difficulty: current.difficulty,
          completedCount: current.completedCount,
          attemptedCount: current.attemptedCount,
          updatedAt: DateTime.utc(2026, 7, 13, 10),
          source: ProjectionSource.localCheckpoint,
        ),
      );
      await runtime.journey.initialize();
    });

    await tester.pumpWidget(_TestApp(runtime: runtime));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Путь'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rank-path-preview')));
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel('Прогресс до следующего звания: 50%'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('rank-progress-rail-current')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('unlocked arena style persists and locked styles stay gated', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = buildVNextTestDatabase();
    final runtime = (await tester.runAsync(
      () => buildVNextTestRuntime(database: database),
    ))!;
    final current = runtime.journey.snapshot!.projection;
    await tester.runAsync(() async {
      await runtime.store.progress.saveProjection(
        ProgressProjection(
          totalXp: 1000,
          traitXp: {for (final trait in Trait.values) trait: 100},
          rank: current.rank,
          rankProgress: current.rankProgress,
          momentum: current.momentum,
          difficulty: current.difficulty,
          completedCount: current.completedCount,
          attemptedCount: current.attemptedCount,
          updatedAt: DateTime.utc(2026, 7, 22),
          source: ProjectionSource.localCheckpoint,
        ),
      );
      await runtime.journey.initialize();
    });

    await tester.pumpWidget(_TestApp(runtime: runtime, textScale: 1.6));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Путь'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rank-style-preview')));
    await tester.pumpAndSettle();

    expect(find.text('4 из 16 открыто'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rank-style-spark.2')));
    await tester.pumpAndSettle();
    expect(runtime.settings.preferences.rankStyleId, 'spark.2');
    expect(find.text('ИСПОЛЬЗУЕТСЯ'), findsOneWidget);

    final scrollable = find
        .descendant(
          of: find.byKey(const PageStorageKey('rank-style-collection-scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('rank-style-mayhem.1')),
      320,
      scrollable: scrollable,
    );
    await tester.tap(find.byKey(const ValueKey('rank-style-mayhem.1')));
    await tester.pump();
    expect(runtime.settings.preferences.rankStyleId, 'spark.2');
    expect(find.text('ОТКРОЕТСЯ НА MAYHEM'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final restored = (await tester.runAsync(
      () => buildVNextTestRuntime(database: database),
    ))!;
    expect(restored.settings.preferences.rankStyleId, 'spark.2');
  });
}

RemoteSeasonSnapshot _activeSeason() => RemoteSeasonSnapshot(
  seasonId: 'season-0',
  revision: 1,
  title: 'Нулевая неделя',
  startsAt: DateTime.utc(2026, 7, 10),
  endsAt: DateTime.utc(2026, 7, 17),
  payload: {
    'days': [
      for (var day = 1; day <= 7; day++)
        {
          'day': day,
          'title': 'День $day',
          'featuredContentIds': ['q-$day'],
        },
    ],
    'boss': {
      'bossEventId': 'boss-0',
      'contentId': 'boss-content',
      'contentRevision': 1,
      'startsAt': '2026-07-13T08:00:00.000Z',
      'endsAt': '2026-07-13T10:00:00.000Z',
      'normalRoute': {'copy': 'Сделай шаг'},
      'lowPressureRoute': {'copy': 'Сделай малый шаг'},
      'advancedRoute': null,
      'advancedRouteSafetyApproved': false,
    },
    'artifacts': [
      {'artifactId': 'founder-1', 'title': 'Первопроходец'},
    ],
  },
);

class _TestApp extends StatelessWidget {
  const _TestApp({required this.runtime, this.textScale = 1});

  final VNextRuntime runtime;
  final double textScale;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: MayhemTheme.dark,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: MayhemStringsScope(
            strings: const MayhemStringsRu(),
            child: MayhemAccessibility(
              preferences: const MayhemMotionPreferences(reduceMotion: true),
              child: VNextShell(
                runtime: runtime,
                onResetLocalData: () async {},
              ),
            ),
          ),
        ),
      ),
    );
  }
}
