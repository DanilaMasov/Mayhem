import 'package:flutter/services.dart';

abstract final class MayhemHaptics {
  static Future<void> touch() => HapticFeedback.selectionClick();

  static Future<void> confirm() => HapticFeedback.mediumImpact();
}
