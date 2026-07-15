abstract interface class MayhemClock {
  DateTime utcNow();

  DateTime localNow();

  String get timezoneId;

  Duration monotonicNow();
}

class SystemMayhemClock implements MayhemClock {
  SystemMayhemClock({required String Function() timezoneIdProvider})
    : this._(timezoneIdProvider, Stopwatch()..start());

  SystemMayhemClock._(this._timezoneIdProvider, this._stopwatch);

  final String Function() _timezoneIdProvider;
  final Stopwatch _stopwatch;

  @override
  DateTime utcNow() => DateTime.now().toUtc();

  @override
  DateTime localNow() => DateTime.now();

  @override
  String get timezoneId {
    final value = _timezoneIdProvider().trim();
    if (value.isEmpty) {
      throw StateError('Timezone ID is not available');
    }
    return value;
  }

  @override
  Duration monotonicNow() => _stopwatch.elapsed;
}

class FixedMayhemClock implements MayhemClock {
  FixedMayhemClock({required DateTime now, required this.timezoneId})
    : _utcNow = now.toUtc(),
      _localNow = now;

  DateTime _utcNow;
  DateTime _localNow;
  Duration _monotonic = Duration.zero;

  @override
  final String timezoneId;

  @override
  DateTime utcNow() => _utcNow;

  @override
  DateTime localNow() => _localNow;

  @override
  Duration monotonicNow() => _monotonic;

  void advance(Duration duration) {
    if (duration.isNegative) {
      throw ArgumentError.value(duration, 'duration', 'Must not be negative');
    }
    _utcNow = _utcNow.add(duration);
    _localNow = _localNow.add(duration);
    _monotonic += duration;
  }
}
