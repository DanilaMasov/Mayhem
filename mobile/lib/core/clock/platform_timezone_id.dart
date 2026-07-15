import 'package:flutter/services.dart';

abstract final class PlatformTimezoneId {
  static const MethodChannel _channel = MethodChannel('mayhem/timezone');

  static Future<String> load() async {
    final value = (await _channel.invokeMethod<String>(
      'getIanaTimezoneId',
    ))?.trim();
    if (value == null || !_ianaPattern.hasMatch(value)) {
      throw StateError('A valid IANA timezone ID is not available');
    }
    return value;
  }

  static final RegExp _ianaPattern = RegExp(
    r'^(?:UTC|GMT|Etc/UTC|[A-Za-z0-9._+-]+(?:/[A-Za-z0-9._+-]+)+)$',
  );
}
