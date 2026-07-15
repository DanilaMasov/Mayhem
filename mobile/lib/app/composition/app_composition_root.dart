import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';

import '../../application/today_controller.dart';
import '../../core/auth/secure_session_store.dart';
import '../../core/feature_flags/feature_flag_runtime.dart';
import '../mayhem_app.dart';
import '../vnext/vnext_runtime.dart';
import 'app_remote_orchestrator.dart';
import 'app_telemetry.dart';

enum AppRemoteRuntimeStatus {
  idle,
  disabled,
  bootstrapping,
  ready,
  degraded,
  disposed,
}

class AppCompositionRoot extends ChangeNotifier with WidgetsBindingObserver {
  AppCompositionRoot({
    required this.legacyController,
    required this.featureFlags,
    required this.vnextRuntime,
    required this.secureSessions,
    required this.remote,
    required this.closeLocalStore,
    this.telemetry = const NoOpAppTelemetry(),
    WidgetsBinding? binding,
  }) : _binding = binding ?? WidgetsBinding.instance;

  final TodayController legacyController;
  final FeatureFlagRuntime featureFlags;
  final VNextRuntime? vnextRuntime;
  final SecureSessionStore secureSessions;
  final AppRemoteOrchestrator remote;
  final Future<void> Function() closeLocalStore;
  final AppTelemetry telemetry;
  final WidgetsBinding _binding;
  final AppCancellationSignal _cancellation = AppCancellationSignal();

  AppRemoteRuntimeStatus _remoteStatus = AppRemoteRuntimeStatus.idle;
  String? _remoteErrorCode;
  Future<AppRemoteRuntimeStatus>? _bootstrap;
  bool _observingLifecycle = false;
  bool _shutdown = false;

  AppRemoteRuntimeStatus get remoteStatus => _remoteStatus;

  String? get remoteErrorCode => _remoteErrorCode;

  Widget buildApp() {
    if (_shutdown) throw StateError('App composition is already disposed');
    return MayhemApp(
      controller: legacyController,
      featureFlags: featureFlags,
      vnextRuntime: vnextRuntime,
    );
  }

  Future<AppRemoteRuntimeStatus> startRemoteBootstrap() {
    if (_shutdown) {
      return Future.value(AppRemoteRuntimeStatus.disposed);
    }
    final active = _bootstrap;
    if (active != null) return active;
    if (!remote.enabled) {
      _setRemoteState(
        AppRemoteRuntimeStatus.disabled,
        errorCode: remote.disabledReason ?? 'remote_runtime_disabled',
      );
      telemetry.record(
        'remote_runtime_disabled',
        fields: {'reason': _remoteErrorCode},
      );
      final disabled = Future.value(_remoteStatus);
      _bootstrap = disabled;
      return disabled;
    }
    if (!_observingLifecycle) {
      _binding.addObserver(this);
      _observingLifecycle = true;
    }
    _setRemoteState(AppRemoteRuntimeStatus.bootstrapping);
    final run = _runBootstrap();
    _bootstrap = run;
    return run;
  }

  Future<AppRemoteRuntimeStatus> _runBootstrap() async {
    try {
      await remote.bootstrap(_cancellation);
      if (_shutdown || _cancellation.isCancelled) {
        return AppRemoteRuntimeStatus.disposed;
      }
      _setRemoteState(AppRemoteRuntimeStatus.ready);
      telemetry.record('remote_bootstrap_ready');
    } on AppOperationCancelled {
      if (_shutdown) return AppRemoteRuntimeStatus.disposed;
      _setRemoteState(
        AppRemoteRuntimeStatus.degraded,
        errorCode: 'remote_bootstrap_cancelled',
      );
    } catch (error, stackTrace) {
      if (_shutdown || _cancellation.isCancelled) {
        return AppRemoteRuntimeStatus.disposed;
      }
      final code = 'remote_bootstrap_${error.runtimeType}';
      _setRemoteState(AppRemoteRuntimeStatus.degraded, errorCode: code);
      telemetry.record('remote_bootstrap_failed', fields: {'code': code});
      developer.log(
        'Remote bootstrap failed; local runtime remains available',
        name: 'mayhem.composition',
        error: error.runtimeType,
        stackTrace: stackTrace,
      );
    }
    return _remoteStatus;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || _shutdown || !remote.enabled) {
      return;
    }
    unawaited(_runForeground());
  }

  Future<void> _runForeground() async {
    try {
      await remote.onForeground(_cancellation);
    } on AppOperationCancelled {
      return;
    } catch (error, stackTrace) {
      if (_shutdown || _cancellation.isCancelled) return;
      final code = 'remote_foreground_${error.runtimeType}';
      _setRemoteState(AppRemoteRuntimeStatus.degraded, errorCode: code);
      telemetry.record('remote_foreground_failed', fields: {'code': code});
      developer.log(
        'Foreground remote refresh failed; local runtime remains available',
        name: 'mayhem.composition',
        error: error.runtimeType,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> shutdown() async {
    if (_shutdown) return;
    _shutdown = true;
    _cancellation.cancel();
    if (_observingLifecycle) {
      _binding.removeObserver(this);
      _observingLifecycle = false;
    }
    try {
      await remote.close();
    } catch (error, stackTrace) {
      telemetry.record(
        'remote_close_failed',
        fields: {'code': error.runtimeType.toString()},
      );
      developer.log(
        'Remote runtime close failed; local disposal continues',
        name: 'mayhem.composition',
        error: error.runtimeType,
        stackTrace: stackTrace,
      );
    }
    try {
      vnextRuntime?.dispose();
      legacyController.dispose();
      featureFlags.dispose();
      await closeLocalStore();
    } finally {
      _remoteStatus = AppRemoteRuntimeStatus.disposed;
      super.dispose();
    }
  }

  void _setRemoteState(AppRemoteRuntimeStatus status, {String? errorCode}) {
    if (_remoteStatus == status && _remoteErrorCode == errorCode) return;
    _remoteStatus = status;
    _remoteErrorCode = errorCode;
    notifyListeners();
  }
}
