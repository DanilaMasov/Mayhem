import 'dart:developer' as developer;

import 'remote_auth_gateway.dart';
import 'remote_auth_session.dart';
import 'secure_session_store.dart';

class AnonymousSessionCoordinator {
  const AnonymousSessionCoordinator({
    required this.gateway,
    required this.store,
  });

  final RemoteAuthGateway gateway;
  final SecureSessionStore store;

  Future<RemoteAuthSession> ensureSession(DateTime now) async {
    final stored = await store.read();
    if (stored == null) {
      final created = await gateway.signInAnonymously();
      await store.write(created);
      developer.log('Anonymous remote session created', name: 'mayhem.auth');
      return created;
    }
    if (stored.isUsableAt(now)) return stored;
    return refreshSession();
  }

  Future<RemoteAuthSession> refreshSession() async {
    final stored = await store.read();
    if (stored == null) {
      throw StateError('Remote session is unavailable for refresh');
    }
    final refreshed = await gateway.refresh(stored);
    if (refreshed.remoteUserId != stored.remoteUserId) {
      throw StateError('Session refresh changed the remote user');
    }
    await store.write(refreshed);
    developer.log('Remote session refreshed', name: 'mayhem.auth');
    return refreshed;
  }
}
