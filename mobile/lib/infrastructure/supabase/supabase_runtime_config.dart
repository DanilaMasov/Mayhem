class SupabaseRuntimeConfig {
  const SupabaseRuntimeConfig({
    required this.projectUrl,
    required this.anonKey,
    this.runtimeEnvironment = 'production',
  });

  static const environment = SupabaseRuntimeConfig(
    projectUrl: String.fromEnvironment('SUPABASE_URL'),
    anonKey: String.fromEnvironment('SUPABASE_ANON_KEY'),
  );

  final String projectUrl;
  final String anonKey;
  final String runtimeEnvironment;

  bool get isConfigured =>
      projectUrl.trim().isNotEmpty && anonKey.trim().isNotEmpty;

  bool get isUsable {
    try {
      _baseUri();
      return true;
    } on FormatException {
      return false;
    }
  }

  SupabaseRuntimeConfig forEnvironment(String environment) =>
      SupabaseRuntimeConfig(
        projectUrl: projectUrl,
        anonKey: anonKey,
        runtimeEnvironment: environment.trim().toLowerCase(),
      );

  Uri rpcUri(String functionName) {
    return _baseUri().resolve('/rest/v1/rpc/$functionName');
  }

  Uri authUri(String path, {Map<String, String> queryParameters = const {}}) {
    if (!path.startsWith('/')) {
      throw const FormatException('Supabase auth path must be absolute');
    }
    final uri = _baseUri().resolve('/auth/v1$path');
    return queryParameters.isEmpty
        ? uri
        : uri.replace(queryParameters: queryParameters);
  }

  Uri _baseUri() {
    if (!isConfigured) {
      throw const FormatException('Supabase runtime is not configured');
    }
    final base = Uri.parse(projectUrl.trim());
    if (!base.hasScheme || base.host.isEmpty) {
      throw const FormatException('SUPABASE_URL is invalid');
    }
    if (base.scheme == 'https') return base;
    final localDevelopment =
        runtimeEnvironment == 'development' ||
        runtimeEnvironment == 'local' ||
        runtimeEnvironment == 'test';
    final localHost =
        base.host == 'localhost' ||
        base.host == '127.0.0.1' ||
        base.host == '::1';
    if (base.scheme != 'http' || !localDevelopment || !localHost) {
      throw const FormatException(
        'SUPABASE_URL must use HTTPS outside local development',
      );
    }
    return base;
  }
}
