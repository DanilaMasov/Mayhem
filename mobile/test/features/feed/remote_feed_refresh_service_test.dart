import 'package:flutter_test/flutter_test.dart';
import 'package:mayhem_mobile/content/domain/content_item_revision.dart';
import 'package:mayhem_mobile/content/domain/content_repository.dart';
import 'package:mayhem_mobile/core/identity/local_identity_repository.dart';
import 'package:mayhem_mobile/features/challenge/domain/challenge_attempt_repository.dart';
import 'package:mayhem_mobile/features/challenge/domain/challenge_models.dart';
import 'package:mayhem_mobile/features/feed/application/remote_feed_refresh_service.dart';
import 'package:mayhem_mobile/features/feed/domain/feed_models.dart';
import 'package:mayhem_mobile/features/feed/domain/feed_repository.dart';
import 'package:mayhem_mobile/features/sync/domain/backend_models.dart';

void main() {
  test(
    'remote Feed preserves order and removes terminal assignments',
    () async {
      final feed = _Feed()..skipped.add('skipped');
      final attempts = _Attempts()..terminal.add('accepted');
      final service = RemoteFeedRefreshService(
        backend: _Backend(
          RemoteFeedBatch(
            batchId: 'remote-batch',
            algorithmRevision: 'feed-v1',
            createdAt: DateTime.utc(2026, 7, 15, 12),
            expiresAt: DateTime.utc(2026, 7, 16),
            assignments: [
              _remote('skipped', 'challenge-a', 5),
              _remote('accepted', 'challenge-b', 7),
              _remote('usable', 'challenge-c', 9),
            ],
          ),
        ),
        feed: feed,
        attempts: attempts,
        identity: _Identity(),
        content: _Content({
          for (final id in ['challenge-a', 'challenge-b', 'challenge-c'])
            id: _revision(id),
        }),
        clock: () => DateTime.utc(2026, 7, 15, 13),
      );

      final result = await service.refresh();

      expect(result.receivedCount, 3);
      expect(result.savedCount, 1);
      expect(result.committed, isTrue);
      expect(feed.batch?.source, FeedBatchSource.remote);
      expect(feed.assignments.single.assignmentId, 'usable');
      expect(feed.assignments.single.position, 0);
      expect(feed.assignments.single.boundedMetadata['serverPosition'], 9);
    },
  );

  test(
    'expired or duplicate remote batches fail before local replacement',
    () async {
      expect(
        () => RemoteFeedBatch(
          batchId: 'duplicate',
          algorithmRevision: 'feed-v1',
          createdAt: DateTime.utc(2026, 7, 15),
          assignments: [
            _remote('same', 'challenge-a', 0),
            _remote('same', 'challenge-b', 1),
          ],
        ),
        throwsFormatException,
      );

      final feed = _Feed();
      final service = RemoteFeedRefreshService(
        backend: _Backend(
          RemoteFeedBatch(
            batchId: 'expired',
            algorithmRevision: 'feed-v1',
            createdAt: DateTime.utc(2026, 7, 14),
            expiresAt: DateTime.utc(2026, 7, 15, 12),
            assignments: [_remote('usable', 'challenge-a', 0)],
          ),
        ),
        feed: feed,
        attempts: _Attempts(),
        identity: _Identity(),
        content: _Content({'challenge-a': _revision('challenge-a')}),
        clock: () => DateTime.utc(2026, 7, 15, 13),
      );

      final result = await service.refresh();
      expect(result.committed, isFalse);
      expect(feed.batch, isNull);
    },
  );
}

RemoteFeedAssignment _remote(String id, String contentId, int position) =>
    RemoteFeedAssignment(
      assignmentId: id,
      contentId: contentId,
      contentRevision: 1,
      locale: 'ru',
      position: position,
      assignmentReason: 'eligible',
      expiresAt: DateTime.utc(2026, 7, 16),
    );

ContentItemRevision _revision(String id) => ContentItemRevision(
  contentId: id,
  revision: 1,
  type: ContentItemType.challenge,
  locale: 'ru',
  publishedAt: DateTime.utc(2026, 7, 1),
  payload: const {'title': 'Challenge'},
  safety: SafetyMetadata(
    safetyReviewed: true,
    safetyRevision: 1,
    requiresContextWarning: false,
    disallowedContexts: const {},
    lowPressureRoute: 'Stop early.',
    exitCopy: 'Stop whenever needed.',
  ),
  active: true,
  source: ContentRevisionSource.bundled,
  checksum: 'checksum',
);

class _Backend implements VNextBackendGateway {
  const _Backend(this.batch);
  final RemoteFeedBatch batch;

  @override
  Future<RemoteFeedBatch> getFeedBatch({
    String locale = 'ru',
    int limit = 20,
  }) async => batch;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Feed implements FeedRepository {
  final Set<String> skipped = {};
  FeedBatch? batch;
  List<FeedAssignment> assignments = const [];

  @override
  Future<void> saveBatch(
    FeedBatch batch,
    List<FeedAssignment> assignments,
  ) async {
    this.batch = batch;
    this.assignments = assignments;
  }

  @override
  Future<bool> wasSkipped(String assignmentId) async =>
      skipped.contains(assignmentId);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Attempts implements ChallengeAttemptRepository {
  final Set<String> terminal = {};

  @override
  Future<ChallengeAttempt?> findByAssignment(String assignmentId) async =>
      terminal.contains(assignmentId)
      ? ChallengeAttempt(
          attemptId: 'attempt-$assignmentId',
          assignmentId: assignmentId,
          contentId: 'challenge',
          contentRevision: 1,
          status: ChallengeAttemptStatus.active,
          selectedRoute: ChallengeRouteType.normal,
          acceptedAt: DateTime.utc(2026, 7, 15),
          timezoneId: 'Europe/Moscow',
          rewardAppliedLocally: false,
          syncState: AttemptSyncState.pending,
        )
      : null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Identity implements LocalIdentityRepository {
  @override
  Future<LocalIdentity> loadIdentity() async => const LocalIdentity(
    localUserId: 'local-user',
    installationId: 'installation-id',
  );
}

class _Content implements ContentRepository {
  const _Content(this.revisions);
  final Map<String, ContentItemRevision> revisions;

  @override
  Future<ContentItemRevision?> findRevision({
    required String contentId,
    required int revision,
    required String locale,
  }) async => revisions[contentId];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
