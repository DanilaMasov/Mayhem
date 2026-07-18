import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../core/sync/event_envelope_v2.dart';
import '../../features/season/domain/season_participation_repository.dart';
import '../../features/season/domain/season_participation_state.dart';
import 'sqlite_vnext_context.dart';

class SqliteSeasonParticipationRepository
    implements SeasonParticipationRepository {
  const SqliteSeasonParticipationRepository(this.context);

  final SqliteVNextContext context;

  @override
  Future<SeasonParticipationState?> load(String seasonId) {
    return context.database.read((db) => _load(db, seasonId));
  }

  @override
  Future<void> clear(String seasonId) => context.database.transaction(
    (db) => db
        .delete('app_metadata', where: 'key = ?', whereArgs: [_key(seasonId)])
        .then((_) {}),
  );

  @override
  Future<void> revertDay(String seasonId, int day) =>
      context.database.transaction((db) async {
        final current = await _load(db, seasonId);
        if (current == null || !current.completedDays.contains(day)) return;
        await _write(
          db,
          current.copyWith(
            completedDays: {...current.completedDays}..remove(day),
          ),
        );
      });

  @override
  Future<void> revertBoss(String seasonId) =>
      context.database.transaction((db) async {
        final current = await _load(db, seasonId);
        if (current == null || current.bossParticipatedAt == null) return;
        await _write(db, current.copyWith(clearBossParticipatedAt: true));
      });

  @override
  Future<void> replaceAuthoritative(
    String seasonId,
    SeasonParticipationState? state,
  ) => context.database.transaction((db) async {
    if (state == null) {
      await db.delete(
        'app_metadata',
        where: 'key = ?',
        whereArgs: [_key(seasonId)],
      );
      return;
    }
    if (state.seasonId != seasonId) {
      throw const FormatException('Projected Season participation is invalid');
    }
    await _write(db, state);
  });

  @override
  Future<bool> commit({
    required SeasonParticipationState state,
    required EventDraftV2 event,
  }) {
    return context.database.transaction((db) async {
      final current = await _load(db, state.seasonId);
      if (!_validTransition(current, state, event)) {
        throw const FormatException('Invalid Season participation transition');
      }
      if (_sameState(current, state)) return false;
      await _write(db, state);
      await context.appendEvents(db, [event]);
      return true;
    });
  }

  Future<void> _write(
    DatabaseExecutor db,
    SeasonParticipationState state,
  ) async {
    await db.insert('app_metadata', {
      'key': _key(state.seasonId),
      'value': jsonEncode({
        'seasonId': state.seasonId,
        'seasonRevision': state.seasonRevision,
        'joinedAt': state.joinedAt.toUtc().toIso8601String(),
        'completedDays': state.completedDays.toList()..sort(),
        'bossParticipatedAt': state.bossParticipatedAt
            ?.toUtc()
            .toIso8601String(),
        'serverConfirmed': state.serverConfirmed,
      }),
      'updated_at': context.clock().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<SeasonParticipationState?> _load(
    DatabaseExecutor db,
    String seasonId,
  ) async {
    final rows = await db.query(
      'app_metadata',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [_key(seasonId)],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final decoded = jsonDecode(rows.single['value'] as String);
    if (decoded is! Map) {
      throw const FormatException('Season participation cache is invalid');
    }
    final json = Map<String, dynamic>.from(decoded);
    if (json['seasonId'] != seasonId) {
      throw const FormatException('Season participation identity is invalid');
    }
    final days = json['completedDays'];
    if (days is! List || days.any((day) => day is! int)) {
      throw const FormatException('Season completed days are invalid');
    }
    return SeasonParticipationState(
      seasonId: json['seasonId'] as String,
      seasonRevision: json['seasonRevision'] as int,
      joinedAt: DateTime.parse(json['joinedAt'] as String).toUtc(),
      completedDays: days.cast<int>().toSet(),
      bossParticipatedAt: json['bossParticipatedAt'] == null
          ? null
          : DateTime.parse(json['bossParticipatedAt'] as String).toUtc(),
      serverConfirmed: json['serverConfirmed'] as bool? ?? false,
    );
  }

  bool _validTransition(
    SeasonParticipationState? current,
    SeasonParticipationState next,
    EventDraftV2 event,
  ) {
    if (event.payload['seasonId'] != next.seasonId ||
        event.payload['seasonRevision'] != next.seasonRevision) {
      return false;
    }
    if (current == null) {
      return event.eventType == CanonicalEventTypeV2.seasonJoined &&
          event.occurredAtUtc.toUtc() == next.joinedAt.toUtc() &&
          event.assignmentId == null &&
          event.attemptId == null &&
          event.contentId == null &&
          event.contentRevision == null &&
          next.completedDays.isEmpty &&
          next.bossParticipatedAt == null;
    }
    if (current.seasonRevision != next.seasonRevision ||
        current.joinedAt != next.joinedAt ||
        event.occurredAtUtc.toUtc().isBefore(current.joinedAt.toUtc()) ||
        event.assignmentId != null ||
        event.attemptId != null ||
        !next.completedDays.containsAll(current.completedDays)) {
      return false;
    }
    if (event.eventType == CanonicalEventTypeV2.seasonDayCompleted) {
      final added = next.completedDays.difference(current.completedDays);
      return added.length == 1 &&
          event.payload['day'] == added.single &&
          event.contentId == null &&
          event.contentRevision == null &&
          next.bossParticipatedAt == current.bossParticipatedAt;
    }
    if (event.eventType == CanonicalEventTypeV2.bossParticipated) {
      return current.bossParticipatedAt == null &&
          next.bossParticipatedAt != null &&
          event.occurredAtUtc.toUtc() == next.bossParticipatedAt!.toUtc() &&
          next.completedDays.length == current.completedDays.length &&
          next.completedDays.containsAll(current.completedDays) &&
          event.payload['bossEventId'] is String &&
          event.payload['route'] is String &&
          const {
            'normal',
            'low_pressure',
            'advanced',
          }.contains(event.payload['route']) &&
          event.contentId?.trim().isNotEmpty == true &&
          (event.contentRevision ?? 0) > 0;
    }
    return false;
  }

  bool _sameState(
    SeasonParticipationState? left,
    SeasonParticipationState right,
  ) =>
      left != null &&
      left.seasonRevision == right.seasonRevision &&
      left.joinedAt == right.joinedAt &&
      left.bossParticipatedAt == right.bossParticipatedAt &&
      left.completedDays.length == right.completedDays.length &&
      left.completedDays.containsAll(right.completedDays);

  String _key(String seasonId) => 'season.participation.$seasonId';
}
