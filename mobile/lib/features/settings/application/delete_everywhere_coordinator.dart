import 'dart:developer' as developer;

import '../../../core/auth/secure_session_store.dart';
import '../../sync/domain/backend_models.dart';

class DeleteEverywhereCoordinator {
  const DeleteEverywhereCoordinator({
    required this.backend,
    required this.sessions,
    required this.clearLocalData,
  });

  final VNextBackendGateway backend;
  final SecureSessionStore sessions;
  final Future<void> Function() clearLocalData;

  Future<DataDeletionReceipt> delete() async {
    final session = await sessions.read();
    if (session == null) throw StateError('Remote session is unavailable');
    final receipt = await backend.deleteMyData();
    if (receipt.remoteUserId != session.remoteUserId ||
        !receipt.authIdentityDeleted) {
      throw StateError('Cloud deletion receipt does not match the session');
    }
    await sessions.clear();
    await clearLocalData();
    developer.log(
      'Cloud deletion confirmed; secure session and local data cleared',
      name: 'mayhem.privacy',
    );
    return receipt;
  }
}
