import 'package:flutter_test/flutter_test.dart';
import 'package:mayhem_mobile/features/streak/domain/momentum_policy.dart';
import 'package:mayhem_mobile/features/streak/domain/momentum_state.dart';
import 'package:mayhem_mobile/infrastructure/sqlite/sqlite_vnext_mappers.dart';

void main() {
  const policy = MomentumPolicy();

  test('same local date earns Momentum exactly once', () {
    final first = policy.earnDay(
      MomentumState.empty(),
      localDate: '2026-07-13',
      earnedAtUtc: DateTime.utc(2026, 7, 13, 9),
      timezoneId: 'Europe/Moscow',
    );
    final duplicate = policy.earnDay(
      first.state,
      localDate: '2026-07-13',
      earnedAtUtc: DateTime.utc(2026, 7, 13, 10),
      timezoneId: 'Europe/Moscow',
    );

    expect(first.state.currentDays, 1);
    expect(duplicate.state.currentDays, 1);
    expect(duplicate.shieldGranted, isFalse);
  });

  test('one missed day consumes a shield without shaming reset', () {
    final state = MomentumState(
      currentDays: 8,
      longestDays: 8,
      earnedToday: false,
      shieldsAvailable: 1,
      lastEarnedLocalDate: '2026-07-11',
      protectedLocalDates: const {},
      nextMilestone: 14,
    );

    final update = policy.earnDay(
      state,
      localDate: '2026-07-13',
      earnedAtUtc: DateTime.utc(2026, 7, 13, 9),
      timezoneId: 'Europe/Moscow',
    );

    expect(update.state.currentDays, 9);
    expect(update.state.shieldsAvailable, 0);
    expect(update.state.protectedLocalDates, contains('2026-07-12'));
    expect(update.shieldConsumed, isTrue);
    expect(update.reset, isFalse);
  });

  test('long gap resets current Momentum but preserves longest', () {
    final state = MomentumState(
      currentDays: 18,
      longestDays: 18,
      earnedToday: false,
      shieldsAvailable: 0,
      lastEarnedLocalDate: '2026-07-01',
      protectedLocalDates: const {},
      nextMilestone: 30,
    );

    final update = policy.earnDay(
      state,
      localDate: '2026-07-13',
      earnedAtUtc: DateTime.utc(2026, 7, 13, 9),
      timezoneId: 'Europe/Moscow',
    );

    expect(update.state.currentDays, 1);
    expect(update.state.longestDays, 18);
    expect(update.reset, isTrue);
  });

  test('different local date inside twenty hours remains pending', () {
    final state = MomentumState(
      currentDays: 3,
      longestDays: 3,
      earnedToday: false,
      shieldsAvailable: 0,
      lastEarnedLocalDate: '2026-07-13',
      lastEarnedAtUtc: DateTime.utc(2026, 7, 13, 20),
      lastEarnedTimezoneId: 'Europe/Moscow',
      protectedLocalDates: const {},
      nextMilestone: 7,
    );

    final update = policy.earnDay(
      state,
      localDate: '2026-07-14',
      earnedAtUtc: DateTime.utc(2026, 7, 14, 15, 59),
      timezoneId: 'Asia/Tokyo',
    );

    expect(update.state.currentDays, 3);
    expect(update.state.lastEarnedLocalDate, '2026-07-13');
    expect(update.state.pendingTimezoneReview, isTrue);
    expect(update.state.pendingLocalDate, '2026-07-14');
  });

  test('different local date at twenty hours earns normally', () {
    final state = MomentumState(
      currentDays: 3,
      longestDays: 3,
      earnedToday: false,
      shieldsAvailable: 0,
      lastEarnedLocalDate: '2026-07-13',
      lastEarnedAtUtc: DateTime.utc(2026, 7, 13, 20),
      lastEarnedTimezoneId: 'Europe/Moscow',
      protectedLocalDates: const {},
      nextMilestone: 7,
    );

    final update = policy.earnDay(
      state,
      localDate: '2026-07-14',
      earnedAtUtc: DateTime.utc(2026, 7, 14, 16),
      timezoneId: 'Asia/Tokyo',
    );

    expect(update.state.currentDays, 4);
    expect(update.state.pendingTimezoneReview, isFalse);
    expect(update.state.lastEarnedTimezoneId, 'Asia/Tokyo');
  });

  test('legacy Momentum JSON restores with safe v1.1 defaults', () {
    final state = SqliteProjectionMapper.momentumFromJson(const {
      'currentDays': 2,
      'longestDays': 4,
      'earnedToday': true,
      'shieldsAvailable': 0,
      'lastEarnedLocalDate': '2026-07-13',
      'protectedLocalDates': <String>[],
      'nextMilestone': 3,
    });

    expect(state.currentDays, 2);
    expect(state.lastEarnedAtUtc, isNull);
    expect(state.pendingTimezoneReview, isFalse);
    expect(state.policyRevision, 'momentum_policy_dev_v1');
  });
}
