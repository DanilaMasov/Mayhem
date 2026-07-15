import 'dart:convert';

class ReflectionDraft {
  const ReflectionDraft({
    required this.fearScore,
    required this.feelAfterScore,
    required this.wantRepeat,
    this.note = '',
  });

  final int fearScore;
  final int feelAfterScore;
  final bool wantRepeat;
  final String note;

  void validate() {
    if (fearScore < 1 || fearScore > 10) {
      throw const FormatException('fearScore must be between 1 and 10');
    }
    if (feelAfterScore < 1 || feelAfterScore > 10) {
      throw const FormatException('feelAfterScore must be between 1 and 10');
    }
    if (note.trim().length > 240) {
      throw const FormatException('reflection note is too long');
    }
  }
}

class QuestReflection {
  const QuestReflection({
    required this.id,
    required this.questId,
    required this.fearScore,
    required this.feelAfterScore,
    required this.wantRepeat,
    required this.note,
    required this.createdAt,
  });

  final String id;
  final String questId;
  final int fearScore;
  final int feelAfterScore;
  final bool wantRepeat;
  final String note;
  final DateTime createdAt;

  Map<String, Object?> toDatabaseMap() {
    return {
      'id': id,
      'quest_id': questId,
      'fear_score': fearScore,
      'feel_after_score': feelAfterScore,
      'want_repeat': wantRepeat ? 1 : 0,
      'note': note,
      'metadata_json': jsonEncode({
        'fearScore': fearScore,
        'feelAfterScore': feelAfterScore,
        'wantRepeat': wantRepeat,
      }),
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }
}
