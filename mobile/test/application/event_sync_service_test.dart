import 'package:flutter_test/flutter_test.dart';
import 'package:mayhem_mobile/application/event_sync_service.dart';
import 'package:mayhem_mobile/domain/models/event_sync.dart';
import 'package:mayhem_mobile/domain/models/game_event.dart';
import 'package:mayhem_mobile/domain/models/game_state.dart';
import 'package:mayhem_mobile/domain/ports/event_sync_transport.dart';

import '../support/fakes.dart';

void main() {
  test('sync wire payload and acknowledgement use the RPC contract', () {
    final now = DateTime.utc(2026, 7, 12, 12);
    final event = GameEvent(
      id: 'event-id',
      type: GameEventType.diceRolled,
      questId: 'level_1',
      createdAt: now,
      payload: const {'modifierId': 'echo', 'isPro': false},
    );
    expect(event.toSyncPayload(), {
      'id': 'event-id',
      'eventType': 'dice_rolled',
      'questId': 'level_1',
      'modifierId': 'echo',
      'payload': {'modifierId': 'echo', 'isPro': false},
      'createdAt': now.toIso8601String(),
    });

    final ack = EventSyncAck.fromJson({
      'acceptedIds': ['event-id'],
      'rejectedById': {'other-id': 'invalid reward'},
      'stats': {'energy': 90},
    });
    expect(ack.acceptedIds, {'event-id'});
    expect(ack.rejectedById, {'other-id': 'invalid reward'});
  });

  test(
    'sync applies partial ack, rejection and missing-ack retry atomically',
    () async {
      final now = DateTime.utc(2026, 7, 12, 12);
      final store = MemoryGameStore();
      final events = [_event('a', now), _event('b', now), _event('c', now)];
      await store.commit(GameState.initial(now), events);
      final transport = FakeEventSyncTransport(
        responder: (_) async => const EventSyncAck(
          acceptedIds: {'a'},
          rejectedById: {'b': 'invalid reward'},
        ),
      );

      final report = await EventSyncService(store, transport).sync(now);
      expect(report.sent, 3);
      expect(report.accepted, 1);
      expect(report.rejected, 1);
      expect(report.retryScheduled, 1);
      expect(store.syncStatusById['a'], 'synced');
      expect(store.syncStatusById['b'], 'rejected');
      expect(store.syncStatusById['c'], 'pending');
      expect(store.syncAttemptsById['c'], 1);
      expect(
        await store.loadPendingEvents(
          now: now.add(const Duration(seconds: 4)),
          limit: 100,
        ),
        isEmpty,
      );
      expect(
        (await store.loadPendingEvents(
          now: now.add(const Duration(seconds: 5)),
          limit: 100,
        )).single.event.id,
        'c',
      );
    },
  );

  test('transport failures retain events with exponential backoff', () async {
    final now = DateTime.utc(2026, 7, 12, 12);
    final store = MemoryGameStore();
    await store.commit(GameState.initial(now), [_event('offline', now)]);
    final transport = FakeEventSyncTransport(
      responder: (_) async => throw Exception('network unavailable'),
    );
    final service = EventSyncService(store, transport);

    final first = await service.sync(now);
    expect(first.retryScheduled, 1);
    expect(store.syncAttemptsById['offline'], 1);
    expect(store.nextRetryById['offline'], now.add(const Duration(seconds: 5)));

    final secondAt = now.add(const Duration(seconds: 5));
    final second = await service.sync(secondAt);
    expect(second.retryScheduled, 1);
    expect(store.syncAttemptsById['offline'], 2);
    expect(
      store.nextRetryById['offline'],
      secondAt.add(const Duration(seconds: 10)),
    );
  });

  test(
    'batch size bounds transport work and leaves the tail pending',
    () async {
      final now = DateTime.utc(2026, 7, 12, 12);
      final store = MemoryGameStore();
      await store.commit(GameState.initial(now), [
        _event('a', now),
        _event('b', now.add(const Duration(seconds: 1))),
        _event('c', now.add(const Duration(seconds: 2))),
      ]);
      final transport = FakeEventSyncTransport(
        responder: (events) async =>
            EventSyncAck(acceptedIds: events.map((event) => event.id).toSet()),
      );

      final report = await EventSyncService(
        store,
        transport,
        batchSize: 2,
      ).sync(now.add(const Duration(seconds: 3)));
      expect(report.sent, 2);
      expect(transport.batches.single.map((event) => event.id), ['a', 'b']);
      expect(store.syncStatusById['c'], 'pending');
    },
  );

  test(
    'unknown ack IDs retry the complete batch without partial writes',
    () async {
      final now = DateTime.utc(2026, 7, 12, 12);
      final store = MemoryGameStore();
      await store.commit(GameState.initial(now), [_event('local', now)]);
      final transport = FakeEventSyncTransport(
        responder: (_) async => const EventSyncAck(acceptedIds: {'foreign'}),
      );

      final report = await EventSyncService(store, transport).sync(now);
      expect(report.accepted, 0);
      expect(report.retryScheduled, 1);
      expect(report.error, contains('unknown event IDs'));
      expect(store.syncStatusById['local'], 'pending');
      expect(store.syncStatusById.containsKey('foreign'), false);
    },
  );
}

GameEvent _event(String id, DateTime createdAt) {
  return GameEvent(
    id: id,
    type: GameEventType.guideOpened,
    questId: 'level_1',
    createdAt: createdAt,
    payload: const {'guideId': 'guide_level_1'},
  );
}

class FakeEventSyncTransport implements EventSyncTransport {
  FakeEventSyncTransport({required this.responder});

  final Future<EventSyncAck> Function(List<GameEvent> events) responder;
  final List<List<GameEvent>> batches = [];

  @override
  Future<EventSyncAck> pushEvents(List<GameEvent> events) {
    batches.add(List.unmodifiable(events));
    return responder(events);
  }
}
