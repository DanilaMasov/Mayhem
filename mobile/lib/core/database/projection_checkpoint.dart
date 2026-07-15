class ProjectionCheckpoint<T> {
  const ProjectionCheckpoint({
    required this.projectionName,
    required this.snapshot,
    required this.schemaVersion,
    required this.updatedAt,
    this.lastAppliedInstallationId,
    this.lastAppliedSequence,
  });

  final String projectionName;
  final T snapshot;
  final String? lastAppliedInstallationId;
  final int? lastAppliedSequence;
  final DateTime updatedAt;
  final int schemaVersion;
}

class QuarantinedEvent {
  const QuarantinedEvent({
    required this.rawRow,
    required this.reason,
    required this.quarantinedAt,
  });

  final Map<String, Object?> rawRow;
  final String reason;
  final DateTime quarantinedAt;
}

abstract interface class ProjectionCheckpointRepository<T> {
  Future<ProjectionCheckpoint<T>?> load(String projectionName);

  Future<void> save(ProjectionCheckpoint<T> checkpoint);
}
