import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mayhem_mobile/content/data/bundled_vnext_content_adapter.dart';
import 'package:mayhem_mobile/content/domain/content_item_revision.dart';
import 'package:mayhem_mobile/data/catalog/bundled_quest_catalog.dart';
import 'package:mayhem_mobile/features/challenge/domain/challenge_models.dart';
import 'package:mayhem_mobile/features/challenge/domain/challenge_transition_service.dart';
import 'package:mayhem_mobile/features/feed/application/feed_session_coordinator.dart';
import 'package:mayhem_mobile/infrastructure/sqlite/sqlite_vnext_store.dart';

import '../../support/memory_vnext_database.dart';

void main() {
  test(
    'Feed session imports, reuses, expires and restores active attempt',
    () async {
      final database = MemoryVNextDatabase(seed: _identitySeed());
      final store = SqliteVNextStore(database);
      var nextId = 0;
      final coordinator = FeedSessionCoordinator(
        content: store.content,
        feed: store.feed,
        attempts: store.challenge,
        identity: store.identity,
        idGenerator: () => 'feed-${++nextId}',
      );
      final bundled = await _bundledContent();
      final now = DateTime.parse('2026-07-13T09:00:00Z');

      final first = await coordinator.initialize(bundled: bundled, nowUtc: now);
      expect(first.generatedLocally, isTrue);
      expect(first.items, hasLength(20));
      expect(first.items.first.revision.type, ContentItemType.challenge);
      expect(first.items.first.challenge, isNotNull);
      expect(
        first.items.map((item) => item.revision.contentId).toSet(),
        hasLength(20),
      );

      final reused = await coordinator.initialize(
        bundled: bundled,
        nowUtc: now.add(const Duration(hours: 1)),
      );
      expect(reused.generatedLocally, isFalse);
      expect(reused.batch.batchId, first.batch.batchId);
      expect(database.executor.rows('content_item_revisions'), hasLength(20));

      final challengeItem = first.items.first;
      final active = const ChallengeTransitionService().accept(
        assignment: challengeItem.assignment,
        definition: challengeItem.challenge!,
        route: ChallengeRouteType.lowPressure,
        attemptId: 'active-attempt-1',
        acceptedAt: now,
        timezoneId: 'Europe/Moscow',
      );
      await store.challenge.save(active);
      final restored = await coordinator.initialize(
        bundled: bundled,
        nowUtc: now.add(const Duration(hours: 2)),
      );
      expect(restored.activeAttempt?.attemptId, 'active-attempt-1');
      expect(restored.activeChallenge?.contentId, active.contentId);

      final resolved = const ChallengeTransitionService().resolve(
        attempt: active,
        result: const AttemptResult(
          outcome: AttemptOutcome.completed,
          felt: FeltComparedToExpected.aboutAsExpected,
          earnedXp: 50,
        ),
        resolvedAt: now.add(const Duration(hours: 2)),
      );
      await store.challenge.save(resolved);
      final scenarioAssignment = first.items
          .firstWhere(
            (item) => item.revision.type == ContentItemType.scenarioPoll,
          )
          .assignment;
      final scenarioRow = database.executor
          .rows('feed_assignments')
          .singleWhere(
            (row) => row['assignment_id'] == scenarioAssignment.assignmentId,
          );
      final scenarioMetadata = Map<String, Object?>.from(
        jsonDecode(scenarioRow['metadata_json'] as String) as Map,
      )..['_scenarioChoiceIndex'] = 0;
      await database.executor.update(
        'feed_assignments',
        {'metadata_json': jsonEncode(scenarioMetadata)},
        where: 'assignment_id = ?',
        whereArgs: [scenarioAssignment.assignmentId],
      );
      final filtered = await coordinator.initialize(
        bundled: bundled,
        nowUtc: now.add(const Duration(hours: 2, minutes: 1)),
      );
      expect(
        filtered.items.map((item) => item.assignment.assignmentId),
        isNot(contains(active.assignmentId)),
      );
      expect(
        filtered.items.map((item) => item.assignment.assignmentId),
        isNot(contains(scenarioAssignment.assignmentId)),
      );
      expect(filtered.items, hasLength(18));

      final staleAssignment = database.executor
          .rows('feed_assignments')
          .firstWhere((row) => row['batch_id'] == first.batch.batchId);
      await database.executor.update(
        'feed_assignments',
        {'content_id': 'removed-by-bundled-update'},
        where: 'assignment_id = ?',
        whereArgs: [staleAssignment['assignment_id']],
      );
      final recovered = await coordinator.initialize(
        bundled: bundled,
        nowUtc: now.add(const Duration(hours: 3)),
      );
      expect(recovered.generatedLocally, isTrue);
      expect(recovered.batch.batchId, isNot(first.batch.batchId));
      expect(recovered.items, hasLength(20));

      final refreshed = await coordinator.initialize(
        bundled: bundled,
        nowUtc: now.add(const Duration(hours: 28)),
      );
      expect(refreshed.generatedLocally, isTrue);
      expect(refreshed.batch.batchId, isNot(first.batch.batchId));
      expect(refreshed.items, hasLength(20));
    },
  );
}

Future<BundledVNextContent> _bundledContent() async {
  final source = await File('assets/content/quest_catalog.json').readAsString();
  final catalog = BundledQuestCatalog.fromJson(
    jsonDecode(source) as Map<String, dynamic>,
  );
  return const BundledVNextContentAdapter().adapt(
    catalog,
    publishedAt: DateTime.parse('2026-07-01T00:00:00Z'),
  );
}

Map<String, List<Map<String, Object?>>> _identitySeed() => {
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
      'updated_at': '2026-07-13T09:00:00Z',
    },
  ],
};
