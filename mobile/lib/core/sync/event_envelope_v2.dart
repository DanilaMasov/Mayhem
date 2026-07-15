import 'dart:convert';

enum CanonicalEventTypeV2 {
  onboardingStarted('onboarding_started'),
  calibrationAnswered('calibration_answered'),
  safetyBoundaryAccepted('safety_boundary_accepted'),
  onboardingCompleted('onboarding_completed'),
  feedBatchReceived('feed_batch_received'),
  feedItemImpressed('feed_item_impressed'),
  feedItemOpened('feed_item_opened'),
  feedItemSkipped('feed_item_skipped'),
  feedItemSaved('feed_item_saved'),
  challengeAccepted('challenge_accepted'),
  challengeRouteSelected('challenge_route_selected'),
  challengeDeferred('challenge_deferred'),
  challengeAbandoned('challenge_abandoned'),
  challengeAttempted('challenge_attempted'),
  challengeCompleted('challenge_completed'),
  reflectionSubmitted('reflection_submitted'),
  momentumDayEarned('momentum_day_earned'),
  momentumShieldGranted('momentum_shield_granted'),
  momentumShieldConsumed('momentum_shield_consumed'),
  rankUnlocked('rank_unlocked'),
  seasonJoined('season_joined'),
  seasonDayCompleted('season_day_completed'),
  bossParticipated('boss_participated'),
  artifactUnlocked('artifact_unlocked'),
  accountLinked('account_linked'),
  privacyPreferenceChanged('privacy_preference_changed');

  const CanonicalEventTypeV2(this.wireName);

  final String wireName;

  static CanonicalEventTypeV2 fromWire(String value) {
    return CanonicalEventTypeV2.values.firstWhere(
      (event) => event.wireName == value,
      orElse: () => throw FormatException('Unknown v2 event type: $value'),
    );
  }
}

class EventDraftV2 {
  EventDraftV2({
    required this.eventId,
    required this.eventType,
    required this.occurredAtUtc,
    required this.timezoneId,
    required this.timezoneOffsetMinutes,
    required Map<String, Object?> payload,
    this.assignmentId,
    this.attemptId,
    this.contentId,
    this.contentRevision,
  }) : payload = Map.unmodifiable(payload);

  final String eventId;
  final CanonicalEventTypeV2 eventType;
  final DateTime occurredAtUtc;
  final String timezoneId;
  final int timezoneOffsetMinutes;
  final String? assignmentId;
  final String? attemptId;
  final String? contentId;
  final int? contentRevision;
  final Map<String, Object?> payload;
}

class EventEnvelopeV2 {
  static const schemaVersion = 2;
  static const maxPayloadBytes = 64 * 1024;

  EventEnvelopeV2({
    required this.eventId,
    required this.eventType,
    required this.localUserId,
    required this.installationId,
    required this.clientSequence,
    required this.occurredAtUtc,
    required this.timezoneId,
    required this.timezoneOffsetMinutes,
    required Map<String, Object?> payload,
    this.remoteUserId,
    this.assignmentId,
    this.attemptId,
    this.contentId,
    this.contentRevision,
  }) : payload = Map.unmodifiable(payload) {
    validate();
  }

  factory EventEnvelopeV2.fromDatabaseMap(Map<String, Object?> row) {
    final decoded = jsonDecode(row['payload_json'] as String);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Event v2 payload must be an object');
    }
    return EventEnvelopeV2(
      eventId: row['event_id'] as String,
      eventType: CanonicalEventTypeV2.fromWire(row['event_type'] as String),
      localUserId: row['local_user_id'] as String,
      installationId: row['installation_id'] as String,
      clientSequence: (row['client_sequence'] as num).toInt(),
      occurredAtUtc: DateTime.parse(row['occurred_at_utc'] as String),
      timezoneId: row['timezone_id'] as String,
      timezoneOffsetMinutes: (row['timezone_offset_minutes'] as num).toInt(),
      assignmentId: row['assignment_id'] as String?,
      attemptId: row['attempt_id'] as String?,
      contentId: row['content_id'] as String?,
      contentRevision: (row['content_revision'] as num?)?.toInt(),
      payload: Map<String, Object?>.from(decoded),
    );
  }

  final String eventId;
  final CanonicalEventTypeV2 eventType;
  final String localUserId;
  final String? remoteUserId;
  final String installationId;
  final int clientSequence;
  final DateTime occurredAtUtc;
  final String timezoneId;
  final int timezoneOffsetMinutes;
  final String? assignmentId;
  final String? attemptId;
  final String? contentId;
  final int? contentRevision;
  final Map<String, Object?> payload;

  void validate() {
    for (final identity in [eventId, localUserId, installationId, timezoneId]) {
      if (identity.trim().isEmpty) {
        throw const FormatException('Event identity must not be empty');
      }
    }
    if (clientSequence < 1) {
      throw const FormatException('Client sequence must be positive');
    }
    if (!occurredAtUtc.isUtc) {
      throw const FormatException('Event time must be UTC');
    }
    if (timezoneOffsetMinutes < -14 * 60 || timezoneOffsetMinutes > 14 * 60) {
      throw const FormatException('Timezone offset is invalid');
    }
    if (contentId == null && contentRevision != null ||
        contentId != null &&
            (contentRevision == null || contentRevision! < 1)) {
      throw const FormatException('Content ID and revision must be paired');
    }
    _rejectPrivateNote(payload);
    final encoded = utf8.encode(jsonEncode(payload));
    if (encoded.length > maxPayloadBytes) {
      throw const FormatException('Event payload exceeds the size limit');
    }
  }

  Map<String, Object?> toSyncJson() => {
    'eventId': eventId,
    'schemaVersion': schemaVersion,
    'eventType': eventType.wireName,
    'localUserId': localUserId,
    'remoteUserId': remoteUserId,
    'installationId': installationId,
    'clientSequence': clientSequence,
    'occurredAtUtc': occurredAtUtc.toIso8601String(),
    'timezoneId': timezoneId,
    'timezoneOffsetMinutes': timezoneOffsetMinutes,
    'assignmentId': assignmentId,
    'attemptId': attemptId,
    'contentId': contentId,
    'contentRevision': contentRevision,
    'payload': payload,
  };

  Map<String, Object?> toDatabaseMap() => {
    'event_id': eventId,
    'local_user_id': localUserId,
    'installation_id': installationId,
    'client_sequence': clientSequence,
    'schema_version': schemaVersion,
    'event_type': eventType.wireName,
    'assignment_id': assignmentId,
    'attempt_id': attemptId,
    'content_id': contentId,
    'content_revision': contentRevision,
    'occurred_at_utc': occurredAtUtc.toIso8601String(),
    'timezone_id': timezoneId,
    'timezone_offset_minutes': timezoneOffsetMinutes,
    'payload_json': jsonEncode(payload),
    'sync_status': 'pending',
    'attempt_count': 0,
  };

  static void _rejectPrivateNote(Object? value) {
    if (value is Map) {
      for (final entry in value.entries) {
        final key = entry.key.toString();
        final normalizedKey = key.replaceAll('_', '').toLowerCase();
        if (_privateNoteKeys.contains(normalizedKey)) {
          throw const FormatException(
            'Private note text is forbidden in event payloads',
          );
        }
        _rejectPrivateNote(entry.value);
      }
    } else if (value is Iterable) {
      for (final item in value) {
        _rejectPrivateNote(item);
      }
    }
  }

  static const _privateNoteKeys = {
    'note',
    'notebody',
    'privatenote',
    'privatenotebody',
  };
}
