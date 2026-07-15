import 'feed_models.dart';

abstract interface class FeedRepository {
  Future<void> saveBatch(FeedBatch batch, List<FeedAssignment> assignments);

  Future<FeedBatch?> latestUsableBatch(DateTime atUtc);

  Future<List<FeedAssignment>> assignmentsFor(String batchId);

  Future<void> markImpressed(String assignmentId, DateTime impressedAtUtc);

  Future<void> markOpened(String assignmentId, DateTime openedAtUtc);

  Future<void> markSkipped(
    String assignmentId,
    DateTime skippedAtUtc, {
    FeedSkipReason? reason,
  });
}
