import 'package:flutter/widgets.dart';

@immutable
class MayhemMotionPreferences {
  const MayhemMotionPreferences({
    this.reduceMotion = false,
    this.reduceTransparency = false,
  });

  final bool reduceMotion;
  final bool reduceTransparency;

  MayhemMotionPreferences copyWith({
    bool? reduceMotion,
    bool? reduceTransparency,
  }) {
    return MayhemMotionPreferences(
      reduceMotion: reduceMotion ?? this.reduceMotion,
      reduceTransparency: reduceTransparency ?? this.reduceTransparency,
    );
  }
}

class MayhemAccessibility extends InheritedWidget {
  const MayhemAccessibility({
    super.key,
    required this.preferences,
    required super.child,
  });

  final MayhemMotionPreferences preferences;

  static MayhemMotionPreferences of(BuildContext context) {
    final inherited = context
        .dependOnInheritedWidgetOfExactType<MayhemAccessibility>();
    final media = MediaQuery.maybeOf(context);
    return MayhemMotionPreferences(
      reduceMotion:
          (inherited?.preferences.reduceMotion ?? false) ||
          (media?.disableAnimations ?? false),
      reduceTransparency:
          (inherited?.preferences.reduceTransparency ?? false) ||
          (media?.highContrast ?? false),
    );
  }

  @override
  bool updateShouldNotify(MayhemAccessibility oldWidget) {
    return oldWidget.preferences.reduceMotion != preferences.reduceMotion ||
        oldWidget.preferences.reduceTransparency !=
            preferences.reduceTransparency;
  }
}
