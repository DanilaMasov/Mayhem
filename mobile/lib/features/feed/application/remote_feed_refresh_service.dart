import '../../../content/domain/content_repository.dart';
import '../../../core/identity/local_identity_repository.dart';
import '../../challenge/domain/challenge_attempt_repository.dart';
import '../../sync/domain/backend_models.dart';
import '../domain/feed_models.dart';
import '../domain/feed_repository.dart';

class RemoteFeedRefreshResult {
  const RemoteFeedRefreshResult({
    required this.receivedCount,
    required this.savedCount,
    required this.committed,
  });

  final int receivedCount;
  final int savedCount;
  final bool committed;
}

abstract interface class RemoteFeedRefresher {
  Future<RemoteFeedRefreshResult> refresh({String locale = 'ru'});
}

class RemoteFeedRefreshService implements RemoteFeedRefresher {
  const RemoteFeedRefreshService({
    required this.backend,
    required this.feed,
    required this.attempts,
    required this.identity,
    required this.content,
    required this.clock,
  });

  final VNextBackendGateway backend;
  final FeedRepository feed;
  final ChallengeAttemptRepository attempts;
  final LocalIdentityRepository identity;
  final ContentRepository content;
  final DateTime Function() clock;

  @override
  Future<RemoteFeedRefreshResult> refresh({String locale = 'ru'}) async {
    final now = clock().toUtc();
    final remote = await backend.getFeedBatch(locale: locale);
    if (remote.expiresAt?.isAfter(now) == false) {
      return RemoteFeedRefreshResult(
        receivedCount: remote.assignments.length,
        savedCount: 0,
        committed: false,
      );
    }
    final localIdentity = await identity.loadIdentity();
    final ordered = remote.assignments.toList(growable: false)
      ..sort((left, right) => left.position.compareTo(right.position));
    final assignments = <FeedAssignment>[];
    for (final candidate in ordered) {
      if (candidate.locale != locale ||
          candidate.expiresAt?.isAfter(now) == false ||
          await attempts.findByAssignment(candidate.assignmentId) != null ||
          await feed.wasSkipped(candidate.assignmentId)) {
        continue;
      }
      final revision = await content.findRevision(
        contentId: candidate.contentId,
        revision: candidate.contentRevision,
        locale: candidate.locale,
      );
      if (revision == null ||
          revision.contentId != candidate.contentId ||
          revision.revision != candidate.contentRevision ||
          revision.locale != candidate.locale) {
        continue;
      }
      assignments.add(
        FeedAssignment(
          assignmentId: candidate.assignmentId,
          localUserId: localIdentity.localUserId,
          contentId: candidate.contentId,
          contentRevision: candidate.contentRevision,
          locale: candidate.locale,
          position: assignments.length,
          batchId: remote.batchId,
          assignmentReason: candidate.assignmentReason,
          assignedAt: remote.createdAt,
          expiresAt: candidate.expiresAt ?? remote.expiresAt,
          boundedMetadata: {'serverPosition': candidate.position},
        ),
      );
    }
    if (assignments.isEmpty) {
      return RemoteFeedRefreshResult(
        receivedCount: remote.assignments.length,
        savedCount: 0,
        committed: false,
      );
    }
    await feed.saveBatch(
      FeedBatch(
        batchId: remote.batchId,
        createdAt: remote.createdAt,
        expiresAt: remote.expiresAt,
        source: FeedBatchSource.remote,
        algorithmRevision: remote.algorithmRevision,
        syncState: FeedBatchSyncState.synced,
      ),
      assignments,
    );
    return RemoteFeedRefreshResult(
      receivedCount: remote.assignments.length,
      savedCount: assignments.length,
      committed: true,
    );
  }
}
