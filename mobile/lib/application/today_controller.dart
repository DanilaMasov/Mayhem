import 'package:flutter/foundation.dart';

import '../domain/models/game_state.dart';
import '../domain/models/npc_dialog.dart';
import '../domain/models/quest.dart';
import '../domain/models/quest_catalog.dart';
import '../domain/models/quest_guide.dart';
import '../domain/models/quest_modifier.dart';
import '../domain/models/quest_reflection.dart';
import '../domain/ports/game_store.dart';
import '../domain/services/game_engine.dart';
import '../domain/services/game_state_rebuilder.dart';

class TodayController extends ChangeNotifier {
  TodayController(
    this._store,
    this._catalog,
    this._guides,
    this._dialogs,
    this._modifiers,
    this._engine, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final GameStore _store;
  final QuestCatalog _catalog;
  final GuideCatalog _guides;
  final DialogCatalog _dialogs;
  final ModifierCatalog _modifiers;
  final GameEngine _engine;
  final GameStateRebuilder _rebuilder = const GameStateRebuilder();
  final DateTime Function() _clock;

  GameState? _state;
  bool _loading = true;
  String _error = '';
  String _loadSource = 'pending';

  bool get loading => _loading;
  String get error => _error;
  String get loadSource => _loadSource;
  GameState get state =>
      _state ?? (throw StateError('Controller is not initialized'));

  Quest get bossQuest => _catalog.byId(state.daily.bossId);
  List<Quest> get localQuests =>
      state.daily.localQuestIds.map(_catalog.byId).toList(growable: false);

  Quest questById(String id) => _catalog.byId(id);
  QuestGuide guideFor(String questId) => _guides.forQuest(questId);
  NpcDialog dialogFor(String questId) => _dialogs.forQuest(questId);
  bool hasDialog(String questId) => _dialogs.hasDialog(questId);
  bool isTrained(String questId) => state.trainedQuestIds.contains(questId);
  bool get shouldShowBoundaries =>
      state.completedCount >= 1 && !state.onboarding.boundariesAcknowledged;

  Quest get onboardingQuest {
    final ids = const ['q_c_001', 'q_b_002', 'q_c_002'];
    final id = ids[state.completedCount.clamp(0, 2)];
    try {
      return _catalog.byId(id);
    } on StateError {
      return _catalog.regularAtLevel(1).first;
    }
  }

  ModifierAllowance get modifierAllowance =>
      _engine.modifierAllowance(state, _clock());

  QuestModifier? modifierFor(Quest quest) {
    final active = state.activeQuest;
    final modifierId = active?.questId == quest.id
        ? active?.modifierId
        : state.preparedModifierIds[quest.id];
    return modifierId == null ? null : _modifiers.byId(modifierId);
  }

  Future<void> openGuide(Quest quest) {
    final guide = _guides.forQuest(quest.id);
    return _apply(_engine.openGuide(state, quest, guide.id, _clock()));
  }

  Future<void> completeTraining(Quest quest) {
    final dialog = _dialogs.forQuest(quest.id);
    return _apply(
      _engine.completeNpcTraining(state, quest, dialog.id, _clock()),
    );
  }

  Future<void> rollModifier(Quest quest) {
    return _apply(_engine.rollModifier(state, quest, _modifiers, _clock()));
  }

  Future<void> acknowledgeBoundaries() {
    return _apply(_engine.acknowledgeBoundaries(state, _clock()));
  }

  Future<void> initialize() async {
    try {
      final now = _clock();
      GameState? snapshot;
      Object? snapshotError;
      StackTrace? snapshotStackTrace;
      try {
        snapshot = await _store.load();
      } catch (error, stackTrace) {
        snapshotError = error;
        snapshotStackTrace = stackTrace;
      }

      final events = await _store.loadEvents();
      GameState base;
      if (events.isNotEmpty) {
        base = _rebuilder.rebuild(events, _catalog, now: now);
        _loadSource = snapshotError == null
            ? 'event_log'
            : 'event_log_recovery';
        debugPrint(
          '[mayhem-recovery] rebuilt state from ${events.length} events '
          '(source: $_loadSource)',
        );
      } else if (snapshotError != null) {
        Error.throwWithStackTrace(snapshotError, snapshotStackTrace!);
      } else if (snapshot != null) {
        base = snapshot;
        _loadSource = 'snapshot';
      } else {
        base = GameState.initial(now);
        _loadSource = 'fresh';
      }

      _state = _engine.refresh(base, _catalog, now);
      await _store.commit(state, const []);
      _error = '';
    } catch (error, stackTrace) {
      _error = 'Не удалось загрузить локальный прогресс.';
      _loadSource = 'failed';
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'mayhem bootstrap',
        ),
      );
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> startQuest(Quest quest, {String variant = 'normal'}) =>
      _apply(_engine.start(state, quest, _clock(), variant: variant));

  Future<void> deferQuest(Quest quest) =>
      _apply(_engine.defer(state, quest, _clock()));

  Future<void> completeQuest(
    Quest quest, {
    ReflectionDraft? reflection,
    bool skipReflection = false,
  }) => _apply(
    _engine.complete(
      state,
      quest,
      _clock(),
      reflection: reflection,
      skipReflection: skipReflection,
    ),
  );

  Future<void> refresh() async {
    final next = _engine.refresh(state, _catalog, _clock());
    _state = next;
    await _store.commit(next, const []);
    notifyListeners();
  }

  Future<void> clearLocalData() async {
    final now = _clock();
    await _store.clear();
    final fresh = _engine.refresh(GameState.initial(now), _catalog, now);
    await _store.commit(fresh, const []);
    _state = fresh;
    _loadSource = 'fresh';
    _error = '';
    notifyListeners();
  }

  Future<void> _apply(GameTransition transition) async {
    await _store.commit(
      transition.state,
      transition.events,
      reflections: transition.reflections,
    );
    _state = transition.state;
    _error = '';
    notifyListeners();
  }

  @override
  void dispose() {
    _store.close();
    super.dispose();
  }
}
