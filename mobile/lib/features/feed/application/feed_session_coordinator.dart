import '../../../content/data/bundled_vnext_content_adapter.dart';
import '../../../content/domain/content_item_revision.dart';
import '../../../content/domain/content_repository.dart';
import '../../../core/identity/local_identity_repository.dart';
import '../../challenge/domain/challenge_attempt_repository.dart';
import '../../challenge/domain/challenge_preparation.dart';
import '../../challenge/domain/challenge_models.dart';
import '../domain/feed_models.dart';
import '../domain/feed_repository.dart';
import '../domain/local_feed_batch_policy.dart';

class FeedSessionItem {
  const FeedSessionItem({
    required this.assignment,
    required this.revision,
    this.challenge,
    this.preparation,
  });

  final FeedAssignment assignment;
  final ContentItemRevision revision;
  final ChallengeDefinition? challenge;
  final ChallengePreparation? preparation;
}

class FeedSessionSnapshot {
  FeedSessionSnapshot({
    required this.batch,
    required List<FeedSessionItem> items,
    required this.generatedLocally,
    this.activeAttempt,
    this.activeChallenge,
  }) : items = List.unmodifiable(items);

  final FeedBatch batch;
  final List<FeedSessionItem> items;
  final bool generatedLocally;
  final ChallengeAttempt? activeAttempt;
  final ChallengeDefinition? activeChallenge;
}

/// Builds a complete offline Feed session from bundled, versioned content.
class FeedSessionCoordinator {
  const FeedSessionCoordinator({
    required this.content,
    required this.feed,
    required this.attempts,
    required this.identity,
    required this.idGenerator,
    this.remoteFeedEnabled = _disabled,
    this.remoteContentEnabled = _disabled,
    this.batchPolicy = const LocalFeedBatchPolicy(),
  });

  final ContentRepository content;
  final FeedRepository feed;
  final ChallengeAttemptRepository attempts;
  final LocalIdentityRepository identity;
  final String Function() idGenerator;
  final bool Function() remoteFeedEnabled;
  final bool Function() remoteContentEnabled;
  final LocalFeedBatchPolicy batchPolicy;

  Future<FeedSessionSnapshot> initialize({
    required BundledVNextContent bundled,
    required DateTime nowUtc,
  }) async {
    final now = nowUtc.toUtc();
    await content.saveValidatedRevisions(bundled.revisions);
    var activeRevisions = await content.activeRevisions(
      locale: BundledVNextContentAdapter.locale,
      atUtc: now,
    );
    if (!remoteContentEnabled() || activeRevisions.isEmpty) {
      await content.activateBundledCatalog(bundled.revisions);
      activeRevisions = await content.activeRevisions(
        locale: BundledVNextContentAdapter.locale,
        atUtc: now,
      );
    }
    final useRemoteFeed = remoteFeedEnabled();
    var batch = await feed.latestUsableBatch(now, preferRemote: useRemoteFeed);
    if (batch?.source == FeedBatchSource.remote && !useRemoteFeed) {
      batch = null;
    }
    var generatedLocally = false;
    List<FeedAssignment> assignments;
    if (batch == null) {
      final generated = await _generateBatch(
        bundled: bundled,
        revisions: activeRevisions,
        now: now,
      );
      await feed.saveBatch(generated.batch, generated.assignments);
      batch = generated.batch;
      assignments = generated.assignments;
      generatedLocally = true;
    } else {
      assignments = await feed.assignmentsFor(batch.batchId);
      if (assignments.isEmpty) {
        throw StateError('Stored feed batch has no assignments');
      }
      final activeIdentities = {
        for (final revision in activeRevisions) revision.identity,
      };
      if (assignments.any(
        (assignment) => !activeIdentities.contains(
          '${assignment.contentId}@${assignment.contentRevision}:'
          '${assignment.locale}',
        ),
      )) {
        final generated = await _generateBatch(
          bundled: bundled,
          revisions: activeRevisions,
          now: now,
        );
        await feed.saveBatch(generated.batch, generated.assignments);
        batch = generated.batch;
        assignments = generated.assignments;
        generatedLocally = true;
      }
    }

    final visibleAssignments = <FeedAssignment>[];
    for (final assignment in assignments) {
      final attempt = await attempts.findByAssignment(assignment.assignmentId);
      if (attempt?.isTerminal == true ||
          assignment.boundedMetadata['_scenarioChoiceIndex'] is num) {
        continue;
      }
      visibleAssignments.add(assignment);
    }
    final revisions = await Future.wait([
      for (final assignment in visibleAssignments)
        content.findRevision(
          contentId: assignment.contentId,
          revision: assignment.contentRevision,
          locale: assignment.locale,
        ),
    ]);
    final items = <FeedSessionItem>[];
    for (var index = 0; index < visibleAssignments.length; index += 1) {
      final revision = revisions[index];
      if (revision == null || !visibleAssignments[index].matches(revision)) {
        throw StateError(
          'Feed assignment content is unavailable: '
          '${visibleAssignments[index].assignmentId}',
        );
      }
      items.add(
        FeedSessionItem(
          assignment: visibleAssignments[index],
          revision: revision,
          challenge: revision.type == ContentItemType.challenge
              ? bundled.challenges[revision.contentId]
              : null,
          preparation: bundled.preparations[revision.contentId],
        ),
      );
    }

    final activeAttempt = await attempts.activeAttempt();
    return FeedSessionSnapshot(
      batch: batch,
      items: items,
      generatedLocally: generatedLocally,
      activeAttempt: activeAttempt,
      activeChallenge: activeAttempt == null
          ? null
          : bundled.challenges[activeAttempt.contentId],
    );
  }

  Future<GeneratedFeedBatch> _generateBatch({
    required BundledVNextContent bundled,
    required List<ContentItemRevision> revisions,
    required DateTime now,
  }) async {
    final localIdentity = await identity.loadIdentity();
    final history = await attempts.history(limit: 500);
    final completedNonRepeatable = history
        .where(
          (attempt) =>
              attempt.status == ChallengeAttemptStatus.completed &&
              !(bundled.challenges[attempt.contentId]?.repeatable ?? false),
        )
        .map((attempt) => attempt.contentId)
        .toSet();
    return batchPolicy.generate(
      revisions: revisions,
      completedContentIds: completedNonRepeatable,
      localUserId: localIdentity.localUserId,
      nowUtc: now,
      idGenerator: idGenerator,
    );
  }

  static bool _disabled() => false;
}
