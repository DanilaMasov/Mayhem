import '../../../core/sync/event_envelope_v2.dart';
import '../../challenge/domain/challenge_models.dart';
import 'season_package_store.dart';
import '../domain/season_participation_repository.dart';
import '../domain/season_participation_state.dart';

class StagedSeasonAction {
  const StagedSeasonAction({required this.committed, this.eventId});

  final bool committed;
  final String? eventId;
}

abstract interface class SeasonJoinStager {
  Future<StagedSeasonAction> stageJoin();
}

class SeasonParticipationCoordinator implements SeasonJoinStager {
  const SeasonParticipationCoordinator({
    required this.packages,
    required this.participation,
    required this.eventIdGenerator,
    required this.clock,
    required this.timezoneId,
    required this.timezoneOffsetMinutes,
    this.onTerminalAction,
  });

  final SeasonPackageStore packages;
  final SeasonParticipationRepository participation;
  final String Function() eventIdGenerator;
  final DateTime Function() clock;
  final String timezoneId;
  final int timezoneOffsetMinutes;
  final void Function()? onTerminalAction;

  Future<bool> join() async => (await stageJoin()).committed;

  @override
  Future<StagedSeasonAction> stageJoin() async {
    final now = clock().toUtc();
    final package = await packages.loadActivePackage(now);
    if (package == null) throw StateError('No active Season package');
    final existing = await participation.load(package.season.seasonId);
    if (existing != null) {
      if (existing.seasonRevision != package.season.revision) {
        throw StateError('Season revision changed during participation');
      }
      return const StagedSeasonAction(committed: false);
    }
    final state = SeasonParticipationState(
      seasonId: package.season.seasonId,
      seasonRevision: package.season.revision,
      joinedAt: now,
      completedDays: const {},
    );
    final event = _event(
      type: CanonicalEventTypeV2.seasonJoined,
      occurredAt: now,
      payload: {
        'seasonId': state.seasonId,
        'seasonRevision': state.seasonRevision,
      },
    );
    final committed = await participation.commit(state: state, event: event);
    if (committed) onTerminalAction?.call();
    return StagedSeasonAction(
      committed: committed,
      eventId: committed ? event.eventId : null,
    );
  }

  Future<bool> completeDay(int day) async {
    final now = clock().toUtc();
    final package = await packages.loadActivePackage(now);
    if (package == null) throw StateError('No active Season package');
    final current = await participation.load(package.season.seasonId);
    if (current == null) throw StateError('Season must be joined first');
    if (current.seasonRevision != package.season.revision) {
      throw StateError('Season revision changed during participation');
    }
    if (current.completedDays.contains(day)) return false;
    if (day < 1 ||
        day > 7 ||
        now.isBefore(
          package.season.startsAt.toUtc().add(Duration(days: day - 1)),
        )) {
      throw const FormatException('Season day is not available');
    }
    final next = current.copyWith(
      completedDays: {...current.completedDays, day},
    );
    final committed = await participation.commit(
      state: next,
      event: _event(
        type: CanonicalEventTypeV2.seasonDayCompleted,
        occurredAt: now,
        payload: {
          'seasonId': current.seasonId,
          'seasonRevision': current.seasonRevision,
          'day': day,
        },
      ),
    );
    if (committed) onTerminalAction?.call();
    return committed;
  }

  Future<bool> participateBoss(ChallengeRouteType route) async {
    final now = clock().toUtc();
    final package = await packages.loadActivePackage(now);
    if (package == null) throw StateError('No active Season package');
    final current = await participation.load(package.season.seasonId);
    if (current == null) throw StateError('Season must be joined first');
    if (current.seasonRevision != package.season.revision) {
      throw StateError('Season revision changed during participation');
    }
    if (current.bossParticipatedAt != null) return false;
    final boss = package.boss;
    if (now.isBefore(boss.startsAt.toUtc()) ||
        !now.isBefore(boss.endsAt.toUtc()) ||
        !boss.supportsRoute(route)) {
      throw const FormatException('Boss route is not available');
    }
    final next = current.copyWith(bossParticipatedAt: now);
    final committed = await participation.commit(
      state: next,
      event: _event(
        type: CanonicalEventTypeV2.bossParticipated,
        occurredAt: now,
        contentId: boss.contentId,
        contentRevision: boss.contentRevision,
        payload: {
          'seasonId': current.seasonId,
          'seasonRevision': current.seasonRevision,
          'bossEventId': boss.bossEventId,
          'route': _routeWire(route),
        },
      ),
    );
    if (committed) onTerminalAction?.call();
    return committed;
  }

  EventDraftV2 _event({
    required CanonicalEventTypeV2 type,
    required DateTime occurredAt,
    required Map<String, Object?> payload,
    String? contentId,
    int? contentRevision,
  }) => EventDraftV2(
    eventId: eventIdGenerator(),
    eventType: type,
    occurredAtUtc: occurredAt,
    timezoneId: timezoneId,
    timezoneOffsetMinutes: timezoneOffsetMinutes,
    contentId: contentId,
    contentRevision: contentRevision,
    payload: payload,
  );

  String _routeWire(ChallengeRouteType route) => switch (route) {
    ChallengeRouteType.normal => 'normal',
    ChallengeRouteType.lowPressure => 'low_pressure',
    ChallengeRouteType.advanced => 'advanced',
  };
}
