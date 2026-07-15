import '../../../content/domain/content_item_revision.dart';
import 'feed_models.dart';

class FeedBatchGenerationException implements Exception {
  const FeedBatchGenerationException(this.code);

  final String code;

  @override
  String toString() => code;
}

class GeneratedFeedBatch {
  GeneratedFeedBatch({
    required this.batch,
    required List<FeedAssignment> assignments,
  }) : assignments = List.unmodifiable(assignments);

  final FeedBatch batch;
  final List<FeedAssignment> assignments;
}

class LocalFeedBatchPolicy {
  const LocalFeedBatchPolicy();

  static const algorithmRevision = 'local_fixture_v1';
  static const batchSize = 20;

  static const _typePlan = [
    ContentItemType.challenge,
    ContentItemType.microTraining,
    ContentItemType.challenge,
    ContentItemType.scenarioPoll,
    ContentItemType.challenge,
    ContentItemType.seasonUpdate,
    ContentItemType.challenge,
    ContentItemType.microTraining,
    ContentItemType.challenge,
    ContentItemType.scenarioPoll,
    ContentItemType.challenge,
    ContentItemType.microTraining,
    ContentItemType.challenge,
    ContentItemType.seasonUpdate,
    ContentItemType.challenge,
    ContentItemType.scenarioPoll,
    ContentItemType.challenge,
    ContentItemType.microTraining,
    ContentItemType.challenge,
    ContentItemType.challenge,
  ];

  GeneratedFeedBatch generate({
    required Iterable<ContentItemRevision> revisions,
    required Set<String> completedContentIds,
    required String localUserId,
    required DateTime nowUtc,
    required String Function() idGenerator,
  }) {
    if (localUserId.trim().isEmpty) {
      throw const FeedBatchGenerationException('local_user_missing');
    }
    final now = nowUtc.toUtc();
    final active = revisions
        .where(
          (revision) =>
              revision.active &&
              !completedContentIds.contains(revision.contentId) &&
              (revision.startsAt == null || !revision.startsAt!.isAfter(now)) &&
              (revision.endsAt == null || revision.endsAt!.isAfter(now)),
        )
        .toList(growable: false);
    final byType = <ContentItemType, List<ContentItemRevision>>{};
    for (final type in _typePlan.toSet()) {
      final pool = active.where((revision) => revision.type == type).toList()
        ..sort((left, right) => left.contentId.compareTo(right.contentId));
      byType[type] = _orderedPool(type, pool, now);
    }

    final requiredCounts = <ContentItemType, int>{};
    for (final type in _typePlan) {
      requiredCounts[type] = (requiredCounts[type] ?? 0) + 1;
    }
    for (final entry in requiredCounts.entries) {
      if ((byType[entry.key]?.length ?? 0) < entry.value) {
        throw FeedBatchGenerationException(
          'insufficient_${entry.key.name}_content',
        );
      }
    }

    final batchId = _validId(idGenerator(), 'batch_id_invalid');
    final offsets = <ContentItemType, int>{};
    final assignments = <FeedAssignment>[];
    for (var position = 0; position < _typePlan.length; position++) {
      final type = _typePlan[position];
      final offset = offsets[type] ?? 0;
      final revision = byType[type]![offset];
      offsets[type] = offset + 1;
      assignments.add(
        FeedAssignment(
          assignmentId: _validId(idGenerator(), 'assignment_id_invalid'),
          localUserId: localUserId,
          contentId: revision.contentId,
          contentRevision: revision.revision,
          locale: revision.locale,
          position: position,
          batchId: batchId,
          assignmentReason: 'editorial_diversity',
          assignedAt: now,
          expiresAt: now.add(const Duration(hours: 24)),
          boundedMetadata: {
            'contentType': revision.type.name,
            if (revision.payload['intensity'] case final int intensity)
              'intensity': intensity,
            if (revision.payload['primaryTrait'] case final String trait)
              'primaryTrait': trait,
            'lowPressureAvailable':
                revision.safety.lowPressureRoute?.trim().isNotEmpty == true,
          },
        ),
      );
    }
    _validate(assignments, active);
    return GeneratedFeedBatch(
      batch: FeedBatch(
        batchId: batchId,
        createdAt: now,
        expiresAt: now.add(const Duration(hours: 24)),
        source: FeedBatchSource.localGenerated,
        algorithmRevision: algorithmRevision,
        syncState: FeedBatchSyncState.localOnly,
      ),
      assignments: assignments,
    );
  }

  List<ContentItemRevision> _orderedPool(
    ContentItemType type,
    List<ContentItemRevision> source,
    DateTime now,
  ) {
    if (source.isEmpty) return source;
    if (type == ContentItemType.challenge) {
      final lower = source
          .where((item) => ((item.payload['intensity'] as int?) ?? 1) <= 3)
          .toList(growable: false);
      final high = source
          .where((item) => ((item.payload['intensity'] as int?) ?? 1) > 3)
          .toList(growable: false);
      return [
        ..._rotate(lower, '${_dayKey(now)}:${type.name}:low'),
        ..._rotate(high, '${_dayKey(now)}:${type.name}:high'),
      ];
    }
    return _rotate(source, '${_dayKey(now)}:${type.name}');
  }

  List<ContentItemRevision> _rotate(
    List<ContentItemRevision> source,
    String seed,
  ) {
    if (source.length < 2) return List.of(source);
    final offset = _fnv1a(seed) % source.length;
    return [...source.skip(offset), ...source.take(offset)];
  }

  void _validate(
    List<FeedAssignment> assignments,
    List<ContentItemRevision> revisions,
  ) {
    if (assignments.length != batchSize ||
        assignments.first.boundedMetadata['contentType'] !=
            ContentItemType.challenge.name) {
      throw const FeedBatchGenerationException('batch_shape_invalid');
    }
    final ids = <String>{};
    var highIntensityInFirstFive = 0;
    for (var index = 0; index < assignments.length; index++) {
      final assignment = assignments[index];
      if (!ids.add(assignment.contentId)) {
        throw const FeedBatchGenerationException('duplicate_content');
      }
      if (index < 5 &&
          (assignment.boundedMetadata['intensity'] as int? ?? 0) >= 4) {
        highIntensityInFirstFive += 1;
      }
      if (index >= 2) {
        final type = assignment.boundedMetadata['contentType'];
        if (assignments[index - 1].boundedMetadata['contentType'] == type &&
            assignments[index - 2].boundedMetadata['contentType'] == type) {
          throw const FeedBatchGenerationException('type_run_too_long');
        }
      }
    }
    if (highIntensityInFirstFive > 2) {
      throw const FeedBatchGenerationException('too_many_early_high_intensity');
    }
    final revisionById = {
      for (final revision in revisions) revision.contentId: revision,
    };
    final lowPressureInFirstSix = assignments.take(6).any((assignment) {
      final revision = revisionById[assignment.contentId];
      return revision?.type == ContentItemType.challenge &&
          revision?.safety.lowPressureRoute?.trim().isNotEmpty == true;
    });
    if (!lowPressureInFirstSix) {
      throw const FeedBatchGenerationException('low_pressure_missing');
    }
  }

  String _validId(String value, String code) {
    if (value.trim().isEmpty) throw FeedBatchGenerationException(code);
    return value;
  }

  String _dayKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  int _fnv1a(String value) {
    var hash = 0x811C9DC5;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }
}
