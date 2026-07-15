import 'package:flutter_test/flutter_test.dart';
import 'package:mayhem_mobile/core/clock/mayhem_clock.dart';

void main() {
  test('fixed clock advances wall and monotonic time deterministically', () {
    final clock = FixedMayhemClock(
      now: DateTime.parse('2026-07-13T12:00:00+03:00'),
      timezoneId: 'Europe/Moscow',
    );

    clock.advance(const Duration(minutes: 7));

    expect(clock.utcNow(), DateTime.parse('2026-07-13T09:07:00Z'));
    expect(clock.localNow().minute, 7);
    expect(clock.monotonicNow(), const Duration(minutes: 7));
    expect(clock.timezoneId, 'Europe/Moscow');
    expect(
      () => clock.advance(const Duration(seconds: -1)),
      throwsArgumentError,
    );
  });
}
