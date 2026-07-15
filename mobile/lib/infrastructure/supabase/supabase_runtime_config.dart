class SupabaseRuntimeConfig {
  const SupabaseRuntimeConfig({
    required this.projectUrl,
    required this.anonKey,
  });

  static const environment = SupabaseRuntimeConfig(
    projectUrl: String.fromEnvironment('SUPABASE_URL'),
    anonKey: String.fromEnvironment('SUPABASE_ANON_KEY'),
  );

  final String projectUrl;
  final String anonKey;

  bool get isConfigured =>
      projectUrl.trim().isNotEmpty && anonKey.trim().isNotEmpty;

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
    return base;
  }
}
