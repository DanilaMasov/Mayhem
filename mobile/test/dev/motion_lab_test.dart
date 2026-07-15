import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mayhem_mobile/core/design_system/mayhem_theme.dart';
import 'package:mayhem_mobile/dev/motion_lab/motion_lab.dart';

void main() {
  const viewports = <Size>[
    Size(360, 800),
    Size(390, 844),
    Size(430, 932),
    Size(412, 915),
  ];

  for (final viewport in viewports) {
    testWidgets(
      'Motion Lab stays coherent at ${viewport.width}x${viewport.height}',
      (tester) async {
        await _setViewport(tester, viewport);
        await _pumpLab(tester);
        expect(find.text('Motion Lab'), findsOneWidget);

        for (final section in ['FEED', 'OBJECTS', 'ACTIONS', 'FOUNDATION']) {
          await tester.ensureVisible(find.text(section));
          await tester.tap(find.text(section));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      },
    );
  }

  for (final scale in [1.3, 1.6]) {
    testWidgets('Motion Lab supports text scale $scale', (tester) async {
      await _setViewport(tester, const Size(390, 844));
      await _pumpLab(tester, textScale: scale);
      for (final section in ['FEED', 'OBJECTS', 'ACTIONS']) {
        await tester.ensureVisible(find.text(section));
        await tester.tap(find.text(section));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets('preferences change the live component gallery', (tester) async {
    await _setViewport(tester, const Size(390, 844));
    await _pumpLab(tester);
    expect(find.byType(BackdropFilter), findsWidgets);

    await tester.tap(find.text('Opaque'));
    await tester.pumpAndSettle();
    expect(find.byType(BackdropFilter), findsNothing);

    await tester.tap(find.text('Reduce motion'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpLab(WidgetTester tester, {double textScale = 1}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: MayhemTheme.dark,
      home: Builder(
        builder: (context) {
          final media = MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale));
          return MediaQuery(data: media, child: const MotionLab());
        },
      ),
    ),
  );
}
