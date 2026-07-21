import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mayhem_mobile/core/environment/runtime_environment.dart';
import 'package:mayhem_mobile/infrastructure/telemetry/staging_crash_reporting.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() {
  test('crash reporting is release-staging only and fails closed', () {
    final production = _configuration(
      environment: MayhemRuntimeEnvironment.production,
      releaseMode: true,
      dsn: _validDsn,
    );
    expect(production.enabled, isFalse);
    expect(
      production.disabledReason,
      CrashReportingDisabledReason.nonStagingEnvironment,
    );
    expect(production.dsn, isNull);

    final debugStaging = _configuration(
      environment: MayhemRuntimeEnvironment.staging,
      releaseMode: false,
      dsn: _validDsn,
    );
    expect(debugStaging.enabled, isFalse);
    expect(
      debugStaging.disabledReason,
      CrashReportingDisabledReason.nonReleaseBuild,
    );

    final missing = _configuration(dsn: '');
    expect(missing.enabled, isFalse);
    expect(missing.disabledReason, CrashReportingDisabledReason.missingDsn);

    for (final invalid in [
      _validDsn.replaceFirst('https', 'http'),
      _validDsn.replaceFirst('public-key', 'public-key:client-secret'),
      _validDsn.replaceFirst('/456', '/project-name'),
    ]) {
      final configuration = _configuration(dsn: invalid);
      expect(configuration.enabled, isFalse);
      expect(
        configuration.disabledReason,
        CrashReportingDisabledReason.invalidDsn,
      );
      expect(configuration.dsn, isNull);
    }

    final enabled = _configuration(dsn: _validDsn);
    expect(enabled.enabled, isTrue);
    expect(enabled.dsn, _validDsn);
    expect(enabled.release, 'com.danilamasov.mayhem.staging@1.2.3+45');
  });

  test('Sentry options enforce the crash-only privacy policy', () {
    final configuration = _configuration(dsn: _validDsn);
    final options = SentryFlutterOptions();

    configuration.configure(options);

    expect(options.dsn, _validDsn);
    expect(options.environment, 'staging');
    expect(options.release, 'com.danilamasov.mayhem.staging@1.2.3+45');
    expect(options.sendDefaultPii, isFalse);
    expect(options.maxBreadcrumbs, 0);
    expect(options.maxRequestBodySize, MaxRequestBodySize.never);
    expect(options.captureFailedRequests, isFalse);
    expect(options.captureNativeFailedRequests, isFalse);
    expect(options.enableLogs, isFalse);
    expect(options.enableMetrics, isFalse);
    expect(options.enableScopeSync, isFalse);
    expect(options.tracesSampleRate, 0);
    // ignore: experimental_member_use
    expect(options.profilesSampleRate, 0);
    expect(options.enableAutoPerformanceTracing, isFalse);
    expect(options.enableFramesTracking, isFalse);
    expect(options.enableNativeTraceSync, isFalse);
    expect(options.enableAutoSessionTracking, isFalse);
    expect(options.enableNativeCrashHandling, isTrue);
    expect(options.enableAutoNativeBreadcrumbs, isFalse);
    expect(options.enableUserInteractionBreadcrumbs, isFalse);
    expect(options.enableUserInteractionTracing, isFalse);
    expect(options.enableWatchdogTerminationTracking, isFalse);
    expect(options.enableAppHangTracking, isFalse);
    expect(options.anrEnabled, isFalse);
    expect(options.attachScreenshot, isFalse);
    // ignore: experimental_member_use
    expect(options.attachViewHierarchy, isFalse);
    expect(options.reportPackages, isFalse);
    expect(options.replay.sessionSampleRate, 0);
    expect(options.replay.onErrorSampleRate, 0);
    expect(
      options.beforeBreadcrumb!(Breadcrumb(message: 'private'), Hint()),
      isNull,
    );
    expect(options.beforeSend, isNotNull);
    expect(options.beforeSendTransaction, isNotNull);
    expect(options.beforeSendFeedback, isNotNull);
  });

  test(
    'SDK initialization failure cannot block or duplicate app launch',
    () async {
      var launchCount = 0;

      await StagingCrashReporting.run(
        configuration: _configuration(dsn: _validDsn),
        appRunner: () async => launchCount += 1,
        initialize: (_, {appRunner}) async {
          throw StateError('synthetic initialization failure');
        },
      );
      expect(launchCount, 1);

      launchCount = 0;
      await StagingCrashReporting.run(
        configuration: _configuration(dsn: _validDsn),
        appRunner: () async => launchCount += 1,
        initialize: (_, {appRunner}) async {
          await appRunner!();
          throw StateError('synthetic post-launch failure');
        },
      );
      expect(launchCount, 1);
    },
  );

  test('beforeSend removes payloads, identifiers and attachments', () async {
    const secret = 'access-token-and-private-server-body';
    final contexts = Contexts(
      app: SentryApp(
        name: secret,
        version: '1.2.3',
        identifier: secret,
        build: '45',
        deviceAppHash: secret,
        viewNames: [secret],
      ),
      device: SentryDevice(name: secret),
      operatingSystem: SentryOperatingSystem(
        name: 'iOS',
        version: '18.0',
        rawDescription: secret,
      ),
      runtimes: [SentryRuntime(name: 'Dart', rawDescription: secret)],
      response: SentryResponse(bodySize: 100, data: secret),
    )..['server_payload'] = {'body': secret};
    final event = SentryEvent(
      serverName: secret,
      message: SentryMessage(secret, params: [secret]),
      transaction: secret,
      culprit: secret,
      modules: {secret: secret},
      tags: {'authorization': secret},
      fingerprint: [secret],
      breadcrumbs: [
        Breadcrumb(message: secret, data: {'body': secret}),
      ],
      user: SentryUser(id: secret, email: secret, ipAddress: secret),
      request: SentryRequest(
        url: 'https://example.invalid/?token=$secret',
        data: secret,
        headers: {'Authorization': secret},
      ),
      contexts: contexts,
      exceptions: [
        SentryException(
          type: 'HttpFailure',
          value: secret,
          module: 'mayhem.network',
          stackTrace: SentryStackTrace(
            frames: [
              SentryStackFrame(
                absPath: '/Users/operator/private/features/feed/feed.dart',
                fileName: '/Users/operator/private/features/feed/feed.dart',
                function: 'FeedController.commit',
                contextLine: secret,
                preContext: [secret],
                postContext: [secret],
                vars: {'token': secret},
                lineNo: 42,
                inApp: true,
              ),
            ],
            registers: {'secret': secret},
          ),
          mechanism: Mechanism(
            type: 'generic',
            description: secret,
            helpLink: 'https://example.invalid/$secret',
            data: {'response': secret},
            meta: {'authorization': secret},
          ),
          throwable: StateError(secret),
        ),
      ],
    );
    // ignore: deprecated_member_use
    event.extra = {'private': secret};
    final hint =
        Hint.withAttachment(
            SentryAttachment.fromIntList(utf8.encode(secret), 'private.txt'),
          )
          ..screenshot = SentryAttachment.fromIntList([1], 'screenshot.png')
          ..viewHierarchy = SentryAttachment.fromIntList([2], 'view.json')
          ..response = SentryResponse(data: secret);

    final sanitized = MayhemSentryEventScrubber.scrub(
      event,
      hint,
      release: 'com.danilamasov.mayhem.staging@1.2.3+45',
    );
    final encoded = jsonEncode(sanitized.toJson());

    expect(encoded, isNot(contains(secret)));
    expect(encoded, isNot(contains('/Users/operator')));
    expect(encoded, contains('details redacted'));
    expect(encoded, contains('features/feed/feed.dart'));
    expect(encoded, contains('HttpFailure'));
    expect(encoded, contains(StagingCrashReportingConfiguration.policyTag));
    expect(sanitized.user, isNull);
    expect(sanitized.request, isNull);
    expect(sanitized.breadcrumbs, isNull);
    // ignore: deprecated_member_use
    expect(sanitized.extra, isNull);
    expect(sanitized.contexts.device, isNull);
    expect(sanitized.contexts.response, isNull);
    expect(sanitized.contexts.containsKey('server_payload'), isFalse);
    expect(hint.attachments, isEmpty);
    expect(hint.screenshot, isNull);
    expect(hint.viewHierarchy, isNull);
    expect(hint.response, isNull);
  });
}

StagingCrashReportingConfiguration _configuration({
  MayhemRuntimeEnvironment environment = MayhemRuntimeEnvironment.staging,
  bool releaseMode = true,
  required String dsn,
}) {
  return StagingCrashReportingConfiguration.resolve(
    environment: environment,
    releaseMode: releaseMode,
    configuredDsn: dsn,
    appVersion: '1.2.3+45',
  );
}

String get _validDsn =>
    ['https://public-key', '@o123.ingest.sentry.io', '/456'].join();
