import '../../core/sync/event_envelope_v2.dart';
import '../../features/season/domain/season_action_journal.dart';
import 'sqlite_vnext_context.dart';

class SqliteSeasonActionJournal implements SeasonActionJournal {
  const SqliteSeasonActionJournal(this.context);

  final SqliteVNextContext context;

  @override
  Future<SeasonActionRecord?> latestJoin(String seasonId) {
    return context.database.read((db) async {
      final rows = await db.query(
        'event_log_v2',
        where: 'event_type = ?',
        whereArgs: [CanonicalEventTypeV2.seasonJoined.wireName],
        orderBy: 'client_sequence DESC',
        limit: 50,
      );
      for (final row in rows) {
        final event = EventEnvelopeV2.fromDatabaseMap(row);
        if (event.payload['seasonId'] != seasonId) continue;
        return SeasonActionRecord(
          eventId: event.eventId,
          eventType: event.eventType,
          seasonId: seasonId,
          delivery: _delivery(row['sync_status']),
          attempts: (row['attempt_count'] as num?)?.toInt() ?? 0,
          errorCode: row['last_error_code'] as String?,
        );
      }
      return null;
    });
  }

  @override
  Future<void> retryNow(String eventId) {
    return context.database.transaction((db) async {
      final changed = await db.update(
        'event_log_v2',
        {'next_retry_at': null, 'last_error_code': null},
        where: 'event_id = ?',
        whereArgs: [eventId],
      );
      if (changed != 1) throw StateError('Season action event is unavailable');
    });
  }

  SeasonActionDelivery _delivery(Object? value) => switch (value) {
    'pending' => SeasonActionDelivery.pending,
    'synced' => SeasonActionDelivery.synced,
    'rejected' => SeasonActionDelivery.rejected,
    _ => throw const FormatException('Season action delivery is invalid'),
  };
}
