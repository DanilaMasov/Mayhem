import 'package:flutter/foundation.dart';

enum AppRemoteRuntimeStatus {
  idle,
  disabled,
  bootstrapping,
  ready,
  degraded,
  disposed,
}

abstract interface class RemoteRuntimeDiagnostics implements Listenable {
  bool get remoteConfigured;

  AppRemoteRuntimeStatus get remoteStatus;

  String? get remoteErrorCode;
}
