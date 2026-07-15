import '../models/game_event.dart';
import '../models/game_state.dart';
import '../models/quest_reflection.dart';

abstract interface class GameStore {
  Future<GameState?> load();

  Future<List<GameEvent>> loadEvents();

  Future<void> commit(
    GameState state,
    List<GameEvent> events, {
    List<QuestReflection> reflections = const [],
  });

  Future<void> clear();

  Future<void> close();
}
