import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../domain/models/quest.dart';
import '../../../features/progress/domain/legacy_progress_mapper.dart';
import 'v5_feed_vnext_sql.g.dart';

class V5FeedVNextMigration {
  const V5FeedVNextMigration._();

  static const migrationMarker = 'migration_v5_feed_vnext_complete';

  static Future<void> apply(
    DatabaseExecutor db, {
    required String Function() idGenerator,
    required DateTime now,
  }) async {
    for (final statement in v5FeedVNextStatements) {
      await db.execute(statement);
    }

    await _ensureIdentity(db, idGenerator, now);
    final alreadyMigrated = await _metadata(db, migrationMarker) == 'true';
    if (!alreadyMigrated) {
      await _importLegacyProgress(db, now);
      await _importLegacyAttempts(db, now);
      await _importLegacyReflections(db, now);
      await _putMetadata(db, migrationMarker, 'true', now);
    }
    await db.insert('feature_flags_cache', {
      'flag_key': 'new_feed_enabled',
      'value_json': 'false',
      'fetched_at': now.toUtc().toIso8601String(),
      'expires_at': null,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  static Future<void> _ensureIdentity(
    DatabaseExecutor db,
    String Function() idGenerator,
    DateTime now,
  ) async {
    final installationId =
        await _metadata(db, 'installation_id') ?? _validId(idGenerator());
    final localUserId =
        await _metadata(db, 'local_user_id') ?? _validId(idGenerator());
    await _putMetadata(db, 'installation_id', installationId, now);
    await _putMetadata(db, 'local_user_id', localUserId, now);
    final sequenceKey = 'client_sequence:$installationId';
    if (await _metadata(db, sequenceKey) == null) {
      await _putMetadata(db, sequenceKey, '0', now);
    }
    await db.insert('user_identity', {
      'local_user_id': localUserId,
      'installation_id': installationId,
      'remote_user_id': null,
      'created_at': now.toUtc().toIso8601String(),
      'linked_at': null,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  static Future<void> _importLegacyProgress(
    DatabaseExecutor db,
    DateTime now,
  ) async {
    final rows = await db.query(
      'state_snapshots',
      columns: ['schema_version', 'payload_json'],
      where: 'id = ?',
      whereArgs: ['current'],
      limit: 1,
    );
    Map<String, dynamic> snapshot = const {};
    var legacySchemaVersion = 0;
    if (rows.isNotEmpty) {
      final decoded = jsonDecode(rows.single['payload_json'] as String);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Legacy snapshot is not an object');
      }
      snapshot = decoded;
      legacySchemaVersion = (rows.single['schema_version'] as num).toInt();
    }
    final xpJson = snapshot['xp'] as Map<String, dynamic>? ?? const {};
    final legacyXp = <StatType, int>{
      for (final type in StatType.values)
        type: (xpJson[type.name] as num?)?.toInt() ?? 0,
    };
    final profile = const LegacyProgressMapper().map(legacyXp);
    final completedCount = (snapshot['completedCount'] as num?)?.toInt() ?? 0;
    final projection = {
      'totalXp': profile.totalXp,
      'traitXp': {
        for (final entry in profile.traitXp.entries)
          entry.key.name: entry.value,
      },
      'completedCount': completedCount,
      'attemptedCount': 0,
      'legacyImported': rows.isNotEmpty,
      'legacySchemaVersion': legacySchemaVersion,
    };
    await db.insert('projection_checkpoints', {
      'projection_name': 'progress',
      'snapshot_json': jsonEncode(projection),
      'last_applied_installation_id': null,
      'last_applied_sequence': null,
      'updated_at': now.toUtc().toIso8601String(),
      'schema_version': 1,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    if (snapshot['activeQuest'] case final Map<String, dynamic> active) {
      final questId = active['questId'] as String?;
      final startedAt = active['startedAt'] as String?;
      if (questId != null && questId.isNotEmpty && startedAt != null) {
        final route = active['variant'] == 'low_pressure'
            ? 'low_pressure'
            : 'normal';
        await _insertLegacyAttempt(
          db,
          attemptId: 'legacy-active:$questId',
          questId: questId,
          status: 'active',
          route: route,
          acceptedAt: startedAt,
          resolvedAt: null,
          result: const {'source': 'legacy_active_import'},
          now: now,
        );
      }
    }
  }

  static Future<void> _importLegacyAttempts(
    DatabaseExecutor db,
    DateTime now,
  ) async {
    final completionRows = await db.query(
      'quest_events',
      columns: ['id', 'quest_id', 'payload_json', 'created_at'],
      where: 'event_type = ?',
      whereArgs: ['quest_completed'],
      orderBy: 'created_at ASC, id ASC',
    );
    for (final row in completionRows) {
      final eventId = row['id'] as String;
      final questId = row['quest_id'] as String;
      final createdAt = row['created_at'] as String;
      final payload = _jsonObject(row['payload_json'] as String);
      final route = payload['variant'] == 'low_pressure'
          ? 'low_pressure'
          : 'normal';
      await _insertLegacyAttempt(
        db,
        attemptId: 'legacy-event:$eventId',
        questId: questId,
        status: 'completed',
        route: route,
        acceptedAt: createdAt,
        resolvedAt: createdAt,
        result: {'source': 'legacy_event_import', 'legacyEventId': eventId},
        now: now,
      );
    }

    final snapshots = await db.query(
      'state_snapshots',
      columns: ['payload_json'],
      where: 'id = ?',
      whereArgs: ['current'],
      limit: 1,
    );
    if (snapshots.isEmpty) return;
    final snapshot = _jsonObject(snapshots.single['payload_json'] as String);
    final completedByDate =
        snapshot['completedByDate'] as Map<String, dynamic>? ?? const {};
    for (final entry in completedByDate.entries) {
      final questIds = entry.value as List<dynamic>? ?? const [];
      for (final value in questIds) {
        if (value is! String || value.isEmpty) continue;
        final existing = await db.query(
          'challenge_attempts',
          columns: ['attempt_id'],
          where:
              "content_id = ? AND status = 'completed' AND substr(resolved_at, 1, 10) = ?",
          whereArgs: [value, entry.key],
          limit: 1,
        );
        if (existing.isNotEmpty) continue;
        final resolvedAt = '${entry.key}T12:00:00.000Z';
        await _insertLegacyAttempt(
          db,
          attemptId: 'legacy-completed:${entry.key}:$value',
          questId: value,
          status: 'completed',
          route: 'normal',
          acceptedAt: resolvedAt,
          resolvedAt: resolvedAt,
          result: {
            'source': 'legacy_snapshot_import',
            'completionDate': entry.key,
          },
          now: now,
        );
      }
    }
  }

  static Future<void> _importLegacyReflections(
    DatabaseExecutor db,
    DateTime now,
  ) async {
    final rows = await db.query('quest_reflections', orderBy: 'created_at ASC');
    for (final row in rows) {
      final reflectionId = row['id'] as String;
      final questId = row['quest_id'] as String;
      final createdAt = row['created_at'] as String;
      final matches = await db.query(
        'challenge_attempts',
        columns: ['attempt_id'],
        where: "content_id = ? AND status = 'completed' AND resolved_at <= ?",
        whereArgs: [questId, createdAt],
        orderBy: 'resolved_at DESC',
        limit: 1,
      );
      final attemptId = matches.isNotEmpty
          ? matches.single['attempt_id'] as String
          : 'legacy-reflection:$reflectionId';
      if (matches.isEmpty) {
        await _insertLegacyAttempt(
          db,
          attemptId: attemptId,
          questId: questId,
          status: 'completed',
          route: 'normal',
          acceptedAt: createdAt,
          resolvedAt: createdAt,
          result: const {'source': 'legacy_reflection_import'},
          now: now,
        );
      }
      await db.insert('private_reflections', {
        'reflection_id': reflectionId,
        'attempt_id': attemptId,
        'fear_before': row['fear_score'],
        'feel_after': row['feel_after_score'],
        'want_repeat': row['want_repeat'],
        'private_note': row['note'],
        'created_at': createdAt,
        'updated_at': createdAt,
        'sync_preference': 'local_only',
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  static Future<void> _insertLegacyAttempt(
    DatabaseExecutor db, {
    required String attemptId,
    required String questId,
    required String status,
    required String route,
    required String acceptedAt,
    required String? resolvedAt,
    required Map<String, Object?> result,
    required DateTime now,
  }) {
    return db.insert('challenge_attempts', {
      'attempt_id': attemptId,
      'assignment_id': 'legacy:$attemptId',
      'content_id': questId,
      'content_revision': 1,
      'status': status,
      'selected_route': route,
      'accepted_at': acceptedAt,
      'resolved_at': resolvedAt,
      'timezone_id': 'legacy/local',
      'result_json': jsonEncode(result),
      'reward_applied_local': status == 'completed' ? 1 : 0,
      'sync_state': 'synced',
      'updated_at': now.toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  static Future<String?> _metadata(DatabaseExecutor db, String key) async {
    final rows = await db.query(
      'app_metadata',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single['value'] as String;
  }

  static Future<void> _putMetadata(
    DatabaseExecutor db,
    String key,
    String value,
    DateTime now,
  ) {
    return db.insert('app_metadata', {
      'key': key,
      'value': value,
      'updated_at': now.toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Map<String, dynamic> _jsonObject(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Legacy JSON must be an object');
    }
    return decoded;
  }

  static String _validId(String value) {
    if (value.trim().isEmpty) {
      throw const FormatException('Generated identity must not be empty');
    }
    return value;
  }
}
