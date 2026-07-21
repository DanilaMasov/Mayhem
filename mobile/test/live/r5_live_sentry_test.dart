import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mayhem_mobile/core/environment/runtime_environment.dart';
import 'package:mayhem_mobile/infrastructure/telemetry/staging_crash_reporting.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

const _confirmation = 'I_UNDERSTAND_THIS_SENDS_A_SYNTHETIC_STAGING_EVENT';
const _privateMarker = 'MAYHEM_R5_PRIVATE_SENTINEL_DO_NOT_INGEST';
const _release = 'com.danilamasov.mayhem.staging@0.0.0+1';

void main() {
  SentryWidgetsFlutterBinding.ensureInitialized();
  final live = _LiveSentryConfig.fromEnvironment(Platform.environment);

  test(
    'privacy-scrubbed staging event reaches the configured transport',
    () async {
      final config = live.requireConfiguration();
      final reporting = StagingCrashReportingConfiguration.resolve(
        environment: MayhemRuntimeEnvironment.staging,
        // The app's kReleaseMode boundary has separate unit coverage. This
        // protected probe explicitly activates that accepted configuration to
        // exercise the real transport and scrubber inside flutter test.
        releaseMode: true,
        configuredDsn: config.dsn,
        appVersion: '0.0.0+1',
      );
      expect(reporting.enabled, isTrue);
      expect(reporting.release, _release);

      SentryId eventId = SentryId.empty();
      try {
        await SentryFlutter.init(reporting.configure);
        eventId = await Sentry.captureEvent(
          _privacyProbeEvent(),
          hint: Hint.withAttachment(
            SentryAttachment.fromIntList(
              utf8.encode(_privateMarker),
              'private-probe.txt',
            ),
          ),
        );
      } finally {
        await Sentry.close();
      }

      final eventIdValue = eventId.toString();
      expect(eventIdValue, matches(RegExp(r'^[a-f0-9]{32}$')));
      await File(config.submissionPath).writeAsString(
        jsonEncode({
          'schemaVersion': 1,
          'eventId': eventIdValue,
          'release': _release,
          'environment': MayhemRuntimeEnvironment.staging.name,
          'policyTag': StagingCrashReportingConfiguration.policyTag,
          'privateMarker': _privateMarker,
          'submittedAt': DateTime.now().toUtc().toIso8601String(),
        }),
        flush: true,
      );
    },
    skip: live.skipReason,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

SentryEvent _privacyProbeEvent() {
  final contexts = Contexts(response: SentryResponse(data: _privateMarker))
    ..['private_context'] = {'secret': _privateMarker};
  return SentryEvent(
    level: SentryLevel.fatal,
    message: SentryMessage(_privateMarker),
    user: SentryUser(
      id: _privateMarker,
      email: '$_privateMarker@example.invalid',
      ipAddress: _privateMarker,
    ),
    request: SentryRequest(
      url: 'https://private.invalid/?token=$_privateMarker',
      data: _privateMarker,
      headers: {'Authorization': _privateMarker},
    ),
    breadcrumbs: [
      Breadcrumb(message: _privateMarker, data: {'body': _privateMarker}),
    ],
    contexts: contexts,
    exceptions: [
      SentryException(
        type: 'SyntheticPrivacyProbe',
        value: _privateMarker,
        module: 'mayhem.acceptance',
        stackTrace: SentryStackTrace(
          frames: [
            SentryStackFrame(
              absPath: '/Users/$_privateMarker/features/acceptance/probe.dart',
              fileName: 'features/acceptance/probe.dart',
              function: 'runPrivacyProbe',
              contextLine: _privateMarker,
              vars: {'token': _privateMarker},
              lineNo: 42,
              inApp: true,
            ),
          ],
          registers: {'private': _privateMarker},
        ),
        mechanism: Mechanism(
          type: 'generic',
          description: _privateMarker,
          data: {'response': _privateMarker},
        ),
      ),
    ],
  );
}

class _LiveSentryConfig {
  const _LiveSentryConfig({
    required this.confirmed,
    required this.dsn,
    required this.submissionPath,
  });

  factory _LiveSentryConfig.fromEnvironment(Map<String, String> environment) {
    return _LiveSentryConfig(
      confirmed: environment['MAYHEM_R5_SENTRY_CONFIRM'] == _confirmation,
      dsn: environment['MAYHEM_SENTRY_DSN']?.trim() ?? '',
      submissionPath:
          environment['MAYHEM_R5_SENTRY_SUBMISSION_PATH']?.trim() ?? '',
    );
  }

  final bool confirmed;
  final String dsn;
  final String submissionPath;

  String? get skipReason => confirmed
      ? null
      : 'requires the protected staging Sentry acceptance workflow';

  _LiveSentryConfig requireConfiguration() {
    if (!confirmed) throw StateError('sentry_live_confirmation_required');
    if (dsn.isEmpty) throw StateError('sentry_live_dsn_required');
    if (submissionPath.isEmpty) {
      throw StateError('sentry_live_submission_path_required');
    }
    return this;
  }
}
