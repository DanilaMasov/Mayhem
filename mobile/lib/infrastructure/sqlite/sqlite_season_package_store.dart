import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../features/season/application/season_package_store.dart';
import '../../features/season/data/remote_season_package_mapper.dart';
import '../../features/season/domain/season_models.dart';
import '../../features/sync/domain/backend_models.dart';
import 'sqlite_vnext_context.dart';

class SqliteSeasonPackageStore implements SeasonPackageStore {
  const SqliteSeasonPackageStore(this.context);

  static const _cacheKey = 'season.active_package.v1';

  final SqliteVNextContext context;

  @override
  Future<SeasonPackage?> loadCachedPackage() {
    return context.database.transaction((db) async {
      final rows = await db.query(
        'app_metadata',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: [_cacheKey],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      try {
        final decoded = jsonDecode(rows.single['value'] as String);
        if (decoded is! Map) {
          throw const FormatException('Season cache must be an object');
        }
        final snapshot = RemoteSeasonSnapshot.fromJson(
          Map<String, dynamic>.from(decoded),
        );
        return RemoteSeasonPackageMapper.fromSnapshot(snapshot);
      } on FormatException {
        await _delete(db);
        return null;
      } on TypeError {
        await _delete(db);
        return null;
      }
    });
  }

  @override
  Future<SeasonPackage?> loadActivePackage(DateTime atUtc) async {
    final package = await loadCachedPackage();
    if (package == null) return null;
    final at = atUtc.toUtc();
    if (at.isBefore(package.season.startsAt.toUtc()) ||
        !at.isBefore(package.season.endsAt.toUtc())) {
      return null;
    }
    return package;
  }

  @override
  Future<void> saveValidatedSnapshot(RemoteSeasonSnapshot snapshot) {
    RemoteSeasonPackageMapper.fromSnapshot(snapshot);
    final encoded = jsonEncode({
      'seasonId': snapshot.seasonId,
      'revision': snapshot.revision,
      'title': snapshot.title,
      'startsAt': snapshot.startsAt.toUtc().toIso8601String(),
      'endsAt': snapshot.endsAt.toUtc().toIso8601String(),
      'payload': snapshot.payload,
      'participation': snapshot.participation?.toJson(),
    });
    return context.database.transaction((db) async {
      await db.insert('app_metadata', {
        'key': _cacheKey,
        'value': encoded,
        'updated_at': context.clock().toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  @override
  Future<void> clear() => context.database.transaction(_delete);

  Future<void> _delete(DatabaseExecutor db) => db
      .delete('app_metadata', where: 'key = ?', whereArgs: [_cacheKey])
      .then((_) {});
}
