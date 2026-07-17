import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mayhem_mobile/app/vnext/vnext_runtime.dart';
import 'package:mayhem_mobile/app/vnext/vnext_shell.dart';
import 'package:mayhem_mobile/core/design_system/accessibility/mayhem_motion_preferences.dart';
import 'package:mayhem_mobile/core/design_system/components/components.dart';
import 'package:mayhem_mobile/core/localization/mayhem_strings.dart';
import 'package:mayhem_mobile/core/feature_flags/feature_flags.dart';
import 'package:mayhem_mobile/features/season/domain/artifact_ownership.dart';
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
    await tester.drag(
      find.byKey(const PageStorageKey('settings-scroll')),
      const Offset(0, -1500),
    );
    await tester.pumpAndSettle();

    expect(find.text('СБРОСИТЬ ДАННЫЕ НА ЭТОМ УСТРОЙСТВЕ'), findsOneWidget);
    expect(find.text('УДАЛИТЬ АККАУНТ И ДАННЫЕ ВЕЗДЕ'), findsOneWidget);
    final unavailable = tester.widget<MayhemSecondaryButton>(
      find
          .ancestor(
            of: find.text('УДАЛИТЬ АККАУНТ И ДАННЫЕ ВЕЗДЕ'),
            matching: find.byType(MayhemSecondaryButton),
          )
          .first,
    );
    expect(unavailable.enabled, isFalse);

    await tester.ensureVisible(find.text('Диагностика'));
    await tester.pumpAndSettle();
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

    await runtime.completeRemoteRefresh(succeeded: true);
    await tester.pumpAndSettle();
    expect(find.text('Состояние подтверждено сервером'), findsOneWidget);
    expect(find.text('Показана последняя сохранённая версия'), findsNothing);
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
    expect(find.text('ЗАПИСАТЬ РЕЗУЛЬТАТ'), findsNothing);
    expect(tester.takeException(), isNull);
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
