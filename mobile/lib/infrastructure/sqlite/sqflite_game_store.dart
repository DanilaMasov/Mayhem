import 'dart:convert';
import 'dart:developer' as developer;

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/migrations/v5_feed_vnext_migration.dart';
import '../../core/database/migrations/v6_feed_vertical_slice_migration.dart';
import '../../core/feature_flags/feature_flags.dart';
import '../../core/identity/local_identity_reset.dart';
import '../../domain/models/game_event.dart';
import '../../domain/models/event_sync.dart';
import '../../domain/models/game_state.dart';
import '../../domain/models/quest_reflection.dart';
import '../../domain/ports/game_store.dart';
import '../../domain/ports/event_sync_store.dart';
import '../../domain/ports/installation_identity_store.dart';
import 'sqlite_vnext_store.dart';
import 'vnext_database.dart';

class SqfliteGameStore
    implements GameStore, EventSyncStore, InstallationIdentityStore {
  SqfliteGameStore._(this._database, this._clock, this._idGenerator);

  static const databaseVersion = 6;
  static const databaseName = 'mayhem.db';
  static const snapshotId = 'current';

  final Database _database;
  final DateTime Function() _clock;
  final String Function() _idGenerator;

  SqliteVNextStore createVNextStore() =>
      SqliteVNextStore(SqfliteVNextDatabase(_database), clock: _clock);

  static Future<SqfliteGameStore> open({
    String Function()? idGenerator,
    DateTime Function()? clock,
  }) async {
    final generateId = idGenerator ?? () => const Uuid().v4();
    final currentTime = clock ?? DateTime.now;
    final root = await getDatabasesPath();
    final database = await openDatabase(
      p.join(root, databaseName),
      version: databaseVersion,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE state_snapshots (
            id TEXT PRIMARY KEY,
            schema_version INTEGER NOT NULL,
            payload_json TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE quest_events (
            id TEXT PRIMARY KEY,
            event_type TEXT NOT NULL,
            quest_id TEXT NOT NULL,
            payload_json TEXT NOT NULL,
            created_at TEXT NOT NULL,
            synced INTEGER NOT NULL DEFAULT 0,
            sync_status TEXT NOT NULL DEFAULT 'pending' CHECK (sync_status IN ('pending', 'synced', 'rejected')),
            sync_attempts INTEGER NOT NULL DEFAULT 0,
            last_sync_error TEXT NOT NULL DEFAULT '',
            next_retry_at TEXT
          )
        ''');
        await db.execute(
          'CREATE INDEX quest_events_sync_idx ON quest_events (synced, created_at)',
        );
        await _createReflectionsTable(db);
        await _createPendingEventsIndex(db);
        await _createAppMetadataTable(db);
        await V5FeedVNextMigration.apply(
          db,
          idGenerator: generateId,
          now: currentTime(),
        );
        await V6FeedVerticalSliceMigration.apply(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createReflectionsTable(db);
        }
        if (oldVersion < 3) {
          await db.execute(
            "ALTER TABLE quest_events ADD COLUMN sync_status TEXT NOT NULL DEFAULT 'pending'",
          );
          await db.execute(
            'ALTER TABLE quest_events ADD COLUMN sync_attempts INTEGER NOT NULL DEFAULT 0',
          );
          await db.execute(
            "ALTER TABLE quest_events ADD COLUMN last_sync_error TEXT NOT NULL DEFAULT ''",
          );
          await db.execute(
            'ALTER TABLE quest_events ADD COLUMN next_retry_at TEXT',
          );
          await db.execute(
            "UPDATE quest_events SET sync_status = 'synced' WHERE synced = 1",
          );
          await _createPendingEventsIndex(db);
        }
        if (oldVersion < 4) {
          await _createAppMetadataTable(db);
        }
        if (oldVersion < 5) {
          await V5FeedVNextMigration.apply(
            db,
            idGenerator: generateId,
            now: currentTime(),
          );
        }
        if (oldVersion < 6) {
          await V6FeedVerticalSliceMigration.apply(db);
        }
      },
    );
    return SqfliteGameStore._(database, currentTime, generateId);
  }

  @override
  Future<GameState?> load() async {
    final rows = await _database.query(
      'state_snapshots',
      where: 'id = ?',
      whereArgs: [snapshotId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final decoded = jsonDecode(rows.single['payload_json'] as String);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Stored state snapshot is invalid');
    }
    return GameState.fromJson(decoded);
  }

  @override
  Future<List<GameEvent>> loadEvents() async {
    return _database.transaction((transaction) async {
      final rows = await transaction.query(
        'quest_events',
        orderBy: 'created_at ASC, id ASC',
      );
      final events = <GameEvent>[];
      var quarantinedCount = 0;
      for (final row in rows) {
        try {
          events.add(GameEvent.fromDatabaseMap(row));
        } catch (error) {
          final rawRow = jsonEncode(row);
          final reason = 'legacy_event_parse_failed:${error.runtimeType}';
          final existing = await transaction.query(
            'event_quarantine',
            columns: ['id'],
            where: 'raw_row_json = ? AND reason = ?',
            whereArgs: [rawRow, reason],
            limit: 1,
          );
          if (existing.isEmpty) {
            await transaction.insert('event_quarantine', {
              'raw_row_json': rawRow,
              'reason': reason,
              'quarantined_at': _clock().toUtc().toIso8601String(),
            });
            quarantinedCount += 1;
          }
        }
      }
      if (quarantinedCount > 0) {
        developer.log(
          'Quarantined $quarantinedCount invalid legacy event rows',
          name: 'mayhem.database',
        );
      }
      return events;
    });
  }

  @override
  Future<String> getOrCreateInstallationId(String Function() generator) async {
    return _database.transaction((transaction) async {
      final existing = await transaction.query(
        'app_metadata',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: ['installation_id'],
        limit: 1,
      );
      final installationId = existing.isNotEmpty
          ? existing.single['value'] as String
          : generator();
      if (installationId.trim().isEmpty) {
        throw const FormatException('Installation ID must not be empty');
      }
      final updatedAt = _clock().toUtc().toIso8601String();
      if (existing.isEmpty) {
        await transaction.insert('app_metadata', {
          'key': 'installation_id',
          'value': installationId,
          'updated_at': updatedAt,
        });
      }
      final localUserRows = await transaction.query(
        'app_metadata',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: ['local_user_id'],
        limit: 1,
      );
      final localUserId = localUserRows.isEmpty
          ? generator()
          : localUserRows.single['value'] as String;
      if (localUserId.trim().isEmpty) {
        throw const FormatException('Local user ID must not be empty');
      }
      if (localUserRows.isEmpty) {
        await transaction.insert('app_metadata', {
          'key': 'local_user_id',
          'value': localUserId,
          'updated_at': updatedAt,
        });
      }
      await transaction.insert('user_identity', {
        'local_user_id': localUserId,
        'installation_id': installationId,
        'remote_user_id': null,
        'created_at': updatedAt,
        'linked_at': null,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      return installationId;
    });
  }

  @override
  Future<List<PendingGameEvent>> loadPendingEvents({
    required DateTime now,
    required int limit,
  }) async {
    final rows = await _database.query(
      'quest_events',
      where:
          "sync_status = 'pending' AND (next_retry_at IS NULL OR next_retry_at <= ?)",
      whereArgs: [now.toUtc().toIso8601String()],
      orderBy: 'created_at ASC, id ASC',
      limit: limit,
    );
    return rows
        .map(
          (row) => PendingGameEvent(
            event: GameEvent.fromDatabaseMap(row),
            attempts: (row['sync_attempts'] as num?)?.toInt() ?? 0,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> applyEventSyncResult({
    required Set<String> acceptedIds,
    required Map<String, String> rejectedById,
    required List<EventRetryUpdate> retries,
  }) async {
    await _database.transaction((transaction) async {
      for (final eventId in acceptedIds) {
        await transaction.update(
          'quest_events',
          {
            'synced': 1,
            'sync_status': 'synced',
            'last_sync_error': '',
            'next_retry_at': null,
          },
          where: 'id = ?',
          whereArgs: [eventId],
        );
      }
      for (final entry in rejectedById.entries) {
        await transaction.update(
          'quest_events',
          {
            'sync_status': 'rejected',
            'last_sync_error': entry.value,
            'next_retry_at': null,
          },
          where: 'id = ?',
          whereArgs: [entry.key],
        );
      }
      await _writeRetryUpdates(transaction, retries);
    });
  }

  @override
  Future<void> scheduleEventRetries(List<EventRetryUpdate> updates) async {
    await _database.transaction(
      (transaction) => _writeRetryUpdates(transaction, updates),
    );
  }

  @override
  Future<void> commit(
    GameState state,
    List<GameEvent> events, {
    List<QuestReflection> reflections = const [],
  }) async {
    await _database.transaction((transaction) async {
      await transaction.insert('state_snapshots', {
        'id': snapshotId,
        'schema_version': state.schemaVersion,
        'payload_json': jsonEncode(state.toJson()),
        'updated_at': _clock().toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      for (final event in events) {
        await transaction.insert(
          'quest_events',
          event.toDatabaseMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      for (final reflection in reflections) {
        await transaction.insert(
          'quest_reflections',
          reflection.toDatabaseMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
  }

  @override
  Future<void> clear() async {
    await _database.transaction((transaction) async {
      await transaction.delete('private_reflections');
      await transaction.delete('challenge_attempts');
      await transaction.delete('feed_assignments');
      await transaction.delete('feed_batches');
      await transaction.delete('content_item_revisions');
      await transaction.delete('event_log_v2');
      await transaction.delete('projection_checkpoints');
      await transaction.delete('event_quarantine');
      await transaction.delete('feature_flags_cache');
      await transaction.delete('media_cache_index');
      await transaction.delete('user_identity');
      await transaction.delete('quest_reflections');
      await transaction.delete('quest_events');
      await transaction.delete('state_snapshots');
      await transaction.delete('app_metadata');
      final now = _clock();
      await LocalIdentityReset.replace(
        transaction,
        idGenerator: _idGenerator,
        now: now,
      );
      for (final flag in MayhemFeatureFlag.values) {
        await transaction.insert('feature_flags_cache', {
          'flag_key': flag.wireName,
          'value_json': 'false',
          'fetched_at': now.toUtc().toIso8601String(),
          'expires_at': null,
        });
      }
    });
  }

  @override
  Future<void> close() => _database.close();

  static Future<void> _createReflectionsTable(DatabaseExecutor db) {
    return db.execute('''
      CREATE TABLE quest_reflections (
        id TEXT PRIMARY KEY,
        quest_id TEXT NOT NULL,
        fear_score INTEGER NOT NULL CHECK (fear_score BETWEEN 1 AND 10),
        feel_after_score INTEGER NOT NULL CHECK (feel_after_score BETWEEN 1 AND 10),
        want_repeat INTEGER NOT NULL CHECK (want_repeat IN (0, 1)),
        note TEXT NOT NULL DEFAULT '',
        metadata_json TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
  }

  static Future<void> _createPendingEventsIndex(DatabaseExecutor db) {
    return db.execute(
      'CREATE INDEX quest_events_pending_idx ON quest_events (sync_status, next_retry_at, created_at)',
    );
  }

  static Future<void> _createAppMetadataTable(DatabaseExecutor db) {
    return db.execute('''
      CREATE TABLE app_metadata (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  static Future<void> _writeRetryUpdates(
    DatabaseExecutor db,
    List<EventRetryUpdate> updates,
  ) async {
    for (final update in updates) {
      await db.update(
        'quest_events',
        {
          'synced': 0,
          'sync_status': 'pending',
          'sync_attempts': update.attempts,
          'last_sync_error': update.error,
          'next_retry_at': update.nextRetryAt.toUtc().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [update.eventId],
      );
    }
  }
}
