import 'package:flutter/widgets.dart';

abstract final class MayhemRadii {
  static const smallValue = 12.0;
  static const mediumValue = 18.0;
  static const largeValue = 24.0;
  static const xLargeValue = 32.0;
  static const pillValue = 999.0;

  static const small = BorderRadius.all(Radius.circular(smallValue));
  static const medium = BorderRadius.all(Radius.circular(mediumValue));
  static const large = BorderRadius.all(Radius.circular(largeValue));
  static const xLarge = BorderRadius.all(Radius.circular(xLargeValue));
  static const pill = BorderRadius.all(Radius.circular(pillValue));
}
