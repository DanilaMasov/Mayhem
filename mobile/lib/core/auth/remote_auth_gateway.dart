import 'remote_auth_session.dart';

enum ExternalIdentityProvider { apple, google }

abstract interface class RemoteAuthGateway {
  Future<RemoteAuthSession> signInAnonymously();

  Future<RemoteAuthSession> refresh(RemoteAuthSession current);

  /// Links an identity to the same Supabase user; it must not create a new
  /// product profile or discard anonymous events.
  Future<RemoteAuthSession> linkIdentity(
    RemoteAuthSession current,
    ExternalIdentityProvider provider,
  );
}
