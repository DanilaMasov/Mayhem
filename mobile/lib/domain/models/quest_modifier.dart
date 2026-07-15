class QuestModifier {
  const QuestModifier({
    required this.id,
    required this.title,
    required this.text,
  });

  factory QuestModifier.fromJson(Map<String, dynamic> json) {
    return QuestModifier(
      id: _requiredString(json, 'id'),
      title: _requiredString(json, 'title'),
      text: _requiredString(json, 'text'),
    );
  }

  final String id;
  final String title;
  final String text;
}

class ModifierCatalog {
  ModifierCatalog({required this.schemaVersion, required this.modifiers}) {
    _validate();
    _byId = {for (final modifier in modifiers) modifier.id: modifier};
  }

  static const expectedModifierCount = 5;

  final int schemaVersion;
  final List<QuestModifier> modifiers;
  late final Map<String, QuestModifier> _byId;

  QuestModifier byId(String id) {
    final modifier = _byId[id];
    if (modifier == null) throw StateError('Unknown modifier: $id');
    return modifier;
  }

  void validateBundledContract() {
    if (modifiers.length != expectedModifierCount) {
      throw FormatException(
        'Schema v1 requires exactly $expectedModifierCount modifiers',
      );
    }
  }

  void _validate() {
    if (schemaVersion != 1) {
      throw FormatException(
        'Unsupported modifier catalog schema: $schemaVersion',
      );
    }
    if (modifiers.isEmpty) {
      throw const FormatException('Modifier catalog must not be empty');
    }
    final ids = <String>{};
    for (final modifier in modifiers) {
      if (!ids.add(modifier.id)) {
        throw FormatException('Duplicate modifier id: ${modifier.id}');
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
