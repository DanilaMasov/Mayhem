import 'dart:convert';

import '../../content/domain/content_item_revision.dart';
import '../../features/challenge/domain/challenge_models.dart';
import '../../features/feed/domain/feed_models.dart';
import '../../features/progress/domain/progress_models.dart';
import '../../features/reflection/domain/private_reflection.dart';
import '../../features/streak/domain/momentum_state.dart';

abstract final class SqliteContentMapper {
  static Map<String, Object?> toRow(ContentItemRevision revision) => {
    'content_id': revision.contentId,
    'revision': revision.revision,
    'locale': revision.locale,
    'type': revision.type.name,
    'payload_json': jsonEncode(revision.payload),
    'safety_json': jsonEncode({
      'safetyReviewed': revision.safety.safetyReviewed,
      'safetyRevision': revision.safety.safetyRevision,
      'requiresContextWarning': revision.safety.requiresContextWarning,
      'disallowedContexts': revision.safety.disallowedContexts.toList()..sort(),
      'lowPressureRoute': revision.safety.lowPressureRoute,
      'exitCopy': revision.safety.exitCopy,
      'advancedRouteSafetyApproved':
          revision.safety.advancedRouteSafetyApproved,
      'reviewerId': revision.safety.reviewerId,
      'reviewedAt': revision.safety.reviewedAt?.toUtc().toIso8601String(),
    }),
    'media_json': revision.media == null
        ? null
        : jsonEncode({
            'type': revision.media!.type.name,
            'remoteUri': revision.media!.remoteUri?.toString(),
            'bundledAsset': revision.media!.bundledAsset,
            'posterUri': revision.media!.posterUri?.toString(),
            'aspectRatio': revision.media!.aspectRatio,
            'checksum': revision.media!.checksum,
            'byteSize': revision.media!.byteSize,
            'captionTrack': revision.media!.captionTrack,
            'fallback': revision.media!.fallback.name,
          }),
    'published_at': revision.publishedAt.toUtc().toIso8601String(),
    'starts_at': revision.startsAt?.toUtc().toIso8601String(),
    'ends_at': revision.endsAt?.toUtc().toIso8601String(),
    'source': revision.source.name,
    'checksum': revision.checksum,
    'active': revision.active ? 1 : 0,
  };

  static ContentItemRevision fromRow(Map<String, Object?> row) {
    final payload = _object(row['payload_json'] as String);
    final safetyJson = _object(row['safety_json'] as String);
    final mediaSource = row['media_json'] as String?;
    final mediaJson = mediaSource == null ? null : _object(mediaSource);
    return ContentItemRevision(
      contentId: row['content_id'] as String,
      revision: (row['revision'] as num).toInt(),
      type: ContentItemType.values.byName(row['type'] as String),
      locale: row['locale'] as String,
      publishedAt: DateTime.parse(row['published_at'] as String).toUtc(),
      startsAt: _date(row['starts_at']),
      endsAt: _date(row['ends_at']),
      payload: payload,
      safety: SafetyMetadata(
        safetyReviewed: safetyJson['safetyReviewed'] == true,
        safetyRevision: (safetyJson['safetyRevision'] as num).toInt(),
        requiresContextWarning: safetyJson['requiresContextWarning'] == true,
        disallowedContexts: Set<String>.from(
          safetyJson['disallowedContexts'] as List<dynamic>? ?? const [],
        ),
        lowPressureRoute: safetyJson['lowPressureRoute'] as String?,
        exitCopy: safetyJson['exitCopy'] as String,
        advancedRouteSafetyApproved:
            safetyJson['advancedRouteSafetyApproved'] == true,
        reviewerId: safetyJson['reviewerId'] as String?,
        reviewedAt: _date(safetyJson['reviewedAt']),
      ),
      media: mediaJson == null
          ? null
          : MediaDescriptor(
              type: MediaType.values.byName(mediaJson['type'] as String),
              remoteUri: _uri(mediaJson['remoteUri']),
              bundledAsset: mediaJson['bundledAsset'] as String?,
              posterUri: _uri(mediaJson['posterUri']),
              aspectRatio: (mediaJson['aspectRatio'] as num).toDouble(),
              checksum: mediaJson['checksum'] as String,
              byteSize: (mediaJson['byteSize'] as num).toInt(),
              captionTrack: mediaJson['captionTrack'] as String?,
              fallback: MediaFallback.values.byName(
                mediaJson['fallback'] as String,
              ),
            ),
      active: (row['active'] as num).toInt() == 1,
      source: ContentRevisionSource.values.byName(row['source'] as String),
      checksum: row['checksum'] as String,
    );
  }
}

abstract final class SqliteFeedMapper {
  static Map<String, Object?> batchToRow(FeedBatch batch) => {
    'batch_id': batch.batchId,
    'created_at': batch.createdAt.toUtc().toIso8601String(),
    'expires_at': batch.expiresAt?.toUtc().toIso8601String(),
    'source': batch.source.name,
    'algorithm_revision': batch.algorithmRevision,
    'sync_state': batch.syncState.name,
  };

  static FeedBatch batchFromRow(Map<String, Object?> row) => FeedBatch(
    batchId: row['batch_id'] as String,
    createdAt: DateTime.parse(row['created_at'] as String).toUtc(),
    expiresAt: _date(row['expires_at']),
    source: FeedBatchSource.values.byName(row['source'] as String),
    algorithmRevision: row['algorithm_revision'] as String,
    syncState: FeedBatchSyncState.values.byName(row['sync_state'] as String),
  );

  static Map<String, Object?> assignmentToRow(FeedAssignment assignment) => {
    'assignment_id': assignment.assignmentId,
    'batch_id': assignment.batchId,
    'content_id': assignment.contentId,
    'content_revision': assignment.contentRevision,
    'locale': assignment.locale,
    'position': assignment.position,
    'assignment_reason': assignment.assignmentReason,
    'metadata_json': jsonEncode(assignment.boundedMetadata),
    'impressed_at': null,
    'opened_at': null,
    'skipped_at': null,
  };

  static FeedAssignment assignmentFromRow(
    Map<String, Object?> row, {
    required String localUserId,
    required FeedBatch batch,
  }) => FeedAssignment(
    assignmentId: row['assignment_id'] as String,
    localUserId: localUserId,
    contentId: row['content_id'] as String,
    contentRevision: (row['content_revision'] as num).toInt(),
    locale: row['locale'] as String,
    position: (row['position'] as num).toInt(),
    batchId: row['batch_id'] as String,
    assignmentReason: row['assignment_reason'] as String,
    assignedAt: batch.createdAt,
    expiresAt: batch.expiresAt,
    boundedMetadata: _object(row['metadata_json'] as String),
  );
}

abstract final class SqliteAttemptMapper {
  static Map<String, Object?> toRow(
    ChallengeAttempt attempt, {
    required DateTime updatedAt,
  }) => {
    'attempt_id': attempt.attemptId,
    'assignment_id': attempt.assignmentId,
    'content_id': attempt.contentId,
    'content_revision': attempt.contentRevision,
    'status': attempt.status.name,
    'selected_route': _routeToWire(attempt.selectedRoute),
    'accepted_at': attempt.acceptedAt.toUtc().toIso8601String(),
    'resolved_at': attempt.resolvedAt?.toUtc().toIso8601String(),
    'timezone_id': attempt.timezoneId,
    'result_json': attempt.result == null
        ? null
        : jsonEncode({
            'outcome': attempt.result!.outcome.name,
            'felt': attempt.result!.felt.name,
            'fearBefore': attempt.result!.fearBefore,
            'feelAfter': attempt.result!.feelAfter,
            'wantRepeat': attempt.result!.wantRepeat,
            'privateNoteId': attempt.result!.privateNoteId,
            'earnedXp': attempt.result!.earnedXp,
            'effectiveLocalDate': attempt.result!.effectiveLocalDate,
          }),
    'reward_applied_local': attempt.rewardAppliedLocally ? 1 : 0,
    'sync_state': attempt.syncState.name,
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };

  static ChallengeAttempt fromRow(Map<String, Object?> row) {
    final resultSource = row['result_json'] as String?;
    final resultJson = resultSource == null ? null : _object(resultSource);
    return ChallengeAttempt(
      attemptId: row['attempt_id'] as String,
      assignmentId: row['assignment_id'] as String,
      contentId: row['content_id'] as String,
      contentRevision: (row['content_revision'] as num).toInt(),
      status: ChallengeAttemptStatus.values.byName(row['status'] as String),
      selectedRoute: _routeFromWire(row['selected_route'] as String),
      acceptedAt: DateTime.parse(row['accepted_at'] as String).toUtc(),
      resolvedAt: _date(row['resolved_at']),
      timezoneId: row['timezone_id'] as String,
      result: resultJson == null || resultJson['outcome'] == null
          ? null
          : AttemptResult(
              outcome: AttemptOutcome.values.byName(
                resultJson['outcome'] as String,
              ),
              felt: FeltComparedToExpected.values.byName(
                resultJson['felt'] as String,
              ),
              fearBefore: (resultJson['fearBefore'] as num?)?.toInt(),
              feelAfter: (resultJson['feelAfter'] as num?)?.toInt(),
              wantRepeat: resultJson['wantRepeat'] as bool?,
              privateNoteId: resultJson['privateNoteId'] as String?,
              earnedXp: (resultJson['earnedXp'] as num?)?.toInt(),
              effectiveLocalDate: resultJson['effectiveLocalDate'] as String?,
            ),
      rewardAppliedLocally: (row['reward_applied_local'] as num).toInt() == 1,
      syncState: AttemptSyncState.values.byName(row['sync_state'] as String),
    );
  }

  static String _routeToWire(ChallengeRouteType route) => switch (route) {
    ChallengeRouteType.normal => 'normal',
    ChallengeRouteType.lowPressure => 'low_pressure',
    ChallengeRouteType.advanced => 'advanced',
  };

  static ChallengeRouteType _routeFromWire(String value) => switch (value) {
    'normal' => ChallengeRouteType.normal,
    'low_pressure' => ChallengeRouteType.lowPressure,
    'advanced' => ChallengeRouteType.advanced,
    _ => throw FormatException('Unknown challenge route: $value'),
  };
}

abstract final class SqliteReflectionMapper {
  static Map<String, Object?> toRow(PrivateReflection reflection) => {
    'reflection_id': reflection.reflectionId,
    'attempt_id': reflection.attemptId,
    'fear_before': reflection.fearBefore,
    'feel_after': reflection.feelAfter,
    'want_repeat': reflection.wantRepeat == null
        ? null
        : (reflection.wantRepeat! ? 1 : 0),
    'private_note': reflection.privateNote,
    'created_at': reflection.createdAt.toUtc().toIso8601String(),
    'updated_at': reflection.updatedAt.toUtc().toIso8601String(),
    'sync_preference': reflection.privateNote?.isNotEmpty == true
        ? 'local_only'
        : 'signals_only',
  };

  static PrivateReflection fromRow(Map<String, Object?> row) =>
      PrivateReflection(
        reflectionId: row['reflection_id'] as String,
        attemptId: row['attempt_id'] as String,
        fearBefore: (row['fear_before'] as num?)?.toInt(),
        feelAfter: (row['feel_after'] as num?)?.toInt(),
        wantRepeat: row['want_repeat'] == null
            ? null
            : (row['want_repeat'] as num).toInt() == 1,
        privateNote: row['private_note'] as String?,
        createdAt: DateTime.parse(row['created_at'] as String).toUtc(),
        updatedAt: DateTime.parse(row['updated_at'] as String).toUtc(),
      );
}

abstract final class SqliteProjectionMapper {
  static Map<String, Object?> progressToJson(ProgressProjection projection) => {
    'totalXp': projection.totalXp,
    'traitXp': {
      for (final entry in projection.traitXp.entries)
        entry.key.name: entry.value,
    },
    'rank': {
      'family': projection.rank.family.name,
      'tier': projection.rank.tier,
      'configRevision': projection.rank.configRevision,
    },
    'rankProgress': projection.rankProgress,
    'momentum': momentumToJson(projection.momentum),
    'difficulty': {
      for (final entry in projection.difficulty.entries)
        entry.key.name: {
          'rating': entry.value.rating,
          'confidence': entry.value.confidence,
          'observations': entry.value.observations,
          'recommendedIntensity': entry.value.recommendedIntensity,
          'updatedAt': entry.value.updatedAt.toUtc().toIso8601String(),
        },
    },
    'completedCount': projection.completedCount,
    'attemptedCount': projection.attemptedCount,
    'updatedAt': projection.updatedAt.toUtc().toIso8601String(),
  };

  static ProgressProjection progressFromRow(Map<String, Object?> row) {
    final json = _object(row['snapshot_json'] as String);
    final updatedAt =
        _date(json['updatedAt']) ??
        DateTime.parse(row['updated_at'] as String).toUtc();
    final traitJson = json['traitXp'] as Map<String, dynamic>? ?? const {};
    final rankJson = json['rank'] as Map<String, dynamic>?;
    final difficultyJson =
        json['difficulty'] as Map<String, dynamic>? ?? const {};
    return ProgressProjection(
      totalXp: (json['totalXp'] as num?)?.toInt() ?? 0,
      traitXp: {
        for (final trait in Trait.values)
          trait: (traitJson[trait.name] as num?)?.toInt() ?? 0,
      },
      rank: rankJson == null
          ? PrestigeRank(
              family: RankFamily.spark,
              tier: 1,
              configRevision: 'local_v1',
            )
          : PrestigeRank(
              family: RankFamily.values.byName(rankJson['family'] as String),
              tier: (rankJson['tier'] as num).toInt(),
              configRevision: rankJson['configRevision'] as String,
            ),
      rankProgress: (json['rankProgress'] as num?)?.toDouble() ?? 0,
      momentum: json['momentum'] is Map<String, dynamic>
          ? momentumFromJson(json['momentum'] as Map<String, dynamic>)
          : MomentumState.empty(),
      difficulty: {
        for (final trait in Trait.values)
          trait: _difficulty(
            trait,
            difficultyJson[trait.name] as Map<String, dynamic>?,
            updatedAt,
          ),
      },
      completedCount: (json['completedCount'] as num?)?.toInt() ?? 0,
      attemptedCount: (json['attemptedCount'] as num?)?.toInt() ?? 0,
      updatedAt: updatedAt,
      source: ProjectionSource.localCheckpoint,
    );
  }

  static Map<String, Object?> momentumToJson(MomentumState state) => {
    'currentDays': state.currentDays,
    'longestDays': state.longestDays,
    'earnedToday': state.earnedToday,
    'shieldsAvailable': state.shieldsAvailable,
    'lastEarnedLocalDate': state.lastEarnedLocalDate,
    'lastEarnedAtUtc': state.lastEarnedAtUtc?.toUtc().toIso8601String(),
    'lastEarnedTimezoneId': state.lastEarnedTimezoneId,
    'protectedLocalDates': state.protectedLocalDates.toList()..sort(),
    'nextMilestone': state.nextMilestone,
    'pendingLocalDate': state.pendingLocalDate,
    'pendingEarnedAtUtc': state.pendingEarnedAtUtc?.toUtc().toIso8601String(),
    'pendingTimezoneId': state.pendingTimezoneId,
    'policyRevision': state.policyRevision,
  };

  static MomentumState momentumFromJson(Map<String, dynamic> json) =>
      MomentumState(
        currentDays: (json['currentDays'] as num?)?.toInt() ?? 0,
        longestDays: (json['longestDays'] as num?)?.toInt() ?? 0,
        earnedToday: json['earnedToday'] == true,
        shieldsAvailable: (json['shieldsAvailable'] as num?)?.toInt() ?? 0,
        lastEarnedLocalDate: json['lastEarnedLocalDate'] as String?,
        lastEarnedAtUtc: _date(json['lastEarnedAtUtc']),
        lastEarnedTimezoneId: json['lastEarnedTimezoneId'] as String?,
        protectedLocalDates: Set<String>.from(
          json['protectedLocalDates'] as List<dynamic>? ?? const [],
        ),
        nextMilestone: (json['nextMilestone'] as num?)?.toInt() ?? 3,
        pendingLocalDate: json['pendingLocalDate'] as String?,
        pendingEarnedAtUtc: _date(json['pendingEarnedAtUtc']),
        pendingTimezoneId: json['pendingTimezoneId'] as String?,
        policyRevision:
            json['policyRevision'] as String? ?? 'momentum_policy_dev_v1',
      );

  static DifficultyState _difficulty(
    Trait trait,
    Map<String, dynamic>? json,
    DateTime fallbackTime,
  ) => DifficultyState(
    trait: trait,
    rating: (json?['rating'] as num?)?.toDouble() ?? 2,
    confidence: (json?['confidence'] as num?)?.toDouble() ?? 0,
    observations: (json?['observations'] as num?)?.toInt() ?? 0,
    recommendedIntensity: (json?['recommendedIntensity'] as num?)?.toInt() ?? 2,
    updatedAt: _date(json?['updatedAt']) ?? fallbackTime,
  );
}

Map<String, dynamic> _object(String source) {
  final decoded = jsonDecode(source);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Stored vNext JSON must be an object');
  }
  return decoded;
}

DateTime? _date(Object? value) {
  if (value == null) return null;
  if (value is! String || value.isEmpty) {
    throw const FormatException('Stored date must be an ISO string');
  }
  return DateTime.parse(value).toUtc();
}

Uri? _uri(Object? value) {
  if (value == null) return null;
  if (value is! String || value.isEmpty) {
    throw const FormatException('Stored URI must be a string');
  }
  return Uri.parse(value);
}
