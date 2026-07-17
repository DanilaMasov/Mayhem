import '../../../core/sync/event_envelope_v2.dart';

enum SeasonActionDelivery { pending, synced, rejected }

class SeasonActionRecord {
  const SeasonActionRecord({
    required this.eventId,
    required this.eventType,
    required this.seasonId,
    required this.delivery,
    required this.attempts,
    this.errorCode,
  });

  final String eventId;
  final CanonicalEventTypeV2 eventType;
  final String seasonId;
  final SeasonActionDelivery delivery;
  final int attempts;
  final String? errorCode;
}

abstract interface class SeasonActionJournal {
  Future<SeasonActionRecord?> latestJoin(String seasonId);

  Future<void> retryNow(String eventId);
}
