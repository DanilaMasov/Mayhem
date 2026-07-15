import '../../feed/domain/feed_models.dart';
import 'challenge_models.dart';

class ChallengeTransitionException implements Exception {
  const ChallengeTransitionException(this.code);

  final String code;

  @override
  String toString() => code;
}

class ChallengeTransitionService {
  const ChallengeTransitionService();

  ChallengeAttempt accept({
    required FeedAssignment assignment,
    required ChallengeDefinition definition,
    required ChallengeRouteType route,
    required String attemptId,
    required DateTime acceptedAt,
    required String timezoneId,
  }) {
    if (assignment.contentId != definition.contentId ||
        assignment.contentRevision != definition.revision) {
      throw const ChallengeTransitionException('assignment_content_mismatch');
    }
    if (!definition.supportsRoute(route)) {
      throw const ChallengeTransitionException('route_unavailable');
    }
    if (attemptId.trim().isEmpty || timezoneId.trim().isEmpty) {
      throw const ChallengeTransitionException('attempt_identity_invalid');
    }
    return ChallengeAttempt(
      attemptId: attemptId,
      assignmentId: assignment.assignmentId,
      contentId: definition.contentId,
      contentRevision: definition.revision,
      status: ChallengeAttemptStatus.active,
      selectedRoute: route,
      acceptedAt: acceptedAt.toUtc(),
      timezoneId: timezoneId,
      rewardAppliedLocally: false,
      syncState: AttemptSyncState.pending,
    );
  }

  ChallengeAttempt selectRoute(
    ChallengeAttempt attempt,
    ChallengeDefinition definition,
    ChallengeRouteType route,
  ) {
    _requireOpen(attempt);
    if (!definition.supportsRoute(route)) {
      throw const ChallengeTransitionException('route_unavailable');
    }
    return attempt.copyWith(selectedRoute: route);
  }

  ChallengeAttempt defer(ChallengeAttempt attempt) {
    if (attempt.status != ChallengeAttemptStatus.active) {
      throw const ChallengeTransitionException('defer_requires_active');
    }
    return attempt.copyWith(status: ChallengeAttemptStatus.deferred);
  }

  ChallengeAttempt resume(ChallengeAttempt attempt) {
    if (attempt.status != ChallengeAttemptStatus.deferred) {
      throw const ChallengeTransitionException('resume_requires_deferred');
    }
    return attempt.copyWith(status: ChallengeAttemptStatus.active);
  }

  ChallengeAttempt abandon(ChallengeAttempt attempt, DateTime resolvedAt) {
    _requireOpen(attempt);
    return attempt.copyWith(
      status: ChallengeAttemptStatus.abandoned,
      resolvedAt: resolvedAt.toUtc(),
    );
  }

  ChallengeAttempt resolve({
    required ChallengeAttempt attempt,
    required AttemptResult result,
    required DateTime resolvedAt,
  }) {
    _requireOpen(attempt);
    final status = switch (result.outcome) {
      AttemptOutcome.attempted => ChallengeAttemptStatus.attempted,
      AttemptOutcome.completed => ChallengeAttemptStatus.completed,
    };
    return attempt.copyWith(
      status: status,
      resolvedAt: resolvedAt.toUtc(),
      result: result,
    );
  }

  void _requireOpen(ChallengeAttempt attempt) {
    if (attempt.status != ChallengeAttemptStatus.active &&
        attempt.status != ChallengeAttemptStatus.deferred) {
      throw const ChallengeTransitionException('attempt_already_terminal');
    }
  }
}
