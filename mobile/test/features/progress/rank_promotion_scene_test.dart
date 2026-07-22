import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mayhem_mobile/core/design_system/accessibility/mayhem_motion_preferences.dart';
import 'package:mayhem_mobile/core/localization/mayhem_strings.dart';
import 'package:mayhem_mobile/features/progress/domain/development_rank_config.dart';
import 'package:mayhem_mobile/features/progress/domain/progress_models.dart';
import 'package:mayhem_mobile/features/progress/presentation/rank_promotion_scene.dart';
import 'package:mayhem_mobile/presentation/theme/mayhem_theme.dart';

void main() {
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

  testWidgets(
    'reduced motion reveals the complete promotion without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var dismissed = false;

      await tester.pumpWidget(
        _TestApp(
          reduceMotion: true,
          textScale: 1.6,
          child: RankPromotionScene(
            previousRank: previous,
            currentRank: current,
            ratingScore: 1130,
            ratingDelta: 30,
            onDismiss: () => dismissed = true,
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('rank-promotion-overlay')),
        findsOneWidget,
      );
      expect(find.text('Было: ИСКРА'), findsOneWidget);
      expect(find.text('Твоё новое звание — ИМПУЛЬС'), findsOneWidget);
      expect(find.text('+30 рейтинга'), findsOneWidget);
      expect(find.text('1130 РЕЙТИНГ'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const ValueKey('rank-promotion-continue')));
      expect(dismissed, isTrue);
    },
  );

  testWidgets('full ceremony gates the action until its reveal completes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _TestApp(
        child: RankPromotionScene(
          previousRank: previous,
          currentRank: current,
          ratingScore: 1130,
          ratingDelta: 30,
          onDismiss: () {},
        ),
      ),
    );
    final button = find.byKey(const ValueKey('rank-promotion-continue'));
    IgnorePointer gate() => tester.widget(
      find.ancestor(of: button, matching: find.byType(IgnorePointer)).first,
    );

    expect(gate().ignoring, isTrue);
    await tester.pump(const Duration(milliseconds: 1200));
    expect(gate().ignoring, isTrue);
    await tester.pump(const Duration(milliseconds: 1100));
    expect(gate().ignoring, isFalse);
    expect(tester.takeException(), isNull);
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({
    required this.child,
    this.reduceMotion = false,
    this.textScale = 1,
  });

  final Widget child;
  final bool reduceMotion;
  final double textScale;

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: MayhemTheme.dark,
    home: MediaQuery(
      data: MediaQueryData(
        size: const Size(390, 844),
        textScaler: TextScaler.linear(textScale),
      ),
      child: MayhemStringsScope(
        strings: const MayhemStringsRu(),
        child: MayhemAccessibility(
          preferences: MayhemMotionPreferences(reduceMotion: reduceMotion),
          child: child,
        ),
      ),
    ),
  );
}
