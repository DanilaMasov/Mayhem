import '../../../core/sync/event_envelope_v2.dart';
import 'feed_models.dart';

abstract interface class LocalFeedInteractionRepository {
  Future<bool> commitImpression({
    required String assignmentId,
    required DateTime impressedAtUtc,
    required EventDraftV2 event,
  });

  Future<bool> commitOpened({
    required String assignmentId,
    required DateTime openedAtUtc,
    required EventDraftV2 event,
  });

  Future<bool> commitSkipped({
    required String assignmentId,
    required DateTime skippedAtUtc,
    required FeedSkipReason reason,
    required EventDraftV2 event,
  });
}
