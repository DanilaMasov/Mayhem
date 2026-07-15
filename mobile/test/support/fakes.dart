import 'package:mayhem_mobile/domain/models/game_event.dart';
import 'package:mayhem_mobile/domain/models/event_sync.dart';
import 'package:mayhem_mobile/domain/models/game_state.dart';
import 'package:mayhem_mobile/domain/models/npc_dialog.dart';
import 'package:mayhem_mobile/domain/models/quest.dart';
import 'package:mayhem_mobile/domain/models/quest_catalog.dart';
import 'package:mayhem_mobile/domain/models/quest_guide.dart';
import 'package:mayhem_mobile/domain/models/quest_modifier.dart';
import 'package:mayhem_mobile/domain/models/quest_reflection.dart';
import 'package:mayhem_mobile/domain/ports/game_store.dart';
import 'package:mayhem_mobile/domain/ports/event_sync_store.dart';
import 'package:mayhem_mobile/domain/ports/installation_identity_store.dart';

class MemoryGameStore
    implements GameStore, EventSyncStore, InstallationIdentityStore {
  GameState? state;
  Object? loadFailure;
  final List<GameEvent> events = [];
  final List<QuestReflection> reflections = [];
  int clearCount = 0;
  final Map<String, String> syncStatusById = {};
  final Map<String, int> syncAttemptsById = {};
  final Map<String, DateTime> nextRetryById = {};
  final Map<String, String> syncErrorById = {};
  String? installationId;

  @override
  Future<GameState?> load() async {
    if (loadFailure != null) throw loadFailure!;
    return state;
  }

  @override
  Future<List<GameEvent>> loadEvents() async => List.unmodifiable(events);

  @override
  Future<String> getOrCreateInstallationId(String Function() generator) async {
    return installationId ??= generator();
  }

  @override
  Future<void> commit(
    GameState state,
    List<GameEvent> events, {
    List<QuestReflection> reflections = const [],
  }) async {
    this.state = state;
    this.events.addAll(events);
    for (final event in events) {
      syncStatusById.putIfAbsent(event.id, () => 'pending');
      syncAttemptsById.putIfAbsent(event.id, () => 0);
    }
    this.reflections.addAll(reflections);
  }

  @override
  Future<List<PendingGameEvent>> loadPendingEvents({
    required DateTime now,
    required int limit,
  }) async {
    final pending =
        events
            .where(
              (event) =>
                  syncStatusById[event.id] == 'pending' &&
                  !(nextRetryById[event.id]?.isAfter(now) ?? false),
            )
            .map(
              (event) => PendingGameEvent(
                event: event,
                attempts: syncAttemptsById[event.id] ?? 0,
              ),
            )
            .toList(growable: false)
          ..sort((left, right) {
            final byTime = left.event.createdAt.compareTo(
              right.event.createdAt,
            );
            return byTime != 0
                ? byTime
                : left.event.id.compareTo(right.event.id);
          });
    return pending.take(limit).toList(growable: false);
  }

  @override
  Future<void> applyEventSyncResult({
    required Set<String> acceptedIds,
    required Map<String, String> rejectedById,
    required List<EventRetryUpdate> retries,
  }) async {
    for (final eventId in acceptedIds) {
      syncStatusById[eventId] = 'synced';
      syncErrorById.remove(eventId);
      nextRetryById.remove(eventId);
    }
    for (final entry in rejectedById.entries) {
      syncStatusById[entry.key] = 'rejected';
      syncErrorById[entry.key] = entry.value;
      nextRetryById.remove(entry.key);
    }
    _applyRetries(retries);
  }

  @override
  Future<void> scheduleEventRetries(List<EventRetryUpdate> updates) async {
    _applyRetries(updates);
  }

  void _applyRetries(List<EventRetryUpdate> updates) {
    for (final update in updates) {
      syncStatusById[update.eventId] = 'pending';
      syncAttemptsById[update.eventId] = update.attempts;
      syncErrorById[update.eventId] = update.error;
      nextRetryById[update.eventId] = update.nextRetryAt;
    }
  }

  @override
  Future<void> clear() async {
    state = null;
    events.clear();
    reflections.clear();
    syncStatusById.clear();
    syncAttemptsById.clear();
    nextRetryById.clear();
    syncErrorById.clear();
    installationId = null;
    clearCount += 1;
    loadFailure = null;
  }

  @override
  Future<void> close() async {}
}

QuestCatalog buildTestCatalog() {
  return QuestCatalog(
    schemaVersion: 1,
    quests: const [
      Quest(
        id: 'level_1',
        level: 1,
        statType: StatType.charisma,
        energyCost: 10,
        category: 'Контакт',
        text: 'Представься одному участнику.',
        alternateRoute: 'Поздоровайся первым.',
        advancedRoute: 'Узнай имя.',
      ),
      Quest(
        id: 'level_2',
        level: 2,
        statType: StatType.boldness,
        energyCost: 25,
        category: 'Позиция',
        text: 'Выскажи одну ясную позицию.',
        alternateRoute: 'Скажи это знакомому.',
        advancedRoute: 'Попроси контраргумент.',
      ),
      Quest(
        id: 'level_3',
        level: 3,
        statType: StatType.networking,
        energyCost: 50,
        category: 'Связь',
        text: 'Предложи обменяться контактами.',
        alternateRoute: 'Попроси публичный профиль.',
        advancedRoute: 'Назови следующий шаг.',
      ),
      Quest(
        id: 'reset_1',
        level: 1,
        statType: StatType.charisma,
        energyCost: 0,
        rewardEnergy: 5,
        category: 'Reset',
        text: 'Подготовь одну фразу.',
        alternateRoute: 'Прочитай фразу.',
        advancedRoute: 'Повтори три раза.',
        isShadow: true,
      ),
    ],
    bosses: const [
      Quest(
        id: 'boss_1',
        level: 3,
        statType: StatType.boldness,
        energyCost: 50,
        category: 'Вызов',
        text: 'Предложи знакомому конкретный план.',
        alternateRoute: 'Предложи план на завтра.',
        advancedRoute: 'Пригласи второго человека.',
        isBoss: true,
      ),
    ],
  );
}

GuideCatalog buildTestGuideCatalog([QuestCatalog? source]) {
  final catalog = source ?? buildTestCatalog();
  return GuideCatalog(
    schemaVersion: 1,
    guides: catalog.quests
        .followedBy(catalog.bosses)
        .map(
          (quest) => QuestGuide(
            id: 'guide_${quest.id}',
            questId: quest.id,
            steps: const [
              'Выбери момент.',
              'Скажи первую фразу.',
              'Заверши контакт сам.',
            ],
            phrases: const ['Привет.', 'Можно вопрос?', 'Спасибо.'],
            exitScript: 'Спасибо, хорошего дня.',
            alternateRoute: quest.alternateRoute,
            advancedRoute: quest.advancedRoute,
          ),
        )
        .toList(growable: false),
  );
}

DialogCatalog buildTestDialogCatalog([QuestCatalog? source]) {
  final catalog = source ?? buildTestCatalog();
  final eligible = catalog.quests
      .where((quest) => !quest.isShadow && quest.level >= 2)
      .followedBy(catalog.bosses);
  return DialogCatalog(
    schemaVersion: 1,
    dialogs: eligible
        .map(
          (quest) => NpcDialog(
            id: 'dialog_${quest.id}',
            questId: quest.id,
            startNodeId: 'start',
            nodes: const [
              DialogNode(
                id: 'start',
                speaker: DialogSpeaker.npc,
                text: 'Что ты скажешь?',
                options: [
                  DialogOption(label: 'Сказать прямо', nextNodeId: 'success'),
                ],
                success: false,
              ),
              DialogNode(
                id: 'success',
                speaker: DialogSpeaker.npc,
                text: 'Понятно, спасибо.',
                options: [],
                success: true,
              ),
            ],
          ),
        )
        .toList(growable: false),
  );
}

QuestCatalog buildOnboardingTestCatalog() {
  return QuestCatalog(
    schemaVersion: 1,
    quests: const [
      Quest(
        id: 'q_c_001',
        level: 1,
        statType: StatType.charisma,
        energyCost: 10,
        category: 'Благодарность',
        text: 'Скажи спасибо чуть теплее обычного.',
        alternateRoute: 'Скажи обычное спасибо.',
        advancedRoute: 'Добавь конкретную благодарность.',
      ),
      Quest(
        id: 'q_b_002',
        level: 1,
        statType: StatType.boldness,
        energyCost: 10,
        category: 'Вопрос',
        text: 'Задай один нейтральный вопрос.',
        alternateRoute: 'Спроси сотрудника.',
        advancedRoute: 'Уточни один нюанс.',
      ),
      Quest(
        id: 'q_c_002',
        level: 1,
        statType: StatType.charisma,
        energyCost: 10,
        category: 'Комплимент',
        text: 'Сделай комплимент вещи.',
        alternateRoute: 'Скажи это знакомому.',
        advancedRoute: 'Задай вопрос о вещи.',
      ),
      Quest(
        id: 'onboarding_level_2',
        level: 2,
        statType: StatType.boldness,
        energyCost: 25,
        category: 'Позиция',
        text: 'Выскажи позицию.',
        alternateRoute: 'Скажи знакомому.',
        advancedRoute: 'Попроси контраргумент.',
      ),
      Quest(
        id: 'onboarding_level_3',
        level: 3,
        statType: StatType.networking,
        energyCost: 50,
        category: 'Связь',
        text: 'Предложи следующий шаг.',
        alternateRoute: 'Попроси профиль.',
        advancedRoute: 'Назови время.',
      ),
      Quest(
        id: 'onboarding_reset',
        level: 1,
        statType: StatType.charisma,
        energyCost: 0,
        rewardEnergy: 5,
        category: 'Reset',
        text: 'Подготовь фразу.',
        alternateRoute: 'Прочитай её.',
        advancedRoute: 'Повтори её.',
        isShadow: true,
      ),
    ],
    bosses: const [
      Quest(
        id: 'onboarding_boss',
        level: 3,
        statType: StatType.boldness,
        energyCost: 50,
        category: 'Вызов',
        text: 'Предложи конкретный план.',
        alternateRoute: 'Предложи план на завтра.',
        advancedRoute: 'Добавь второго человека.',
        isBoss: true,
      ),
    ],
  );
}

ModifierCatalog buildTestModifierCatalog() {
  return ModifierCatalog(
    schemaVersion: 1,
    modifiers: const [
      QuestModifier(
        id: 'whisper',
        title: 'Без разгона',
        text: 'Начни в течение пяти секунд.',
      ),
      QuestModifier(
        id: 'drama',
        title: 'Без оправданий',
        text: 'Не начинай с извинений.',
      ),
      QuestModifier(
        id: 'capybara',
        title: 'Две минуты',
        text: 'Останься на две минуты при взаимном интересе.',
      ),
      QuestModifier(
        id: 'robot',
        title: 'Одна фраза',
        text: 'Сформулируй действие одним предложением.',
      ),
      QuestModifier(
        id: 'echo',
        title: 'Чистый выход',
        text: 'Сам закончи контакт.',
      ),
    ],
  );
}
