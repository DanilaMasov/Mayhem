import 'package:flutter_test/flutter_test.dart';
import 'package:mayhem_mobile/content/domain/content_item_revision.dart';
import 'package:mayhem_mobile/core/sync/event_envelope_v2.dart';
import 'package:mayhem_mobile/features/challenge/domain/challenge_models.dart';
import 'package:mayhem_mobile/features/progress/domain/progress_models.dart';
import 'package:mayhem_mobile/features/reflection/domain/private_reflection.dart';
import 'package:mayhem_mobile/features/streak/domain/momentum_state.dart';
import 'package:mayhem_mobile/infrastructure/sqlite/sqlite_vnext_store.dart';

import '../../support/memory_vnext_database.dart';

void main() {
  late MemoryVNextDatabase database;
  late SqliteVNextStore store;
  final acceptedAt = DateTime.parse('2026-07-13T09:00:00Z');
  final resolvedAt = DateTime.parse('2026-07-13T09:10:00Z');

  setUp(() {
    database = MemoryVNextDatabase(
      seed: {
        'user_identity': [
          {
            'local_user_id': 'local-user-1',
            'installation_id': 'installation-1',
            'remote_user_id': null,
          },
        ],
        'app_metadata': [
          {
            'key': 'client_sequence:installation-1',
            'value': '0',
            'updated_at': acceptedAt.toIso8601String(),
          },
        ],
      },
    );
    store = SqliteVNextStore(database, clock: () => resolvedAt);
  });

  test('active content query excludes persisted inactive revisions', () async {
    final activeRevision = _contentRevision('active-content', active: true);
    final inactiveRevision = _contentRevision(
      'inactive-content',
      active: false,
    );
    await store.content.saveValidatedRevisions([
      activeRevision,
      inactiveRevision,
    ]);
    await store.content.activateBundledCatalog([activeRevision]);

    final active = await store.content.activeRevisions(
      locale: 'ru-RU',
      atUtc: resolvedAt,
    );

    expect(active.map((item) => item.contentId), ['active-content']);
    expect(
      database.executor
          .rows('content_item_revisions')
          .singleWhere(
            (row) => row['content_id'] == 'inactive-content',
          )['active'],
      0,
    );

    final replacement = _contentRevision('replacement-content', active: true);
    await store.content.saveValidatedRevisions([replacement]);
    await store.content.activateBundledCatalog([replacement]);
    final replaced = await store.content.activeRevisions(
      locale: 'ru-RU',
      atUtc: resolvedAt,
    );
    expect(replaced.map((item) => item.contentId), ['replacement-content']);
    expect(
      database.executor
          .rows('content_item_revisions')
          .singleWhere(
            (row) => row['content_id'] == 'active-content',
          )['active'],
      0,
    );
  });

  test('accept is durable, restorable and idempotent per assignment', () async {
    final attempt = _activeAttempt(acceptedAt);
    final event = _event(
      id: 'event-accept-1',
      type: CanonicalEventTypeV2.challengeAccepted,
      at: acceptedAt,
    );

    expect(
      await store.challenge.commitAccepted(attempt: attempt, event: event),
      isTrue,
    );
    expect(
      await store.challenge.commitAccepted(
        attempt: _activeAttempt(acceptedAt, id: 'attempt-duplicate'),
        event: _event(
          id: 'event-accept-duplicate',
          type: CanonicalEventTypeV2.challengeAccepted,
          at: acceptedAt,
          attemptId: 'attempt-duplicate',
        ),
      ),
      isFalse,
    );

    final restoredStore = SqliteVNextStore(database);
    final restored = await restoredStore.challenge.activeAttempt();
    expect(restored?.attemptId, attempt.attemptId);
    expect(database.executor.rows('challenge_attempts'), hasLength(1));
    expect(database.executor.rows('event_log_v2'), hasLength(1));
    expect(_sequence(database), '1');
  });

  test('resolution applies reward once and keeps private note local', () async {
    final active = _activeAttempt(acceptedAt);
    await store.challenge.commitAccepted(
      attempt: active,
      event: _event(
        id: 'event-accept-1',
        type: CanonicalEventTypeV2.challengeAccepted,
        at: acceptedAt,
      ),
    );
    final momentum = _momentum();
    final projection = _projection(resolvedAt, momentum);
    final reflection = _reflection(resolvedAt);
    final completed = _completedAttempt(active, resolvedAt);
    final events = [
      _event(
        id: 'event-complete-1',
        type: CanonicalEventTypeV2.challengeCompleted,
        at: resolvedAt,
      ),
      _event(
        id: 'event-reflection-1',
        type: CanonicalEventTypeV2.reflectionSubmitted,
        at: resolvedAt,
        payload: const {'fearBefore': 8, 'feelAfter': 4, 'wantRepeat': true},
      ),
    ];

    expect(
      await store.challenge.commitResolution(
        attempt: completed,
        projection: projection,
        momentum: momentum,
        events: events,
        reflection: reflection,
      ),
      isTrue,
    );
    expect(
      await store.challenge.commitResolution(
        attempt: completed,
        projection: projection,
        momentum: momentum,
        events: events,
        reflection: reflection,
      ),
      isFalse,
    );

    final persisted = await store.challenge.findById(active.attemptId);
    expect(persisted?.rewardAppliedLocally, isTrue);
    expect((await store.progress.loadProjection())?.totalXp, 75);
    expect((await store.momentum.loadMomentum()).currentDays, 1);
    expect(
      (await store.reflection.findForAttempt(active.attemptId))?.privateNote,
      'This stays only on this device',
    );
    expect(database.executor.rows('event_log_v2'), hasLength(3));
    expect(_sequence(database), '3');
    for (final row in database.executor.rows('event_log_v2')) {
      expect(row['payload_json'], isNot(contains('This stays only')));
    }
  });

  test(
    'event failure rolls back attempt, projections and reflection',
    () async {
      final active = _activeAttempt(acceptedAt);
      await store.challenge.commitAccepted(
        attempt: active,
        event: _event(
          id: 'event-accept-1',
          type: CanonicalEventTypeV2.challengeAccepted,
          at: acceptedAt,
        ),
      );
      database.executor.failNextInsertInto = 'event_log_v2';
      final momentum = _momentum();

      await expectLater(
        store.challenge.commitResolution(
          attempt: _completedAttempt(active, resolvedAt),
          projection: _projection(resolvedAt, momentum),
          momentum: momentum,
          events: [
            _event(
              id: 'event-complete-1',
              type: CanonicalEventTypeV2.challengeCompleted,
              at: resolvedAt,
            ),
          ],
          reflection: _reflection(resolvedAt),
        ),
        throwsStateError,
      );

      expect(
        (await store.challenge.findById(active.attemptId))?.status,
        ChallengeAttemptStatus.active,
      );
      expect(await store.progress.loadProjection(), isNull);
      expect(await store.reflection.findForAttempt(active.attemptId), isNull);
      expect(database.executor.rows('event_log_v2'), hasLength(1));
      expect(_sequence(database), '1');
    },
  );

  test('event payload rejects private note text before commit', () async {
    final active = _activeAttempt(acceptedAt);
    await store.challenge.commitAccepted(
      attempt: active,
      event: _event(
        id: 'event-accept-1',
        type: CanonicalEventTypeV2.challengeAccepted,
        at: acceptedAt,
      ),
    );
    final momentum = _momentum();

    await expectLater(
      store.challenge.commitResolution(
        attempt: _completedAttempt(active, resolvedAt),
        projection: _projection(resolvedAt, momentum),
        momentum: momentum,
        events: [
          _event(
            id: 'event-complete-1',
            type: CanonicalEventTypeV2.challengeCompleted,
            at: resolvedAt,
            payload: const {'privateNote': 'must never sync'},
          ),
        ],
      ),
      throwsFormatException,
    );
    expect(
      (await store.challenge.findById(active.attemptId))?.status,
      ChallengeAttemptStatus.active,
    );
    expect(database.executor.rows('event_log_v2'), hasLength(1));
  });
}

ChallengeAttempt _activeAttempt(
  DateTime acceptedAt, {
  String id = 'attempt-1',
}) => ChallengeAttempt(
  attemptId: id,
  assignmentId: 'assignment-1',
  contentId: 'challenge-1',
  contentRevision: 1,
  status: ChallengeAttemptStatus.active,
  selectedRoute: ChallengeRouteType.normal,
  acceptedAt: acceptedAt,
  timezoneId: 'Europe/Moscow',
  rewardAppliedLocally: false,
  syncState: AttemptSyncState.pending,
);

ChallengeAttempt _completedAttempt(ChallengeAttempt active, DateTime at) =>
    active.copyWith(
      status: ChallengeAttemptStatus.completed,
      resolvedAt: at,
      result: const AttemptResult(
        outcome: AttemptOutcome.completed,
        felt: FeltComparedToExpected.easierThanExpected,
        fearBefore: 8,
        feelAfter: 4,
        wantRepeat: true,
        privateNoteId: 'reflection-1',
      ),
      rewardAppliedLocally: true,
    );

EventDraftV2 _event({
  required String id,
  required CanonicalEventTypeV2 type,
  required DateTime at,
  String attemptId = 'attempt-1',
  Map<String, Object?> payload = const {},
}) => EventDraftV2(
  eventId: id,
  eventType: type,
  occurredAtUtc: at,
  timezoneId: 'Europe/Moscow',
  timezoneOffsetMinutes: 180,
  assignmentId: 'assignment-1',
  attemptId: attemptId,
  contentId: 'challenge-1',
  contentRevision: 1,
  payload: payload,
);

MomentumState _momentum() => MomentumState(
  currentDays: 1,
  longestDays: 1,
  earnedToday: true,
  shieldsAvailable: 0,
  protectedLocalDates: const {},
  nextMilestone: 3,
  lastEarnedLocalDate: '2026-07-13',
);

ProgressProjection _projection(DateTime at, MomentumState momentum) =>
    ProgressProjection(
      totalXp: 75,
      ratingScore: 1075,
      peakRatingScore: 1075,
      traitXp: const {
        Trait.initiation: 75,
        Trait.expression: 0,
        Trait.connection: 0,
        Trait.presence: 0,
      },
      rank: PrestigeRank(
        family: RankFamily.spark,
        tier: 1,
        configRevision: 'local_v1',
      ),
      rankProgress: 0.25,
      momentum: momentum,
      difficulty: {
        for (final trait in Trait.values)
          trait: DifficultyState(
            trait: trait,
            rating: 0,
            confidence: 0,
            observations: 0,
            recommendedIntensity: 1,
            updatedAt: at,
          ),
      },
      completedCount: 1,
      attemptedCount: 0,
      updatedAt: at,
      source: ProjectionSource.localCheckpoint,
    );

PrivateReflection _reflection(DateTime at) => PrivateReflection(
  reflectionId: 'reflection-1',
  attemptId: 'attempt-1',
  fearBefore: 8,
  feelAfter: 4,
  wantRepeat: true,
  privateNote: 'This stays only on this device',
  createdAt: at,
  updatedAt: at,
);

String? _sequence(MemoryVNextDatabase database) {
  final row = database.executor
      .rows('app_metadata')
      .singleWhere((row) => row['key'] == 'client_sequence:installation-1');
  return row['value'] as String?;
}

ContentItemRevision _contentRevision(String id, {required bool active}) =>
    ContentItemRevision(
      contentId: id,
      revision: 1,
      type: ContentItemType.microTraining,
      locale: 'ru-RU',
      publishedAt: DateTime.parse('2026-07-01T00:00:00Z'),
      payload: const {'title': 'Fixture'},
      safety: SafetyMetadata(
        safetyReviewed: true,
        safetyRevision: 1,
        requiresContextWarning: false,
        disallowedContexts: const {},
        lowPressureRoute: 'Stop safely.',
        exitCopy: 'Stop safely.',
      ),
      active: active,
      source: ContentRevisionSource.bundled,
      checksum: 'checksum:$id:$active',
    );
