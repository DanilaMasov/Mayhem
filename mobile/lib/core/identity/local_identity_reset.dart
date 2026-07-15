import 'package:sqflite/sqflite.dart';

import 'local_identity_repository.dart';

abstract final class LocalIdentityReset {
  static Future<LocalIdentity> replace(
    DatabaseExecutor db, {
    required String Function() idGenerator,
    required DateTime now,
  }) async {
    final installationId = _validId(idGenerator());
    final localUserId = _validId(idGenerator());
    final updatedAt = now.toUtc().toIso8601String();
    await db.insert('app_metadata', {
      'key': 'installation_id',
      'value': installationId,
      'updated_at': updatedAt,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert('app_metadata', {
      'key': 'local_user_id',
      'value': localUserId,
      'updated_at': updatedAt,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert('app_metadata', {
      'key': 'client_sequence:$installationId',
      'value': '0',
      'updated_at': updatedAt,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert('user_identity', {
      'local_user_id': localUserId,
      'installation_id': installationId,
      'remote_user_id': null,
      'created_at': updatedAt,
      'linked_at': null,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return LocalIdentity(
      localUserId: localUserId,
      remoteUserId: null,
      installationId: installationId,
    );
  }

  static String _validId(String value) {
    if (value.trim().isEmpty) {
      throw const FormatException('Local identity ID must not be empty');
    }
    return value;
  }
}
