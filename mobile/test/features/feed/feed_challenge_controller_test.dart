import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mayhem_mobile/features/challenge/application/challenge_flow_coordinator.dart';
import 'package:mayhem_mobile/features/challenge/domain/challenge_models.dart';
import 'package:mayhem_mobile/features/feed/application/feed_challenge_controller.dart';
import 'package:mayhem_mobile/features/feed/application/feed_session_coordinator.dart';
import 'package:mayhem_mobile/features/progress/domain/progress_models.dart';

import '../../support/vnext_runtime_harness.dart';

void main() {
  test(
    'accept restores after cold start and resolution updates Journey privately',
    () async {
      final database = buildVNextTestDatabase();
      final first = await buildVNextTestRuntime(database: database);
      final item = first.feed.snapshot!.items.first;

      expect(
        await first.feedChallenge.accept(
          item: item,
          route: ChallengeRouteType.lowPressure,
        ),
        isTrue,
      );
      final attemptId = first.feedChallenge.activeAttempt!.attemptId;
      expect(first.feed.snapshot!.activeAttempt?.attemptId, attemptId);

      final restored = await buildVNextTestRuntime(database: database);
      expect(restored.feedChallenge.activeAttempt?.attemptId, attemptId);
      expect(
        restored.feedChallenge.activeDefinition?.contentId,
        item.challenge!.contentId,
      );

      expect(
        await restored.feedChallenge.resolve(
          outcome: AttemptOutcome.completed,
          felt: FeltComparedToExpected.aboutAsExpected,
          reflection: const ReflectionInput(
            fearBefore: 7,
            feelAfter: 4,
            wantRepeat: true,
            privateNote: 'private-controller-note',
          ),
        ),
        isTrue,
      );

      final reward = restored.feedChallenge.reward;
      expect(reward?.outcome, AttemptOutcome.completed);
      expect(reward?.xp, greaterThan(0));
      expect(reward?.momentumDays, 1);
      expect(restored.feedChallenge.activeAttempt, isNull);
      expect(restored.feed.snapshot!.activeAttempt, isNull);
      expect(restored.journey.snapshot!.projection.totalXp, reward!.xp);
      expect(database.executor.rows('private_reflections'), hasLength(1));
      expect(
        database.executor.rows('private_reflections').single['private_note'],
        'private-controller-note',
      );
      expect(
        jsonEncode(database.executor.rows('event_log_v2')),
        isNot(contains('private-controller-note')),
      );
    },
  );

  test('post-commit Journey refresh failure does not negate success', () async {
    final runtime = await buildVNextTestRuntime();
    final item = runtime.feed.snapshot!.items.first;
    final controller = FeedChallengeController(
      flow: runtime.feedChallenge.flow,
      clock: runtime.feedChallenge.clock,
      timezoneOffsetMinutes: () => 180,
      onActiveChanged: (_, _) {},
      onProjectionChanged: () => throw StateError('injected refresh failure'),
    )..initialize(runtime.feed.snapshot!);

    expect(
      await controller.accept(item: item, route: ChallengeRouteType.normal),
      isTrue,
    );
    expect(
      await controller.resolve(
        outcome: AttemptOutcome.attempted,
        felt: FeltComparedToExpected.harderThanExpected,
      ),
      isTrue,
    );
    expect(controller.reward?.xp, greaterThan(0));
    expect(controller.error, isNull);
  });

  test(
    'lost UI acknowledgement recovers an already committed result',
    () async {
      final runtime = await buildVNextTestRuntime();
      final item = runtime.feed.snapshot!.items.first;
      final controller = runtime.feedChallenge;

      expect(
        await controller.accept(item: item, route: ChallengeRouteType.normal),
        isTrue,
      );
      final attemptId = controller.activeAttempt!.attemptId;
      final committed = await controller.flow.resolve(
        attemptId: attemptId,
        definition: item.challenge!,
        outcome: AttemptOutcome.completed,
        felt: FeltComparedToExpected.aboutAsExpected,
        resolvedAt: controller.clock.utcNow(),
        localDate: '2026-07-13',
        timezoneOffsetMinutes: 180,
      );
      expect(committed.applied, isTrue);

      expect(
        await controller.resolve(
          outcome: AttemptOutcome.completed,
          felt: FeltComparedToExpected.aboutAsExpected,
        ),
        isTrue,
      );
      expect(controller.activeAttempt, isNull);
      expect(controller.reward?.xp, committed.attempt.result?.earnedXp);
      expect(controller.error, isNull);
    },
  );

  test(
    'missing active content fails closed and blocks a second accept',
    () async {
      final runtime = await buildVNextTestRuntime();
      final snapshot = runtime.feed.snapshot!;
      final item = snapshot.items.first;
      await runtime.feedChallenge.accept(
        item: item,
        route: ChallengeRouteType.normal,
      );
      final active = runtime.feedChallenge.activeAttempt!;

      runtime.feedChallenge.initialize(
        FeedSessionSnapshot(
          batch: snapshot.batch,
          items: snapshot.items,
          generatedLocally: snapshot.generatedLocally,
          activeAttempt: active,
        ),
      );

      expect(runtime.feedChallenge.hasActiveChallenge, isTrue);
      expect(
        await runtime.feedChallenge.accept(
          item: item,
          route: ChallengeRouteType.normal,
        ),
        isFalse,
      );
      expect(runtime.feedChallenge.error, 'active_challenge_exists');
    },
  );

  test('challenge reward notifies runtime when it unlocks a rank', () async {
    final runtime = await buildVNextTestRuntime();
    final current = runtime.journey.snapshot!.projection;
    await runtime.store.progress.saveProjection(
      ProgressProjection(
        totalXp: 240,
        traitXp: current.traitXp,
        rank: current.rank,
        rankProgress: current.rankProgress,
        momentum: current.momentum,
        difficulty: current.difficulty,
        completedCount: current.completedCount,
        attemptedCount: current.attemptedCount,
        updatedAt: DateTime.utc(2026, 7, 13, 9),
        source: ProjectionSource.localCheckpoint,
      ),
    );
    var notifications = 0;
    runtime.addListener(() => notifications += 1);
    final item = runtime.feed.snapshot!.items.first;

    await runtime.feedChallenge.accept(
      item: item,
      route: ChallengeRouteType.normal,
    );
    await runtime.feedChallenge.resolve(
      outcome: AttemptOutcome.completed,
      felt: FeltComparedToExpected.aboutAsExpected,
    );

    expect(runtime.pendingRankUp, 'SPARK II');
    expect(notifications, greaterThan(0));
  });
}
