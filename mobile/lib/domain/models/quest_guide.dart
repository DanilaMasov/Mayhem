class QuestGuide {
  const QuestGuide({
    required this.id,
    required this.questId,
    required this.steps,
    required this.phrases,
    required this.exitScript,
    required this.alternateRoute,
    required this.advancedRoute,
  });

  factory QuestGuide.fromJson(Map<String, dynamic> json) {
    return QuestGuide(
      id: _requiredString(json, 'id'),
      questId: _requiredString(json, 'questId'),
      steps: _requiredStrings(json, 'steps'),
      phrases: _requiredStrings(json, 'phrases'),
      exitScript: _requiredString(json, 'exitScript'),
      alternateRoute: _requiredString(json, 'alternateRoute'),
      advancedRoute: _requiredString(json, 'advancedRoute'),
    );
  }

  final String id;
  final String questId;
  final List<String> steps;
  final List<String> phrases;
  final String exitScript;
  final String alternateRoute;
  final String advancedRoute;
}

class GuideCatalog {
  GuideCatalog({required this.schemaVersion, required this.guides}) {
    _validate();
    _byQuestId = {for (final guide in guides) guide.questId: guide};
  }

  final int schemaVersion;
  final List<QuestGuide> guides;
  late final Map<String, QuestGuide> _byQuestId;

  QuestGuide forQuest(String questId) {
    final guide = _byQuestId[questId];
    if (guide == null) {
      throw StateError('Guide is missing for quest: $questId');
    }
    return guide;
  }

  void validateCoverage(Iterable<String> questIds) {
    final expected = questIds.toSet();
    final actual = _byQuestId.keys.toSet();
    final missing = expected.difference(actual);
    final unknown = actual.difference(expected);
    if (missing.isNotEmpty) {
      throw FormatException('Missing guides: ${missing.join(', ')}');
    }
    if (unknown.isNotEmpty) {
      throw FormatException(
        'Guides reference unknown quests: ${unknown.join(', ')}',
      );
    }
  }

  void _validate() {
    if (schemaVersion != 1) {
      throw FormatException('Unsupported guide catalog schema: $schemaVersion');
    }
    if (guides.isEmpty) {
      throw const FormatException('Guide catalog must not be empty');
    }
    final ids = <String>{};
    final questIds = <String>{};
    for (final guide in guides) {
      if (!ids.add(guide.id)) {
        throw FormatException('Duplicate guide id: ${guide.id}');
      }
      if (!questIds.add(guide.questId)) {
        throw FormatException('Duplicate guide questId: ${guide.questId}');
      }
      if (guide.steps.length != 3) {
        throw FormatException('${guide.id} must contain exactly 3 steps');
      }
      if (guide.phrases.length < 3 || guide.phrases.length > 5) {
        throw FormatException('${guide.id} must contain 3 to 5 phrases');
      }
    }
  }
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key must be a non-empty string');
  }
  return value.trim();
}

List<String> _requiredStrings(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List<dynamic>) {
    throw FormatException('$key must be an array');
  }
  return value
      .map((item) {
        if (item is! String || item.trim().isEmpty) {
          throw FormatException('$key contains an invalid item');
        }
        return item.trim();
      })
      .toList(growable: false);
}
