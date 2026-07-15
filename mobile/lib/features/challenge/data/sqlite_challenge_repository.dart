import 'package:sqflite/sqflite.dart';

import '../../../core/sync/event_envelope_v2.dart';
import '../../progress/domain/progress_models.dart';
import '../../reflection/domain/private_reflection.dart';
import '../../streak/domain/momentum_state.dart';
import '../../../infrastructure/sqlite/sqlite_vnext_context.dart';
import '../../../infrastructure/sqlite/sqlite_vnext_mappers.dart';
import '../domain/challenge_attempt_repository.dart';
import '../domain/challenge_models.dart';
import '../domain/local_challenge_commit_repository.dart';

class SqliteChallengeRepository
    implements ChallengeAttemptRepository, LocalChallengeCommitRepository {
  const SqliteChallengeRepository(this.context);

  final SqliteVNextContext context;

  @override
  Future<ChallengeAttempt?> activeAttempt() {
    return context.database.read((db) async {
      final rows = await db.query(
        'challenge_attempts',
        where: "status = 'active'",
        orderBy: 'accepted_at DESC',
        limit: 1,
      );
      return rows.isEmpty ? null : SqliteAttemptMapper.fromRow(rows.single);
    });
  }

  @override
  Future<ChallengeAttempt?> findById(String attemptId) {
    return context.database.read((db) async {
      final rows = await db.query(
        'challenge_attempts',
        where: 'attempt_id = ?',
        whereArgs: [attemptId],
        limit: 1,
      );
      return rows.isEmpty ? null : SqliteAttemptMapper.fromRow(rows.single);
    });
  }

  @override
  Future<ChallengeAttempt?> findByAssignment(String assignmentId) {
    return context.database.read((db) async {
      final rows = await db.query(
        'challenge_attempts',
        where: 'assignment_id = ?',
        whereArgs: [assignmentId],
        limit: 1,
      );
      return rows.isEmpty ? null : SqliteAttemptMapper.fromRow(rows.single);
    });
  }

  @override
  Future<void> save(ChallengeAttempt attempt) {
    if (attempt.rewardAppliedLocally) {
      throw StateError('Reward-bearing attempts require commitResolution');
    }
    return context.database.transaction((db) async {
      final rows = await db.query(
        'challenge_attempts',
        where: 'attempt_id = ?',
        whereArgs: [attempt.attemptId],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        final current = SqliteAttemptMapper.fromRow(rows.single);
        _requireSameIdentity(current, attempt);
        if (current.rewardAppliedLocally) {
          throw StateError('A rewarded attempt cannot be overwritten');
        }
      }
      await db.insert(
        'challenge_attempts',
        SqliteAttemptMapper.toRow(attempt, updatedAt: context.clock()),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  @override
  Future<List<ChallengeAttempt>> history({int limit = 100}) {
    if (limit < 1 || limit > 500) {
      throw ArgumentError.value(limit, 'limit', 'Must be between 1 and 500');
    }
    return context.database.read((db) async {
      final rows = await db.query(
        'challenge_attempts',
        orderBy: 'resolved_at DESC, accepted_at DESC',
        limit: limit,
      );
      return rows.map(SqliteAttemptMapper.fromRow).toList(growable: false);
    });
  }

  @override
  Future<bool> commitAccepted({
    required ChallengeAttempt attempt,
    required EventDraftV2 event,
  }) {
    _validateAccepted(attempt, event);
    return context.database.transaction((db) async {
      final existing = await db.query(
        'challenge_attempts',
        columns: ['attempt_id'],
        where: 'assignment_id = ?',
        whereArgs: [attempt.assignmentId],
        limit: 1,
      );
      if (existing.isNotEmpty) return false;
      await db.insert(
        'challenge_attempts',
        SqliteAttemptMapper.toRow(attempt, updatedAt: context.clock()),
      );
      await context.appendEvents(db, [event]);
      return true;
    });
  }

  @override
  Future<bool> commitResolution({
    required ChallengeAttempt attempt,
    required ProgressProjection projection,
    required MomentumState momentum,
    required List<EventDraftV2> events,
    PrivateReflection? reflection,
  }) {
    _validateResolution(attempt, events, reflection);
    return context.database.transaction((db) async {
      final rows = await db.query(
        'challenge_attempts',
        where: 'attempt_id = ?',
        whereArgs: [attempt.attemptId],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw StateError('Cannot resolve an unknown attempt');
      }
      final current = SqliteAttemptMapper.fromRow(rows.single);
      _requireSameIdentity(current, attempt);
      if (current.rewardAppliedLocally || current.isTerminal) return false;

      final changed = await db.update(
        'challenge_attempts',
        SqliteAttemptMapper.toRow(attempt, updatedAt: context.clock()),
        where: 'attempt_id = ? AND reward_applied_local = 0',
        whereArgs: [attempt.attemptId],
      );
      if (changed != 1) return false;
      if (reflection != null) await context.saveReflection(db, reflection);
      await context.saveProgress(db, projection);
      await context.saveMomentum(db, momentum);
      await context.appendEvents(db, events);
      return true;
    });
  }

  static void _requireSameIdentity(
    ChallengeAttempt current,
    ChallengeAttempt next,
  ) {
    if (current.attemptId != next.attemptId ||
        current.assignmentId != next.assignmentId ||
        current.contentId != next.contentId ||
        current.contentRevision != next.contentRevision ||
        current.acceptedAt != next.acceptedAt) {
      throw const FormatException('Challenge attempt identity is immutable');
    }
  }

  static void _validateAccepted(ChallengeAttempt attempt, EventDraftV2 event) {
    if (attempt.status != ChallengeAttemptStatus.active ||
        attempt.result != null ||
        attempt.rewardAppliedLocally ||
        event.eventType != CanonicalEventTypeV2.challengeAccepted ||
        event.attemptId != attempt.attemptId ||
        event.assignmentId != attempt.assignmentId ||
        event.contentId != attempt.contentId ||
        event.contentRevision != attempt.contentRevision) {
      throw const FormatException('Invalid challenge acceptance commit');
    }
  }

  static void _validateResolution(
    ChallengeAttempt attempt,
    List<EventDraftV2> events,
    PrivateReflection? reflection,
  ) {
    final expectedEvent = switch (attempt.status) {
      ChallengeAttemptStatus.attempted =>
        CanonicalEventTypeV2.challengeAttempted,
      ChallengeAttemptStatus.completed =>
        CanonicalEventTypeV2.challengeCompleted,
      _ => null,
    };
    if (expectedEvent == null ||
        attempt.result?.outcome.name != attempt.status.name ||
        !attempt.rewardAppliedLocally ||
        attempt.resolvedAt == null ||
        events.isEmpty ||
        !events.any((event) => event.eventType == expectedEvent) ||
        events.any(
          (event) =>
              event.attemptId != attempt.attemptId ||
              event.assignmentId != attempt.assignmentId ||
              event.contentId != attempt.contentId ||
              event.contentRevision != attempt.contentRevision,
        ) ||
        reflection != null && reflection.attemptId != attempt.attemptId) {
      throw const FormatException('Invalid challenge resolution commit');
    }
    reflection?.validate();
  }
}
