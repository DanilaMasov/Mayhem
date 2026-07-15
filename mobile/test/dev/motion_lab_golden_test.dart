import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mayhem_mobile/core/design_system/mayhem_theme.dart';
import 'package:mayhem_mobile/dev/motion_lab/motion_lab.dart';

import '../support/golden_test_fonts.dart';

void main() {
  setUpAll(loadGoldenTestFonts);

  testWidgets('Motion Lab foundation mobile golden', (tester) async {
    await _setViewport(tester);
    await _pumpLab(tester);
    await expectLater(
      find.byType(MotionLab),
      matchesGoldenFile(goldenTestPath('motion_lab_foundation_390x844.png')),
    );
  });

  testWidgets('Motion Lab objects mobile golden', (tester) async {
    await _setViewport(tester);
    await _pumpLab(tester);
    await tester.tap(find.text('OBJECTS'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MotionLab),
      matchesGoldenFile(goldenTestPath('motion_lab_objects_390x844.png')),
    );
  });
}

Future<void> _setViewport(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpLab(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: MayhemTheme.dark,
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(390, 844),
          disableAnimations: true,
        ),
        child: const MotionLab(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
