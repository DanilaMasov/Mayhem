import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mayhem_mobile/app/vnext/vnext_runtime.dart';
import 'package:mayhem_mobile/app/vnext/vnext_shell.dart';
import 'package:mayhem_mobile/core/design_system/accessibility/mayhem_motion_preferences.dart';
import 'package:mayhem_mobile/core/design_system/components/components.dart';
import 'package:mayhem_mobile/core/debug/debug_visual_overlays.dart';
import 'package:mayhem_mobile/core/localization/mayhem_strings.dart';
import 'package:mayhem_mobile/features/challenge/domain/challenge_models.dart';
import 'package:mayhem_mobile/features/progress/domain/development_rank_config.dart';
import 'package:mayhem_mobile/features/progress/domain/progress_models.dart';
import 'package:mayhem_mobile/features/progress/presentation/rank_promotion_scene.dart';
import 'package:mayhem_mobile/presentation/theme/mayhem_theme.dart';

import '../support/golden_test_fonts.dart';
import '../support/vnext_runtime_harness.dart';

void main() {
  setUpAll(loadGoldenTestFonts);

  testWidgets('Phase 4 Feed Journey and You mobile goldens', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final runtime = (await tester.runAsync(buildVNextTestRuntime))!;

    await tester.pumpWidget(
      MaterialApp(
        theme: MayhemTheme.dark,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            disableAnimations: true,
          ),
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
    await tester.pumpAndSettle();
    expect(mayhemDebugVisualOverlaysDisabled, isTrue);
    await expectLater(
      find.byType(VNextShell),
      matchesGoldenFile(goldenTestPath('phase4_feed_390x844.png')),
    );

    await tester.tap(find.text('Путь'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(VNextShell),
      matchesGoldenFile(goldenTestPath('phase4_journey_390x844.png')),
    );

    await tester.tap(find.byTooltip('КАРТА НАВЫКОВ'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(VNextShell),
      matchesGoldenFile(goldenTestPath('phase7_trait_legend_390x844.png')),
    );

    await tester.tap(find.byTooltip('Назад'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rank-path-preview')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(VNextShell),
      matchesGoldenFile(goldenTestPath('phase6_rank_path_390x844.png')),
    );

    await tester.tap(find.text('Ты'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(VNextShell),
      matchesGoldenFile(goldenTestPath('phase4_you_390x844.png')),
    );
  });

  testWidgets('Feed action loop mobile goldens', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final runtime = (await tester.runAsync(buildVNextTestRuntime))!;

    await _pumpApp(tester, runtime);
    final first = runtime.feed.snapshot!.items.first;
    await tester.runAsync(
      () => runtime.feedChallenge.accept(
        item: first,
        route: ChallengeRouteType.normal,
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(VNextShell),
      matchesGoldenFile(goldenTestPath('phase6_feed_active_390x844.png')),
    );

    await tester.tap(find.text('ЗАПИСАТЬ РЕЗУЛЬТАТ'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MayhemSheet),
      matchesGoldenFile(goldenTestPath('phase6_result_sheet_390x844.png')),
    );

    await tester.tap(find.text('ЗАСЧИТАТЬ'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(RewardStage),
      matchesGoldenFile(goldenTestPath('phase6_reward_390x844.png')),
    );
  });

  testWidgets('Feed preparation and skip sheets mobile goldens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final runtime = (await tester.runAsync(buildVNextTestRuntime))!;
    final rehearsalIndex = runtime.feed.snapshot!.items.indexWhere(
      (item) => item.preparation?.rehearsal != null,
    );
    await runtime.feed.setCurrentIndex(rehearsalIndex);

    await _pumpApp(tester, runtime);
    await tester.tap(find.byTooltip('ПОДГОТОВКА'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MayhemSheet),
      matchesGoldenFile(goldenTestPath('feed_preparation_sheet_390x844.png')),
    );

    Navigator.of(tester.element(find.byType(MayhemSheet))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Пропустить'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MayhemSheet),
      matchesGoldenFile(goldenTestPath('feed_skip_sheet_390x844.png')),
    );
  });

  testWidgets('Rank promotion final frame mobile golden', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final previous = PrestigeRank(
      family: RankFamily.spark,
      tier: 1,
      configRevision: DevelopmentRankConfig.revision,
    );
    final current = PrestigeRank(
      family: RankFamily.spark,
      tier: 2,
      configRevision: DevelopmentRankConfig.revision,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: MayhemTheme.dark,
        home: MayhemStringsScope(
          strings: const MayhemStringsRu(),
          child: MayhemAccessibility(
            preferences: const MayhemMotionPreferences(reduceMotion: true),
            child: RankPromotionScene(
              previousRank: previous,
              currentRank: current,
              ratingScore: 1130,
              ratingDelta: 30,
              onDismiss: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await expectLater(
      find.byType(RankPromotionScene),
      matchesGoldenFile(goldenTestPath('rank_promotion_390x844.png')),
    );
  });
}

Future<void> _pumpApp(WidgetTester tester, VNextRuntime runtime) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: MayhemTheme.dark,
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(390, 844),
          disableAnimations: true,
        ),
        child: MayhemStringsScope(
          strings: const MayhemStringsRu(),
          child: MayhemAccessibility(
            preferences: const MayhemMotionPreferences(reduceMotion: true),
            child: VNextShell(runtime: runtime, onResetLocalData: () async {}),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
