import '../../../content/domain/content_item_revision.dart';
import '../../../core/feature_flags/feature_flags.dart';
import '../../../core/sync/event_envelope_v2.dart';
import '../../progress/domain/development_rank_config.dart';
import '../../progress/domain/progress_models.dart';
import '../../streak/domain/momentum_state.dart';
import 'remote_content_checksum.dart';

class CapabilityRevisionSet {
  CapabilityRevisionSet(Map<String, int> revisions)
    : revisions = Map.unmodifiable(revisions) {
    for (final entry in revisions.entries) {
      if (entry.key.trim().isEmpty || entry.value < 1) {
        throw const FormatException('Capability revision is invalid');
      }
    }
  }

  final Map<String, int> revisions;

  bool supports(String key, int revision) => (revisions[key] ?? 0) >= revision;

  Map<String, Object?> toJson() => Map<String, Object?>.from(revisions);
}

class InstallationRegistration {
  InstallationRegistration({
    required this.installationId,
    required this.remoteUserId,
    required this.registeredAt,
  }) {
    _nonEmpty(installationId, 'installationId');
    _nonEmpty(remoteUserId, 'remoteUserId');
  }

  factory InstallationRegistration.fromJson(Map<String, dynamic> json) =>
      InstallationRegistration(
        installationId: _string(json, 'installationId'),
        remoteUserId: _string(json, 'remoteUserId'),
        registeredAt: _utcDate(json, 'registeredAt'),
      );

  final String installationId;
  final String remoteUserId;
  final DateTime registeredAt;
}

enum RemoteEventDisposition {
  accepted,
  duplicateEvent,
  staleContentButValidAssignment,
  invalidTransition,
  unknownAssignment,
  permanentSchema;

  static RemoteEventDisposition fromWire(String value) => switch (value) {
    'accepted' => RemoteEventDisposition.accepted,
    'duplicate_event' => RemoteEventDisposition.duplicateEvent,
    'stale_content_but_valid_assignment' =>
      RemoteEventDisposition.staleContentButValidAssignment,
    'invalid_transition' => RemoteEventDisposition.invalidTransition,
    'unknown_assignment' => RemoteEventDisposition.unknownAssignment,
    'permanent_schema' => RemoteEventDisposition.permanentSchema,
    _ => throw FormatException('Unknown event disposition: $value'),
  };
}

class RemoteEventResult {
  const RemoteEventResult({
    required this.eventId,
    required this.accepted,
    required this.disposition,
  });

  factory RemoteEventResult.fromJson(Map<String, dynamic> json) {
    final accepted = json['accepted'];
    if (accepted is! bool) {
      throw const FormatException('Event result acceptance is invalid');
    }
    return RemoteEventResult(
      eventId: _string(json, 'eventId'),
      accepted: accepted,
      disposition: RemoteEventDisposition.fromWire(
        _string(json, 'disposition'),
      ),
    );
  }

  final String eventId;
  final bool accepted;
  final RemoteEventDisposition disposition;
}

class EventIngestAckV2 {
  EventIngestAckV2({
    required List<RemoteEventResult> results,
    required this.projection,
    required this.serverTime,
  }) : results = List.unmodifiable(results) {
    final ids = <String>{};
    if (results.any((result) => !ids.add(result.eventId))) {
      throw const FormatException('Event result IDs must be unique');
    }
  }

  factory EventIngestAckV2.fromJson(Map<String, dynamic> json) =>
      EventIngestAckV2(
        results: _objectList(
          json,
          'results',
        ).map(RemoteEventResult.fromJson).toList(growable: false),
        projection: ServerProjectionSnapshot.fromJson(
          _object(json, 'projection'),
        ),
        serverTime: _utcDate(json, 'serverTime'),
      );

  final List<RemoteEventResult> results;
  final ServerProjectionSnapshot projection;
  final DateTime serverTime;
}

class RemoteFlagRecord {
  RemoteFlagRecord({
    required this.flag,
    required this.enabled,
    required this.updatedAt,
    this.requiredCapabilityKey,
    this.requiredCapabilityRevision,
  }) {
    final hasRequirement =
        requiredCapabilityKey != null || requiredCapabilityRevision != null;
    if (hasRequirement &&
        (requiredCapabilityKey?.trim().isEmpty != false ||
            (requiredCapabilityRevision ?? 0) < 1)) {
      throw const FormatException('Remote flag capability is invalid');
    }
  }

  factory RemoteFlagRecord.fromJson(Map<String, dynamic> json) {
    final key = _string(json, 'key');
    final enabled = json['enabled'];
    if (enabled is! bool) {
      throw const FormatException('Remote flag value is invalid');
    }
    final capabilityKeyValue = json['requiredCapabilityKey'];
    if (capabilityKeyValue != null && capabilityKeyValue is! String) {
      throw const FormatException('Remote flag capability key is invalid');
    }
    final capabilityRevisionValue = json['requiredCapabilityRevision'];
    int? capabilityRevision;
    if (capabilityRevisionValue != null) {
      if (capabilityRevisionValue is! num ||
          !capabilityRevisionValue.isFinite ||
          capabilityRevisionValue.toInt() != capabilityRevisionValue) {
        throw const FormatException(
          'Remote flag capability revision is invalid',
        );
      }
      capabilityRevision = capabilityRevisionValue.toInt();
    }
    return RemoteFlagRecord(
      flag: MayhemFeatureFlag.values.firstWhere(
        (flag) => flag.wireName == key,
        orElse: () => throw FormatException('Unknown feature flag: $key'),
      ),
      enabled: enabled,
      requiredCapabilityKey: capabilityKeyValue as String?,
      requiredCapabilityRevision: capabilityRevision,
      updatedAt: _utcDate(json, 'updatedAt'),
    );
  }

  final MayhemFeatureFlag flag;
  final bool enabled;
  final String? requiredCapabilityKey;
  final int? requiredCapabilityRevision;
  final DateTime updatedAt;

  Map<String, Object?> toCacheJson() => {
    'key': flag.wireName,
    'enabled': enabled,
    'requiredCapabilityKey': requiredCapabilityKey,
    'requiredCapabilityRevision': requiredCapabilityRevision,
    'updatedAt': updatedAt.toIso8601String(),
  };
}

class ContentManifestReference {
  ContentManifestReference({
    required this.contentId,
    required this.revision,
    required this.locale,
    required this.type,
    required this.checksum,
  }) {
    _nonEmpty(contentId, 'contentId');
    _nonEmpty(locale, 'locale');
    _validRevision(revision);
    _validChecksum(checksum);
  }

  factory ContentManifestReference.fromJson(
    Map<String, dynamic> json,
    String locale,
  ) => ContentManifestReference(
    contentId: _string(json, 'contentId'),
    revision: _integer(json, 'revision'),
    locale: locale,
    type: _contentType(_string(json, 'type')),
    checksum: _string(json, 'checksum'),
  );

  final String contentId;
  final int revision;
  final String locale;
  final ContentItemType type;
  final String checksum;

  Map<String, Object?> toRequestJson() => {
    'contentId': contentId,
    'revision': revision,
    'locale': locale,
  };

  String get identity => '$contentId@$revision:$locale';
}

class RemoteContentManifest {
  RemoteContentManifest({
    required this.revision,
    required this.locale,
    required this.generatedAt,
    required List<ContentManifestReference> items,
  }) : items = List.unmodifiable(items) {
    if (revision < 0 || locale.trim().isEmpty) {
      throw const FormatException('Content manifest is invalid');
    }
    final identities = <String>{};
    if (items.any((item) => !identities.add(item.identity))) {
      throw const FormatException('Content manifest contains duplicates');
    }
  }

  factory RemoteContentManifest.fromJson(Map<String, dynamic> json) {
    final locale = _string(json, 'locale');
    return RemoteContentManifest(
      revision: _integer(json, 'manifestRevision'),
      locale: locale,
      generatedAt: _utcDate(json, 'generatedAt'),
      items: _objectList(json, 'items')
          .map((item) => ContentManifestReference.fromJson(item, locale))
          .toList(growable: false),
    );
  }

  final int revision;
  final String locale;
  final DateTime generatedAt;
  final List<ContentManifestReference> items;
}

class RemoteContentRevision {
  RemoteContentRevision({required this.revision, required this.serverChecksum});

  factory RemoteContentRevision.fromJson(Map<String, dynamic> json) {
    final checksum = _string(json, 'checksum');
    _validChecksum(checksum);
    if (RemoteContentChecksum.compute(json) != checksum) {
      throw const FormatException('Remote content checksum mismatch');
    }
    final safetyJson = _object(json, 'safety');
    final mediaJson = json['media'] == null
        ? null
        : Map<String, dynamic>.from(json['media'] as Map);
    final safety = SafetyMetadata(
      safetyReviewed: safetyJson['safetyReviewed'] == true,
      safetyRevision: _integer(safetyJson, 'safetyRevision'),
      requiresContextWarning: safetyJson['requiresContextWarning'] == true,
      disallowedContexts: Set<String>.from(
        safetyJson['disallowedContexts'] as List<dynamic>? ?? const [],
      ),
      lowPressureRoute: safetyJson['lowPressureRoute'] as String?,
      exitCopy: _string(safetyJson, 'exitCopy'),
      advancedRouteSafetyApproved:
          safetyJson['advancedRouteSafetyApproved'] == true,
      reviewerId: safetyJson['reviewerId'] as String?,
      reviewedAt: _optionalUtcDate(safetyJson['reviewedAt']),
    );
    final media = mediaJson == null
        ? null
        : MediaDescriptor(
            type: MediaType.values.byName(_string(mediaJson, 'type')),
            remoteUri: _optionalUri(mediaJson['remoteUri']),
            bundledAsset: mediaJson['bundledAsset'] as String?,
            posterUri: _optionalUri(mediaJson['posterUri']),
            aspectRatio: _number(mediaJson, 'aspectRatio').toDouble(),
            checksum: _string(mediaJson, 'checksum'),
            byteSize: _integer(mediaJson, 'byteSize'),
            captionTrack: mediaJson['captionTrack'] as String?,
            fallback: MediaFallback.values.byName(
              _string(mediaJson, 'fallback'),
            ),
          );
    return RemoteContentRevision(
      serverChecksum: checksum,
      revision: ContentItemRevision(
        contentId: _string(json, 'contentId'),
        revision: _integer(json, 'revision'),
        type: _contentType(_string(json, 'type')),
        locale: _string(json, 'locale'),
        publishedAt: _utcDate(json, 'publishedAt'),
        startsAt: _optionalUtcDate(json['startsAt']),
        endsAt: _optionalUtcDate(json['endsAt']),
        payload: Map<String, Object?>.from(_object(json, 'payload')),
        safety: safety,
        media: media,
        active: false,
        source: ContentRevisionSource.remote,
        checksum: checksum,
      ),
    );
  }

  final ContentItemRevision revision;
  final String serverChecksum;
}

class RemoteFeedAssignment {
  RemoteFeedAssignment({
    required this.assignmentId,
    required this.contentId,
    required this.contentRevision,
    required this.locale,
    required this.position,
    required this.assignmentReason,
    this.expiresAt,
  }) {
    _nonEmpty(assignmentId, 'assignmentId');
    _nonEmpty(contentId, 'contentId');
    _validRevision(contentRevision);
    if (position < 0) throw const FormatException('Feed position is invalid');
  }

  factory RemoteFeedAssignment.fromJson(Map<String, dynamic> json) =>
      RemoteFeedAssignment(
        assignmentId: _string(json, 'assignmentId'),
        contentId: _string(json, 'contentId'),
        contentRevision: _integer(json, 'contentRevision'),
        locale: _string(json, 'locale'),
        position: _integer(json, 'position'),
        assignmentReason: _string(json, 'assignmentReason'),
        expiresAt: _optionalUtcDate(json['expiresAt']),
      );

  final String assignmentId;
  final String contentId;
  final int contentRevision;
  final String locale;
  final int position;
  final String assignmentReason;
  final DateTime? expiresAt;
}

class RemoteFeedBatch {
  RemoteFeedBatch({
    required this.batchId,
    required this.algorithmRevision,
    required this.createdAt,
    required List<RemoteFeedAssignment> assignments,
    this.expiresAt,
  }) : assignments = List.unmodifiable(assignments) {
    if (assignments.length > 20) {
      throw const FormatException('Remote Feed batch exceeds the item limit');
    }
    final assignmentIds = <String>{};
    final positions = <int>{};
    if (assignments.any(
      (item) =>
          !assignmentIds.add(item.assignmentId) ||
          !positions.add(item.position),
    )) {
      throw const FormatException('Remote Feed batch contains duplicates');
    }
  }

  factory RemoteFeedBatch.fromJson(Map<String, dynamic> json) =>
      RemoteFeedBatch(
        batchId: _string(json, 'batchId'),
        algorithmRevision: _string(json, 'algorithmRevision'),
        createdAt: _utcDate(json, 'createdAt'),
        expiresAt: _optionalUtcDate(json['expiresAt']),
        assignments: _objectList(
          json,
          'assignments',
        ).map(RemoteFeedAssignment.fromJson).toList(growable: false),
      );

  final String batchId;
  final String algorithmRevision;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final List<RemoteFeedAssignment> assignments;
}

class ServerMomentumSnapshot {
  ServerMomentumSnapshot({
    required this.currentDays,
    required this.longestDays,
    required this.shieldsAvailable,
    required Set<String> protectedLocalDates,
    required this.policyRevision,
    required this.projectionRevision,
    this.lastEarnedLocalDate,
    this.lastEarnedAtUtc,
    this.lastEarnedTimezoneId,
    this.pendingLocalDate,
    this.pendingEarnedAtUtc,
    this.pendingTimezoneId,
  }) : protectedLocalDates = Set.unmodifiable(protectedLocalDates) {
    if (projectionRevision < 0 || policyRevision != 'momentum_policy_dev_v1') {
      throw const FormatException('Server Momentum revision is unsupported');
    }
  }

  factory ServerMomentumSnapshot.fromJson(Map<String, dynamic> json) =>
      ServerMomentumSnapshot(
        currentDays: _integer(json, 'currentDays'),
        longestDays: _integer(json, 'longestDays'),
        shieldsAvailable: _integer(json, 'shieldsAvailable'),
        lastEarnedLocalDate: json['lastEarnedLocalDate'] as String?,
        lastEarnedAtUtc: _optionalUtcDate(json['lastEarnedAtUtc']),
        lastEarnedTimezoneId: json['lastEarnedTimezoneId'] as String?,
        protectedLocalDates: Set<String>.from(
          json['protectedLocalDates'] as List<dynamic>? ?? const [],
        ),
        pendingLocalDate: json['pendingLocalDate'] as String?,
        pendingEarnedAtUtc: _optionalUtcDate(json['pendingEarnedAtUtc']),
        pendingTimezoneId: json['pendingTimezoneId'] as String?,
        policyRevision: _string(json, 'policyRevision'),
        projectionRevision: _integer(json, 'projectionRevision'),
      );

  final int currentDays;
  final int longestDays;
  final int shieldsAvailable;
  final String? lastEarnedLocalDate;
  final DateTime? lastEarnedAtUtc;
  final String? lastEarnedTimezoneId;
  final Set<String> protectedLocalDates;
  final String? pendingLocalDate;
  final DateTime? pendingEarnedAtUtc;
  final String? pendingTimezoneId;
  final String policyRevision;
  final int projectionRevision;

  MomentumState toLocal({required MomentumState previous}) => MomentumState(
    currentDays: currentDays,
    longestDays: longestDays > previous.longestDays
        ? longestDays
        : previous.longestDays,
    earnedToday:
        lastEarnedLocalDate != null &&
        lastEarnedLocalDate == previous.lastEarnedLocalDate &&
        previous.earnedToday,
    shieldsAvailable: shieldsAvailable,
    lastEarnedLocalDate: lastEarnedLocalDate,
    lastEarnedAtUtc: lastEarnedAtUtc,
    lastEarnedTimezoneId: lastEarnedTimezoneId,
    protectedLocalDates: {
      ...previous.protectedLocalDates,
      ...protectedLocalDates,
    },
    nextMilestone: _nextMomentumMilestone(currentDays),
    pendingLocalDate: pendingLocalDate,
    pendingEarnedAtUtc: pendingEarnedAtUtc,
    pendingTimezoneId: pendingTimezoneId,
    policyRevision: policyRevision,
  );
}

class RemoteOwnedArtifact {
  RemoteOwnedArtifact({
    required this.artifactId,
    required this.seasonId,
    required this.seasonRevision,
    required this.bossEventId,
    required this.unlockedAt,
  }) {
    _nonEmpty(artifactId, 'artifactId');
    _nonEmpty(seasonId, 'seasonId');
    _nonEmpty(bossEventId, 'bossEventId');
    _validRevision(seasonRevision);
  }

  factory RemoteOwnedArtifact.fromJson(Map<String, dynamic> json) =>
      RemoteOwnedArtifact(
        artifactId: _string(json, 'artifactId'),
        seasonId: _string(json, 'seasonId'),
        seasonRevision: _integer(json, 'seasonRevision'),
        bossEventId: _string(json, 'bossEventId'),
        unlockedAt: _utcDate(json, 'unlockedAt'),
      );

  final String artifactId;
  final String seasonId;
  final int seasonRevision;
  final String bossEventId;
  final DateTime unlockedAt;
}

class ServerProjectionSnapshot {
  ServerProjectionSnapshot({
    required this.projection,
    required this.projectionRevision,
    required this.rewardPolicyRevision,
    required this.momentum,
    required List<RemoteOwnedArtifact> ownedArtifacts,
  }) : ownedArtifacts = List.unmodifiable(ownedArtifacts) {
    if (projectionRevision < 0 ||
        rewardPolicyRevision != 'reward_policy_dev_v1') {
      throw const FormatException('Server projection revision is unsupported');
    }
    final artifactIds = <String>{};
    if (ownedArtifacts.any(
      (artifact) => !artifactIds.add(artifact.artifactId),
    )) {
      throw const FormatException('Server artifact ownership is duplicated');
    }
  }

  factory ServerProjectionSnapshot.fromJson(Map<String, dynamic> json) {
    final traitJson = _object(json, 'traitXp');
    final traitXp = {
      for (final trait in Trait.values) trait: _integer(traitJson, trait.name),
    };
    final totalXp = _integer(json, 'totalXp');
    final rankJson = _object(json, 'rank');
    final serverRank = PrestigeRank(
      family: RankFamily.values.byName(_string(rankJson, 'family')),
      tier: _integer(rankJson, 'tier'),
      configRevision: _string(rankJson, 'configRevision'),
    );
    final hasDynamicRating = json['ratingScore'] != null;
    if (hasDynamicRating &&
        json['ratingModelRevision'] != 'rating_model_dev_v1') {
      throw const FormatException('Server rating revision is unsupported');
    }
    final ratingScore = switch (json['ratingScore']) {
      final num value when value.toInt() == value && value >= 0 =>
        value.toInt(),
      null when serverRank.configRevision == 'rank_config_dev_v1' =>
        DevelopmentRankConfig.migrateLegacyRating(
          rank: serverRank,
          rankProgress: 0,
        ),
      _ => throw const FormatException('Server rating score is invalid'),
    };
    final peakRatingScore = switch (json['peakRatingScore']) {
      final num value when value.toInt() == value && value >= ratingScore =>
        value.toInt(),
      null => ratingScore,
      _ => throw const FormatException('Server peak rating is invalid'),
    };
    final resolved = DevelopmentRankConfig.policy().resolve(
      ratingScore: ratingScore,
      traitXp: traitXp,
    );
    final supportedRankRevision =
        serverRank.configRevision == DevelopmentRankConfig.revision ||
        serverRank.configRevision == 'rank_config_dev_v1';
    if (serverRank.stableId != resolved.rank.stableId ||
        !supportedRankRevision) {
      throw const FormatException('Server rank diverges from frozen config');
    }
    final updatedAt = _utcDate(json, 'updatedAt');
    final difficultyJson = _object(json, 'difficulty');
    final difficulty = <Trait, DifficultyState>{};
    for (final trait in Trait.values) {
      final source = difficultyJson[trait.name];
      if (source == null) {
        difficulty[trait] = DifficultyState(
          trait: trait,
          rating: 2,
          confidence: 0,
          observations: 0,
          recommendedIntensity: 2,
          updatedAt: updatedAt,
        );
        continue;
      }
      final item = Map<String, dynamic>.from(source as Map);
      if (_string(item, 'algorithmRevision') != 'difficulty_model_dev_v1') {
        throw const FormatException(
          'Server difficulty revision is unsupported',
        );
      }
      difficulty[trait] = DifficultyState(
        trait: trait,
        rating: _number(item, 'rating').toDouble(),
        confidence: _number(item, 'confidence').toDouble(),
        observations: _integer(item, 'observations'),
        recommendedIntensity: _integer(item, 'recommendedIntensity'),
        updatedAt: _utcDate(item, 'updatedAt'),
      );
    }
    final momentum = ServerMomentumSnapshot.fromJson(_object(json, 'momentum'));
    final localMomentum = momentum.toLocal(previous: MomentumState.empty());
    final ownedArtifacts = json['ownedArtifacts'] == null
        ? const <RemoteOwnedArtifact>[]
        : _objectList(
            json,
            'ownedArtifacts',
          ).map(RemoteOwnedArtifact.fromJson).toList(growable: false);
    return ServerProjectionSnapshot(
      projectionRevision: _integer(json, 'projectionRevision'),
      rewardPolicyRevision: _string(json, 'rewardPolicyRevision'),
      momentum: momentum,
      ownedArtifacts: ownedArtifacts,
      projection: ProgressProjection(
        totalXp: totalXp,
        ratingScore: ratingScore,
        peakRatingScore: peakRatingScore,
        traitXp: traitXp,
        rank: resolved.rank,
        rankProgress: resolved.progressToNext,
        momentum: localMomentum,
        difficulty: difficulty,
        completedCount: _integer(json, 'completedCount'),
        attemptedCount: _integer(json, 'attemptedCount'),
        updatedAt: updatedAt,
        source: ProjectionSource.serverReconciled,
      ),
    );
  }

  final ProgressProjection projection;
  final int projectionRevision;
  final String rewardPolicyRevision;
  final ServerMomentumSnapshot momentum;
  final List<RemoteOwnedArtifact> ownedArtifacts;
}

class RemoteSeasonParticipationSnapshot {
  RemoteSeasonParticipationSnapshot({
    required this.seasonId,
    required this.seasonRevision,
    required this.joinedAt,
    required Set<int> completedDays,
    this.bossParticipatedAt,
  }) : completedDays = Set.unmodifiable(completedDays) {
    _nonEmpty(seasonId, 'seasonId');
    _validRevision(seasonRevision);
    if (completedDays.any((day) => day < 1 || day > 7) ||
        bossParticipatedAt?.isBefore(joinedAt) == true) {
      throw const FormatException('Remote Season participation is invalid');
    }
  }

  factory RemoteSeasonParticipationSnapshot.fromJson(
    Map<String, dynamic> json,
  ) {
    final values = json['completedDays'];
    if (values is! List ||
        values.any((value) => value is! num || value.toInt() != value)) {
      throw const FormatException('completedDays must contain integers');
    }
    final days = values.cast<num>().map((value) => value.toInt()).toSet();
    if (days.length != values.length) {
      throw const FormatException('completedDays must be unique');
    }
    return RemoteSeasonParticipationSnapshot(
      seasonId: _string(json, 'seasonId'),
      seasonRevision: _integer(json, 'seasonRevision'),
      joinedAt: _utcDate(json, 'joinedAt'),
      completedDays: days,
      bossParticipatedAt: _optionalUtcDate(json['bossParticipatedAt']),
    );
  }

  final String seasonId;
  final int seasonRevision;
  final DateTime joinedAt;
  final Set<int> completedDays;
  final DateTime? bossParticipatedAt;

  Map<String, Object?> toJson() => {
    'seasonId': seasonId,
    'seasonRevision': seasonRevision,
    'joinedAt': joinedAt.toUtc().toIso8601String(),
    'completedDays': completedDays.toList()..sort(),
    'bossParticipatedAt': bossParticipatedAt?.toUtc().toIso8601String(),
  };
}

class RemoteSeasonSnapshot {
  RemoteSeasonSnapshot({
    required this.seasonId,
    required this.revision,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    required Map<String, dynamic> payload,
    this.participation,
  }) : payload = Map.unmodifiable(payload) {
    _nonEmpty(seasonId, 'seasonId');
    _nonEmpty(title, 'title');
    _validRevision(revision);
    if (!endsAt.isAfter(startsAt)) {
      throw const FormatException('Remote season schedule is invalid');
    }
    final remoteParticipation = participation;
    if (remoteParticipation != null &&
        (remoteParticipation.seasonId != seasonId ||
            remoteParticipation.seasonRevision != revision ||
            remoteParticipation.joinedAt.isBefore(startsAt) ||
            !remoteParticipation.joinedAt.isBefore(endsAt))) {
      throw const FormatException('Remote Season participation is mismatched');
    }
  }

  factory RemoteSeasonSnapshot.fromJson(Map<String, dynamic> json) =>
      RemoteSeasonSnapshot(
        seasonId: _string(json, 'seasonId'),
        revision: _integer(json, 'revision'),
        title: _string(json, 'title'),
        startsAt: _utcDate(json, 'startsAt'),
        endsAt: _utcDate(json, 'endsAt'),
        payload: _object(json, 'payload'),
        participation: json['participation'] == null
            ? null
            : RemoteSeasonParticipationSnapshot.fromJson(
                _object(json, 'participation'),
              ),
      );

  final String seasonId;
  final int revision;
  final String title;
  final DateTime startsAt;
  final DateTime endsAt;
  final Map<String, dynamic> payload;
  final RemoteSeasonParticipationSnapshot? participation;
}

class BootstrapPayload {
  BootstrapPayload({
    required this.remoteUserId,
    required this.localUserId,
    required this.installationId,
    required List<RemoteFlagRecord> flags,
    required this.projection,
    required this.contentManifest,
    required this.serverTime,
    this.activeSeason,
  }) : flags = List.unmodifiable(flags);

  factory BootstrapPayload.fromJson(Map<String, dynamic> json) {
    final identity = _object(json, 'identity');
    return BootstrapPayload(
      remoteUserId: _string(identity, 'remoteUserId'),
      localUserId: _string(identity, 'localUserId'),
      installationId: _string(identity, 'installationId'),
      flags: _parseFlagsFailClosed(json),
      projection: ServerProjectionSnapshot.fromJson(
        _object(json, 'projection'),
      ),
      contentManifest: RemoteContentManifest.fromJson(
        _object(json, 'contentManifest'),
      ),
      activeSeason: json['activeSeason'] == null
          ? null
          : RemoteSeasonSnapshot.fromJson(_object(json, 'activeSeason')),
      serverTime: _utcDate(json, 'serverTime'),
    );
  }

  final String remoteUserId;
  final String localUserId;
  final String installationId;
  final List<RemoteFlagRecord> flags;
  final ServerProjectionSnapshot projection;
  final RemoteContentManifest contentManifest;
  final RemoteSeasonSnapshot? activeSeason;
  final DateTime serverTime;
}

class DataDeletionReceipt {
  DataDeletionReceipt({
    required this.receiptId,
    required this.remoteUserId,
    required this.deletedAt,
    required this.authIdentityDeleted,
  }) {
    if (!authIdentityDeleted) {
      throw const FormatException('Remote deletion was not confirmed');
    }
  }

  factory DataDeletionReceipt.fromJson(Map<String, dynamic> json) =>
      DataDeletionReceipt(
        receiptId: _string(json, 'receiptId'),
        remoteUserId: _string(json, 'remoteUserId'),
        deletedAt: _utcDate(json, 'deletedAt'),
        authIdentityDeleted: json['authIdentityDeleted'] == true,
      );

  final String receiptId;
  final String remoteUserId;
  final DateTime deletedAt;
  final bool authIdentityDeleted;
}

abstract interface class VNextBackendGateway {
  Future<InstallationRegistration> registerInstallation({
    required String installationId,
    required String localUserId,
    required String platform,
    required String appVersion,
    required CapabilityRevisionSet capabilities,
  });

  Future<BootstrapPayload> getBootstrapPayload({
    required String installationId,
    required String locale,
    String environment = 'production',
  });

  Future<EventIngestAckV2> ingestEvents({
    required String installationId,
    required List<EventEnvelopeV2> events,
  });

  Future<RemoteContentManifest> getContentManifest({String locale = 'ru'});

  Future<List<RemoteContentRevision>> getContentRevisions(
    List<ContentManifestReference> revisions,
  );

  Future<RemoteFeedBatch> getFeedBatch({String locale = 'ru', int limit = 20});

  Future<RemoteSeasonSnapshot?> getActiveSeason();

  Future<DataDeletionReceipt> deleteMyData();
}

Map<String, dynamic> _object(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! Map) throw FormatException('$key must be an object');
  return Map<String, dynamic>.from(value);
}

List<Map<String, dynamic>> _objectList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List) throw FormatException('$key must be an array');
  return value
      .map((item) {
        if (item is! Map) throw FormatException('$key item must be an object');
        return Map<String, dynamic>.from(item);
      })
      .toList(growable: false);
}

String _string(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key must be a non-empty string');
  }
  return value;
}

num _number(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! num || !value.isFinite) {
    throw FormatException('$key must be a finite number');
  }
  return value;
}

int _integer(Map<String, dynamic> json, String key) {
  final value = _number(json, key);
  if (value.toInt() != value) {
    throw FormatException('$key must be an integer');
  }
  return value.toInt();
}

DateTime _utcDate(Map<String, dynamic> json, String key) {
  final parsed = DateTime.parse(_string(json, key));
  return parsed.toUtc();
}

DateTime? _optionalUtcDate(Object? value) {
  if (value == null) return null;
  if (value is! String || value.trim().isEmpty) {
    throw const FormatException('Optional date must be an ISO string');
  }
  return DateTime.parse(value).toUtc();
}

Uri? _optionalUri(Object? value) {
  if (value == null) return null;
  if (value is! String || value.trim().isEmpty) {
    throw const FormatException('Optional URI must be a string');
  }
  final uri = Uri.parse(value);
  if (!uri.hasScheme) throw const FormatException('Remote URI is invalid');
  return uri;
}

ContentItemType _contentType(String value) => switch (value) {
  'challenge' => ContentItemType.challenge,
  'microTraining' || 'micro_training' => ContentItemType.microTraining,
  'scenarioPoll' || 'scenario_poll' => ContentItemType.scenarioPoll,
  'editorialVideo' || 'editorial_video' => ContentItemType.editorialVideo,
  'atmosphericLoop' || 'atmospheric_loop' => ContentItemType.atmosphericLoop,
  'socialProof' || 'social_proof' => ContentItemType.socialProof,
  'seasonUpdate' || 'season_update' => ContentItemType.seasonUpdate,
  'bossRaid' || 'boss_raid' => ContentItemType.bossRaid,
  'progressInsight' || 'progress_insight' => ContentItemType.progressInsight,
  _ => throw FormatException('Unknown content type: $value'),
};

void _nonEmpty(String value, String name) {
  if (value.trim().isEmpty) throw FormatException('$name must not be empty');
}

void _validRevision(int value) {
  if (value < 1) throw const FormatException('Revision must be positive');
}

void _validChecksum(String value) {
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(value)) {
    throw const FormatException('Checksum must be lowercase SHA-256');
  }
}

int _nextMomentumMilestone(int current) {
  for (final milestone in const [3, 7, 14, 30, 50, 100]) {
    if (milestone > current) return milestone;
  }
  return ((current ~/ 50) + 1) * 50;
}

List<RemoteFlagRecord> _parseFlagsFailClosed(Map<String, dynamic> json) {
  final records = <RemoteFlagRecord>[];
  final value = json['flags'];
  if (value is! List) return records;
  for (final item in value) {
    if (item is! Map) continue;
    try {
      records.add(RemoteFlagRecord.fromJson(Map<String, dynamic>.from(item)));
    } on Object {
      // Unknown or malformed remote flags must resolve to the local false default.
    }
  }
  return records;
}
