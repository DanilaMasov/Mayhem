import '../../core/identity/local_identity_repository.dart';
import 'sqlite_vnext_context.dart';

class SqliteLocalIdentityRepository
    implements LocalIdentityRepository, RemoteIdentityBindingRepository {
  const SqliteLocalIdentityRepository(this.context);

  final SqliteVNextContext context;

  @override
  Future<LocalIdentity> loadIdentity() {
    return context.database.read(context.identity);
  }

  @override
  Future<void> bindRemoteUser(String remoteUserId, DateTime linkedAt) {
    if (remoteUserId.trim().isEmpty) {
      throw const FormatException('Remote user ID must not be empty');
    }
    return context.database.transaction((db) async {
      final identity = await context.identity(db);
      if (identity.remoteUserId != null &&
          identity.remoteUserId != remoteUserId) {
        throw StateError('Local identity is already linked to another user');
      }
      await db.update(
        'user_identity',
        {
          'remote_user_id': remoteUserId,
          'linked_at': linkedAt.toUtc().toIso8601String(),
        },
        where: 'local_user_id = ?',
        whereArgs: [identity.localUserId],
      );
    });
  }
}
