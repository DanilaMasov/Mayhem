class OwnedFounderArtifact {
  OwnedFounderArtifact({
    required this.artifactId,
    required this.seasonId,
    required this.seasonRevision,
    required this.bossEventId,
    required this.unlockedAt,
  }) {
    if (artifactId.trim().isEmpty ||
        seasonId.trim().isEmpty ||
        seasonRevision < 1 ||
        bossEventId.trim().isEmpty) {
      throw const FormatException('Owned artifact identity is invalid');
    }
  }

  final String artifactId;
  final String seasonId;
  final int seasonRevision;
  final String bossEventId;
  final DateTime unlockedAt;
}

abstract interface class ArtifactOwnershipRepository {
  Future<List<OwnedFounderArtifact>> loadOwnedArtifacts();
}
