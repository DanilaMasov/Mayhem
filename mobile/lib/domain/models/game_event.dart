import 'dart:convert';

enum GameEventType {
  questStarted('quest_started'),
  questCompleted('quest_completed'),
  questDeferred('quest_deferred'),
  reflectionSubmitted('reflection_submitted'),
  guideOpened('guide_opened'),
  npcTrainingCompleted('npc_training_completed'),
  diceRolled('dice_rolled'),
  onboardingStepCompleted('onboarding_step_completed');

  const GameEventType(this.wireName);
  final String wireName;

  static GameEventType fromWire(String value) {
    return GameEventType.values.firstWhere(
      (type) => type.wireName == value,
      orElse: () => throw FormatException('Unknown event type: $value'),
    );
  }
}

class GameEvent {
  const GameEvent({
    required this.id,
    required this.type,
    required this.questId,
    required this.createdAt,
    required this.payload,
  });

  factory GameEvent.fromDatabaseMap(Map<String, Object?> row) {
    final payloadJson = row['payload_json'];
    final decoded = payloadJson is String ? jsonDecode(payloadJson) : null;
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Event payload must be an object');
    }
    final id = row['id'];
    final eventType = row['event_type'];
    final questId = row['quest_id'];
    final createdAt = row['created_at'];
    if (id is! String ||
        eventType is! String ||
        questId is! String ||
        createdAt is! String) {
      throw const FormatException('Event row contains invalid fields');
    }
    return GameEvent(
      id: id,
      type: GameEventType.fromWire(eventType),
      questId: questId,
      createdAt: DateTime.parse(createdAt),
      payload: Map<String, Object?>.from(decoded),
    );
  }

  final String id;
  final GameEventType type;
  final String questId;
  final DateTime createdAt;
  final Map<String, Object?> payload;

  Map<String, Object?> toDatabaseMap() {
    return {
      'id': id,
      'event_type': type.wireName,
      'quest_id': questId,
      'payload_json': jsonEncode(payload),
      'created_at': createdAt.toUtc().toIso8601String(),
      'synced': 0,
    };
  }

  Map<String, Object?> toSyncPayload() {
    return {
      'id': id,
      'eventType': type.wireName,
      'questId': questId,
      'modifierId': payload['modifierId'],
      'payload': payload,
      'createdAt': createdAt.toUtc().toIso8601String(),
    };
  }
}
