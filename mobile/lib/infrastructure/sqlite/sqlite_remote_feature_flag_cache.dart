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

  @override
  Future<CachedRemoteFlags?> load({
    required DateTime now,
    required CapabilityRevisionSet capabilities,
  }) {
    return context.database.read((db) async {
      final rows = await db.query('feature_flags_cache');
      if (rows.length != MayhemFeatureFlag.values.length) return null;
      try {
        final records = <RemoteFlagRecord>[];
        final seen = <MayhemFeatureFlag>{};
        DateTime? fetchedAt;
        DateTime? expiresAt;
        for (final row in rows) {
          final rowFetchedAt = DateTime.parse(
            row['fetched_at'] as String,
          ).toUtc();
          final rowExpiresAt = DateTime.parse(
            row['expires_at'] as String,
          ).toUtc();
          if ((fetchedAt != null && fetchedAt != rowFetchedAt) ||
              (expiresAt != null && expiresAt != rowExpiresAt)) {
            return null;
          }
          fetchedAt = rowFetchedAt;
          expiresAt = rowExpiresAt;
          final decoded = jsonDecode(row['value_json'] as String);
          if (decoded is! Map<String, dynamic>) return null;
          decoded['updatedAt'] ??= row['fetched_at'];
          final record = RemoteFlagRecord.fromJson(decoded);
          if (row['flag_key'] != record.flag.wireName ||
              !seen.add(record.flag)) {
            return null;
          }
          records.add(record);
        }
        if (fetchedAt == null ||
            expiresAt == null ||
            !expiresAt.isAfter(fetchedAt) ||
            !expiresAt.isAfter(now.toUtc())) {
          return null;
        }
        return CachedRemoteFlags(
          snapshot: RemoteFeatureFlagResolver.resolve(
            records: records,
            capabilities: capabilities,
          ),
          fetchedAt: fetchedAt,
          expiresAt: expiresAt,
        );
      } on FormatException {
        return null;
      } on TypeError {
        return null;
      }
    });
  }
}
