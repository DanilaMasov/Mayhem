import '../models/game_event.dart';
import '../models/game_state.dart';
import '../models/quest.dart';
import '../models/quest_catalog.dart';
import '../models/quest_modifier.dart';
import '../models/quest_reflection.dart';

class GameRuleException implements Exception {
  const GameRuleException(this.message);
  final String message;

  @override
  String toString() => message;
}

class GameTransition {
  const GameTransition(this.state, this.events, [this.reflections = const []]);
  final GameState state;
  final List<GameEvent> events;
  final List<QuestReflection> reflections;
}

class ModifierAllowance {
  const ModifierAllowance({required this.canRoll, required this.remaining});

  final bool canRoll;
  final int remaining;
}

class GameEngine {
  GameEngine(this._idGenerator);

  static const energyRegenInterval = Duration(minutes: 10);
  static const xpByLevel = {1: 40, 2: 75, 3: 140};

  final String Function() _idGenerator;

  GameState refresh(GameState state, QuestCatalog catalog, DateTime now) {
    var next = _refreshModifierDice(regenerateEnergy(state, now), now);
    final localDate = localDailyKey(now);
    final bossDate = utcDayKey(now);
    final localExpired =
        next.daily.localDate != localDate ||
        next.daily.localQuestIds.length != 2;
    final bossExpired =
        next.daily.bossDate != bossDate || next.daily.bossId.isEmpty;
    if (!localExpired && !bossExpired) return next;

    var localIds = next.daily.localQuestIds;
    var bossId = next.daily.bossId;
    if (localExpired) {
      final advanced = next.completedCount >= 8;
      final firstPool = catalog.regularAtLevel(advanced ? 2 : 1);
      final secondPool = catalog.regularAtLevel(advanced ? 3 : 2);
      final firstQuest = _pickStable(firstPool, localDate, 1);
      localIds = [firstQuest.id, _pickStable(secondPool, localDate, 3).id];
    }
    if (bossExpired) bossId = _pickStable(catalog.bosses, bossDate, 7).id;

    return next.copyWith(
      daily: DailySelection(
        localDate: localDate,
        localQuestIds: localIds,
        bossDate: bossDate,
        bossId: bossId,
      ),
    );
  }

  GameTransition acknowledgeBoundaries(GameState state, DateTime now) {
    if (state.completedCount < 1) {
      throw const GameRuleException('Сначала заверши первый вызов.');
    }
    if (state.onboarding.boundariesAcknowledged) {
      return GameTransition(state, const []);
    }
    final next = state.copyWith(
      onboarding: const OnboardingState(boundariesAcknowledged: true),
    );
    return GameTransition(next, [
      GameEvent(
        id: _idGenerator(),
        type: GameEventType.onboardingStepCompleted,
        questId: 'onboarding',
        createdAt: now,
        payload: {'step': 'boundaries_acknowledged'},
      ),
    ]);
  }

  GameState regenerateEnergy(GameState state, DateTime now) {
    final elapsed = now.toUtc().difference(state.energyUpdatedAt.toUtc());
    if (elapsed.isNegative) return state;
    final ticks = elapsed.inMilliseconds ~/ energyRegenInterval.inMilliseconds;
    if (ticks <= 0 || state.energy >= 100) return state;
    return state.copyWith(
      energy: (state.energy + ticks).clamp(0, 100),
      energyUpdatedAt: state.energyUpdatedAt.add(
        Duration(milliseconds: ticks * energyRegenInterval.inMilliseconds),
      ),
    );
  }

  GameTransition openGuide(
    GameState state,
    Quest quest,
    String guideId,
    DateTime now,
  ) {
    if (guideId.trim().isEmpty) {
      throw const GameRuleException('Guide не найден.');
    }
    return GameTransition(state, [
      GameEvent(
        id: _idGenerator(),
        type: GameEventType.guideOpened,
        questId: quest.id,
        createdAt: now,
        payload: {'guideId': guideId},
      ),
    ]);
  }

  GameTransition completeNpcTraining(
    GameState state,
    Quest quest,
    String dialogId,
    DateTime now,
  ) {
    if (quest.level < 2 && !quest.isBoss) {
      throw const GameRuleException('Репетиция недоступна для этого вызова.');
    }
    if (dialogId.trim().isEmpty) {
      throw const GameRuleException('Сценарий репетиции не найден.');
    }
    final trainedQuestIds = {...state.trainedQuestIds, quest.id};
    final active = state.activeQuest;
    final next = state.copyWith(
      trainedQuestIds: trainedQuestIds,
      activeQuest: active?.questId == quest.id
          ? ActiveQuest(
              questId: active!.questId,
              startedAt: active.startedAt,
              variant: active.variant,
              npcTrained: true,
              modifierId: active.modifierId,
            )
          : active,
    );
    return GameTransition(next, [
      GameEvent(
        id: _idGenerator(),
        type: GameEventType.npcTrainingCompleted,
        questId: quest.id,
        createdAt: now,
        payload: {'dialogId': dialogId, 'xpBuffPercent': 10},
      ),
    ]);
  }

  ModifierAllowance modifierAllowance(GameState state, DateTime now) {
    final dice = state.modifierDice.date == calendarDayKey(now)
        ? state.modifierDice
        : ModifierDiceState.empty();
    final remaining = (1 - dice.rollsUsed).clamp(0, 1);
    return ModifierAllowance(canRoll: remaining > 0, remaining: remaining);
  }

  GameTransition rollModifier(
    GameState state,
    Quest quest,
    ModifierCatalog catalog,
    DateTime now,
  ) {
    if (quest.isShadow) {
      throw const GameRuleException(
        'Модификатор применяется только к реальному вызову.',
      );
    }
    if (state.activeQuest != null) {
      throw const GameRuleException('Бросок доступен только до старта.');
    }
    final completionKey = quest.isBoss ? utcDayKey(now) : localDailyKey(now);
    if (state.completedByDate[completionKey]?.contains(quest.id) == true) {
      throw const GameRuleException('Этот вызов уже закрыт сегодня.');
    }

    final refreshed = _refreshModifierDice(state, now);
    if (refreshed.modifierDice.rollsUsed >= 1) {
      throw const GameRuleException(
        'Бесплатный бросок уже использован сегодня.',
      );
    }
    final index =
        _fnv1a('${quest.id}:${now.toUtc().toIso8601String()}:free') %
        catalog.modifiers.length;
    final modifier = catalog.modifiers[index];
    final next = refreshed.copyWith(
      modifierDice: ModifierDiceState(
        date: calendarDayKey(now),
        rollsUsed: refreshed.modifierDice.rollsUsed + 1,
      ),
      preparedModifierIds: {
        ...refreshed.preparedModifierIds,
        quest.id: modifier.id,
      },
    );
    return GameTransition(next, [
      GameEvent(
        id: _idGenerator(),
        type: GameEventType.diceRolled,
        questId: quest.id,
        createdAt: now,
        payload: {
          'modifierId': modifier.id,
          'isPro': false,
          'diceDate': calendarDayKey(now),
        },
      ),
    ]);
  }

  GameTransition start(
    GameState state,
    Quest quest,
    DateTime now, {
    String variant = 'normal',
  }) {
    final next = regenerateEnergy(state, now);
    if (variant != 'normal' && variant != 'low_pressure') {
      throw const GameRuleException('Неизвестный маршрут вызова.');
    }
    if (next.activeQuest != null) {
      throw const GameRuleException('Сначала закрой текущую попытку.');
    }
    final completionKey = quest.isBoss ? utcDayKey(now) : localDailyKey(now);
    if (next.completedByDate[completionKey]?.contains(quest.id) == true) {
      throw const GameRuleException('Этот вызов уже закрыт сегодня.');
    }
    final active = ActiveQuest(
      questId: quest.id,
      startedAt: now.toUtc(),
      variant: variant,
      npcTrained: next.trainedQuestIds.contains(quest.id),
      modifierId: next.preparedModifierIds[quest.id],
    );
    return GameTransition(next.copyWith(activeQuest: active), [
      GameEvent(
        id: _idGenerator(),
        type: GameEventType.questStarted,
        questId: quest.id,
        createdAt: now,
        payload: {
          'level': quest.level,
          'statType': quest.statType.name,
          'isBoss': quest.isBoss,
          'isShadow': quest.isShadow,
          'variant': variant,
          'npcTrained': active.npcTrained,
          'modifierId': active.modifierId,
        },
      ),
    ]);
  }

  GameTransition defer(GameState state, Quest quest, DateTime now) {
    final active = state.activeQuest;
    if (active?.questId != quest.id) {
      throw const GameRuleException('Сначала прими этот вызов.');
    }
    final activeQuest = active!;
    final duration = now
        .toUtc()
        .difference(activeQuest.startedAt.toUtc())
        .inSeconds;
    return GameTransition(state.copyWith(activeQuest: null), [
      GameEvent(
        id: _idGenerator(),
        type: GameEventType.questDeferred,
        questId: quest.id,
        createdAt: now,
        payload: {
          'deferReason': 'not_now',
          'attemptDurationSeconds': duration < 0 ? 0 : duration,
          'energyDelta': 0,
          'energyAfter': state.energy,
          'variant': activeQuest.variant,
          'modifierId': activeQuest.modifierId,
        },
      ),
    ]);
  }

  GameTransition complete(
    GameState state,
    Quest quest,
    DateTime now, {
    ReflectionDraft? reflection,
    bool skipReflection = false,
  }) {
    final active = state.activeQuest;
    if (active?.questId != quest.id) {
      throw const GameRuleException('Сначала прими этот вызов.');
    }
    final activeQuest = active!;
    if (!skipReflection && reflection == null) {
      throw const GameRuleException('Заполни reflection или выбери пропуск.');
    }
    reflection?.validate();
    final beforeEnergy = state.energy;
    final energy = quest.isShadow
        ? (state.energy + quest.rewardEnergy).clamp(0, 100)
        : (state.energy - quest.energyCost).clamp(0, 100);
    final baseXp = xpByLevel[quest.level] ?? 40;
    var gainedXp = quest.isShadow
        ? (baseXp * 0.5).round()
        : quest.isBoss
        ? baseXp * 2
        : baseXp;
    if (activeQuest.npcTrained) {
      gainedXp = (gainedXp * 1.1).round();
    }
    final xp = {
      ...state.xp,
      quest.statType: (state.xp[quest.statType] ?? 0) + gainedXp,
    };
    final completionKey = quest.isBoss ? utcDayKey(now) : localDailyKey(now);
    final completedByDate = {
      ...state.completedByDate,
      completionKey: {
        ...?state.completedByDate[completionKey],
        quest.id,
      }.toList(growable: false),
    };
    final next = state.copyWith(
      energy: energy,
      energyUpdatedAt: now.toUtc(),
      xp: xp,
      activeQuest: null,
      completedCount: state.completedCount + (quest.isShadow ? 0 : 1),
      completedByDate: completedByDate,
      trainedQuestIds: {...state.trainedQuestIds}..remove(quest.id),
      preparedModifierIds: {...state.preparedModifierIds}..remove(quest.id),
    );
    final reflectionRecord = reflection == null
        ? null
        : QuestReflection(
            id: _idGenerator(),
            questId: quest.id,
            fearScore: reflection.fearScore,
            feelAfterScore: reflection.feelAfterScore,
            wantRepeat: reflection.wantRepeat,
            note: reflection.note.trim(),
            createdAt: now,
          );
    final events = <GameEvent>[
      GameEvent(
        id: _idGenerator(),
        type: GameEventType.questCompleted,
        questId: quest.id,
        createdAt: now,
        payload: {
          'statType': quest.statType.name,
          'xpDelta': gainedXp,
          'energyDelta': energy - beforeEnergy,
          'energyAfter': energy,
          'isBoss': quest.isBoss,
          'variant': activeQuest.variant,
          'npcTrained': activeQuest.npcTrained,
          'modifierId': activeQuest.modifierId,
          'reflectionId': reflectionRecord?.id,
          'reflectionSkipped': skipReflection,
          'completionKey': completionKey,
          'attemptDurationSeconds': now
              .toUtc()
              .difference(activeQuest.startedAt.toUtc())
              .inSeconds
              .clamp(0, 86400),
        },
      ),
    ];
    if (reflectionRecord != null) {
      events.add(
        GameEvent(
          id: _idGenerator(),
          type: GameEventType.reflectionSubmitted,
          questId: quest.id,
          createdAt: now,
          payload: {
            'reflectionId': reflectionRecord.id,
            'fearScore': reflectionRecord.fearScore,
            'feelAfterScore': reflectionRecord.feelAfterScore,
            'wantRepeat': reflectionRecord.wantRepeat,
          },
        ),
      );
    }
    return GameTransition(
      next,
      events,
      reflectionRecord == null ? const [] : [reflectionRecord],
    );
  }

  static String localDailyKey(DateTime date) {
    final shifted = date.hour < 12
        ? DateTime(date.year, date.month, date.day - 1, 12)
        : date;
    return _dateKey(shifted.year, shifted.month, shifted.day);
  }

  static String utcDayKey(DateTime date) {
    final utc = date.toUtc();
    return _dateKey(utc.year, utc.month, utc.day);
  }

  static String calendarDayKey(DateTime date) {
    return _dateKey(date.year, date.month, date.day);
  }

  GameState _refreshModifierDice(GameState state, DateTime now) {
    final date = calendarDayKey(now);
    if (state.modifierDice.date == date) return state;
    return state.copyWith(
      modifierDice: ModifierDiceState(date: date, rollsUsed: 0),
    );
  }

  Quest _pickStable(List<Quest> items, String seed, int salt) {
    if (items.isEmpty) throw StateError('Quest selection pool is empty');
    final index = _fnv1a('$seed:$salt') % items.length;
    return items[index];
  }

  int _fnv1a(String input) {
    var hash = 0x811c9dc5;
    for (final unit in input.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }

  static String _dateKey(int year, int month, int day) {
    return '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
  }
}
