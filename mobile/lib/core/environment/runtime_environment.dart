enum MayhemRuntimeEnvironment {
  development,
  staging,
  production;

  static MayhemRuntimeEnvironment resolve({
    required String configured,
    required bool releaseMode,
  }) {
    final normalized = configured.trim().toLowerCase();
    final environment = normalized.isEmpty
        ? releaseMode
              ? production
              : development
        : MayhemRuntimeEnvironment.values
              .where((candidate) => candidate.name == normalized)
              .firstOrNull;
    if (environment == null) {
      throw const FormatException(
        'MAYHEM_ENVIRONMENT must be development, staging, or production',
      );
    }
    if (releaseMode && environment == development) {
      throw const FormatException(
        'Release builds cannot target the development environment',
      );
    }
    return environment;
  }
}
