import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mayhem_mobile/core/database/projection_checkpoint.dart';
import 'package:mayhem_mobile/core/database/projection_replayer.dart';
import 'package:mayhem_mobile/core/sync/event_envelope_v2.dart';

void main() {
  Map<String, Object?> row(int sequence, int delta) => {
    'event_id': 'event-$sequence',
    'local_user_id': 'local-1',
    'installation_id': 'install-1',
    'client_sequence': sequence,
    'schema_version': 2,
    'event_type': CanonicalEventTypeV2.challengeCompleted.wireName,
    'assignment_id': 'assignment-$sequence',
    'attempt_id': 'attempt-$sequence',
    'content_id': 'challenge-1',
    'content_revision': 1,
    'occurred_at_utc': '2026-07-13T12:00:00.000Z',
    'timezone_id': 'Europe/Moscow',
    'timezone_offset_minutes': 180,
    'payload_json': jsonEncode({'delta': delta}),
  };

  test('checkpoint replays only tail and quarantines one broken event', () {
    final checkpoint = ProjectionCheckpoint<int>(
      projectionName: 'counter',
      snapshot: 5,
      lastAppliedInstallationId: 'install-1',
      lastAppliedSequence: 1,
      updatedAt: DateTime.parse('2026-07-13T12:00:00Z'),
      schemaVersion: 1,
    );
    final broken = row(2, 20)..['payload_json'] = '{broken';
    final replayer = ProjectionReplayer<int>(
      reducer: (current, event) => current + (event.payload['delta'] as int),
    );

    final result = replayer.replay(
      initial: 0,
      installationId: 'install-1',
      rows: [row(3, 7), row(1, 100), broken],
      quarantinedAt: DateTime.parse('2026-07-13T13:00:00Z'),
      checkpoint: checkpoint,
    );

    expect(result.snapshot, 12);
    expect(result.lastAppliedSequence, 3);
    expect(result.quarantined, hasLength(1));
    expect(result.quarantined.single.reason, contains('FormatException'));
  });
}
