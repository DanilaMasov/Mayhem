abstract interface class AppTelemetry {
  void record(String event, {Map<String, Object?> fields = const {}});
}

class NoOpAppTelemetry implements AppTelemetry {
  const NoOpAppTelemetry();

  @override
  void record(String event, {Map<String, Object?> fields = const {}}) {}
}
