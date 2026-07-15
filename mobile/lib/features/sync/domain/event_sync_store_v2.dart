import '../../../core/sync/event_envelope_v2.dart';
import 'backend_models.dart';

class PendingEventV2 {
  const PendingEventV2({required this.event, required this.attempts});

  final EventEnvelopeV2 event;
  final int attempts;
}

class EventRetryV2 {
  const EventRetryV2({
    required this.eventId,
    required this.attempts,
    required this.nextRetryAt,
    required this.errorCode,
  });

  final String eventId;
  final int attempts;
  final DateTime nextRetryAt;
  final String errorCode;
}

abstract interface class EventSyncStoreV2 {
  Future<List<PendingEventV2>> loadReadyPending({
    required DateTime now,
    int limit = 100,
  });

  Future<List<EventEnvelopeV2>> loadAllPending({int limit = 500});

  Future<void> applyServerResults({
    required List<RemoteEventResult> results,
    required DateTime receivedAt,
  });

  Future<void> scheduleRetries(List<EventRetryV2> retries);
}
