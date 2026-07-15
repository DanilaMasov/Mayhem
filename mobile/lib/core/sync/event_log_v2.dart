import 'event_envelope_v2.dart';

abstract interface class EventLogV2 {
  Future<EventEnvelopeV2> append(EventDraftV2 draft);

  Future<List<EventEnvelopeV2>> loadAfter({
    required String installationId,
    required int clientSequence,
    int limit = 500,
  });
}
