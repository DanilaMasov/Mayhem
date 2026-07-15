import 'dart:developer' as developer;

import '../identity/local_identity_repository.dart';
import 'remote_auth_gateway.dart';
import 'secure_session_store.dart';

class AccountLinkCoordinator {
  const AccountLinkCoordinator({
    required this.gateway,
    required this.sessions,
    required this.identityBinding,
    required this.clock,
  });

  final RemoteAuthGateway gateway;
  final SecureSessionStore sessions;
  final RemoteIdentityBindingRepository identityBinding;
  final DateTime Function() clock;

  Future<void> link(ExternalIdentityProvider provider) async {
    final current = await sessions.read();
    if (current == null) throw StateError('Remote session is unavailable');
    final linked = await gateway.linkIdentity(current, provider);
    if (linked.remoteUserId != current.remoteUserId || linked.isAnonymous) {
      throw StateError('Account linking did not preserve the remote user');
    }
    await sessions.write(linked);
    await identityBinding.bindRemoteUser(linked.remoteUserId, clock().toUtc());
    developer.log(
      'External identity linked to existing account',
      name: 'mayhem.auth',
    );
  }
}
