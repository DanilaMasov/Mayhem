class LocalIdentity {
  const LocalIdentity({
    required this.localUserId,
    required this.installationId,
    this.remoteUserId,
  });

  final String localUserId;
  final String installationId;
  final String? remoteUserId;
}

abstract interface class LocalIdentityRepository {
  Future<LocalIdentity> loadIdentity();
}

abstract interface class RemoteIdentityBindingRepository {
  Future<void> bindRemoteUser(String remoteUserId, DateTime linkedAt);
}
