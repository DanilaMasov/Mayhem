import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mayhem_mobile/features/feed/application/feed_interaction_coordinator.dart';
import 'package:mayhem_mobile/features/feed/domain/feed_models.dart';
import 'package:mayhem_mobile/infrastructure/sqlite/sqlite_vnext_store.dart';

import '../../support/memory_vnext_database.dart';

void main() {
  final at = DateTime.parse('2026-07-13T09:00:00Z');

  test('impression, open and skip are idempotent canonical events', () async {
    final database = MemoryVNextDatabase(seed: _seed(at));
    final store = SqliteVNextStore(database, clock: () => at);
    var nextId = 0;
    final coordinator = FeedInteractionCoordinator(
      repository: store.feed,
      idGenerator: () => 'interaction-${++nextId}',
    );
    final assignment = _assignment(at);

    expect(
      await coordinator.impress(
        assignment: assignment,
        atUtc: at,
        timezoneId: 'Europe/Moscow',
        timezoneOffsetMinutes: 180,
      ),
      isTrue,
    );
    expect(
      await coordinator.impress(
        assignment: assignment,
        atUtc: at.add(const Duration(seconds: 1)),
        timezoneId: 'Europe/Moscow',
        timezoneOffsetMinutes: 180,
      ),
      isFalse,
    );
    expect(
      await coordinator.open(
        assignment: assignment,
        atUtc: at.add(const Duration(seconds: 2)),
        timezoneId: 'Europe/Moscow',
        timezoneOffsetMinutes: 180,
      ),
      isTrue,
    );
    expect(
      await coordinator.skip(
        assignment: assignment,
        reason: FeedSkipReason.tooIntense,
        atUtc: at.add(const Duration(seconds: 3)),
        timezoneId: 'Europe/Moscow',
        timezoneOffsetMinutes: 180,
      ),
      isTrue,
    );

    final row = database.executor.rows('feed_assignments').single;
    expect(row['impressed_at'], at.toIso8601String());
    expect(
      row['opened_at'],
      at.add(const Duration(seconds: 2)).toIso8601String(),
    );
    expect(
      row['skipped_at'],
      at.add(const Duration(seconds: 3)).toIso8601String(),
    );
    expect(
      (jsonDecode(row['metadata_json'] as String) as Map)['_skipReason'],
      FeedSkipReason.tooIntense.name,
    );
    expect(
      database.executor
          .rows('event_log_v2')
          .map((event) => event['event_type']),
      ['feed_item_impressed', 'feed_item_opened', 'feed_item_skipped'],
    );
  });

  test('event failure rolls back impression timestamp', () async {
    final database = MemoryVNextDatabase(seed: _seed(at));
    final store = SqliteVNextStore(database, clock: () => at);
    final coordinator = FeedInteractionCoordinator(
      repository: store.feed,
      idGenerator: () => 'interaction-failure',
    );
    database.executor.failNextInsertInto = 'event_log_v2';

    await expectLater(
      coordinator.impress(
        assignment: _assignment(at),
        atUtc: at,
        timezoneId: 'Europe/Moscow',
        timezoneOffsetMinutes: 180,
      ),
      throwsStateError,
    );

    expect(
      database.executor.rows('feed_assignments').single['impressed_at'],
      isNull,
    );
    expect(database.executor.rows('event_log_v2'), isEmpty);
  });

  test('scenario choice is private, atomic and idempotent', () async {
    final database = MemoryVNextDatabase(seed: _seed(at));
    final store = SqliteVNextStore(database, clock: () => at);
    var nextId = 0;
    final coordinator = FeedInteractionCoordinator(
      repository: store.feed,
      idGenerator: () => 'scenario-${++nextId}',
    );

    expect(
      await coordinator.answerScenario(
        assignment: _assignment(at),
        choiceIndex: 1,
        atUtc: at,
        timezoneId: 'Europe/Moscow',
        timezoneOffsetMinutes: 180,
      ),
      isTrue,
    );
    expect(
      await coordinator.answerScenario(
        assignment: _assignment(at),
        choiceIndex: 2,
        atUtc: at.add(const Duration(seconds: 1)),
        timezoneId: 'Europe/Moscow',
        timezoneOffsetMinutes: 180,
      ),
      isFalse,
    );

    final metadata =
        jsonDecode(
              database.executor.rows('feed_assignments').single['metadata_json']
                  as String,
            )
            as Map<String, dynamic>;
    expect(metadata['_scenarioChoiceIndex'], 1);
    expect(metadata['_scenarioAnsweredAt'], at.toIso8601String());
    final event = database.executor.rows('event_log_v2').single;
    expect(event['event_type'], 'feed_item_saved');
    expect(jsonDecode(event['payload_json'] as String), {
      'kind': 'scenarioPollResponse',
      'choiceIndex': 1,
    });
  });

  test('event failure rolls back scenario choice', () async {
    final database = MemoryVNextDatabase(seed: _seed(at));
    final store = SqliteVNextStore(database, clock: () => at);
    final coordinator = FeedInteractionCoordinator(
      repository: store.feed,
      idGenerator: () => 'scenario-failure',
    );
    database.executor.failNextInsertInto = 'event_log_v2';

    await expectLater(
      coordinator.answerScenario(
        assignment: _assignment(at),
        choiceIndex: 0,
        atUtc: at,
        timezoneId: 'Europe/Moscow',
        timezoneOffsetMinutes: 180,
      ),
      throwsStateError,
    );

    final metadata =
        jsonDecode(
              database.executor.rows('feed_assignments').single['metadata_json']
                  as String,
            )
            as Map<String, dynamic>;
    expect(metadata, isNot(contains('_scenarioChoiceIndex')));
    expect(database.executor.rows('event_log_v2'), isEmpty);
  });
}

FeedAssignment _assignment(DateTime at) => FeedAssignment(
  assignmentId: 'assignment-1',
  localUserId: 'local-user-1',
  contentId: 'challenge-1',
  contentRevision: 1,
  locale: 'ru-RU',
  position: 0,
  batchId: 'batch-1',
  assignmentReason: 'difficulty_edge',
  assignedAt: at,
  boundedMetadata: const {'contentType': 'challenge'},
);

Map<String, List<Map<String, Object?>>> _seed(DateTime at) => {
  'user_identity': [
    {
      'local_user_id': 'local-user-1',
      'installation_id': 'installation-1',
      'remote_user_id': null,
    },
  ],
  'app_metadata': [
    {
      'key': 'client_sequence:installation-1',
      'value': '0',
      'updated_at': at.toIso8601String(),
    },
  ],
  'feed_assignments': [
    {
      'assignment_id': 'assignment-1',
      'batch_id': 'batch-1',
      'content_id': 'challenge-1',
      'content_revision': 1,
      'locale': 'ru-RU',
      'position': 0,
      'assignment_reason': 'difficulty_edge',
      'metadata_json': jsonEncode({'contentType': 'challenge'}),
      'impressed_at': null,
      'opened_at': null,
      'skipped_at': null,
    },
  ],
};
