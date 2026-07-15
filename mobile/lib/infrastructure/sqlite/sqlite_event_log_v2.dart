import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../core/sync/event_envelope_v2.dart';
import '../../core/sync/event_log_v2.dart';

class SqliteEventLogV2 implements EventLogV2 {
  SqliteEventLogV2(this._database, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final Database _database;
  final DateTime Function() _clock;

  @override
  Future<EventEnvelopeV2> append(EventDraftV2 draft) {
    return _database.transaction((transaction) async {
      final identities = await transaction.query('user_identity', limit: 1);
      if (identities.isEmpty) {
        throw StateError('Local identity is not initialized');
      }
      final identity = identities.single;
      final installationId = identity['installation_id'] as String;
      final localUserId = identity['local_user_id'] as String;
      final remoteUserId = identity['remote_user_id'] as String?;
      final sequenceKey = 'client_sequence:$installationId';
      final sequenceRows = await transaction.query(
        'app_metadata',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: [sequenceKey],
        limit: 1,
      );
      final previous = sequenceRows.isEmpty
          ? 0
          : int.parse(sequenceRows.single['value'] as String);
      final next = previous + 1;
      final envelope = EventEnvelopeV2(
        eventId: draft.eventId,
        eventType: draft.eventType,
        localUserId: localUserId,
        remoteUserId: remoteUserId,
        installationId: installationId,
        clientSequence: next,
        occurredAtUtc: draft.occurredAtUtc.toUtc(),
        timezoneId: draft.timezoneId,
        timezoneOffsetMinutes: draft.timezoneOffsetMinutes,
        assignmentId: draft.assignmentId,
        attemptId: draft.attemptId,
        contentId: draft.contentId,
        contentRevision: draft.contentRevision,
        payload: draft.payload,
      );
      await transaction.insert('event_log_v2', envelope.toDatabaseMap());
      await transaction.insert('app_metadata', {
        'key': sequenceKey,
        'value': next.toString(),
        'updated_at': _clock().toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      return envelope;
    });
  }

  @override
  Future<List<EventEnvelopeV2>> loadAfter({
    required String installationId,
    required int clientSequence,
    int limit = 500,
  }) {
    if (limit < 1 || limit > 1000) {
      throw ArgumentError.value(limit, 'limit', 'Must be between 1 and 1000');
    }
    return _database.transaction((transaction) async {
      final rows = await transaction.query(
        'event_log_v2',
        where: 'installation_id = ? AND client_sequence > ?',
        whereArgs: [installationId, clientSequence],
        orderBy: 'client_sequence ASC',
        limit: limit,
      );
      final events = <EventEnvelopeV2>[];
      for (final row in rows) {
        try {
          events.add(EventEnvelopeV2.fromDatabaseMap(row));
        } catch (error) {
          await transaction.insert('event_quarantine', {
            'raw_row_json': jsonEncode(row),
            'reason': 'event_v2_parse_failed:${error.runtimeType}',
            'quarantined_at': _clock().toUtc().toIso8601String(),
          });
        }
      }
      return events;
    });
  }
}
