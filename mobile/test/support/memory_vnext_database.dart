import 'package:mayhem_mobile/infrastructure/sqlite/vnext_database.dart';
import 'package:sqflite/sqflite.dart';

class MemoryVNextDatabase implements VNextDatabase {
  MemoryVNextDatabase({Map<String, List<Map<String, Object?>>> seed = const {}})
    : executor = MemoryDatabaseExecutor(seed);

  final MemoryDatabaseExecutor executor;

  @override
  Future<T> read<T>(VNextDatabaseOperation<T> operation) => operation(executor);

  @override
  Future<T> transaction<T>(VNextDatabaseOperation<T> operation) async {
    final snapshot = executor.snapshot();
    try {
      return await operation(executor);
    } catch (_) {
      executor.restore(snapshot);
      rethrow;
    }
  }
}

class MemoryDatabaseExecutor implements DatabaseExecutor {
  MemoryDatabaseExecutor(Map<String, List<Map<String, Object?>>> seed)
    : _tables = _copyTables(seed);

  Map<String, List<Map<String, Object?>>> _tables;
  String? failNextInsertInto;

  List<Map<String, Object?>> rows(String table) => List.unmodifiable(
    (_tables[table] ?? const []).map(Map<String, Object?>.unmodifiable),
  );

  Map<String, List<Map<String, Object?>>> snapshot() => _copyTables(_tables);

  void restore(Map<String, List<Map<String, Object?>>> snapshot) {
    _tables = _copyTables(snapshot);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return switch (invocation.memberName) {
      #query => _query(invocation),
      #insert => _insert(invocation),
      #update => _update(invocation),
      #delete => _delete(invocation),
      _ => super.noSuchMethod(invocation),
    };
  }

  Future<List<Map<String, Object?>>> _query(Invocation invocation) async {
    final table = invocation.positionalArguments.first as String;
    final where = invocation.namedArguments[#where] as String?;
    final whereArgs =
        invocation.namedArguments[#whereArgs] as List<Object?>? ?? const [];
    var result = rows(table)
        .where((row) => _matches(row, where, whereArgs))
        .map(Map<String, Object?>.from)
        .toList();
    final orderBy = invocation.namedArguments[#orderBy] as String?;
    if (orderBy == 'installation_id ASC, client_sequence ASC') {
      result.sort((left, right) {
        final installation = (left['installation_id'] as String).compareTo(
          right['installation_id'] as String,
        );
        return installation != 0
            ? installation
            : (left['client_sequence'] as num).compareTo(
                right['client_sequence'] as num,
              );
      });
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
    if (failNextInsertInto == table) {
      failNextInsertInto = null;
      throw StateError('Injected insert failure for $table');
    }
    final values = Map<String, Object?>.from(
      invocation.positionalArguments[1] as Map,
    );
    final rows = _tables.putIfAbsent(table, () => []);
    final key = _rowKey(table, values);
    final existingIndex = key == null
        ? -1
        : rows.indexWhere((row) => _rowKey(table, row) == key);
    final conflict =
        invocation.namedArguments[#conflictAlgorithm] as ConflictAlgorithm?;
    if (existingIndex >= 0) {
      if (conflict == ConflictAlgorithm.replace) {
        rows[existingIndex] = values;
      } else if (conflict != ConflictAlgorithm.ignore) {
        throw StateError('Duplicate key for $table');
      }
      return existingIndex + 1;
    }
    rows.add(values);
    return rows.length;
  }

  Future<int> _update(Invocation invocation) async {
    final table = invocation.positionalArguments[0] as String;
    final values = Map<String, Object?>.from(
      invocation.positionalArguments[1] as Map,
    );
    final where = invocation.namedArguments[#where] as String?;
    final whereArgs =
        invocation.namedArguments[#whereArgs] as List<Object?>? ?? const [];
    var changed = 0;
    for (final row in _tables[table] ?? const []) {
      if (_matches(row, where, whereArgs)) {
        row.addAll(values);
        changed += 1;
      }
    }
    return changed;
  }

  Future<int> _delete(Invocation invocation) async {
    final table = invocation.positionalArguments.first as String;
    final where = invocation.namedArguments[#where] as String?;
    final whereArgs =
        invocation.namedArguments[#whereArgs] as List<Object?>? ?? const [];
    final rows = _tables[table] ?? <Map<String, Object?>>[];
    final before = rows.length;
    rows.removeWhere((row) => _matches(row, where, whereArgs));
    return before - rows.length;
  }

  static bool _matches(
    Map<String, Object?> row,
    String? where,
    List<Object?> args,
  ) {
    if (where == null) return true;
    return switch (where) {
      'key = ?' => row['key'] == args[0],
      'event_id = ?' => row['event_id'] == args[0],
      'local_user_id = ?' => row['local_user_id'] == args[0],
      'assignment_id = ?' => row['assignment_id'] == args[0],
      'attempt_id = ?' => row['attempt_id'] == args[0],
      'batch_id = ?' => row['batch_id'] == args[0],
      'projection_name = ?' => row['projection_name'] == args[0],
      "status = 'active'" => row['status'] == 'active',
      'attempt_id = ? AND reward_applied_local = 0' =>
        row['attempt_id'] == args[0] && row['reward_applied_local'] == 0,
      'assignment_id = ? AND impressed_at IS NULL' =>
        row['assignment_id'] == args[0] && row['impressed_at'] == null,
      'assignment_id = ? AND opened_at IS NULL' =>
        row['assignment_id'] == args[0] && row['opened_at'] == null,
      'assignment_id = ? AND skipped_at IS NULL' =>
        row['assignment_id'] == args[0] && row['skipped_at'] == null,
      'content_id = ? AND revision = ? AND locale = ?' =>
        row['content_id'] == args[0] &&
            row['revision'] == args[1] &&
            row['locale'] == args[2],
      'locale = ? AND source = ?' =>
        row['locale'] == args[0] && row['source'] == args[1],
      'flag_key = ?' => row['flag_key'] == args[0],
      'content_id = ? AND revision = ? AND locale = ? AND source = ?' =>
        row['content_id'] == args[0] &&
            row['revision'] == args[1] &&
            row['locale'] == args[2] &&
            row['source'] == args[3],
      "sync_status = 'pending'" => row['sync_status'] == 'pending',
      "sync_status = 'pending' AND "
          '(next_retry_at IS NULL OR next_retry_at <= ?)' =>
        row['sync_status'] == 'pending' &&
            (row['next_retry_at'] == null ||
                (row['next_retry_at'] as String).compareTo(args[0] as String) <=
                    0),
      'expires_at IS NULL OR expires_at > ?' =>
        row['expires_at'] == null ||
            (row['expires_at'] as String).compareTo(args[0] as String) > 0,
      'active = 1 AND locale = ? AND published_at <= ? '
          'AND (starts_at IS NULL OR starts_at <= ?) '
          'AND (ends_at IS NULL OR ends_at > ?)' =>
        row['active'] == 1 &&
            row['locale'] == args[0] &&
            (row['published_at'] as String).compareTo(args[1] as String) <= 0 &&
            (row['starts_at'] == null ||
                (row['starts_at'] as String).compareTo(args[2] as String) <=
                    0) &&
            (row['ends_at'] == null ||
                (row['ends_at'] as String).compareTo(args[3] as String) > 0),
      _ => throw UnsupportedError('Unsupported test where clause: $where'),
    };
  }

  static Map<String, List<Map<String, Object?>>> _copyTables(
    Map<String, List<Map<String, Object?>>> source,
  ) => {
    for (final entry in source.entries)
      entry.key: entry.value.map(Map<String, Object?>.from).toList(),
  };

  static Object? _rowKey(String table, Map<String, Object?> row) =>
      switch (table) {
        'app_metadata' => row['key'],
        'content_item_revisions' =>
          '${row['content_id']}@${row['revision']}:${row['locale']}',
        'feed_batches' => row['batch_id'],
        'feed_assignments' => row['assignment_id'],
        'challenge_attempts' => row['attempt_id'],
        'private_reflections' => row['reflection_id'],
        'event_log_v2' => row['event_id'],
        'projection_checkpoints' => row['projection_name'],
        'feature_flags_cache' => row['flag_key'],
        _ => null,
      };
}
