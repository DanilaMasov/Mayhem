import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mayhem_mobile/core/design_system/accessibility/mayhem_motion_preferences.dart';
import 'package:mayhem_mobile/core/localization/mayhem_strings.dart';
import 'package:mayhem_mobile/core/metadata/local_metadata_repository.dart';
import 'package:mayhem_mobile/features/onboarding/application/onboarding_controller.dart';
import 'package:mayhem_mobile/features/onboarding/data/local_onboarding_repository.dart';
import 'package:mayhem_mobile/features/onboarding/presentation/vnext_onboarding_flow.dart';
import 'package:mayhem_mobile/features/progress/domain/progress_models.dart';
import 'package:mayhem_mobile/features/progress/domain/progress_repository.dart';
import 'package:mayhem_mobile/presentation/theme/mayhem_theme.dart';

void main() {
  for (final textScale in [1.0, 1.3, 1.6]) {
    testWidgets(
      'fresh onboarding reaches profile reveal at text scale $textScale',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = OnboardingController(
          repository: LocalOnboardingRepository(_Metadata()),
          progressRepository: _Progress(),
          clock: () => DateTime.utc(2026, 7, 13),
        );
        await controller.initialize(
          legacyUserHasProgress: false,
          legacySafetyAccepted: false,
        );
        var completed = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: MayhemTheme.dark,
            home: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(textScale)),
                child: MayhemStringsScope(
                  strings: const MayhemStringsRu(),
                  child: MayhemAccessibility(
                    preferences: const MayhemMotionPreferences(
                      reduceMotion: true,
                    ),
                    child: VNextOnboardingFlow(
                      controller: controller,
                      onCompleted: () async => completed = true,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        expect(find.text('РЕАЛЬНАЯ ЖИЗНЬ\nИ ЕСТЬ ИГРА.'), findsOneWidget);
        await tester.tap(find.text('НАЧАТЬ'));
        await tester.pumpAndSettle();
        for (var step = 0; step < 4; step++) {
          await tester.ensureVisible(find.text('A'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('A'));
          await tester.pumpAndSettle();
        }
        expect(find.text('ГРАНИЦЫ ВАЖНЕЕ СЕРИИ'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Я ПОНИМАЮ'),
          240,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(find.text('Я ПОНИМАЮ'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Я ПОНИМАЮ'));
        await tester.pumpAndSettle();
        expect(find.text('СТАРТОВЫЙ СИГНАЛ'), findsOneWidget);
        expect(find.text('SPARK I'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.scrollUntilVisible(
          find.text('ПРОДОЛЖИТЬ'),
          240,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(find.text('ПРОДОЛЖИТЬ'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('ПРОДОЛЖИТЬ'));
        await tester.pumpAndSettle();
        expect(completed, isTrue);
      },
    );
  }
}

class _Metadata implements LocalMetadataRepository {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

class _Progress implements ProgressRepository {
  ProgressProjection? value;

  @override
  Future<ProgressProjection?> loadProjection() async => value;

  @override
  Future<void> saveProjection(ProgressProjection projection) async {
    value = projection;
  }
}
