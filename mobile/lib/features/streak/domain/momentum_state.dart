class MomentumState {
  MomentumState({
    required this.currentDays,
    required this.longestDays,
    required this.earnedToday,
    required this.shieldsAvailable,
    required Set<String> protectedLocalDates,
    required this.nextMilestone,
    this.lastEarnedLocalDate,
    this.lastEarnedAtUtc,
    this.lastEarnedTimezoneId,
    this.pendingLocalDate,
    this.pendingEarnedAtUtc,
    this.pendingTimezoneId,
    this.policyRevision = 'momentum_policy_dev_v1',
  }) : protectedLocalDates = Set.unmodifiable(protectedLocalDates) {
    if (currentDays < 0 || longestDays < currentDays) {
      throw const FormatException('Momentum counters are invalid');
    }
    if (shieldsAvailable < 0 || shieldsAvailable > 2) {
      throw const FormatException('Momentum shields are invalid');
    }
    if (policyRevision.trim().isEmpty) {
      throw const FormatException('Momentum policy revision is required');
    }
    final hasPending =
        pendingLocalDate != null ||
        pendingEarnedAtUtc != null ||
        pendingTimezoneId != null;
    if (hasPending &&
        (pendingLocalDate == null ||
            pendingEarnedAtUtc == null ||
            pendingTimezoneId?.trim().isEmpty != false)) {
      throw const FormatException('Momentum pending record is incomplete');
    }
    if (lastEarnedAtUtc != null &&
        lastEarnedTimezoneId?.trim().isEmpty != false) {
      throw const FormatException('Momentum earned timezone is required');
    }
  }

  factory MomentumState.empty() => MomentumState(
    currentDays: 0,
    longestDays: 0,
    earnedToday: false,
    shieldsAvailable: 0,
    protectedLocalDates: const {},
    nextMilestone: 3,
  );

  final int currentDays;
  final int longestDays;
  final bool earnedToday;
  final int shieldsAvailable;
  final String? lastEarnedLocalDate;
  final DateTime? lastEarnedAtUtc;
  final String? lastEarnedTimezoneId;
  final Set<String> protectedLocalDates;
  final int nextMilestone;
  final String? pendingLocalDate;
  final DateTime? pendingEarnedAtUtc;
  final String? pendingTimezoneId;
  final String policyRevision;

  bool get pendingTimezoneReview => pendingLocalDate != null;
}
