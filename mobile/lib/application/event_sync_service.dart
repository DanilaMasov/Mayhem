import '../domain/models/event_sync.dart';
import '../domain/ports/event_sync_store.dart';
import '../domain/ports/event_sync_transport.dart';

class EventSyncService {
  const EventSyncService(this._store, this._transport, {this.batchSize = 100});

  final EventSyncStore _store;
  final EventSyncTransport _transport;
  final int batchSize;

  Future<EventSyncReport> sync(DateTime now) async {
    final pending = await _store.loadPendingEvents(now: now, limit: batchSize);
    if (pending.isEmpty) return const EventSyncReport.idle();

    try {
      final ack = await _transport.pushEvents(
        pending.map((item) => item.event).toList(growable: false),
      );
      _validateAck(pending, ack);
      final resolved = {...ack.acceptedIds, ...ack.rejectedById.keys};
      final unacknowledged = pending
          .where((item) => !resolved.contains(item.event.id))
          .toList(growable: false);
      final error = unacknowledged.isEmpty
          ? ''
          : 'Server response omitted ${unacknowledged.length} event acknowledgements';
      final retries = _retryUpdates(unacknowledged, error, now);
      await _store.applyEventSyncResult(
        acceptedIds: ack.acceptedIds,
        rejectedById: ack.rejectedById,
        retries: retries,
      );
      return EventSyncReport(
        sent: pending.length,
        accepted: ack.acceptedIds.length,
        rejected: ack.rejectedById.length,
        retryScheduled: unacknowledged.length,
        error: error,
      );
    } catch (error) {
      final message = error is Exception ? error.toString() : '$error';
      await _scheduleRetries(pending, message, now);
      return EventSyncReport(
        sent: pending.length,
        accepted: 0,
        rejected: 0,
        retryScheduled: pending.length,
        error: message,
      );
    }
  }

  void _validateAck(List<PendingGameEvent> pending, EventSyncAck ack) {
    final sentIds = pending.map((item) => item.event.id).toSet();
    final overlap = ack.acceptedIds.intersection(ack.rejectedById.keys.toSet());
    if (overlap.isNotEmpty) {
      throw StateError(
        'Sync ack both accepted and rejected: ${overlap.join(', ')}',
      );
    }
    final unknown = {
      ...ack.acceptedIds,
      ...ack.rejectedById.keys,
    }.difference(sentIds);
    if (unknown.isNotEmpty) {
      throw StateError(
        'Sync ack contains unknown event IDs: ${unknown.join(', ')}',
      );
    }
  }

  Future<void> _scheduleRetries(
    List<PendingGameEvent> pending,
    String error,
    DateTime now,
  ) {
    return _store.scheduleEventRetries(_retryUpdates(pending, error, now));
  }

  List<EventRetryUpdate> _retryUpdates(
    List<PendingGameEvent> pending,
    String error,
    DateTime now,
  ) {
    return pending
        .map((item) {
          final attempts = item.attempts + 1;
          return EventRetryUpdate(
            eventId: item.event.id,
            attempts: attempts,
            nextRetryAt: now.add(_retryDelay(attempts)),
            error: error,
          );
        })
        .toList(growable: false);
  }

  Duration _retryDelay(int attempts) {
    final exponent = (attempts - 1).clamp(0, 10);
    final seconds = (5 * (1 << exponent)).clamp(5, 3600);
    return Duration(seconds: seconds);
  }
}
