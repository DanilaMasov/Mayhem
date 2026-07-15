abstract interface class InstallationIdentityStore {
  Future<String> getOrCreateInstallationId(String Function() generator);
}
