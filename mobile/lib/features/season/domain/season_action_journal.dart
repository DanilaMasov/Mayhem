import '../../../core/sync/event_envelope_v2.dart';

enum SeasonActionDelivery { pending, synced, rejected }

class SeasonActionRecord {
  const SeasonActionRecord({
    required this.eventId,
    required this.eventType,
    required this.seasonId,
    required this.seasonRevision,
    required this.delivery,
    required this.attempts,
    this.day,
    this.bossEventId,
    this.errorCode,
  });

  final String eventId;
  final CanonicalEventTypeV2 eventType;
  final String seasonId;
  final int seasonRevision;
  final SeasonActionDelivery delivery;
  final int attempts;
  final int? day;
  final String? bossEventId;
  final String? errorCode;
}

abstract interface class SeasonActionJournal {
  Future<SeasonActionRecord?> latestJoin(String seasonId);

  Future<Map<int, SeasonActionRecord>> latestDays(String seasonId);

  Future<SeasonActionRecord?> latestBoss(String seasonId, String bossEventId);

  Future<void> retryNow(String eventId);
}
