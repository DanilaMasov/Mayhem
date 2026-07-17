import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/r2_live_client_acceptance.dart';

void main() {
  final liveEnabled = Platform.environment['MAYHEM_R2_RUN_LIVE'] == 'true';

  test(
    'production Flutter adapters pass R2 against disposable Supabase',
    () async {
      final previousOverrides = HttpOverrides.current;
      HttpOverrides.global = _LiveHttpOverrides();
      try {
        final report = await runR2LiveClientAcceptance();
        final encoded = base64Url.encode(utf8.encode(jsonEncode(report)));
        // The Node orchestrator extracts only this secret-free report marker.
        stdout.writeln('MAYHEM_R2_CLIENT_REPORT:$encoded');
      } finally {
        HttpOverrides.global = previousOverrides;
      }
    },
    skip: liveEnabled ? false : 'requires an explicit disposable R2 target',
  );
}

class _LiveHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context)
        ..connectionTimeout = const Duration(seconds: 15);
}
