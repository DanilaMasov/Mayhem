import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../core/feature_flags/feature_flags.dart';
import '../../core/feature_flags/remote_feature_flag_resolver.dart';
import '../../features/sync/domain/backend_models.dart';
import '../../features/sync/domain/remote_flag_cache.dart';
import 'sqlite_vnext_context.dart';

class SqliteRemoteFeatureFlagCache implements RemoteFlagCache {
  const SqliteRemoteFeatureFlagCache(this.context);

  final SqliteVNextContext context;

  @override
  Future<void> save({
    required Iterable<RemoteFlagRecord> records,
    required DateTime fetchedAt,
    required DateTime expiresAt,
  }) {
    final byFlag = {for (final record in records) record.flag: record};
    return context.database.transaction((db) async {
      for (final flag in MayhemFeatureFlag.values) {
        final record = byFlag[flag];
        await db.insert('feature_flags_cache', {
          'flag_key': flag.wireName,
          'value_json': jsonEncode(
            record?.toCacheJson() ?? {'key': flag.wireName, 'enabled': false},
          ),
          'fetched_at': fetchedAt.toUtc().toIso8601String(),
          'expires_at': expiresAt.toUtc().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<FeatureFlagSnapshot> load({
    required DateTime now,
    required CapabilityRevisionSet capabilities,
  }) {
    return context.database.read((db) async {
      final rows = await db.query('feature_flags_cache');
      final records = <RemoteFlagRecord>[];
      for (final row in rows) {
        final expiresAt = row['expires_at'] as String?;
        if (expiresAt == null ||
            !DateTime.parse(expiresAt).toUtc().isAfter(now.toUtc())) {
          continue;
        }
        try {
          final decoded = jsonDecode(row['value_json'] as String);
          if (decoded is! Map<String, dynamic>) continue;
          decoded['updatedAt'] ??= row['fetched_at'];
          records.add(RemoteFlagRecord.fromJson(decoded));
        } on FormatException {
          // A corrupt cache row is equivalent to the false safe default.
        }
      }
      return RemoteFeatureFlagResolver.resolve(
        records: records,
        capabilities: capabilities,
      );
    });
  }
}
