class SeasonParticipationState {
  SeasonParticipationState({
    required this.seasonId,
    required this.seasonRevision,
    required this.joinedAt,
    required Set<int> completedDays,
    this.bossParticipatedAt,
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

  SeasonParticipationState copyWith({
    Set<int>? completedDays,
    DateTime? bossParticipatedAt,
  }) => SeasonParticipationState(
    seasonId: seasonId,
    seasonRevision: seasonRevision,
    joinedAt: joinedAt,
    completedDays: completedDays ?? this.completedDays,
    bossParticipatedAt: bossParticipatedAt ?? this.bossParticipatedAt,
  );
}
