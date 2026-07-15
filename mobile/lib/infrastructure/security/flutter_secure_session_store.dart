import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/auth/remote_auth_session.dart';
import '../../core/auth/secure_session_store.dart';

abstract interface class SecureKeyValueStore {
  Future<String?> read({required String key});

  Future<void> write({required String key, required String value});

  Future<void> delete({required String key});
}

class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  FlutterSecureKeyValueStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read({required String key}) => _storage.read(key: key);

  @override
  Future<void> write({required String key, required String value}) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete({required String key}) => _storage.delete(key: key);
}

class FlutterSecureSessionStore implements SecureSessionStore {
  FlutterSecureSessionStore({
    required this.storage,
    required String environment,
  }) : _key = _sessionKey(environment);

  static const int _schemaVersion = 1;
  static const int _maximumPayloadLength = 32 * 1024;
  static final RegExp _validEnvironment = RegExp(
    r'^[a-z0-9][a-z0-9._-]{0,63}$',
  );

  final SecureKeyValueStore storage;
  final String _key;

  @override
  Future<RemoteAuthSession?> read() async {
    final payload = await storage.read(key: _key);
    if (payload == null) return null;
    try {
      return _decode(payload);
    } on FormatException {
      await storage.delete(key: _key);
      return null;
    }
  }

  @override
  Future<void> write(RemoteAuthSession session) {
    final payload = jsonEncode({
      'version': _schemaVersion,
      'remoteUserId': session.remoteUserId,
      'accessToken': session.accessToken,
      'refreshToken': session.refreshToken,
      'expiresAt': session.expiresAt.toIso8601String(),
      'isAnonymous': session.isAnonymous,
    });
    if (payload.length > _maximumPayloadLength) {
      throw const FormatException('Remote auth session payload is too large');
    }
    return storage.write(key: _key, value: payload);
  }

  @override
  Future<void> clear() => storage.delete(key: _key);

  RemoteAuthSession _decode(String payload) {
    if (payload.length > _maximumPayloadLength) {
      throw const FormatException('Remote auth session payload is too large');
    }
    final decoded = jsonDecode(payload);
    if (decoded is! Map<String, dynamic> ||
        decoded['version'] != _schemaVersion ||
        decoded['remoteUserId'] is! String ||
        decoded['accessToken'] is! String ||
        decoded['refreshToken'] is! String ||
        decoded['expiresAt'] is! String ||
        decoded['isAnonymous'] is! bool) {
      throw const FormatException('Remote auth session payload is invalid');
    }
    return RemoteAuthSession(
      remoteUserId: decoded['remoteUserId'] as String,
      accessToken: decoded['accessToken'] as String,
      refreshToken: decoded['refreshToken'] as String,
      expiresAt: DateTime.parse(decoded['expiresAt'] as String),
      isAnonymous: decoded['isAnonymous'] as bool,
    );
  }

  static String _sessionKey(String environment) {
    final normalized = environment.trim().toLowerCase();
    if (!_validEnvironment.hasMatch(normalized)) {
      throw const FormatException('Secure storage environment is invalid');
    }
    return 'mayhem.$normalized.remote_auth_session.v1';
  }
}
