import '../../../core/sync/event_envelope_v2.dart';
import '../domain/feed_models.dart';
import '../domain/local_feed_interaction_repository.dart';

class FeedInteractionCoordinator {
  const FeedInteractionCoordinator({
    required this.repository,
    required this.idGenerator,
  });

  final LocalFeedInteractionRepository repository;
  final String Function() idGenerator;

  Future<bool> impress({
    required FeedAssignment assignment,
    required DateTime atUtc,
    required String timezoneId,
    required int timezoneOffsetMinutes,
  }) => repository.commitImpression(
    assignmentId: assignment.assignmentId,
    impressedAtUtc: atUtc,
    event: _event(
      assignment: assignment,
      type: CanonicalEventTypeV2.feedItemImpressed,
      atUtc: atUtc,
      timezoneId: timezoneId,
      timezoneOffsetMinutes: timezoneOffsetMinutes,
      payload: const {},
    ),
  );

  Future<bool> open({
    required FeedAssignment assignment,
    required DateTime atUtc,
    required String timezoneId,
    required int timezoneOffsetMinutes,
  }) => repository.commitOpened(
    assignmentId: assignment.assignmentId,
    openedAtUtc: atUtc,
    event: _event(
      assignment: assignment,
      type: CanonicalEventTypeV2.feedItemOpened,
      atUtc: atUtc,
      timezoneId: timezoneId,
      timezoneOffsetMinutes: timezoneOffsetMinutes,
      payload: const {},
    ),
  );

  Future<bool> skip({
    required FeedAssignment assignment,
    required FeedSkipReason reason,
    required DateTime atUtc,
    required String timezoneId,
    required int timezoneOffsetMinutes,
  }) => repository.commitSkipped(
    assignmentId: assignment.assignmentId,
    skippedAtUtc: atUtc,
    reason: reason,
    event: _event(
      assignment: assignment,
      type: CanonicalEventTypeV2.feedItemSkipped,
      atUtc: atUtc,
      timezoneId: timezoneId,
      timezoneOffsetMinutes: timezoneOffsetMinutes,
      payload: {'reason': reason.name},
    ),
  );

  EventDraftV2 _event({
    required FeedAssignment assignment,
    required CanonicalEventTypeV2 type,
    required DateTime atUtc,
    required String timezoneId,
    required int timezoneOffsetMinutes,
    required Map<String, Object?> payload,
  }) => EventDraftV2(
    eventId: idGenerator(),
    eventType: type,
    occurredAtUtc: atUtc.toUtc(),
    timezoneId: timezoneId,
    timezoneOffsetMinutes: timezoneOffsetMinutes,
    assignmentId: assignment.assignmentId,
    contentId: assignment.contentId,
    contentRevision: assignment.contentRevision,
    payload: payload,
  );
}
