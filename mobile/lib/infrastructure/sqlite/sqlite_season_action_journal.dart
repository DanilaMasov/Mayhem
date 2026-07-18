import 'package:sqflite/sqflite.dart';

import '../../core/sync/event_envelope_v2.dart';
import '../../features/season/domain/season_action_journal.dart';
import 'sqlite_vnext_context.dart';

class SqliteSeasonActionJournal implements SeasonActionJournal {
  const SqliteSeasonActionJournal(this.context);

  final SqliteVNextContext context;

  @override
  Future<SeasonActionRecord?> latestJoin(String seasonId) {
    return context.database.read((db) async {
      for (final record in await _records(
        db,
        CanonicalEventTypeV2.seasonJoined,
      )) {
        if (record.seasonId == seasonId) return record;
      }
      return null;
    });
  }

  @override
  Future<Map<int, SeasonActionRecord>> latestDays(String seasonId) {
    return context.database.read((db) async {
      final latest = <int, SeasonActionRecord>{};
      for (final record in await _records(
        db,
        CanonicalEventTypeV2.seasonDayCompleted,
        limit: 100,
      )) {
        final day = record.day;
        if (record.seasonId == seasonId && day != null) {
          latest.putIfAbsent(day, () => record);
        }
      }
      return Map.unmodifiable(latest);
    });
  }

  @override
  Future<SeasonActionRecord?> latestBoss(String seasonId, String bossEventId) {
    return context.database.read((db) async {
      for (final record in await _records(
        db,
        CanonicalEventTypeV2.bossParticipated,
      )) {
        if (record.seasonId == seasonId && record.bossEventId == bossEventId) {
          return record;
        }
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

  Future<List<SeasonActionRecord>> _records(
    DatabaseExecutor db,
    CanonicalEventTypeV2 type, {
    int limit = 50,
  }) async {
    final rows = await db.query(
      'event_log_v2',
      where: 'event_type = ?',
      whereArgs: [type.wireName],
      orderBy: 'client_sequence DESC',
      limit: limit,
    );
    return [
      for (final row in rows)
        _record(EventEnvelopeV2.fromDatabaseMap(row), row),
    ];
  }

  SeasonActionRecord _record(EventEnvelopeV2 event, Map<String, Object?> row) {
    final seasonId = event.payload['seasonId'];
    final seasonRevision = event.payload['seasonRevision'];
    if (seasonId is! String ||
        seasonId.trim().isEmpty ||
        seasonRevision is! int ||
        seasonRevision < 1) {
      throw const FormatException('Season action identity is invalid');
    }
    final day = event.payload['day'];
    final bossEventId = event.payload['bossEventId'];
    return SeasonActionRecord(
      eventId: event.eventId,
      eventType: event.eventType,
      seasonId: seasonId,
      seasonRevision: seasonRevision,
      delivery: _delivery(row['sync_status']),
      attempts: (row['attempt_count'] as num?)?.toInt() ?? 0,
      day: day is int ? day : null,
      bossEventId: bossEventId is String ? bossEventId : null,
      errorCode: row['last_error_code'] as String?,
    );
  }

  SeasonActionDelivery _delivery(Object? value) => switch (value) {
    'pending' => SeasonActionDelivery.pending,
    'synced' => SeasonActionDelivery.synced,
    'rejected' => SeasonActionDelivery.rejected,
    _ => throw const FormatException('Season action delivery is invalid'),
  };
}
