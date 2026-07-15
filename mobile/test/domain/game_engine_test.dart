import 'package:flutter_test/flutter_test.dart';
import 'package:mayhem_mobile/domain/models/game_event.dart';
import 'package:mayhem_mobile/domain/models/game_state.dart';
import 'package:mayhem_mobile/domain/models/quest.dart';
import 'package:mayhem_mobile/domain/models/quest_reflection.dart';
import 'package:mayhem_mobile/domain/services/game_engine.dart';

import '../support/fakes.dart';

void main() {
  late GameEngine engine;
  var id = 0;

  setUp(() {
    id = 0;
    engine = GameEngine(() => 'event_${id++}');
  });

  test(
    'daily selection is stable and advances difficulty after completion',
    () {
      final now = DateTime(2026, 7, 11, 13);
      final catalog = buildTestCatalog();
      final initial = engine.refresh(GameState.initial(now), catalog, now);

      expect(initial.daily.localQuestIds, ['level_1', 'level_2']);
      expect(initial.daily.bossId, 'boss_1');
      expect(
        engine.refresh(initial, catalog, now).daily.localQuestIds,
        initial.daily.localQuestIds,
      );

      final nextDay = now.add(const Duration(days: 1));
      final progressed = engine.refresh(
        initial.copyWith(completedCount: 1),
        catalog,
        nextDay,
      );
      expect(progressed.daily.localQuestIds, ['level_1', 'level_2']);

      final advanced = engine.refresh(
        initial.copyWith(completedCount: 8),
        catalog,
        nextDay.add(const Duration(days: 1)),
      );
      expect(advanced.daily.localQuestIds, ['level_2', 'level_3']);
    },
  );

  test('defer preserves energy and completion commits canonical reward', () {
    final now = DateTime.utc(2026, 7, 11, 12);
    final catalog = buildTestCatalog();
    final quest = catalog.bosses.single;
    var state = engine.refresh(GameState.initial(now), catalog, now);

    final started = engine.start(state, quest, now, variant: 'low_pressure');
    expect(started.events.single.type, GameEventType.questStarted);
    expect(started.state.activeQuest?.variant, 'low_pressure');
    state = started.state;

    final deferred = engine.defer(
      state,
      quest,
      now.add(const Duration(seconds: 20)),
    );
    expect(deferred.state.energy, 100);
    expect(deferred.events.single.payload['attemptDurationSeconds'], 20);
    expect(deferred.events.single.payload['variant'], 'low_pressure');

    state = engine
        .start(deferred.state, quest, now.add(const Duration(minutes: 1)))
        .state;
    final completed = engine.complete(
      state,
      quest,
      now.add(const Duration(minutes: 2)),
      reflection: const ReflectionDraft(
        fearScore: 7,
        feelAfterScore: 8,
        wantRepeat: true,
        note: 'Сработала конкретика.',
      ),
    );
    expect(completed.state.energy, 50);
    expect(completed.state.xp[StatType.boldness], 280);
    expect(completed.state.completedCount, 1);
    expect(completed.events, hasLength(2));
    expect(completed.events.first.payload['xpDelta'], 280);
    expect(completed.events.last.type, GameEventType.reflectionSubmitted);
    expect(completed.reflections.single.fearScore, 7);
    expect(completed.reflections.single.note, 'Сработала конкретика.');
    expect(
      () => engine.start(
        completed.state,
        quest,
        now.add(const Duration(minutes: 3)),
      ),
      throwsA(isA<GameRuleException>()),
    );
  });

  test('energy regeneration advances only in complete ten-minute ticks', () {
    final now = DateTime.utc(2026, 7, 11, 12);
    final state = GameState.initial(now).copyWith(energy: 50);

    expect(
      engine
          .regenerateEnergy(state, now.add(const Duration(minutes: 9)))
          .energy,
      50,
    );
    final regenerated = engine.regenerateEnergy(
      state,
      now.add(const Duration(minutes: 25)),
    );
    expect(regenerated.energy, 52);
    expect(regenerated.energyUpdatedAt, now.add(const Duration(minutes: 20)));
  });

  test('opening a guide emits a canonical event without mutating state', () {
    final now = DateTime.utc(2026, 7, 11, 12);
    final state = GameState.initial(now);
    final quest = buildTestCatalog().bosses.single;

    final transition = engine.openGuide(state, quest, 'guide_boss_1', now);
    expect(identical(transition.state, state), true);
    expect(transition.events.single.type, GameEventType.guideOpened);
    expect(transition.events.single.payload['guideId'], 'guide_boss_1');
  });

  test(
    'rehearsal survives defer, grants ten percent XP and clears on completion',
    () {
      final now = DateTime.utc(2026, 7, 11, 12);
      final catalog = buildTestCatalog();
      final quest = catalog.bosses.single;
      var state = engine.refresh(GameState.initial(now), catalog, now);

      final trained = engine.completeNpcTraining(
        state,
        quest,
        'dialog_boss_1',
        now,
      );
      expect(trained.state.trainedQuestIds, contains(quest.id));
      expect(trained.events.single.type, GameEventType.npcTrainingCompleted);

      state = engine.start(trained.state, quest, now).state;
      expect(state.activeQuest?.npcTrained, true);
      state = engine
          .defer(state, quest, now.add(const Duration(seconds: 10)))
          .state;
      expect(state.trainedQuestIds, contains(quest.id));

      state = engine
          .start(state, quest, now.add(const Duration(minutes: 1)))
          .state;
      final completed = engine.complete(
        state,
        quest,
        now.add(const Duration(minutes: 2)),
        skipReflection: true,
      );
      expect(completed.events.first.payload['xpDelta'], 308);
      expect(completed.events.first.payload['npcTrained'], true);
      expect(completed.state.trainedQuestIds, isNot(contains(quest.id)));
    },
  );

  test('legacy Energy is a soft signal and never blocks quest acceptance', () {
    final now = DateTime.utc(2026, 7, 11, 12);
    final quest = buildTestCatalog().regularAtLevel(1).single;
    final state = GameState.initial(now).copyWith(energy: 15);

    final transition = engine.start(state, quest, now);

    expect(transition.state.activeQuest?.questId, quest.id);
    expect(transition.state.energy, 15);
  });

  test(
    'skipped reflection still completes without creating a reflection record',
    () {
      final now = DateTime.utc(2026, 7, 11, 12);
      final catalog = buildTestCatalog();
      final quest = catalog.bosses.single;
      var state = engine.refresh(GameState.initial(now), catalog, now);
      state = engine.start(state, quest, now).state;

      final completed = engine.complete(
        state,
        quest,
        now.add(const Duration(minutes: 1)),
        skipReflection: true,
      );
      expect(completed.state.energy, 50);
      expect(completed.events, hasLength(1));
      expect(completed.events.single.payload['reflectionSkipped'], true);
      expect(completed.reflections, isEmpty);
    },
  );

  test('modifier survives defer and clears only after completion', () {
    final now = DateTime.utc(2026, 7, 11, 12);
    final quest = buildTestCatalog().bosses.single;
    final modifiers = buildTestModifierCatalog();
    var state = GameState.initial(now);

    final rolled = engine.rollModifier(state, quest, modifiers, now);
    final modifierId = rolled.state.preparedModifierIds[quest.id];
    expect(modifierId, isNotNull);
    expect(rolled.events.single.type, GameEventType.diceRolled);
    expect(rolled.events.single.payload['modifierId'], modifierId);
    state = rolled.state;

    final started = engine.start(state, quest, now);
    expect(started.state.activeQuest?.modifierId, modifierId);
    expect(started.events.single.payload['modifierId'], modifierId);
    state = started.state;

    final deferred = engine.defer(
      state,
      quest,
      now.add(const Duration(seconds: 30)),
    );
    expect(deferred.state.preparedModifierIds[quest.id], modifierId);
    expect(deferred.events.single.payload['modifierId'], modifierId);
    state = engine
        .start(deferred.state, quest, now.add(const Duration(minutes: 1)))
        .state;

    final completed = engine.complete(
      state,
      quest,
      now.add(const Duration(minutes: 2)),
      skipReflection: true,
    );
    expect(completed.events.single.payload['modifierId'], modifierId);
    expect(completed.state.preparedModifierIds, isNot(contains(quest.id)));
  });

  test('free modifier roll is limited per calendar day', () {
    final now = DateTime(2026, 7, 11, 23, 59);
    final catalog = buildTestCatalog();
    final modifiers = buildTestModifierCatalog();
    final first = engine.rollModifier(
      GameState.initial(now),
      catalog.regularAtLevel(1).single,
      modifiers,
      now,
    );

    expect(engine.modifierAllowance(first.state, now).remaining, 0);
    expect(
      () => engine.rollModifier(
        first.state,
        catalog.regularAtLevel(2).single,
        modifiers,
        now,
      ),
      throwsA(isA<GameRuleException>()),
    );

    final nextDay = now.add(const Duration(minutes: 2));
    expect(engine.modifierAllowance(first.state, nextDay).remaining, 1);
    expect(
      () => engine.rollModifier(
        first.state,
        catalog.regularAtLevel(2).single,
        modifiers,
        nextDay,
      ),
      returnsNormally,
    );
  });

  test('modifier is unavailable for Shadow quests', () {
    final now = DateTime.utc(2026, 7, 11, 12);
    final shadow = buildTestCatalog().shadowQuests.single;
    expect(
      () => engine.rollModifier(
        GameState.initial(now),
        shadow,
        buildTestModifierCatalog(),
        now,
      ),
      throwsA(isA<GameRuleException>()),
    );
  });

  test('schema v2 snapshot migrates with empty modifier preparation', () {
    final now = DateTime.utc(2026, 7, 11, 12);
    final legacy = GameState.initial(now).toJson()
      ..['schemaVersion'] = 2
      ..remove('modifierDice')
      ..remove('preparedModifierIds');

    final migrated = GameState.fromJson(legacy);
    expect(migrated.schemaVersion, 4);
    expect(migrated.modifierDice.rollsUsed, 0);
    expect(migrated.preparedModifierIds, isEmpty);
    expect(migrated.onboarding.boundariesAcknowledged, false);
  });

  test(
    'boundaries acknowledgement is available only after first completion',
    () {
      final now = DateTime.utc(2026, 7, 12, 12);
      expect(
        () => engine.acknowledgeBoundaries(GameState.initial(now), now),
        throwsA(isA<GameRuleException>()),
      );

      final state = GameState.initial(now).copyWith(completedCount: 1);
      final acknowledged = engine.acknowledgeBoundaries(state, now);
      expect(acknowledged.state.onboarding.boundariesAcknowledged, true);
      expect(
        acknowledged.events.single.type,
        GameEventType.onboardingStepCompleted,
      );
      expect(
        acknowledged.events.single.payload['step'],
        'boundaries_acknowledged',
      );
    },
  );
}
