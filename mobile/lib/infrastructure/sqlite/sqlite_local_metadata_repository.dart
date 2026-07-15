import 'package:sqflite/sqflite.dart';

import '../../core/metadata/local_metadata_repository.dart';
import 'sqlite_vnext_context.dart';

class SqliteLocalMetadataRepository implements LocalMetadataRepository {
  const SqliteLocalMetadataRepository(this.context);

  final SqliteVNextContext context;

  @override
  Future<String?> read(String key) {
    return context.database.read((db) async {
      final rows = await db.query(
        'app_metadata',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: [key],
        limit: 1,
      );
      return rows.isEmpty ? null : rows.single['value'] as String;
    });
  }

  @override
  Future<void> write(String key, String value) {
    if (key.trim().isEmpty) {
      throw const FormatException('Metadata key must not be empty');
    }
    return context.database.transaction((db) async {
      await db.insert('app_metadata', {
        'key': key,
        'value': value,
        'updated_at': context.clock().toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  @override
  Future<void> delete(String key) {
    return context.database.transaction((db) async {
      await db.delete('app_metadata', where: 'key = ?', whereArgs: [key]);
    });
  }
}
