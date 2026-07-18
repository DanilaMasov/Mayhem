import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mayhem_mobile/core/clock/platform_timezone_id.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('platform timezone accepts a valid IANA identifier', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('mayhem/timezone'),
          (_) async => 'Europe/Moscow',
        );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('mayhem/timezone'),
            null,
          ),
    );

    expect(await PlatformTimezoneId.load(), 'Europe/Moscow');
  });

  testWidgets('platform timezone rejects abbreviations and empty values', (
    tester,
  ) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const channel = MethodChannel('mayhem/timezone');
    for (final value in ['', 'MSK']) {
      messenger.setMockMethodCallHandler(channel, (_) async => value);
      await expectLater(PlatformTimezoneId.load(), throwsStateError);
    }
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('iOS and Android hosts expose the timezone channel', () async {
    final android = await File(
      'android/app/src/main/kotlin/com/danilamasov/mayhem/'
      'MainActivity.kt',
    ).readAsString();
    final ios = await File('ios/Runner/AppDelegate.swift').readAsString();

    expect(android, contains('"mayhem/timezone"'));
    expect(android, contains('TimeZone.getDefault().id'));
    expect(ios, contains('"mayhem/timezone"'));
    expect(ios, contains('TimeZone.current.identifier'));
  });
}
