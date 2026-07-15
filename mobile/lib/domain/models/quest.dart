enum StatType {
  charisma,
  boldness,
  networking;

  static StatType fromWire(String value) {
    return StatType.values.firstWhere(
      (item) => item.name == value,
      orElse: () => throw FormatException('Unknown stat type: $value'),
    );
  }

  String get label => switch (this) {
    StatType.charisma => 'Charisma',
    StatType.boldness => 'Boldness',
    StatType.networking => 'Networking',
  };
}

class Quest {
  const Quest({
    required this.id,
    required this.level,
    required this.statType,
    required this.energyCost,
    required this.category,
    required this.text,
    required this.alternateRoute,
    required this.advancedRoute,
    this.rewardEnergy = 0,
    this.isShadow = false,
    this.isBoss = false,
  });

  factory Quest.fromJson(Map<String, dynamic> json) {
    return Quest(
      id: _requiredString(json, 'id'),
      level: _requiredInt(json, 'level'),
      statType: StatType.fromWire(_requiredString(json, 'statType')),
      energyCost: _requiredInt(json, 'energyCost'),
      category: _requiredString(json, 'category'),
      text: _requiredString(json, 'questText'),
      alternateRoute: _requiredString(json, 'alternateRoute'),
      advancedRoute: _requiredString(json, 'advancedRoute'),
      rewardEnergy: (json['rewardEnergy'] as num?)?.toInt() ?? 0,
      isShadow: json['isShadow'] == true,
      isBoss: json['isBoss'] == true,
    );
  }

  final String id;
  final int level;
  final StatType statType;
  final int energyCost;
  final int rewardEnergy;
  final String category;
  final String text;
  final String alternateRoute;
  final String advancedRoute;
  final bool isShadow;
  final bool isBoss;
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key must be a non-empty string');
  }
  return value.trim();
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! num) throw FormatException('$key must be a number');
  return value.toInt();
}
