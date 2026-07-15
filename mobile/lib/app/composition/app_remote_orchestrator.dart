class AppCancellationSignal {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;

  void throwIfCancelled() {
    if (_cancelled) throw const AppOperationCancelled();
  }
}

class AppOperationCancelled implements Exception {
  const AppOperationCancelled();
}

abstract interface class AppRemoteOrchestrator {
  bool get enabled;

  String? get disabledReason;

  Future<void> bootstrap(AppCancellationSignal cancellation);

  Future<void> onForeground(AppCancellationSignal cancellation);

  Future<void> close();
}

class DisabledAppRemoteOrchestrator implements AppRemoteOrchestrator {
  const DisabledAppRemoteOrchestrator(this.reason);

  final String reason;

  @override
  bool get enabled => false;

  @override
  String get disabledReason => reason;

  @override
  Future<void> bootstrap(AppCancellationSignal cancellation) async {}

  @override
  Future<void> onForeground(AppCancellationSignal cancellation) async {}

  @override
  Future<void> close() async {}
}
