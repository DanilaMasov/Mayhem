import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mayhem_mobile/core/database/migrations/v5_feed_vnext_migration.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  test(
    'v5 migrator preserves progress, history, reflection and identity',
    () async {
      final database = _MemoryDatabaseExecutor({
        'app_metadata': [
          {
            'key': 'installation_id',
            'value': 'install-1',
            'updated_at': '2026-07-12T00:00:00Z',
          },
        ],
        'state_snapshots': [
          {
            'id': 'current',
            'schema_version': 4,
            'payload_json': jsonEncode({
              'xp': {'charisma': 10, 'boldness': 20, 'networking': 30},
              'completedCount': 1,
              'completedByDate': {
                '2026-07-12': ['q_c_001'],
              },
            }),
            'updated_at': '2026-07-12T12:00:00Z',
          },
        ],
        'quest_events': [
          {
            'id': 'legacy-event-1',
            'event_type': 'quest_completed',
            'quest_id': 'q_c_001',
            'payload_json': jsonEncode({'variant': 'normal'}),
            'created_at': '2026-07-12T12:00:00Z',
          },
        ],
        'quest_reflections': [
          {
            'id': 'reflection-1',
            'quest_id': 'q_c_001',
            'fear_score': 7,
            'feel_after_score': 4,
            'want_repeat': 1,
            'note': 'local private text',
            'metadata_json': '{}',
            'created_at': '2026-07-12T12:01:00Z',
          },
        ],
      });
      var generatedIds = 0;

      await V5FeedVNextMigration.apply(
        database,
        idGenerator: () => 'generated-${++generatedIds}',
        now: DateTime.parse('2026-07-13T00:00:00Z'),
      );
      await V5FeedVNextMigration.apply(
        database,
        idGenerator: () => 'unexpected-${++generatedIds}',
        now: DateTime.parse('2026-07-13T00:00:01Z'),
      );

      expect(database.executedStatements, hasLength(34));
      expect(generatedIds, 1);
      expect(
        database.rows('user_identity').single,
        containsPair('installation_id', 'install-1'),
      );
      expect(database.rows('challenge_attempts'), hasLength(1));
      expect(database.rows('private_reflections'), hasLength(1));
      expect(
        database.rows('private_reflections').single,
        allOf(
          containsPair('attempt_id', 'legacy-event:legacy-event-1'),
          containsPair('private_note', 'local private text'),
          containsPair('sync_preference', 'local_only'),
        ),
      );
      final projection =
          jsonDecode(
                database.rows('projection_checkpoints').single['snapshot_json']
                    as String,
              )
              as Map<String, dynamic>;
      expect(projection['totalXp'], 60);
      expect(
        (projection['traitXp'] as Map<String, dynamic>).values.fold<int>(
          0,
          (sum, value) => sum + (value as num).toInt(),
        ),
        60,
      );
      expect(database.metadata(V5FeedVNextMigration.migrationMarker), 'true');
      expect(database.rows('feature_flags_cache'), hasLength(1));
    },
  );
}

class _MemoryDatabaseExecutor implements DatabaseExecutor {
  _MemoryDatabaseExecutor(Map<String, List<Map<String, Object?>>> seed)
    : _tables = {
        for (final entry in seed.entries)
          entry.key: entry.value.map(Map<String, Object?>.from).toList(),
      };

  final Map<String, List<Map<String, Object?>>> _tables;
  final List<String> executedStatements = [];

  List<Map<String, Object?>> rows(String table) =>
      List.unmodifiable(_tables[table] ?? const []);

  String? metadata(String key) {
    for (final row in rows('app_metadata')) {
      if (row['key'] == key) return row['value'] as String;
    }
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #execute) {
      executedStatements.add(invocation.positionalArguments.first as String);
      return Future<void>.value();
    }
    if (invocation.memberName == #query) {
      return _query(invocation);
    }
    if (invocation.memberName == #insert) {
      return _insert(invocation);
    }
    return super.noSuchMethod(invocation);
  }

  Future<List<Map<String, Object?>>> _query(Invocation invocation) async {
    final table = invocation.positionalArguments.first as String;
    var result = rows(table).map(Map<String, Object?>.from).toList();
    final where = invocation.namedArguments[#where] as String?;
    final whereArgs =
        invocation.namedArguments[#whereArgs] as List<Object?>? ?? const [];
    if (table == 'app_metadata' && whereArgs.isNotEmpty) {
      result = result.where((row) => row['key'] == whereArgs.first).toList();
    } else if (table == 'state_snapshots' && whereArgs.isNotEmpty) {
      result = result.where((row) => row['id'] == whereArgs.first).toList();
    } else if (table == 'quest_events' && whereArgs.isNotEmpty) {
      result = result
          .where((row) => row['event_type'] == whereArgs.first)
          .toList();
    } else if (table == 'challenge_attempts' && where != null) {
      final questId = whereArgs.firstOrNull;
      result = result.where((row) {
        if (row['content_id'] != questId || row['status'] != 'completed') {
          return false;
        }
        if (where.contains('substr')) {
          return (row['resolved_at'] as String?)?.startsWith(
                whereArgs[1] as String,
              ) ==
              true;
        }
        return (row['resolved_at'] as String).compareTo(
              whereArgs[1] as String,
            ) <=
            0;
      }).toList();
    }
    final columns = invocation.namedArguments[#columns] as List<String>?;
    if (columns != null) {
      result = [
        for (final row in result)
          {for (final column in columns) column: row[column]},
      ];
    }
    final limit = invocation.namedArguments[#limit] as int?;
    return limit == null ? result : result.take(limit).toList();
  }

  Future<int> _insert(Invocation invocation) async {
    final table = invocation.positionalArguments[0] as String;
    final values = Map<String, Object?>.from(
      invocation.positionalArguments[1] as Map,
    );
    final rows = _tables.putIfAbsent(table, () => []);
    final key = _primaryKeyByTable[table];
    final existingIndex = key == null
        ? -1
        : rows.indexWhere((row) => row[key] == values[key]);
    final conflict =
        invocation.namedArguments[#conflictAlgorithm] as ConflictAlgorithm?;
    if (existingIndex >= 0) {
      if (conflict == ConflictAlgorithm.replace) {
        rows[existingIndex] = values;
      }
      return existingIndex + 1;
    }
    rows.add(values);
    return rows.length;
  }

  static const _primaryKeyByTable = <String, String>{
    'app_metadata': 'key',
    'user_identity': 'local_user_id',
    'projection_checkpoints': 'projection_name',
    'challenge_attempts': 'attempt_id',
    'private_reflections': 'reflection_id',
    'feature_flags_cache': 'flag_key',
  };
}
