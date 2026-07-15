import '../models/game_event.dart';
import '../models/game_state.dart';
import '../models/quest.dart';
import '../models/quest_catalog.dart';

class GameStateRebuilder {
  const GameStateRebuilder();

  GameState rebuild(
    Iterable<GameEvent> events,
    QuestCatalog catalog, {
    required DateTime now,
  }) {
    final ordered = events.toList(growable: false)
      ..sort((left, right) {
        final byTime = left.createdAt.compareTo(right.createdAt);
        return byTime != 0 ? byTime : left.id.compareTo(right.id);
      });
    if (ordered.isEmpty) return GameState.initial(now);

    var state = GameState.initial(ordered.first.createdAt);
    for (final event in ordered) {
      state = _apply(state, event, catalog);
    }
    return state;
  }

  GameState _apply(GameState state, GameEvent event, QuestCatalog catalog) {
    switch (event.type) {
      case GameEventType.diceRolled:
        final modifierId = _string(event.payload['modifierId']);
        if (modifierId == null) return state;
        final diceDate =
            _string(event.payload['diceDate']) ?? _dateKey(event.createdAt);
        final rollsUsed = state.modifierDice.date == diceDate
            ? state.modifierDice.rollsUsed + 1
            : 1;
        return state.copyWith(
          modifierDice: ModifierDiceState(date: diceDate, rollsUsed: rollsUsed),
          preparedModifierIds: {
            ...state.preparedModifierIds,
            event.questId: modifierId,
          },
        );

      case GameEventType.npcTrainingCompleted:
        catalog.byId(event.questId);
        return state.copyWith(
          trainedQuestIds: {...state.trainedQuestIds, event.questId},
        );

      case GameEventType.questStarted:
        catalog.byId(event.questId);
        return state.copyWith(
          activeQuest: ActiveQuest(
            questId: event.questId,
            startedAt: event.createdAt.toUtc(),
            variant: _string(event.payload['variant']) ?? 'normal',
            npcTrained:
                event.payload['npcTrained'] == true ||
                state.trainedQuestIds.contains(event.questId),
            modifierId:
                _string(event.payload['modifierId']) ??
                state.preparedModifierIds[event.questId],
          ),
        );

      case GameEventType.questDeferred:
        if (state.activeQuest?.questId != event.questId) return state;
        return state.copyWith(activeQuest: null);

      case GameEventType.questCompleted:
        final quest = catalog.byId(event.questId);
        final completionKey =
            _string(event.payload['completionKey']) ??
            (quest.isBoss
                ? _utcDateKey(event.createdAt)
                : _dateKey(event.createdAt));
        final completed = state.completedByDate[completionKey] ?? const [];
        if (completed.contains(event.questId)) return state;

        final statType = _statType(event.payload['statType']) ?? quest.statType;
        final xpDelta = _integer(event.payload['xpDelta']) ?? 0;
        final energyDelta = _integer(event.payload['energyDelta']) ?? 0;
        final energyAfter =
            _integer(event.payload['energyAfter']) ??
            (state.energy + energyDelta).clamp(0, 100);
        final prepared = {...state.preparedModifierIds}..remove(event.questId);
        final trained = {...state.trainedQuestIds}..remove(event.questId);
        return state.copyWith(
          energy: energyAfter,
          energyUpdatedAt: event.createdAt.toUtc(),
          xp: {...state.xp, statType: (state.xp[statType] ?? 0) + xpDelta},
          activeQuest: null,
          completedCount: state.completedCount + (quest.isShadow ? 0 : 1),
          completedByDate: {
            ...state.completedByDate,
            completionKey: {
              ...completed,
              event.questId,
            }.toList(growable: false),
          },
          trainedQuestIds: trained,
          preparedModifierIds: prepared,
        );

      case GameEventType.reflectionSubmitted:
      case GameEventType.guideOpened:
        return state;

      case GameEventType.onboardingStepCompleted:
        if (event.payload['step'] != 'boundaries_acknowledged') return state;
        return state.copyWith(
          onboarding: const OnboardingState(boundariesAcknowledged: true),
        );
    }
  }

  StatType? _statType(Object? value) {
    if (value is! String) return null;
    for (final type in StatType.values) {
      if (type.name == value) return type;
    }
    return null;
  }

  int? _integer(Object? value) => value is num ? value.toInt() : null;

  String? _string(Object? value) {
    return value is String && value.trim().isNotEmpty ? value.trim() : null;
  }

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  String _utcDateKey(DateTime date) => _dateKey(date.toUtc());
}
