class SeasonParticipationState {
  SeasonParticipationState({
    required this.seasonId,
    required this.seasonRevision,
    required this.joinedAt,
    required Set<int> completedDays,
    this.bossParticipatedAt,
    this.serverConfirmed = false,
  }) : completedDays = Set.unmodifiable(completedDays) {
    if (seasonId.trim().isEmpty ||
        seasonRevision < 1 ||
        completedDays.any((day) => day < 1 || day > 7) ||
        bossParticipatedAt?.isBefore(joinedAt) == true) {
      throw const FormatException('Season participation state is invalid');
    }
  }

  final String seasonId;
  final int seasonRevision;
  final DateTime joinedAt;
  final Set<int> completedDays;
  final DateTime? bossParticipatedAt;
  final bool serverConfirmed;

  SeasonParticipationState copyWith({
    Set<int>? completedDays,
    DateTime? bossParticipatedAt,
    bool clearBossParticipatedAt = false,
    bool? serverConfirmed,
  }) => SeasonParticipationState(
    seasonId: seasonId,
    seasonRevision: seasonRevision,
    joinedAt: joinedAt,
    completedDays: completedDays ?? this.completedDays,
    bossParticipatedAt: clearBossParticipatedAt
        ? null
        : bossParticipatedAt ?? this.bossParticipatedAt,
    serverConfirmed: serverConfirmed ?? this.serverConfirmed,
  );
}
