enum MayhemRuntimeEnvironment {
  development,
  staging,
  production;

  static MayhemRuntimeEnvironment resolve({
    required String configured,
    required bool releaseMode,
    String flavor = '',
  }) {
    final configuredEnvironment = _parse(
      configured,
      source: 'MAYHEM_ENVIRONMENT',
    );
    final flavorEnvironment = _parse(flavor, source: 'build flavor');
    if (configuredEnvironment != null &&
        flavorEnvironment != null &&
        configuredEnvironment != flavorEnvironment) {
      throw const FormatException(
        'MAYHEM_ENVIRONMENT must match the native build flavor',
      );
    }
    final environment =
        configuredEnvironment ??
        flavorEnvironment ??
        (releaseMode ? production : development);
    if (releaseMode && environment == development) {
      throw const FormatException(
        'Release builds cannot target the development environment',
      );
    }
    return environment;
  }

  static MayhemRuntimeEnvironment? _parse(
    String value, {
    required String source,
  }) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    final environment = MayhemRuntimeEnvironment.values
        .where((candidate) => candidate.name == normalized)
        .firstOrNull;
    if (environment == null) {
      throw FormatException(
        '$source must be development, staging, or production',
      );
    }
    return environment;
  }
}
