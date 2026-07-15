import '../sync/event_envelope_v2.dart';
import 'projection_checkpoint.dart';

typedef ProjectionReducer<T> = T Function(T current, EventEnvelopeV2 event);

class ProjectionReplayResult<T> {
  ProjectionReplayResult({
    required this.snapshot,
    required this.lastAppliedSequence,
    required List<QuarantinedEvent> quarantined,
  }) : quarantined = List.unmodifiable(quarantined);

  final T snapshot;
  final int lastAppliedSequence;
  final List<QuarantinedEvent> quarantined;
}

class ProjectionReplayer<T> {
  const ProjectionReplayer({required this.reducer});

  final ProjectionReducer<T> reducer;

  ProjectionReplayResult<T> replay({
    required T initial,
    required String installationId,
    required Iterable<Map<String, Object?>> rows,
    required DateTime quarantinedAt,
    ProjectionCheckpoint<T>? checkpoint,
  }) {
    final orderedRows = rows.toList(growable: false)
      ..sort((left, right) {
        final leftSequence = (left['client_sequence'] as num?)?.toInt() ?? -1;
        final rightSequence = (right['client_sequence'] as num?)?.toInt() ?? -1;
        return leftSequence.compareTo(rightSequence);
      });
    var snapshot = checkpoint?.snapshot ?? initial;
    var lastSequence = checkpoint?.lastAppliedInstallationId == installationId
        ? checkpoint?.lastAppliedSequence ?? 0
        : 0;
    final quarantined = <QuarantinedEvent>[];

    for (final row in orderedRows) {
      try {
        final event = EventEnvelopeV2.fromDatabaseMap(row);
        if (event.installationId != installationId) {
          throw const FormatException('Unexpected installation');
        }
        if (event.clientSequence <= lastSequence) continue;
        snapshot = reducer(snapshot, event);
        lastSequence = event.clientSequence;
      } catch (error) {
        quarantined.add(
          QuarantinedEvent(
            rawRow: Map.unmodifiable(row),
            reason: 'projection_event_failed:${error.runtimeType}',
            quarantinedAt: quarantinedAt.toUtc(),
          ),
        );
      }
    }
    return ProjectionReplayResult(
      snapshot: snapshot,
      lastAppliedSequence: lastSequence,
      quarantined: quarantined,
    );
  }
}
