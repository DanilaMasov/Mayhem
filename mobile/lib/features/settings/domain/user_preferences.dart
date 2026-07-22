class UserPreferences {
  const UserPreferences({
    this.reduceMotion = false,
    this.reduceTransparency = false,
    this.hapticsEnabled = true,
    this.soundEnabled = true,
    this.ceremoniesEnabled = true,
    this.locale = 'ru-RU',
    this.rankStyleId,
  });

  final bool reduceMotion;
  final bool reduceTransparency;

  // Retained for backward-compatible reads of pre-R5 preference snapshots.
  final bool hapticsEnabled;
  final bool soundEnabled;
  final bool ceremoniesEnabled;
  final String locale;

  // Retained only so snapshots written by the retired rank-style collection
  // continue to deserialize. The release UI intentionally ignores this field.
  final String? rankStyleId;

  UserPreferences copyWith({
    bool? reduceMotion,
    bool? reduceTransparency,
    bool? hapticsEnabled,
    bool? soundEnabled,
    bool? ceremoniesEnabled,
    String? rankStyleId,
  }) => UserPreferences(
    reduceMotion: reduceMotion ?? this.reduceMotion,
    reduceTransparency: reduceTransparency ?? this.reduceTransparency,
    hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
    soundEnabled: soundEnabled ?? this.soundEnabled,
    ceremoniesEnabled: ceremoniesEnabled ?? this.ceremoniesEnabled,
    locale: locale,
    rankStyleId: rankStyleId ?? this.rankStyleId,
  );

  Map<String, Object?> toJson() => {
    'reduceMotion': reduceMotion,
    'reduceTransparency': reduceTransparency,
    'hapticsEnabled': hapticsEnabled,
    'soundEnabled': soundEnabled,
    'ceremoniesEnabled': ceremoniesEnabled,
    'locale': locale,
    if (rankStyleId != null) 'rankStyleId': rankStyleId,
  };

  factory UserPreferences.fromJson(Map<String, dynamic> json) =>
      UserPreferences(
        reduceMotion: json['reduceMotion'] == true,
        reduceTransparency: json['reduceTransparency'] == true,
        hapticsEnabled: json['hapticsEnabled'] != false,
        soundEnabled: json['soundEnabled'] != false,
        ceremoniesEnabled: json['ceremoniesEnabled'] != false,
        locale: json['locale'] as String? ?? 'ru-RU',
        rankStyleId: switch (json['rankStyleId']) {
          final String value when value.trim().isNotEmpty => value,
          _ => null,
        },
      );
}
