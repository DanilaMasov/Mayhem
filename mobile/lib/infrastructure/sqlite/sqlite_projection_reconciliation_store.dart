import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../features/sync/domain/reconciliation_models.dart';
import '../../features/season/domain/artifact_ownership.dart';
import 'sqlite_vnext_context.dart';

class SqliteProjectionReconciliationStore
    implements ProjectionReconciliationStore, ArtifactOwnershipRepository {
  const SqliteProjectionReconciliationStore(this.context);

  static const _revisionKey = 'sync.server_projection_revision';
  static const _correctionKey = 'sync.pending_correction_notice';
  static const _lastCorrectionKey = 'sync.last_correction_notice_id';
  static const _artifactsKey = 'sync.owned_artifacts.v1';

  final SqliteVNextContext context;

  @override
  Future<int> loadLastServerProjectionRevision() {
    return context.database.read((db) async {
      final revisionRows = await db.query(
        'app_metadata',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: [_revisionKey],
        limit: 1,
      );
      final artifactRows = await db.query(
        'app_metadata',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: [_artifactsKey],
        limit: 1,
      );
      if (revisionRows.isEmpty || artifactRows.isEmpty) return 0;
      final revision = int.tryParse(revisionRows.single['value'] as String);
      if (revision == null) return 0;
      try {
        final snapshot = _decodeArtifacts(
          artifactRows.single['value'] as String,
        );
        return snapshot.projectionRevision == revision ? revision : 0;
      } on FormatException {
        return 0;
      } on TypeError {
        return 0;
      }
    });
  }

  @override
  Future<void> commit(ReconciledState state) {
    if (!state.applied) return Future.value();
    return context.database.transaction((db) async {
      final now = state.projection.updatedAt.toUtc().toIso8601String();
      await db.insert('app_metadata', {
        'key': _revisionKey,
        'value': state.serverProjectionRevision.toString(),
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await context.saveProgress(db, state.projection);
      await context.saveMomentum(db, state.momentum);
      await db.insert('app_metadata', {
        'key': _artifactsKey,
        'value': jsonEncode({
          'projectionRevision': state.serverProjectionRevision,
          'items': [
            for (final artifact in state.ownedArtifacts)
              {
                'artifactId': artifact.artifactId,
                'seasonId': artifact.seasonId,
                'seasonRevision': artifact.seasonRevision,
                'bossEventId': artifact.bossEventId,
                'unlockedAt': artifact.unlockedAt.toUtc().toIso8601String(),
              },
          ],
        }),
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      final notice = state.correctionNotice;
      if (notice == null) return;
      final previous = await db.query(
        'app_metadata',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: [_lastCorrectionKey],
        limit: 1,
      );
      if (previous.isNotEmpty && previous.single['value'] == notice.noticeId) {
        return;
      }
      await db.insert('app_metadata', {
        'key': _correctionKey,
        'value': jsonEncode({
          'noticeId': notice.noticeId,
          'reasons': notice.reasons.map((reason) => reason.wireName).toList()
            ..sort(),
          'createdAt': notice.createdAt.toUtc().toIso8601String(),
        }),
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await db.insert('app_metadata', {
        'key': _lastCorrectionKey,
        'value': notice.noticeId,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  @override
  Future<List<OwnedFounderArtifact>> loadOwnedArtifacts() {
    return context.database.transaction((db) async {
      final rows = await db.query(
        'app_metadata',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: [_artifactsKey],
        limit: 1,
      );
      if (rows.isEmpty) return const [];
      try {
        return _decodeArtifacts(rows.single['value'] as String).artifacts;
      } on FormatException {
        await db.delete(
          'app_metadata',
          where: 'key = ?',
          whereArgs: [_artifactsKey],
        );
        return const [];
      } on TypeError {
        await db.delete(
          'app_metadata',
          where: 'key = ?',
          whereArgs: [_artifactsKey],
        );
        return const [];
      }
    });
  }

  ({int projectionRevision, List<OwnedFounderArtifact> artifacts})
  _decodeArtifacts(String encoded) {
    final decoded = jsonDecode(encoded);
    if (decoded is! Map) {
      throw const FormatException('Artifact snapshot must be an object');
    }
    final snapshot = Map<String, dynamic>.from(decoded);
    final projectionRevision = snapshot['projectionRevision'];
    final values = snapshot['items'];
    if (projectionRevision is! int ||
        projectionRevision < 0 ||
        values is! List) {
      throw const FormatException('Artifact snapshot metadata is invalid');
    }
    final ids = <String>{};
    final artifacts = <OwnedFounderArtifact>[];
    for (final value in values) {
      if (value is! Map) {
        throw const FormatException('Owned artifact must be an object');
      }
      final item = Map<String, dynamic>.from(value);
      final artifact = OwnedFounderArtifact(
        artifactId: item['artifactId'] as String,
        seasonId: item['seasonId'] as String,
        seasonRevision: item['seasonRevision'] as int,
        bossEventId: item['bossEventId'] as String,
        unlockedAt: DateTime.parse(item['unlockedAt'] as String).toUtc(),
      );
      if (!ids.add(artifact.artifactId)) {
        throw const FormatException('Owned artifacts are duplicated');
      }
      artifacts.add(artifact);
    }
    return (
      projectionRevision: projectionRevision,
      artifacts: List.unmodifiable(artifacts),
    );
  }

  @override
  Future<CorrectionNotice?> takePendingCorrectionNotice() {
    return context.database.transaction((db) async {
      final rows = await db.query(
        'app_metadata',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: [_correctionKey],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      await db.delete(
        'app_metadata',
        where: 'key = ?',
        whereArgs: [_correctionKey],
      );
      try {
        final value = jsonDecode(rows.single['value'] as String);
        if (value is! Map) return null;
        final json = Map<String, dynamic>.from(value);
        final noticeId = json['noticeId'];
        final reasonValues = json['reasons'];
        final createdAt = json['createdAt'];
        if (noticeId is! String ||
            noticeId.isEmpty ||
            reasonValues is! List ||
            createdAt is! String) {
          return null;
        }
        final reasons = reasonValues.map((value) {
          if (value is! String) {
            throw const FormatException('Correction reason is invalid');
          }
          return CorrectionReason.values.firstWhere(
            (reason) => reason.wireName == value,
            orElse: () =>
                throw const FormatException('Correction reason is unknown'),
          );
        }).toSet();
        if (reasons.isEmpty) return null;
        return CorrectionNotice(
          noticeId: noticeId,
          reasons: reasons,
          createdAt: DateTime.parse(createdAt).toUtc(),
        );
      } on FormatException {
        return null;
      }
    });
  }
}
