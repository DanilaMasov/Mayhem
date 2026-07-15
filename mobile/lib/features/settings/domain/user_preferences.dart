class UserPreferences {
  const UserPreferences({
    this.reduceMotion = false,
    this.reduceTransparency = false,
    this.hapticsEnabled = true,
    this.soundEnabled = true,
    this.ceremoniesEnabled = true,
    this.locale = 'ru-RU',
  });

  final bool reduceMotion;
  final bool reduceTransparency;
  final bool hapticsEnabled;
  final bool soundEnabled;
  final bool ceremoniesEnabled;
  final String locale;

  UserPreferences copyWith({
    bool? reduceMotion,
    bool? reduceTransparency,
    bool? hapticsEnabled,
    bool? soundEnabled,
    bool? ceremoniesEnabled,
  }) => UserPreferences(
    reduceMotion: reduceMotion ?? this.reduceMotion,
    reduceTransparency: reduceTransparency ?? this.reduceTransparency,
    hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
    soundEnabled: soundEnabled ?? this.soundEnabled,
    ceremoniesEnabled: ceremoniesEnabled ?? this.ceremoniesEnabled,
    locale: locale,
  );

  Map<String, Object?> toJson() => {
    'reduceMotion': reduceMotion,
    'reduceTransparency': reduceTransparency,
    'hapticsEnabled': hapticsEnabled,
    'soundEnabled': soundEnabled,
    'ceremoniesEnabled': ceremoniesEnabled,
    'locale': locale,
  };

  factory UserPreferences.fromJson(Map<String, dynamic> json) =>
      UserPreferences(
        reduceMotion: json['reduceMotion'] == true,
        reduceTransparency: json['reduceTransparency'] == true,
        hapticsEnabled: json['hapticsEnabled'] != false,
        soundEnabled: json['soundEnabled'] != false,
        ceremoniesEnabled: json['ceremoniesEnabled'] != false,
        locale: json['locale'] as String? ?? 'ru-RU',
      );
}
