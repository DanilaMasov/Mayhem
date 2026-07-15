import 'package:flutter/material.dart';

import 'mayhem_colors.dart';

abstract final class MayhemMaterials {
  static const controlFill = Color(0x9412161D);
  static const controlBorder = Color(0x24FFFFFF);
  static const controlBlur = 18.0;

  static const navigationFill = Color(0xAD0C0F14);
  static const navigationBorder = Color(0x1AFFFFFF);
  static const navigationBlur = 24.0;

  static const sheetFill = Color(0xD111151B);
  static const sheetBlur = 30.0;

  static const opaqueFallback = MayhemColors.surfaceRaised;
}
