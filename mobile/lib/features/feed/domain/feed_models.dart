import '../../../content/domain/content_item_revision.dart';

enum FeedBatchSource { bundled, localGenerated, remote }

enum FeedBatchSyncState { localOnly, pending, synced }

enum FeedSkipReason { notNow, tooIntense, wrongContext, notRelevant }

class FeedBatch {
  const FeedBatch({
    required this.batchId,
    required this.createdAt,
    required this.source,
    required this.algorithmRevision,
    required this.syncState,
    this.expiresAt,
  });

  final String batchId;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final FeedBatchSource source;
  final String algorithmRevision;
  final FeedBatchSyncState syncState;
}

class FeedAssignment {
  FeedAssignment({
    required this.assignmentId,
    required this.localUserId,
    required this.contentId,
    required this.contentRevision,
    required this.locale,
    required this.position,
    required this.batchId,
    required this.assignmentReason,
    required this.assignedAt,
    required Map<String, Object?> boundedMetadata,
    this.expiresAt,
  }) : boundedMetadata = Map.unmodifiable(boundedMetadata) {
    if (assignmentId.trim().isEmpty || batchId.trim().isEmpty) {
      throw const FormatException('Feed assignment identity is invalid');
    }
    if (contentId.trim().isEmpty || contentRevision < 1 || position < 0) {
      throw const FormatException('Feed assignment content is invalid');
    }
    if (boundedMetadata.length > 24) {
      throw const FormatException('Feed assignment metadata is too large');
    }
  }

  final String assignmentId;
  final String localUserId;
  final String contentId;
  final int contentRevision;
  final String locale;
  final int position;
  final String batchId;
  final String assignmentReason;
  final DateTime assignedAt;
  final DateTime? expiresAt;
  final Map<String, Object?> boundedMetadata;

  bool matches(ContentItemRevision revision) =>
      contentId == revision.contentId &&
      contentRevision == revision.revision &&
      locale == revision.locale;
}
