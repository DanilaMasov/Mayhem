import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mayhem_mobile/app/vnext/vnext_runtime.dart';
import 'package:mayhem_mobile/core/design_system/accessibility/mayhem_motion_preferences.dart';
import 'package:mayhem_mobile/core/feature_flags/feature_flags.dart';
import 'package:mayhem_mobile/core/localization/mayhem_strings.dart';
import 'package:mayhem_mobile/features/season/application/season_bootstrap_activator.dart';
import 'package:mayhem_mobile/features/season/domain/season_experience_state.dart';
import 'package:mayhem_mobile/features/season/presentation/vnext_season_screen.dart';
import 'package:mayhem_mobile/features/sync/domain/backend_models.dart';
import 'package:mayhem_mobile/presentation/theme/mayhem_theme.dart';

import '../../support/vnext_runtime_harness.dart';

void main() {
  testWidgets('incompatible Season retries remote and recovers once', (
    tester,
  ) async {
    final runtime = await _buildRuntime(tester);
    final gate = Completer<void>();
    var syncCalls = 0;
    runtime.season.attachRemote(
      synchronize: () async {
        syncCalls += 1;
        await gate.future;
        await runtime.store.season.saveValidatedSnapshot(_activeSeason());
        await runtime.refreshAfterRemoteSeason();
        return true;
      },
    );
    await runtime.reportRemoteSeasonFailure(
      SeasonActivationFailure.incompatiblePackage,
    );

    await tester.pumpWidget(_TestApp(runtime: runtime));
    await tester.pumpAndSettle();

    const strings = MayhemStringsRu();
    expect(find.text(strings.seasonPackageIncompatible), findsOneWidget);
    expect(find.text(strings.seasonUnavailable), findsNothing);

    await tester.tap(find.text(strings.retry));
    await tester.pump();
    expect(syncCalls, 1);
    expect(runtime.season.state.availability, SeasonAvailability.loadingRemote);
    expect(find.text(strings.loading), findsOneWidget);

    await runtime.season.retryRemote();
    expect(syncCalls, 1);

    gate.complete();
    await tester.pumpAndSettle();

    expect(find.text('Нулевая неделя'), findsOneWidget);
    expect(find.text(strings.seasonConfirmed), findsOneWidget);
    expect(runtime.season.state.availability, SeasonAvailability.ready);
    expect(tester.takeException(), isNull);
  });

  testWidgets('recoverable and unavailable empty states stay distinct', (
    tester,
  ) async {
    final runtime = await _buildRuntime(tester);
    runtime.season.attachRemote(synchronize: () async => false);
    await runtime.reportRemoteSeasonFailure(
      SeasonActivationFailure.recoverable,
    );

    await tester.pumpWidget(_TestApp(runtime: runtime));
    await tester.pumpAndSettle();

    const strings = MayhemStringsRu();
    expect(find.text(strings.seasonRecoverableError), findsOneWidget);
    expect(find.text(strings.seasonPackageIncompatible), findsNothing);
    expect(find.text(strings.seasonUnavailable), findsNothing);

    await runtime.refreshAfterRemoteSeason();
    await tester.pumpAndSettle();

    expect(find.text(strings.seasonUnavailable), findsOneWidget);
    expect(find.text(strings.seasonRecoverableError), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'incompatible cached package stays visible but blocks mutations',
    (tester) async {
      final runtime = await _buildRuntime(tester);
      await runtime.store.season.saveValidatedSnapshot(_activeSeason());
      await runtime.season.initialize();
      runtime.season.attachRemote(synchronize: () async => false);
      await runtime.reportRemoteSeasonFailure(
        SeasonActivationFailure.incompatiblePackage,
      );

      await tester.pumpWidget(_TestApp(runtime: runtime, textScale: 1.6));
      await tester.pumpAndSettle();

      const strings = MayhemStringsRu();
      expect(find.text('Нулевая неделя'), findsOneWidget);
      expect(find.text(strings.seasonPackageIncompatible), findsOneWidget);
      expect(find.text(strings.retry), findsOneWidget);
      expect(runtime.season.canJoin, isFalse);
      expect(runtime.season.canCompleteDay, isFalse);
      expect(runtime.season.canParticipateBoss, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('remote retry exception always leaves loading state', (
    tester,
  ) async {
    final runtime = await _buildRuntime(tester);
    runtime.season.attachRemote(
      synchronize: () async => throw StateError('network unavailable'),
    );

    await runtime.season.retryRemote();

    expect(runtime.season.state.availability, SeasonAvailability.unavailable);
    expect(runtime.season.canRetryRemote, isTrue);
  });
}

Future<VNextRuntime> _buildRuntime(WidgetTester tester) async {
  final runtime = (await tester.runAsync(
    () => buildVNextTestRuntime(
      debugOverrides: const {
        MayhemFeatureFlag.newFeedEnabled: true,
        MayhemFeatureFlag.seasonZeroEnabled: true,
        MayhemFeatureFlag.bossRaidEnabled: true,
      },
    ),
  ))!;
  addTearDown(runtime.dispose);
  return runtime;
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.runtime, this.textScale = 1});

  final VNextRuntime runtime;
  final double textScale;

  @override
  Widget build(BuildContext context) => MaterialApp(
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
            child: VNextSeasonScreen(controller: runtime.season),
          ),
        ),
      ),
    ),
  );
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
      'startsAt': '2026-07-16T12:00:00.000Z',
      'endsAt': '2026-07-17T00:00:00.000Z',
      'normalRoute': {'copy': 'Сделай шаг'},
      'lowPressureRoute': {'copy': 'Сделай малый шаг'},
      'advancedRoute': null,
      'advancedRouteSafetyApproved': false,
    },
    'artifacts': [
      {'artifactId': 'founder-0', 'title': 'Первопроходец'},
    ],
  },
);
