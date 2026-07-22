import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../core/identity/local_identity_repository.dart';
import '../../core/sync/event_envelope_v2.dart';
import '../../features/progress/domain/progress_models.dart';
import '../../features/reflection/domain/private_reflection.dart';
import '../../features/streak/domain/momentum_state.dart';
import 'sqlite_vnext_mappers.dart';
import 'vnext_database.dart';

class SqliteVNextContext {
  SqliteVNextContext(this.database, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now;

  static const progressProjection = 'progress';
  static const momentumProjection = 'momentum';

  final VNextDatabase database;
  final DateTime Function() clock;

  Future<LocalIdentity> identity(DatabaseExecutor db) async {
    final rows = await db.query('user_identity', limit: 1);
    if (rows.isEmpty) {
      throw StateError('Local identity is not initialized');
    }
    return LocalIdentity(
      localUserId: rows.single['local_user_id'] as String,
      remoteUserId: rows.single['remote_user_id'] as String?,
      installationId: rows.single['installation_id'] as String,
    );
  }

  Future<void> saveReflection(
    DatabaseExecutor db,
    PrivateReflection reflection,
  ) async {
    reflection.validate();
    await db.insert(
      'private_reflections',
      SqliteReflectionMapper.toRow(reflection),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveProgress(
    DatabaseExecutor db,
    ProgressProjection projection,
  ) async {
    await db.insert('projection_checkpoints', {
      'projection_name': progressProjection,
      'snapshot_json': jsonEncode(
        SqliteProjectionMapper.progressToJson(projection),
      ),
      'last_applied_installation_id': null,
      'last_applied_sequence': null,
      'updated_at': projection.updatedAt.toUtc().toIso8601String(),
      'schema_version': 2,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> saveMomentum(DatabaseExecutor db, MomentumState state) async {
    await db.insert('projection_checkpoints', {
      'projection_name': momentumProjection,
      'snapshot_json': jsonEncode(SqliteProjectionMapper.momentumToJson(state)),
      'last_applied_installation_id': null,
      'last_applied_sequence': null,
      'updated_at': clock().toUtc().toIso8601String(),
      'schema_version': 1,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> appendEvents(
    DatabaseExecutor db,
    List<EventDraftV2> drafts,
  ) async {
    final localIdentity = await identity(db);
    final sequenceKey = 'client_sequence:${localIdentity.installationId}';
    final sequenceRows = await db.query(
      'app_metadata',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [sequenceKey],
      limit: 1,
    );
    var sequence = sequenceRows.isEmpty
        ? 0
        : int.parse(sequenceRows.single['value'] as String);
    final eventRows = await db.query(
      'event_log_v2',
      columns: ['client_sequence'],
      where: 'installation_id = ?',
      whereArgs: [localIdentity.installationId],
      orderBy: 'client_sequence DESC',
      limit: 1,
    );
    if (eventRows.isNotEmpty) {
      final highestStoredSequence = (eventRows.single['client_sequence'] as num)
          .toInt();
      if (highestStoredSequence > sequence) sequence = highestStoredSequence;
    }
    for (final draft in drafts) {
      sequence += 1;
      final envelope = EventEnvelopeV2(
        eventId: draft.eventId,
        eventType: draft.eventType,
        localUserId: localIdentity.localUserId,
        remoteUserId: localIdentity.remoteUserId,
        installationId: localIdentity.installationId,
        clientSequence: sequence,
        occurredAtUtc: draft.occurredAtUtc.toUtc(),
        timezoneId: draft.timezoneId,
        timezoneOffsetMinutes: draft.timezoneOffsetMinutes,
        assignmentId: draft.assignmentId,
        attemptId: draft.attemptId,
        contentId: draft.contentId,
        contentRevision: draft.contentRevision,
        payload: draft.payload,
      );
      await db.insert('event_log_v2', envelope.toDatabaseMap());
    }
    await db.insert('app_metadata', {
      'key': sequenceKey,
      'value': sequence.toString(),
      'updated_at': clock().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
