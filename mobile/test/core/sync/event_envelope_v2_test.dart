import 'package:flutter_test/flutter_test.dart';
import 'package:mayhem_mobile/core/sync/event_envelope_v2.dart';

void main() {
  EventEnvelopeV2 event({
    Map<String, Object?> payload = const {'felt': 'about_as_expected'},
    String? contentId = 'challenge_start_first_001',
    int? contentRevision = 3,
  }) => EventEnvelopeV2(
    eventId: 'event-1',
    eventType: CanonicalEventTypeV2.challengeCompleted,
    localUserId: 'local-1',
    remoteUserId: null,
    installationId: 'install-1',
    clientSequence: 42,
    occurredAtUtc: DateTime.parse('2026-07-13T12:00:00Z'),
    timezoneId: 'Europe/Moscow',
    timezoneOffsetMinutes: 180,
    assignmentId: 'assignment-1',
    attemptId: 'attempt-1',
    contentId: contentId,
    contentRevision: contentRevision,
    payload: payload,
  );

  test('v2 envelope preserves immutable content identity and ordering', () {
    final value = event();
    final json = value.toSyncJson();
    final row = value.toDatabaseMap();

    expect(json['schemaVersion'], 2);
    expect(json['contentRevision'], 3);
    expect(json['clientSequence'], 42);
    expect(row['sync_status'], 'pending');
    expect(row['attempt_count'], 0);
  });

  test('v2 envelope rejects private note text at any payload depth', () {
    expect(
      () => event(
        payload: const {
          'reflection': {'privateNote': 'must remain local'},
        },
      ),
      throwsFormatException,
    );
    expect(
      () => event(
        payload: const {
          'items': [
            {'PRIVATE_NOTE_BODY': 'must also remain local'},
          ],
        },
      ),
      throwsFormatException,
    );
    expect(
      () => event(contentId: null, contentRevision: 3),
      throwsFormatException,
    );
  });
}
