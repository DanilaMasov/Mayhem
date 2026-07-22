import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mayhem_mobile/app/mayhem_app.dart';
import 'package:mayhem_mobile/core/design_system/accessibility/mayhem_motion_preferences.dart';
import 'package:mayhem_mobile/core/design_system/components/components.dart';
import 'package:mayhem_mobile/core/design_system/mayhem_theme.dart';
import 'package:mayhem_mobile/core/design_system/motion/mayhem_durations.dart';
import 'package:mayhem_mobile/core/design_system/tokens/tokens.dart';
import 'package:mayhem_mobile/dev/motion_lab/motion_lab.dart';

void main() {
  testWidgets('Mayhem text never inherits the Material fallback underline', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: MayhemText('MAYHEM')));

    final text = tester.widget<Text>(find.text('MAYHEM'));
    expect(text.style?.inherit, isFalse);
    expect(text.style?.decoration, isNull);
  });

  testWidgets('Mayhem text uses the bundled display and body families', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Column(
          children: [
            MayhemText(
              'СИЛЬНЫЙ ЗАГОЛОВОК',
              variant: MayhemTextVariant.displayMedium,
            ),
            MayhemText('Спокойный текст'),
          ],
        ),
      ),
    );

    final texts = tester.widgetList<Text>(find.byType(Text)).toList();
    expect(texts[0].style?.fontFamily, MayhemTypography.displayFontFamily);
    expect(texts[1].style?.fontFamily, MayhemTypography.bodyFontFamily);
  });

  group('design tokens', () {
    test('match the master specification', () {
      expect(MayhemColors.canvasDeep, const Color(0xFF050608));
      expect(MayhemColors.brandSignal, const Color(0xFF8B7CFF));
      expect(MayhemColors.traitInitiation, const Color(0xFFFF6A45));
      expect(MayhemColors.semanticSuccess, const Color(0xFF78D6A3));
      expect(MayhemSpacing.x20, 80);
      expect(MayhemRadii.mediumValue, 18);
      expect(MayhemDurations.slow, const Duration(milliseconds: 620));
      expect(MayhemTypography.displayHero.fontSize, 48);
      expect(
        MayhemTypography.displayHero.fontFamily,
        MayhemTypography.displayFontFamily,
      );
      expect(
        MayhemTypography.bodyLarge.fontFamily,
        MayhemTypography.bodyFontFamily,
      );
      expect(
        MayhemTypography.navigationTitle.fontFamily,
        MayhemTypography.bodyFontFamily,
      );
      expect(MayhemTypography.bodyLarge.height, 1.45);
    });

    test('release route map excludes Motion Lab', () {
      expect(mayhemInternalRoutes(debug: false), isEmpty);
      expect(mayhemInternalRoutes(debug: true), contains(MotionLab.routeName));
    });
  });

  testWidgets('hold cancel is harmless and threshold commits exactly once', (
    tester,
  ) async {
    var canceled = 0;
    var completed = 0;
    await _pumpHarness(
      tester,
      MayhemHoldButton(
        label: 'HOLD TO ACCEPT',
        onCanceled: () => canceled += 1,
        onCompleted: () => completed += 1,
      ),
    );

    final button = find.byType(MayhemHoldButton);
    final canceledGesture = await tester.startGesture(tester.getCenter(button));
    await tester.pump(const Duration(milliseconds: 300));
    await canceledGesture.up();
    await tester.pumpAndSettle();
    expect(canceled, 1);
    expect(completed, 0);

    final completedGesture = await tester.startGesture(
      tester.getCenter(button),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(completed, 1);
    await completedGesture.up();
    await tester.pumpAndSettle();
    expect(completed, 1);
    expect(find.text('CHALLENGE ACCEPTED'), findsOneWidget);
  });

  testWidgets('hold exposes a screen-reader confirmation action', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pumpHarness(
      tester,
      MayhemHoldButton(label: 'Accept', onCompleted: () {}),
    );

    expect(
      tester.getSemantics(find.byType(MayhemHoldButton)),
      matchesSemantics(
        label: 'Accept',
        hint: 'Double tap to confirm without holding',
        value: 'Hold to confirm',
        isButton: true,
        isEnabled: true,
        hasEnabledState: true,
        hasTapAction: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('opaque preference removes backdrop filtering', (tester) async {
    await _pumpHarness(
      tester,
      const MayhemGlassControl(child: Text('Control')),
      preferences: const MayhemMotionPreferences(reduceTransparency: true),
    );
    expect(find.byType(BackdropFilter), findsNothing);

    await _pumpHarness(
      tester,
      const MayhemGlassControl(child: Text('Control')),
    );
    expect(find.byType(BackdropFilter), findsOneWidget);
  });

  testWidgets('Core and Sigil expose semantic product state', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pumpHarness(
      tester,
      const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          MomentumCore(days: 9, state: MomentumCoreState.shielded),
          RankSigil(tier: RankSigilTier.mover),
        ],
      ),
      preferences: const MayhemMotionPreferences(reduceMotion: true),
    );

    expect(
      find.bySemanticsLabel('Momentum 9 days, protected by a shield'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Rank Mover'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('vertical Feed settles on the next fixture', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var page = 0;
    await _pumpHarness(
      tester,
      FeedPager(
        items: const [
          FeedFixtureItem(
            kind: FeedFixtureKind.challenge,
            eyebrow: 'Challenge',
            statement: 'Say the direct version.',
            detail: 'No preamble.',
            energy: MayhemColors.traitInitiation,
          ),
          FeedFixtureItem(
            kind: FeedFixtureKind.training,
            eyebrow: 'Training',
            statement: 'Hold the silence.',
            detail: 'Three seconds.',
            energy: MayhemColors.traitPresence,
          ),
        ],
        onPageChanged: (value) => page = value,
      ),
      expand: true,
    );

    await tester.fling(find.byType(PageView), const Offset(0, -600), 1400);
    await tester.pumpAndSettle();
    expect(page, 1);
    expect(find.text('Hold the silence.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Feed can replace an injected PageController', (tester) async {
    final first = PageController();
    final second = PageController();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    const item = FeedFixtureItem(
      kind: FeedFixtureKind.challenge,
      eyebrow: 'Challenge',
      statement: 'Make the request.',
      detail: 'Use one sentence.',
      energy: MayhemColors.traitInitiation,
    );

    await _pumpHarness(
      tester,
      FeedPager(controller: first, items: const [item]),
      expand: true,
    );
    expect(first.hasClients, isTrue);

    await _pumpHarness(
      tester,
      FeedPager(controller: second, items: const [item]),
      expand: true,
    );
    expect(first.hasClients, isFalse);
    expect(second.hasClients, isTrue);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpHarness(
  WidgetTester tester,
  Widget child, {
  MayhemMotionPreferences preferences = const MayhemMotionPreferences(),
  bool expand = false,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: MayhemTheme.dark,
      home: MayhemAccessibility(
        preferences: preferences,
        child: Scaffold(
          body: expand
              ? child
              : Center(
                  child: Padding(
                    padding: const EdgeInsets.all(MayhemSpacing.x4),
                    child: child,
                  ),
                ),
        ),
      ),
    ),
  );
}
