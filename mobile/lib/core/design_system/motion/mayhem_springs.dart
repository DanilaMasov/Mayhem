import 'package:flutter/physics.dart';

abstract final class MayhemSprings {
  static const snappy = SpringDescription(mass: 1, stiffness: 520, damping: 42);
  static const standard = SpringDescription(
    mass: 1,
    stiffness: 390,
    damping: 34,
  );
  static const heavy = SpringDescription(
    mass: 1.25,
    stiffness: 300,
    damping: 28,
  );
  static const floating = SpringDescription(
    mass: 0.9,
    stiffness: 210,
    damping: 24,
  );
}
