enum ContentItemType {
  challenge,
  microTraining,
  scenarioPoll,
  editorialVideo,
  atmosphericLoop,
  socialProof,
  seasonUpdate,
  bossRaid,
  progressInsight,
}

enum ContentRevisionSource { bundled, remote, legacyImport }

enum MediaType { image, loopVideo, video, rive, shaderPreset }

enum MediaFallback { poster, bundledAsset, staticScene, none }

class SafetyMetadata {
  SafetyMetadata({
    required this.safetyReviewed,
    required this.safetyRevision,
    required this.requiresContextWarning,
    required Set<String> disallowedContexts,
    required this.lowPressureRoute,
    required this.exitCopy,
    this.advancedRouteSafetyApproved = false,
    this.reviewerId,
    this.reviewedAt,
  }) : disallowedContexts = Set.unmodifiable(disallowedContexts) {
    if (safetyRevision < 1) {
      throw const FormatException('Safety revision must be positive');
    }
    if (exitCopy.trim().isEmpty) {
      throw const FormatException('Safety exit copy must not be empty');
    }
  }

  final bool safetyReviewed;
  final int safetyRevision;
  final bool requiresContextWarning;
  final Set<String> disallowedContexts;
  final String? lowPressureRoute;
  final String exitCopy;
  final bool advancedRouteSafetyApproved;
  final String? reviewerId;
  final DateTime? reviewedAt;
}

class MediaDescriptor {
  const MediaDescriptor({
    required this.type,
    required this.aspectRatio,
    required this.checksum,
    required this.byteSize,
    required this.fallback,
    this.remoteUri,
    this.bundledAsset,
    this.posterUri,
    this.captionTrack,
  });

  final MediaType type;
  final Uri? remoteUri;
  final String? bundledAsset;
  final Uri? posterUri;
  final double aspectRatio;
  final String checksum;
  final int byteSize;
  final String? captionTrack;
  final MediaFallback fallback;

  void validate() {
    if (aspectRatio <= 0) {
      throw const FormatException('Media aspect ratio must be positive');
    }
    if (byteSize < 0) {
      throw const FormatException('Media byte size must not be negative');
    }
    if (checksum.trim().isEmpty) {
      throw const FormatException('Media checksum must not be empty');
    }
    if (remoteUri == null && bundledAsset == null && posterUri == null) {
      throw const FormatException('Media requires a source or poster');
    }
  }
}

class ContentItemRevision {
  ContentItemRevision({
    required this.contentId,
    required this.revision,
    required this.type,
    required this.locale,
    required this.publishedAt,
    required Map<String, Object?> payload,
    required this.safety,
    required this.active,
    required this.source,
    required this.checksum,
    this.startsAt,
    this.endsAt,
    this.media,
  }) : payload = Map.unmodifiable(payload) {
    if (contentId.trim().isEmpty || locale.trim().isEmpty) {
      throw const FormatException('Content identity must not be empty');
    }
    if (revision < 1) {
      throw const FormatException('Content revision must be positive');
    }
    if (endsAt != null && startsAt != null && !endsAt!.isAfter(startsAt!)) {
      throw const FormatException('Content availability window is invalid');
    }
    if (checksum.trim().isEmpty) {
      throw const FormatException('Content checksum must not be empty');
    }
    if (!safety.safetyReviewed) {
      throw const FormatException('Active content must be safety reviewed');
    }
    media?.validate();
  }

  final String contentId;
  final int revision;
  final ContentItemType type;
  final String locale;
  final DateTime publishedAt;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final Map<String, Object?> payload;
  final SafetyMetadata safety;
  final MediaDescriptor? media;
  final bool active;
  final ContentRevisionSource source;
  final String checksum;

  String get identity => '$contentId@$revision:$locale';
}
