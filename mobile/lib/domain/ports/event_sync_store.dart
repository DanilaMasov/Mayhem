import '../models/event_sync.dart';

abstract interface class EventSyncStore {
  Future<List<PendingGameEvent>> loadPendingEvents({
    required DateTime now,
    required int limit,
  });

  Future<void> applyEventSyncResult({
    required Set<String> acceptedIds,
    required Map<String, String> rejectedById,
    required List<EventRetryUpdate> retries,
  });

  Future<void> scheduleEventRetries(List<EventRetryUpdate> updates);
}
