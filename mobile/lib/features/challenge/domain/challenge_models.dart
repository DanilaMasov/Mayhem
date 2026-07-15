import '../../progress/domain/progress_models.dart';

enum ChallengeRouteType { normal, lowPressure, advanced }

enum ChallengeAttemptStatus {
  active,
  deferred,
  abandoned,
  attempted,
  completed,
}

enum AttemptOutcome { attempted, completed }

enum FeltComparedToExpected {
  easierThanExpected,
  aboutAsExpected,
  harderThanExpected,
  stoppedEarly,
}

enum AttemptSyncState { pending, synced, rejected }

class ChallengeRoute {
  const ChallengeRoute({required this.copy, this.completionCriteriaOverride});

  final String copy;
  final String? completionCriteriaOverride;
}

class ChallengeDefinition {
  ChallengeDefinition({
    required this.contentId,
    required this.revision,
    required this.title,
    required this.primaryTrait,
    required Map<Trait, double> secondaryTraitWeights,
    required this.intensity,
    required this.baseXp,
    required Set<String> contextTags,
    required this.completionCriteria,
    required this.normalRoute,
    required this.lowPressureRoute,
    required List<String> preparationContentIds,
    required this.momentumEligible,
    required this.repeatable,
    this.supportingCopy,
    this.estimatedDuration,
    this.advancedRoute,
    this.advancedRouteSafetyApproved = false,
  }) : secondaryTraitWeights = Map.unmodifiable(secondaryTraitWeights),
       contextTags = Set.unmodifiable(contextTags),
       preparationContentIds = List.unmodifiable(preparationContentIds) {
    if (contentId.trim().isEmpty || revision < 1 || title.trim().isEmpty) {
      throw const FormatException('Challenge identity is invalid');
    }
    if (intensity < 1 || intensity > 5 || baseXp < 0) {
      throw const FormatException('Challenge difficulty or XP is invalid');
    }
    if (completionCriteria.trim().isEmpty || normalRoute.copy.trim().isEmpty) {
      throw const FormatException('Challenge route is incomplete');
    }
    if (lowPressureRoute.copy.trim().isEmpty) {
      throw const FormatException('Low-pressure route is required');
    }
    if (advancedRouteSafetyApproved && advancedRoute == null) {
      throw const FormatException(
        'Advanced route approval requires an advanced route',
      );
    }
    for (final entry in secondaryTraitWeights.entries) {
      if (entry.key == primaryTrait || entry.value <= 0 || entry.value > 1) {
        throw const FormatException('Secondary trait weight is invalid');
      }
    }
  }

  final String contentId;
  final int revision;
  final String title;
  final String? supportingCopy;
  final Trait primaryTrait;
  final Map<Trait, double> secondaryTraitWeights;
  final int intensity;
  final int baseXp;
  final Duration? estimatedDuration;
  final Set<String> contextTags;
  final String completionCriteria;
  final ChallengeRoute normalRoute;
  final ChallengeRoute lowPressureRoute;
  final ChallengeRoute? advancedRoute;
  final bool advancedRouteSafetyApproved;
  final List<String> preparationContentIds;
  final bool momentumEligible;
  final bool repeatable;

  bool supportsRoute(ChallengeRouteType route) => switch (route) {
    ChallengeRouteType.normal => true,
    ChallengeRouteType.lowPressure => true,
    ChallengeRouteType.advanced => advancedRoute != null,
  };
}

class AttemptResult {
  const AttemptResult({
    required this.outcome,
    required this.felt,
    this.fearBefore,
    this.feelAfter,
    this.wantRepeat,
    this.privateNoteId,
    this.earnedXp,
    this.effectiveLocalDate,
  });

  final AttemptOutcome outcome;
  final FeltComparedToExpected felt;
  final int? fearBefore;
  final int? feelAfter;
  final bool? wantRepeat;
  final String? privateNoteId;
  final int? earnedXp;
  final String? effectiveLocalDate;

  AttemptResult copyWith({int? earnedXp, String? effectiveLocalDate}) =>
      AttemptResult(
        outcome: outcome,
        felt: felt,
        fearBefore: fearBefore,
        feelAfter: feelAfter,
        wantRepeat: wantRepeat,
        privateNoteId: privateNoteId,
        earnedXp: earnedXp ?? this.earnedXp,
        effectiveLocalDate: effectiveLocalDate ?? this.effectiveLocalDate,
      );
}

class ChallengeAttempt {
  const ChallengeAttempt({
    required this.attemptId,
    required this.assignmentId,
    required this.contentId,
    required this.contentRevision,
    required this.status,
    required this.selectedRoute,
    required this.acceptedAt,
    required this.timezoneId,
    required this.rewardAppliedLocally,
    required this.syncState,
    this.resolvedAt,
    this.result,
  });

  final String attemptId;
  final String assignmentId;
  final String contentId;
  final int contentRevision;
  final ChallengeAttemptStatus status;
  final ChallengeRouteType selectedRoute;
  final DateTime acceptedAt;
  final DateTime? resolvedAt;
  final String timezoneId;
  final AttemptResult? result;
  final bool rewardAppliedLocally;
  final AttemptSyncState syncState;

  bool get isTerminal => switch (status) {
    ChallengeAttemptStatus.abandoned ||
    ChallengeAttemptStatus.attempted ||
    ChallengeAttemptStatus.completed => true,
    _ => false,
  };

  ChallengeAttempt copyWith({
    ChallengeAttemptStatus? status,
    ChallengeRouteType? selectedRoute,
    DateTime? resolvedAt,
    AttemptResult? result,
    bool? rewardAppliedLocally,
    AttemptSyncState? syncState,
  }) => ChallengeAttempt(
    attemptId: attemptId,
    assignmentId: assignmentId,
    contentId: contentId,
    contentRevision: contentRevision,
    status: status ?? this.status,
    selectedRoute: selectedRoute ?? this.selectedRoute,
    acceptedAt: acceptedAt,
    resolvedAt: resolvedAt ?? this.resolvedAt,
    timezoneId: timezoneId,
    result: result ?? this.result,
    rewardAppliedLocally: rewardAppliedLocally ?? this.rewardAppliedLocally,
    syncState: syncState ?? this.syncState,
  );
}
