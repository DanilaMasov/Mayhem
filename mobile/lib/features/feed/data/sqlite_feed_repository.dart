import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../core/sync/event_envelope_v2.dart';
import '../../../infrastructure/sqlite/sqlite_vnext_context.dart';
import '../../../infrastructure/sqlite/sqlite_vnext_mappers.dart';
import '../domain/feed_models.dart';
import '../domain/feed_repository.dart';
import '../domain/local_feed_interaction_repository.dart';

class SqliteFeedRepository
    implements FeedRepository, LocalFeedInteractionRepository {
  const SqliteFeedRepository(this.context);

  final SqliteVNextContext context;

  @override
  Future<void> saveBatch(FeedBatch batch, List<FeedAssignment> assignments) {
    if (assignments.any((assignment) => assignment.batchId != batch.batchId)) {
      throw const FormatException('Feed assignment belongs to another batch');
    }
    return context.database.transaction((db) async {
      await db.insert(
        'feed_batches',
        SqliteFeedMapper.batchToRow(batch),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      for (final assignment in assignments) {
        await db.insert(
          'feed_assignments',
          SqliteFeedMapper.assignmentToRow(assignment),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
  }

  @override
  Future<FeedBatch?> latestUsableBatch(
    DateTime atUtc, {
    bool preferRemote = false,
  }) {
    final time = atUtc.toUtc().toIso8601String();
    return context.database.read((db) async {
      final rows = await db.query(
        'feed_batches',
        where: 'expires_at IS NULL OR expires_at > ?',
        whereArgs: [time],
        orderBy: preferRemote
            ? "CASE WHEN source = 'remote' THEN 0 ELSE 1 END, created_at DESC"
            : 'created_at DESC',
        limit: 1,
      );
      return rows.isEmpty ? null : SqliteFeedMapper.batchFromRow(rows.single);
    });
  }

  @override
  Future<List<FeedAssignment>> assignmentsFor(String batchId) {
    return context.database.read((db) async {
      final batchRows = await db.query(
        'feed_batches',
        where: 'batch_id = ?',
        whereArgs: [batchId],
        limit: 1,
      );
      if (batchRows.isEmpty) return const [];
      final identity = await context.identity(db);
      final batch = SqliteFeedMapper.batchFromRow(batchRows.single);
      final rows = await db.query(
        'feed_assignments',
        where: 'batch_id = ?',
        whereArgs: [batchId],
        orderBy: 'position ASC',
      );
      return rows
          .map(
            (row) => SqliteFeedMapper.assignmentFromRow(
              row,
              localUserId: identity.localUserId,
              batch: batch,
            ),
          )
          .toList(growable: false);
    });
  }

  @override
  Future<bool> wasSkipped(String assignmentId) {
    return context.database.read((db) async {
      final rows = await db.query(
        'feed_assignments',
        columns: ['skipped_at'],
        where: 'assignment_id = ?',
        whereArgs: [assignmentId],
        limit: 1,
      );
      return rows.isNotEmpty && rows.single['skipped_at'] != null;
    });
  }

  @override
  Future<void> markImpressed(String assignmentId, DateTime impressedAtUtc) =>
      _markOnce(assignmentId, 'impressed_at', impressedAtUtc);

  @override
  Future<void> markOpened(String assignmentId, DateTime openedAtUtc) =>
      _markOnce(assignmentId, 'opened_at', openedAtUtc);

  @override
  Future<void> markSkipped(
    String assignmentId,
    DateTime skippedAtUtc, {
    FeedSkipReason? reason,
  }) {
    return context.database.transaction((db) async {
      final rows = await db.query(
        'feed_assignments',
        columns: ['metadata_json', 'skipped_at'],
        where: 'assignment_id = ?',
        whereArgs: [assignmentId],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw StateError('Unknown feed assignment: $assignmentId');
      }
      if (rows.single['skipped_at'] != null) return;
      final metadata = _metadata(rows.single['metadata_json'] as String);
      if (reason != null) _setSkipReason(metadata, reason);
      await db.update(
        'feed_assignments',
        {
          'skipped_at': skippedAtUtc.toUtc().toIso8601String(),
          'metadata_json': jsonEncode(metadata),
        },
        where: 'assignment_id = ? AND skipped_at IS NULL',
        whereArgs: [assignmentId],
      );
    });
  }

  @override
  Future<bool> commitImpression({
    required String assignmentId,
    required DateTime impressedAtUtc,
    required EventDraftV2 event,
  }) => _commitInteraction(
    assignmentId: assignmentId,
    column: 'impressed_at',
    atUtc: impressedAtUtc,
    event: event,
    expectedType: CanonicalEventTypeV2.feedItemImpressed,
  );

  @override
  Future<bool> commitOpened({
    required String assignmentId,
    required DateTime openedAtUtc,
    required EventDraftV2 event,
  }) => _commitInteraction(
    assignmentId: assignmentId,
    column: 'opened_at',
    atUtc: openedAtUtc,
    event: event,
    expectedType: CanonicalEventTypeV2.feedItemOpened,
  );

  @override
  Future<bool> commitSkipped({
    required String assignmentId,
    required DateTime skippedAtUtc,
    required FeedSkipReason reason,
    required EventDraftV2 event,
  }) => _commitInteraction(
    assignmentId: assignmentId,
    column: 'skipped_at',
    atUtc: skippedAtUtc,
    event: event,
    expectedType: CanonicalEventTypeV2.feedItemSkipped,
    skipReason: reason,
  );

  @override
  Future<bool> commitScenarioChoice({
    required String assignmentId,
    required int choiceIndex,
    required DateTime answeredAtUtc,
    required EventDraftV2 event,
  }) {
    if (choiceIndex < 0) {
      throw ArgumentError.value(choiceIndex, 'choiceIndex');
    }
    if (event.eventType != CanonicalEventTypeV2.feedItemSaved ||
        event.assignmentId != assignmentId ||
        event.payload['kind'] != 'scenarioPollResponse' ||
        event.payload['choiceIndex'] != choiceIndex) {
      throw const FormatException('Scenario response event does not match');
    }
    return context.database.transaction((db) async {
      final rows = await db.query(
        'feed_assignments',
        columns: ['content_id', 'content_revision', 'metadata_json'],
        where: 'assignment_id = ?',
        whereArgs: [assignmentId],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw StateError('Unknown feed assignment: $assignmentId');
      }
      final row = rows.single;
      if (event.contentId != row['content_id'] ||
          event.contentRevision != row['content_revision']) {
        throw const FormatException('Scenario response content does not match');
      }
      final metadata = _metadata(row['metadata_json'] as String);
      if (metadata.containsKey('_scenarioChoiceIndex')) return false;
      if (metadata.length > 22) {
        throw const FormatException('Feed assignment metadata is full');
      }
      metadata['_scenarioChoiceIndex'] = choiceIndex;
      metadata['_scenarioAnsweredAt'] = answeredAtUtc.toUtc().toIso8601String();
      final changed = await db.update(
        'feed_assignments',
        {'metadata_json': jsonEncode(metadata)},
        where: 'assignment_id = ?',
        whereArgs: [assignmentId],
      );
      if (changed != 1) return false;
      await context.appendEvents(db, [event]);
      return true;
    });
  }

  Future<void> _markOnce(String assignmentId, String column, DateTime atUtc) {
    if (column != 'impressed_at' && column != 'opened_at') {
      throw ArgumentError.value(column, 'column');
    }
    return context.database.transaction((db) async {
      final rows = await db.query(
        'feed_assignments',
        columns: [column],
        where: 'assignment_id = ?',
        whereArgs: [assignmentId],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw StateError('Unknown feed assignment: $assignmentId');
      }
      if (rows.single[column] != null) return;
      await db.update(
        'feed_assignments',
        {column: atUtc.toUtc().toIso8601String()},
        where: 'assignment_id = ? AND $column IS NULL',
        whereArgs: [assignmentId],
      );
    });
  }

  Future<bool> _commitInteraction({
    required String assignmentId,
    required String column,
    required DateTime atUtc,
    required EventDraftV2 event,
    required CanonicalEventTypeV2 expectedType,
    FeedSkipReason? skipReason,
  }) {
    if (!const {'impressed_at', 'opened_at', 'skipped_at'}.contains(column)) {
      throw ArgumentError.value(column, 'column');
    }
    if (event.eventType != expectedType || event.assignmentId != assignmentId) {
      throw const FormatException('Feed interaction event does not match');
    }
    return context.database.transaction((db) async {
      final rows = await db.query(
        'feed_assignments',
        columns: [column, 'content_id', 'content_revision', 'metadata_json'],
        where: 'assignment_id = ?',
        whereArgs: [assignmentId],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw StateError('Unknown feed assignment: $assignmentId');
      }
      final row = rows.single;
      if (row[column] != null) return false;
      if (event.contentId != row['content_id'] ||
          event.contentRevision != row['content_revision']) {
        throw const FormatException('Feed interaction content does not match');
      }
      final values = <String, Object?>{column: atUtc.toUtc().toIso8601String()};
      if (skipReason != null) {
        final metadata = _metadata(row['metadata_json'] as String);
        _setSkipReason(metadata, skipReason);
        values['metadata_json'] = jsonEncode(metadata);
      }
      final changed = await db.update(
        'feed_assignments',
        values,
        where: 'assignment_id = ? AND $column IS NULL',
        whereArgs: [assignmentId],
      );
      if (changed != 1) return false;
      await context.appendEvents(db, [event]);
      return true;
    });
  }

  Map<String, Object?> _metadata(String source) =>
      Map<String, Object?>.from(jsonDecode(source) as Map);

  void _setSkipReason(Map<String, Object?> metadata, FeedSkipReason reason) {
    if (metadata.length >= 24 && !metadata.containsKey('_skipReason')) {
      throw const FormatException('Feed assignment metadata is full');
    }
    metadata['_skipReason'] = reason.name;
  }
}
