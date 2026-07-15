import 'dart:convert';
import 'dart:io';

import 'supabase_event_sync_transport.dart';

class DartIoJsonHttpExecutor implements JsonHttpExecutor {
  const DartIoJsonHttpExecutor();

  @override
  Future<JsonHttpResponse> post(
    Uri uri, {
    required Map<String, String> headers,
    required String body,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client
          .postUrl(uri)
          .timeout(const Duration(seconds: 20));
      headers.forEach(request.headers.set);
      request.write(body);
      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );
      final responseBody = await response.transform(utf8.decoder).join();
      return JsonHttpResponse(
        statusCode: response.statusCode,
        body: responseBody,
      );
    } finally {
      client.close(force: true);
    }
  }
}
