import 'game_event.dart';

class PendingGameEvent {
  const PendingGameEvent({required this.event, required this.attempts});

  final GameEvent event;
  final int attempts;
}

class EventSyncAck {
  const EventSyncAck({
    this.acceptedIds = const {},
    this.rejectedById = const {},
  });

  factory EventSyncAck.fromJson(Map<String, dynamic> json) {
    final accepted = json['acceptedIds'];
    final rejected = json['rejectedById'];
    if (accepted is! List<dynamic> || rejected is! Map<String, dynamic>) {
      throw const FormatException('Invalid event sync acknowledgement');
    }
    return EventSyncAck(
      acceptedIds: accepted.map((item) {
        if (item is! String || item.isEmpty) {
          throw const FormatException('Invalid accepted event ID');
        }
        return item;
      }).toSet(),
      rejectedById: rejected.map((key, value) {
        if (key.isEmpty || value is! String || value.isEmpty) {
          throw const FormatException('Invalid rejected event record');
        }
        return MapEntry(key, value);
      }),
    );
  }

  final Set<String> acceptedIds;
  final Map<String, String> rejectedById;
}

class EventRetryUpdate {
  const EventRetryUpdate({
    required this.eventId,
    required this.attempts,
    required this.nextRetryAt,
    required this.error,
  });

  final String eventId;
  final int attempts;
  final DateTime nextRetryAt;
  final String error;
}

class EventSyncReport {
  const EventSyncReport({
    required this.sent,
    required this.accepted,
    required this.rejected,
    required this.retryScheduled,
    required this.error,
  });

  const EventSyncReport.idle()
    : sent = 0,
      accepted = 0,
      rejected = 0,
      retryScheduled = 0,
      error = '';

  final int sent;
  final int accepted;
  final int rejected;
  final int retryScheduled;
  final String error;
}
