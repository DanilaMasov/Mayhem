import 'dart:convert';

import '../../core/auth/remote_auth_gateway.dart';
import '../../core/auth/remote_auth_session.dart';
import 'supabase_event_sync_transport.dart';
import 'supabase_runtime_config.dart';

class SupabaseAuthException implements Exception {
  const SupabaseAuthException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'Supabase Auth failed ($statusCode): $message';
}

abstract interface class ExternalIdentityLinkHandler {
  Future<RemoteAuthSession> link(
    RemoteAuthSession current,
    ExternalIdentityProvider provider,
  );
}

class SupabaseAnonymousAuthGateway implements RemoteAuthGateway {
  const SupabaseAnonymousAuthGateway({
    required this.config,
    required this.http,
    required this.clock,
    this.identityLinkHandler,
    this.captchaTokenProvider,
  });

  final SupabaseRuntimeConfig config;
  final JsonHttpExecutor http;
  final DateTime Function() clock;
  final ExternalIdentityLinkHandler? identityLinkHandler;
  final Future<String?> Function()? captchaTokenProvider;

  @override
  Future<RemoteAuthSession> signInAnonymously() async {
    final captchaToken = (await captchaTokenProvider?.call())?.trim();
    return _request(config.authUri('/signup'), {
      if (captchaToken?.isNotEmpty == true) 'captcha_token': captchaToken,
    }, expectedAnonymous: true);
  }

  @override
  Future<RemoteAuthSession> refresh(RemoteAuthSession current) async {
    final refreshed = await _request(
      config.authUri(
        '/token',
        queryParameters: const {'grant_type': 'refresh_token'},
      ),
      {'refresh_token': current.refreshToken},
      expectedAnonymous: current.isAnonymous,
    );
    if (refreshed.remoteUserId != current.remoteUserId) {
      throw StateError('Supabase refresh changed the remote user');
    }
    return refreshed;
  }

  @override
  Future<RemoteAuthSession> linkIdentity(
    RemoteAuthSession current,
    ExternalIdentityProvider provider,
  ) {
    final handler = identityLinkHandler;
    if (handler == null) {
      throw UnsupportedError(
        'External identity linking requires an approved platform handler',
      );
    }
    return handler.link(current, provider);
  }

  Future<RemoteAuthSession> _request(
    Uri uri,
    Map<String, Object?> body, {
    required bool expectedAnonymous,
  }) async {
    final response = await http.post(
      uri,
      headers: {
        'apikey': config.anonKey,
        'authorization': 'Bearer ${config.anonKey}',
        'content-type': 'application/json',
      },
      body: jsonEncode(body),
    );
    final decoded = _decode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail =
          decoded?['msg'] ??
          decoded?['message'] ??
          decoded?['error_description'] ??
          decoded?['error'] ??
          'request failed';
      var bounded = '$detail';
      for (final secret in body.values.whereType<String>()) {
        if (secret.isNotEmpty) {
          bounded = bounded.replaceAll(secret, '<redacted>');
        }
      }
      throw SupabaseAuthException(
        response.statusCode,
        bounded.substring(0, bounded.length.clamp(0, 240)),
      );
    }
    if (decoded == null) {
      throw const FormatException('Supabase Auth response must be an object');
    }
    final user = decoded['user'];
    final expiresIn = decoded['expires_in'];
    if (user is! Map || expiresIn is! num || expiresIn.toInt() < 1) {
      throw const FormatException('Supabase Auth session payload is invalid');
    }
    final remoteUserId = user['id'];
    final accessToken = decoded['access_token'];
    final refreshToken = decoded['refresh_token'];
    final isAnonymous = user['is_anonymous'];
    if (remoteUserId is! String ||
        accessToken is! String ||
        refreshToken is! String ||
        isAnonymous is! bool ||
        isAnonymous != expectedAnonymous) {
      throw const FormatException('Supabase Auth identity payload is invalid');
    }
    return RemoteAuthSession(
      remoteUserId: remoteUserId,
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: clock().toUtc().add(Duration(seconds: expiresIn.toInt())),
      isAnonymous: isAnonymous,
    );
  }

  Map<String, dynamic>? _decode(String body) {
    if (body.trim().isEmpty) return null;
    final value = jsonDecode(body);
    return value is Map<String, dynamic> ? value : null;
  }
}
