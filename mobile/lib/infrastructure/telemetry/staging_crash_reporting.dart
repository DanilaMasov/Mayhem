import 'dart:async';
import 'dart:developer' as developer;

import 'package:sentry_flutter/sentry_flutter.dart';

import '../../core/environment/runtime_environment.dart';

enum CrashReportingDisabledReason {
  nonStagingEnvironment,
  nonReleaseBuild,
  missingDsn,
  invalidDsn,
}

typedef StagingCrashInitializer =
    Future<void> Function(
      FlutterOptionsConfiguration optionsConfiguration, {
      AppRunner? appRunner,
    });

class StagingCrashReportingConfiguration {
  const StagingCrashReportingConfiguration._({
    required this.enabled,
    required this.release,
    this.dsn,
    this.disabledReason,
  });

  static const policyTag = 'staging_crash_v1';

  final bool enabled;
  final String? dsn;
  final String release;
  final CrashReportingDisabledReason? disabledReason;

  factory StagingCrashReportingConfiguration.resolve({
    required MayhemRuntimeEnvironment environment,
    required bool releaseMode,
    required String configuredDsn,
    required String appVersion,
  }) {
    final release =
        'com.danilamasov.mayhem.staging@${_safeVersion(appVersion)}';
    if (environment != MayhemRuntimeEnvironment.staging) {
      return StagingCrashReportingConfiguration._(
        enabled: false,
        release: release,
        disabledReason: CrashReportingDisabledReason.nonStagingEnvironment,
      );
    }
    if (!releaseMode) {
      return StagingCrashReportingConfiguration._(
        enabled: false,
        release: release,
        disabledReason: CrashReportingDisabledReason.nonReleaseBuild,
      );
    }
    final candidate = configuredDsn.trim();
    if (candidate.isEmpty) {
      return StagingCrashReportingConfiguration._(
        enabled: false,
        release: release,
        disabledReason: CrashReportingDisabledReason.missingDsn,
      );
    }
    if (!_isValidPublicDsn(candidate)) {
      return StagingCrashReportingConfiguration._(
        enabled: false,
        release: release,
        disabledReason: CrashReportingDisabledReason.invalidDsn,
      );
    }
    return StagingCrashReportingConfiguration._(
      enabled: true,
      dsn: candidate,
      release: release,
    );
  }

  void configure(SentryFlutterOptions options) {
    if (!enabled || dsn == null) {
      throw StateError('Disabled crash reporting cannot configure Sentry');
    }
    options
      ..dsn = dsn
      ..environment = MayhemRuntimeEnvironment.staging.name
      ..release = release
      ..sendDefaultPii = false
      ..sampleRate = 1.0
      ..maxBreadcrumbs = 0
      ..maxCacheItems = 10
      ..maxRequestBodySize = MaxRequestBodySize.never
      ..captureFailedRequests = false
      ..captureNativeFailedRequests = false
      ..enableScopeSync = false
      ..enableLogs = false
      ..enableMetrics = false
      ..tracesSampleRate = 0
      // Sentry marks profiling experimental; it is explicitly disabled here.
      // ignore: experimental_member_use
      ..profilesSampleRate = 0
      ..enableAutoPerformanceTracing = false
      ..enableFramesTracking = false
      ..enableNativeTraceSync = false
      ..enableAutoSessionTracking = false
      ..enableNativeCrashHandling = true
      ..enableAutoNativeBreadcrumbs = false
      ..enableAppLifecycleBreadcrumbs = false
      ..enableWindowMetricBreadcrumbs = false
      ..enableBrightnessChangeBreadcrumbs = false
      ..enableTextScaleChangeBreadcrumbs = false
      ..enableMemoryPressureBreadcrumbs = false
      ..enableUserInteractionBreadcrumbs = false
      ..enableUserInteractionTracing = false
      ..enableWatchdogTerminationTracking = false
      ..enableAppHangTracking = false
      ..anrEnabled = false
      ..enableTombstone = false
      ..attachScreenshot = false
      // The experimental view-hierarchy attachment must stay fail-closed.
      // ignore: experimental_member_use
      ..attachViewHierarchy = false
      ..reportViewHierarchyIdentifiers = false
      ..reportPackages = false
      ..reportSilentFlutterErrors = false
      ..beforeBreadcrumb = ((_, _) => null)
      ..beforeSendTransaction = ((_, _) => null)
      ..beforeSendFeedback = ((_, _) => null)
      ..beforeSend = ((event, hint) =>
          MayhemSentryEventScrubber.scrub(event, hint, release: release));
    options.replay
      ..sessionSampleRate = 0
      ..onErrorSampleRate = 0;
  }

  static bool _isValidPublicDsn(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isEmpty ||
        uri.userInfo.contains(':') ||
        uri.query.isNotEmpty ||
        uri.fragment.isNotEmpty ||
        uri.pathSegments.isEmpty) {
      return false;
    }
    return RegExp(r'^\d+$').hasMatch(uri.pathSegments.last);
  }

  static String _safeVersion(String value) {
    final candidate = value.trim();
    return RegExp(r'^\d+\.\d+\.\d+\+\d+$').hasMatch(candidate)
        ? candidate
        : '0.0.0+0';
  }
}

class StagingCrashReporting {
  const StagingCrashReporting._();

  static Future<void> run({
    required StagingCrashReportingConfiguration configuration,
    required Future<void> Function() appRunner,
    StagingCrashInitializer initialize = _initializeSentry,
  }) async {
    if (!configuration.enabled) {
      await appRunner();
      return;
    }
    var appStarted = false;
    try {
      await initialize(
        configuration.configure,
        appRunner: () async {
          appStarted = true;
          await appRunner();
        },
      );
    } catch (error, stackTrace) {
      developer.log(
        'Staging crash reporting unavailable; local runtime continues',
        name: 'mayhem.telemetry',
        error: error.runtimeType,
        stackTrace: stackTrace,
      );
      if (!appStarted) await appRunner();
    }
  }

  static Future<void> _initializeSentry(
    FlutterOptionsConfiguration optionsConfiguration, {
    AppRunner? appRunner,
  }) {
    return SentryFlutter.init(optionsConfiguration, appRunner: appRunner);
  }
}

class MayhemSentryEventScrubber {
  const MayhemSentryEventScrubber._();

  static SentryEvent scrub(
    SentryEvent event,
    Hint hint, {
    required String release,
  }) {
    hint.attachments.clear();
    hint
      ..screenshot = null
      ..viewHierarchy = null
      ..response = null;

    final originalContexts = event.contexts;
    event
      ..serverName = null
      ..release = release
      ..dist = _buildNumber(release)
      ..environment = MayhemRuntimeEnvironment.staging.name
      ..logger = 'mayhem.crash'
      ..message = event.exceptions?.isEmpty ?? true
          ? SentryMessage('Unhandled application error')
          : null
      ..transaction = null
      ..culprit = null
      ..modules = null
      ..tags = const {
        'privacy_policy': StagingCrashReportingConfiguration.policyTag,
      }
      // ignore: deprecated_member_use
      ..extra = null
      ..fingerprint = null
      ..breadcrumbs = null
      ..user = null
      ..request = null
      ..threads = null
      ..exceptions = event.exceptions
          ?.map(_sanitizeException)
          .toList(growable: false)
      ..contexts = Contexts(
        app: _sanitizeApp(originalContexts.app),
        operatingSystem: _sanitizeOs(originalContexts.operatingSystem),
        runtimes: originalContexts.runtimes
            .map(_sanitizeRuntime)
            .toList(growable: false),
      );
    return event;
  }

  static SentryException _sanitizeException(SentryException exception) {
    return SentryException(
      type: _boundedSymbol(exception.type, fallback: 'ApplicationError'),
      value: 'details redacted',
      module: _boundedSymbol(exception.module),
      stackTrace: _sanitizeStackTrace(exception.stackTrace),
      mechanism: _sanitizeMechanism(exception.mechanism),
      threadId: exception.threadId,
    );
  }

  static Mechanism? _sanitizeMechanism(Mechanism? mechanism) {
    if (mechanism == null) return null;
    return Mechanism(
      type: _boundedSymbol(mechanism.type, fallback: 'generic')!,
      handled: mechanism.handled,
      synthetic: mechanism.synthetic,
      isExceptionGroup: mechanism.isExceptionGroup,
      exceptionId: mechanism.exceptionId,
      parentId: mechanism.parentId,
    );
  }

  static SentryStackTrace? _sanitizeStackTrace(SentryStackTrace? stackTrace) {
    if (stackTrace == null) return null;
    return SentryStackTrace(
      frames: stackTrace.frames.map(_sanitizeFrame).toList(growable: false),
      lang: _boundedSymbol(stackTrace.lang),
      snapshot: stackTrace.snapshot,
    );
  }

  static SentryStackFrame _sanitizeFrame(SentryStackFrame frame) {
    return SentryStackFrame(
      fileName: _safeFileName(frame.fileName),
      function: _boundedSymbol(frame.function),
      module: _boundedSymbol(frame.module),
      lineNo: frame.lineNo,
      colNo: frame.colNo,
      inApp: frame.inApp,
      package: _boundedSymbol(frame.package),
      native: frame.native,
      platform: _boundedSymbol(frame.platform),
      imageAddr: _boundedSymbol(frame.imageAddr),
      symbolAddr: _boundedSymbol(frame.symbolAddr),
      instructionAddr: _boundedSymbol(frame.instructionAddr),
      rawFunction: _boundedSymbol(frame.rawFunction),
      symbol: _boundedSymbol(frame.symbol),
      stackStart: frame.stackStart,
    );
  }

  static SentryApp? _sanitizeApp(SentryApp? app) {
    if (app == null) return null;
    return SentryApp(
      name: 'MAYHEM STAGING',
      version: _boundedSymbol(app.version),
      identifier: 'com.danilamasov.mayhem.staging',
      build: _boundedSymbol(app.build),
      buildType: _boundedSymbol(app.buildType),
      inForeground: app.inForeground,
    );
  }

  static SentryOperatingSystem? _sanitizeOs(SentryOperatingSystem? os) {
    if (os == null) return null;
    return SentryOperatingSystem(
      name: _boundedSymbol(os.name),
      version: _boundedSymbol(os.version),
      build: _boundedSymbol(os.build),
    );
  }

  static SentryRuntime _sanitizeRuntime(SentryRuntime runtime) {
    return SentryRuntime(
      name: _boundedSymbol(runtime.name),
      version: _boundedSymbol(runtime.version),
      compiler: _boundedSymbol(runtime.compiler),
      build: _boundedSymbol(runtime.build),
    );
  }

  static String? _safeFileName(String? value) {
    if (value == null || value.isEmpty) return null;
    final normalized = value.replaceAll('\\', '/');
    if (normalized.startsWith('package:')) {
      return normalized.length <= 240
          ? normalized
          : normalized.substring(0, 240);
    }
    final segments = normalized
        .split('/')
        .where((part) => part.isNotEmpty)
        .toList();
    if (segments.isEmpty) return null;
    final safe = segments
        .skip(segments.length > 3 ? segments.length - 3 : 0)
        .join('/');
    return safe.length <= 240 ? safe : safe.substring(safe.length - 240);
  }

  static String? _boundedSymbol(String? value, {String? fallback}) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) return fallback;
    return normalized.length <= 160 ? normalized : normalized.substring(0, 160);
  }

  static String? _buildNumber(String release) {
    final separator = release.lastIndexOf('+');
    return separator < 0 ? null : release.substring(separator + 1);
  }
}
