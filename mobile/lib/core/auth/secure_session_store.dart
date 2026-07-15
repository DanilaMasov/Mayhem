import 'remote_auth_session.dart';

/// Must be backed by platform-protected storage in production.
abstract interface class SecureSessionStore {
  Future<RemoteAuthSession?> read();

  Future<void> write(RemoteAuthSession session);

  Future<void> clear();
}
