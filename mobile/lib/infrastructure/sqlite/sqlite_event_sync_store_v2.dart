import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../core/sync/event_envelope_v2.dart';
import '../../features/sync/domain/backend_models.dart';
import '../../features/sync/domain/event_sync_store_v2.dart';
import 'sqlite_vnext_context.dart';

class SqliteEventSyncStoreV2 implements EventSyncStoreV2 {
  const SqliteEventSyncStoreV2(this.context);

  final SqliteVNextContext context;

  @override
  Future<List<PendingEventV2>> loadReadyPending({
    required DateTime now,
    int limit = 100,
  }) {
    if (limit < 1 || limit > 100) {
      throw ArgumentError.value(limit, 'limit', 'Must be between 1 and 100');
    }
    return context.database.transaction((db) async {
      final rows = await db.query(
        'event_log_v2',
        where:
            "sync_status = 'pending' AND "
            '(next_retry_at IS NULL OR next_retry_at <= ?)',
        whereArgs: [now.toUtc().toIso8601String()],
        orderBy: 'installation_id ASC, client_sequence ASC',
        limit: limit,
      );
      final pending = <PendingEventV2>[];
      for (final row in rows) {
        try {
          pending.add(
            PendingEventV2(
              event: EventEnvelopeV2.fromDatabaseMap(row),
              attempts: (row['attempt_count'] as num).toInt(),
            ),
          );
        } catch (error) {
          await _quarantine(
            db,
            rawRow: row,
            reason: 'sync_event_parse_failed:${error.runtimeType}',
            at: now,
          );
          final eventId = row['event_id'] as String?;
          if (eventId != null) {
            await db.update(
              'event_log_v2',
              {
                'sync_status': 'rejected',
                'last_error_code': 'permanent_schema',
              },
              where: 'event_id = ?',
              whereArgs: [eventId],
            );
          }
        }
      }
      return pending;
    });
  }

  @override
  Future<List<EventEnvelopeV2>> loadAllPending({int limit = 500}) {
    if (limit < 1 || limit > 1000) {
      throw ArgumentError.value(limit, 'limit', 'Must be between 1 and 1000');
    }
    return context.database.transaction((db) async {
      final rows = await db.query(
        'event_log_v2',
        where: "sync_status = 'pending'",
        orderBy: 'installation_id ASC, client_sequence ASC',
        limit: limit,
      );
      final pending = <EventEnvelopeV2>[];
      for (final row in rows) {
        try {
          pending.add(EventEnvelopeV2.fromDatabaseMap(row));
        } catch (error) {
          await _quarantine(
            db,
            rawRow: row,
            reason: 'sync_event_parse_failed:${error.runtimeType}',
            at: context.clock(),
          );
          final eventId = row['event_id'] as String?;
          if (eventId != null) {
            await db.update(
              'event_log_v2',
              {
                'sync_status': 'rejected',
                'last_error_code': 'permanent_schema',
              },
              where: 'event_id = ?',
              whereArgs: [eventId],
            );
          }
        }
      }
      return pending;
    });
  }

  @override
  Future<void> applyServerResults({
    required List<RemoteEventResult> results,
    required DateTime receivedAt,
  }) {
    return context.database.transaction((db) async {
      for (final result in results) {
        if (result.accepted) {
          await db.update(
            'event_log_v2',
            {
              'sync_status': 'synced',
              'next_retry_at': null,
              'last_error_code': null,
              'received_server_at': receivedAt.toUtc().toIso8601String(),
            },
            where: 'event_id = ?',
            whereArgs: [result.eventId],
          );
          continue;
        }
        final code = _dispositionCode(result.disposition);
        final rows = await db.query(
          'event_log_v2',
          where: 'event_id = ?',
          whereArgs: [result.eventId],
          limit: 1,
        );
        if (rows.isNotEmpty) {
          await _quarantine(
            db,
            rawRow: rows.single,
            reason: 'server_rejected:$code',
            at: receivedAt,
          );
        }
        await db.update(
          'event_log_v2',
          {
            'sync_status': 'rejected',
            'next_retry_at': null,
            'last_error_code': code,
            'received_server_at': receivedAt.toUtc().toIso8601String(),
          },
          where: 'event_id = ?',
          whereArgs: [result.eventId],
        );
      }
    });
  }

  @override
  Future<void> scheduleRetries(List<EventRetryV2> retries) {
    return context.database.transaction((db) async {
      for (final retry in retries) {
        await db.update(
          'event_log_v2',
          {
            'sync_status': 'pending',
            'attempt_count': retry.attempts,
            'next_retry_at': retry.nextRetryAt.toUtc().toIso8601String(),
            'last_error_code': retry.errorCode,
          },
          where: 'event_id = ?',
          whereArgs: [retry.eventId],
        );
      }
    });
  }

  Future<void> _quarantine(
    DatabaseExecutor db, {
    required Map<String, Object?> rawRow,
    required String reason,
    required DateTime at,
  }) => db
      .insert('event_quarantine', {
        'raw_row_json': jsonEncode(rawRow),
        'reason': reason,
        'quarantined_at': at.toUtc().toIso8601String(),
      })
      .then((_) {});

  String _dispositionCode(RemoteEventDisposition disposition) =>
      switch (disposition) {
        RemoteEventDisposition.accepted => 'accepted_false',
        RemoteEventDisposition.duplicateEvent => 'duplicate_event_false',
        RemoteEventDisposition.staleContentButValidAssignment =>
          'stale_content_false',
        RemoteEventDisposition.invalidTransition => 'invalid_transition',
        RemoteEventDisposition.unknownAssignment => 'unknown_assignment',
        RemoteEventDisposition.permanentSchema => 'permanent_schema',
      };
}
