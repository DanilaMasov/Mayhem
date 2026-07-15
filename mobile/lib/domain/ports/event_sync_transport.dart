import '../models/event_sync.dart';
import '../models/game_event.dart';

abstract interface class EventSyncTransport {
  Future<EventSyncAck> pushEvents(List<GameEvent> events);
}
