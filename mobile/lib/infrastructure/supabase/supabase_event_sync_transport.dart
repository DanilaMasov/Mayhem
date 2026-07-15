import 'dart:convert';

import '../../domain/models/event_sync.dart';
import '../../domain/models/game_event.dart';
import '../../domain/ports/event_sync_transport.dart';
import 'supabase_runtime_config.dart';

class JsonHttpResponse {
  const JsonHttpResponse({required this.statusCode, required this.body});

  final int statusCode;
  final String body;
}

abstract interface class JsonHttpExecutor {
  Future<JsonHttpResponse> post(
    Uri uri, {
    required Map<String, String> headers,
    required String body,
  });
}

class SupabaseRpcException implements Exception {
  const SupabaseRpcException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'Supabase RPC failed ($statusCode): $message';
}

class SupabaseRpcAuthRecoveryException extends SupabaseRpcException {
  const SupabaseRpcAuthRecoveryException(String code) : super(401, code);
}

class SupabaseRpcClient {
  const SupabaseRpcClient({
    required this.config,
    required this.accessTokenProvider,
    required this.http,
    this.refreshSession,
  });

  final SupabaseRuntimeConfig config;
  final Future<String?> Function() accessTokenProvider;
  final JsonHttpExecutor http;
  final Future<void> Function()? refreshSession;

  Future<Map<String, dynamic>> invoke(
    String functionName,
    Map<String, Object?> arguments,
  ) async {
    final decoded = await invokeValue(functionName, arguments);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Supabase RPC response must be an object');
    }
    return decoded;
  }

  Future<Object?> invokeValue(
    String functionName,
    Map<String, Object?> arguments,
  ) async {
    var token = await _accessToken();
    var response = await _post(functionName, arguments, token);
    if (response.statusCode == 401 && refreshSession != null) {
      try {
        await refreshSession!();
      } catch (_) {
        throw const SupabaseRpcAuthRecoveryException('session_refresh_failed');
      }
      token = await _accessToken(missingCode: 'session_missing_after_refresh');
      response = await _post(functionName, arguments, token);
      if (response.statusCode == 401) {
        throw const SupabaseRpcAuthRecoveryException(
          'session_rejected_after_refresh',
        );
      }
    }
    final decoded = _decodeValue(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = decoded is Map<String, dynamic> ? decoded : null;
      final message = error?['message'] ?? error?['code'] ?? 'request failed';
      final redacted = '$message'.replaceAll(token, '<redacted>');
      throw SupabaseRpcException(
        response.statusCode,
        redacted.substring(0, redacted.length.clamp(0, 240)),
      );
    }
    if (decoded == null) {
      throw const FormatException('Supabase RPC response is empty');
    }
    return decoded;
  }

  Future<String> _accessToken({
    String missingCode = 'authenticated_session_missing',
  }) async {
    final token = (await accessTokenProvider())?.trim() ?? '';
    if (token.isEmpty) {
      throw SupabaseRpcAuthRecoveryException(missingCode);
    }
    return token;
  }

  Future<JsonHttpResponse> _post(
    String functionName,
    Map<String, Object?> arguments,
    String token,
  ) {
    return http.post(
      config.rpcUri(functionName),
      headers: {
        'apikey': config.anonKey,
        'authorization': 'Bearer $token',
        'content-type': 'application/json',
      },
      body: jsonEncode(arguments),
    );
  }

  Object? _decodeValue(String body) {
    if (body.trim().isEmpty) return null;
    return jsonDecode(body);
  }
}

class SupabaseEventSyncTransport implements EventSyncTransport {
  const SupabaseEventSyncTransport({
    required this.rpc,
    required this.installationId,
  });

  final SupabaseRpcClient rpc;
  final String installationId;

  @override
  Future<EventSyncAck> pushEvents(List<GameEvent> events) async {
    if (installationId.trim().isEmpty) {
      throw const FormatException('Installation ID is missing');
    }
    final response = await rpc.invoke('ingest_quest_events', {
      'p_installation_id': installationId,
      'p_events': events
          .map((event) => event.toSyncPayload())
          .toList(growable: false),
    });
    return EventSyncAck.fromJson(response);
  }
}
