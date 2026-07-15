import 'package:flutter_test/flutter_test.dart';
import 'package:mayhem_mobile/application/today_controller.dart';
import 'package:mayhem_mobile/domain/models/game_event.dart';
import 'package:mayhem_mobile/domain/models/game_state.dart';
import 'package:mayhem_mobile/domain/models/quest.dart';
import 'package:mayhem_mobile/domain/services/game_engine.dart';
import 'package:mayhem_mobile/domain/services/game_state_rebuilder.dart';

import '../support/fakes.dart';

void main() {
  late GameEngine engine;
  const rebuilder = GameStateRebuilder();
  var id = 0;

  setUp(() {
    id = 0;
    engine = GameEngine(() => 'rebuild_${id++}');
  });

  test('journal rebuild restores active preparation without snapshot', () {
    final now = DateTime.utc(2026, 7, 12, 10);
    final catalog = buildTestCatalog();
    final quest = catalog.bosses.single;
    final events = <GameEvent>[];
    var state = GameState.initial(now);

    var transition = engine.completeNpcTraining(
      state,
      quest,
      'dialog_boss_1',
      now,
    );
    state = transition.state;
    events.addAll(transition.events);
    transition = engine.rollModifier(
      state,
      quest,
      buildTestModifierCatalog(),
      now.add(const Duration(seconds: 1)),
    );
    state = transition.state;
    events.addAll(transition.events);
    transition = engine.start(
      state,
      quest,
      now.add(const Duration(seconds: 2)),
      variant: 'low_pressure',
    );
    events.addAll(transition.events);

    final rebuilt = rebuilder.rebuild(events.reversed, catalog, now: now);
    expect(rebuilt.activeQuest?.questId, quest.id);
    expect(rebuilt.activeQuest?.variant, 'low_pressure');
    expect(rebuilt.activeQuest?.npcTrained, true);
    expect(rebuilt.activeQuest?.modifierId, isNotNull);
    expect(rebuilt.trainedQuestIds, contains(quest.id));
    expect(rebuilt.preparedModifierIds, contains(quest.id));
    expect(rebuilt.modifierDice.rollsUsed, 1);
  });

  test('journal rebuild restores canonical completion exactly once', () {
    final now = DateTime.utc(2026, 7, 12, 10);
    final catalog = buildTestCatalog();
    final quest = catalog.bosses.single;
    final events = <GameEvent>[];
    var state = GameState.initial(now);

    final started = engine.start(state, quest, now);
    state = started.state;
    events.addAll(started.events);
    final completed = engine.complete(
      state,
      quest,
      now.add(const Duration(minutes: 2)),
      skipReflection: true,
    );
    events.addAll(completed.events);
    final duplicate = GameEvent(
      id: 'duplicate_completion',
      type: completed.events.single.type,
      questId: quest.id,
      createdAt: completed.events.single.createdAt,
      payload: completed.events.single.payload,
    );

    final rebuilt = rebuilder.rebuild(
      [...events, duplicate],
      catalog,
      now: now,
    );
    expect(rebuilt.energy, 50);
    expect(rebuilt.xp[StatType.boldness], 280);
    expect(rebuilt.completedCount, 1);
    expect(rebuilt.activeQuest, isNull);
    expect(rebuilt.completedByDate[GameEngine.utcDayKey(now)], [quest.id]);
  });

  test('controller recovers a broken snapshot from the journal', () async {
    final now = DateTime.utc(2026, 7, 12, 10);
    final catalog = buildTestCatalog();
    final quest = catalog.regularAtLevel(1).single;
    final store = MemoryGameStore()
      ..loadFailure = const FormatException('broken snapshot');
    store.events.addAll(
      engine.start(GameState.initial(now), quest, now).events,
    );
    final controller = TodayController(
      store,
      catalog,
      buildTestGuideCatalog(),
      buildTestDialogCatalog(),
      buildTestModifierCatalog(),
      engine,
      clock: () => now,
    );

    await controller.initialize();
    expect(controller.error, isEmpty);
    expect(controller.loadSource, 'event_log_recovery');
    expect(controller.state.activeQuest?.questId, quest.id);
    expect(store.state?.activeQuest?.questId, quest.id);
  });

  test('database event parser rejects unknown event types', () {
    expect(
      () => GameEvent.fromDatabaseMap({
        'id': 'bad_event',
        'event_type': 'unknown_event',
        'quest_id': 'level_1',
        'payload_json': '{}',
        'created_at': DateTime.utc(2026, 7, 12).toIso8601String(),
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test('journal rebuild restores onboarding acknowledgement', () {
    final now = DateTime.utc(2026, 7, 12, 10);
    final catalog = buildTestCatalog();
    final completedState = GameState.initial(now).copyWith(completedCount: 1);
    final event = engine
        .acknowledgeBoundaries(completedState, now)
        .events
        .single;
    final completion = GameEvent(
      id: 'completion_before_boundary',
      type: GameEventType.questCompleted,
      questId: catalog.regularAtLevel(1).single.id,
      createdAt: now.subtract(const Duration(seconds: 1)),
      payload: {
        'statType': StatType.charisma.name,
        'xpDelta': 40,
        'energyDelta': -10,
        'energyAfter': 90,
        'completionKey': '2026-07-12',
      },
    );

    final rebuilt = rebuilder.rebuild([event, completion], catalog, now: now);
    expect(rebuilt.completedCount, 1);
    expect(rebuilt.onboarding.boundariesAcknowledged, true);
  });
}
