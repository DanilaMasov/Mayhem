import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../core/database/projection_checkpoint.dart';

class SqliteProjectionCheckpointRepository<T>
    implements ProjectionCheckpointRepository<T> {
  const SqliteProjectionCheckpointRepository(
    this._database, {
    required this.encode,
    required this.decode,
  });

  final Database _database;
  final Map<String, Object?> Function(T value) encode;
  final T Function(Map<String, dynamic> json) decode;

  @override
  Future<ProjectionCheckpoint<T>?> load(String projectionName) async {
    final rows = await _database.query(
      'projection_checkpoints',
      where: 'projection_name = ?',
      whereArgs: [projectionName],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    final snapshotJson = jsonDecode(row['snapshot_json'] as String);
    if (snapshotJson is! Map<String, dynamic>) {
      throw const FormatException('Projection checkpoint must be an object');
    }
    return ProjectionCheckpoint<T>(
      projectionName: projectionName,
      snapshot: decode(snapshotJson),
      lastAppliedInstallationId: row['last_applied_installation_id'] as String?,
      lastAppliedSequence: (row['last_applied_sequence'] as num?)?.toInt(),
      updatedAt: DateTime.parse(row['updated_at'] as String),
      schemaVersion: (row['schema_version'] as num).toInt(),
    );
  }

  @override
  Future<void> save(ProjectionCheckpoint<T> checkpoint) {
    return _database
        .insert('projection_checkpoints', {
          'projection_name': checkpoint.projectionName,
          'snapshot_json': jsonEncode(encode(checkpoint.snapshot)),
          'last_applied_installation_id': checkpoint.lastAppliedInstallationId,
          'last_applied_sequence': checkpoint.lastAppliedSequence,
          'updated_at': checkpoint.updatedAt.toUtc().toIso8601String(),
          'schema_version': checkpoint.schemaVersion,
        }, conflictAlgorithm: ConflictAlgorithm.replace)
        .then((_) {});
  }
}
