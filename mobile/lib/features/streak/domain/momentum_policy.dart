import 'momentum_state.dart';

class MomentumUpdate {
  const MomentumUpdate({
    required this.state,
    required this.shieldConsumed,
    required this.shieldGranted,
    required this.reset,
  });

  final MomentumState state;
  final bool shieldConsumed;
  final bool shieldGranted;
  final bool reset;
}

class MomentumPolicy {
  const MomentumPolicy();

  static const milestones = [3, 7, 14, 30, 50, 100];
  static const minimumDaySeparation = Duration(hours: 20);
  static const revision = 'momentum_policy_dev_v1';

  MomentumUpdate earnDay(
    MomentumState current, {
    required String localDate,
    required DateTime earnedAtUtc,
    required String timezoneId,
  }) {
    final today = _parseDate(localDate);
    final earnedAt = earnedAtUtc.toUtc();
    if (timezoneId.trim().isEmpty) {
      throw const FormatException('Momentum timezone is required');
    }
    final lastKey = current.lastEarnedLocalDate;
    if (lastKey == localDate) {
      return MomentumUpdate(
        state: _copy(current, earnedToday: true),
        shieldConsumed: false,
        shieldGranted: false,
        reset: false,
      );
    }

    final previousEarnedAt = current.lastEarnedAtUtc;
    if (lastKey != null &&
        previousEarnedAt != null &&
        earnedAt.difference(previousEarnedAt.toUtc()) < minimumDaySeparation) {
      return MomentumUpdate(
        state: MomentumState(
          currentDays: current.currentDays,
          longestDays: current.longestDays,
          earnedToday: false,
          shieldsAvailable: current.shieldsAvailable,
          lastEarnedLocalDate: current.lastEarnedLocalDate,
          lastEarnedAtUtc: current.lastEarnedAtUtc,
          lastEarnedTimezoneId: current.lastEarnedTimezoneId,
          protectedLocalDates: current.protectedLocalDates,
          nextMilestone: current.nextMilestone,
          pendingLocalDate: localDate,
          pendingEarnedAtUtc: earnedAt,
          pendingTimezoneId: timezoneId,
          policyRevision: revision,
        ),
        shieldConsumed: false,
        shieldGranted: false,
        reset: false,
      );
    }

    var nextDays = 1;
    var shields = current.shieldsAvailable;
    var shieldConsumed = false;
    var reset = false;
    final protectedDates = {...current.protectedLocalDates};
    if (lastKey != null) {
      final last = _parseDate(lastKey);
      final gap = today.difference(last).inDays;
      if (gap <= 0) {
        return MomentumUpdate(
          state: _copy(current, earnedToday: false),
          shieldConsumed: false,
          shieldGranted: false,
          reset: false,
        );
      }
      if (gap == 1) {
        nextDays = current.currentDays + 1;
      } else if (gap == 2 && shields > 0) {
        shields -= 1;
        shieldConsumed = true;
        nextDays = current.currentDays + 1;
        protectedDates.add(_dateKey(last.add(const Duration(days: 1))));
      } else {
        reset = current.currentDays > 0;
      }
    }

    var shieldGranted = false;
    if (nextDays % 7 == 0 && shields < 2) {
      shields += 1;
      shieldGranted = true;
    }
    final longest = nextDays > current.longestDays
        ? nextDays
        : current.longestDays;
    return MomentumUpdate(
      state: MomentumState(
        currentDays: nextDays,
        longestDays: longest,
        earnedToday: true,
        shieldsAvailable: shields,
        lastEarnedLocalDate: localDate,
        lastEarnedAtUtc: earnedAt,
        lastEarnedTimezoneId: timezoneId,
        protectedLocalDates: protectedDates,
        nextMilestone: _nextMilestone(nextDays),
        policyRevision: revision,
      ),
      shieldConsumed: shieldConsumed,
      shieldGranted: shieldGranted,
      reset: reset,
    );
  }

  MomentumState refreshForDate(MomentumState state, String localDate) {
    _parseDate(localDate);
    return _copy(state, earnedToday: state.lastEarnedLocalDate == localDate);
  }

  MomentumState _copy(MomentumState state, {required bool earnedToday}) {
    return MomentumState(
      currentDays: state.currentDays,
      longestDays: state.longestDays,
      earnedToday: earnedToday,
      shieldsAvailable: state.shieldsAvailable,
      lastEarnedLocalDate: state.lastEarnedLocalDate,
      lastEarnedAtUtc: state.lastEarnedAtUtc,
      lastEarnedTimezoneId: state.lastEarnedTimezoneId,
      protectedLocalDates: state.protectedLocalDates,
      nextMilestone: state.nextMilestone,
      pendingLocalDate: state.pendingLocalDate,
      pendingEarnedAtUtc: state.pendingEarnedAtUtc,
      pendingTimezoneId: state.pendingTimezoneId,
      policyRevision: state.policyRevision,
    );
  }

  int _nextMilestone(int current) {
    return milestones.firstWhere(
      (milestone) => milestone > current,
      orElse: () => ((current ~/ 50) + 1) * 50,
    );
  }

  DateTime _parseDate(String value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      throw const FormatException('Momentum date must use YYYY-MM-DD');
    }
    final parsed = DateTime.parse('${value}T00:00:00Z');
    if (_dateKey(parsed) != value) {
      throw const FormatException('Momentum date is invalid');
    }
    return parsed;
  }

  String _dateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
