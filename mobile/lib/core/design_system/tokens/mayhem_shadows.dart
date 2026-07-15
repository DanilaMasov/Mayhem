import 'package:flutter/material.dart';

import 'mayhem_colors.dart';

abstract final class MayhemShadows {
  static const control = [
    BoxShadow(
      color: MayhemColors.shadowControl,
      offset: Offset(0, 8),
      blurRadius: 24,
    ),
  ];

  static const sheet = [
    BoxShadow(
      color: MayhemColors.shadowSheet,
      offset: Offset(0, 24),
      blurRadius: 64,
    ),
  ];
}
