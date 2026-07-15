import 'package:flutter/material.dart';

import '../../core/design_system/mayhem_theme.dart';
import 'motion_lab.dart';

void main() {
  runApp(const MotionLabApp());
}

class MotionLabApp extends StatelessWidget {
  const MotionLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MAYHEM Motion Lab',
      debugShowCheckedModeBanner: false,
      theme: MayhemTheme.dark,
      home: const MotionLab(),
    );
  }
}
