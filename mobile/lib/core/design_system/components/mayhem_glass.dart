import 'dart:ui';

import 'package:flutter/widgets.dart';

import '../accessibility/mayhem_motion_preferences.dart';
import '../tokens/tokens.dart';

enum MayhemGlassKind { control, navigation, sheet }

class MayhemGlass extends StatelessWidget {
  const MayhemGlass({
    super.key,
    required this.child,
    this.kind = MayhemGlassKind.control,
    this.borderRadius = MayhemRadii.large,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final MayhemGlassKind kind;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final reduceTransparency = MayhemAccessibility.of(
      context,
    ).reduceTransparency;
    final fill = reduceTransparency
        ? MayhemMaterials.opaqueFallback
        : switch (kind) {
            MayhemGlassKind.control => MayhemMaterials.controlFill,
            MayhemGlassKind.navigation => MayhemMaterials.navigationFill,
            MayhemGlassKind.sheet => MayhemMaterials.sheetFill,
          };
    final border = switch (kind) {
      MayhemGlassKind.control => MayhemMaterials.controlBorder,
      MayhemGlassKind.navigation => MayhemMaterials.navigationBorder,
      MayhemGlassKind.sheet => MayhemColors.lineStrong,
    };
    final blur = switch (kind) {
      MayhemGlassKind.control => MayhemMaterials.controlBlur,
      MayhemGlassKind.navigation => MayhemMaterials.navigationBlur,
      MayhemGlassKind.sheet => MayhemMaterials.sheetBlur,
    };

    final surface = DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: borderRadius,
        border: Border.all(color: border),
        boxShadow: kind == MayhemGlassKind.sheet
            ? MayhemShadows.sheet
            : MayhemShadows.control,
      ),
      child: Padding(padding: padding, child: child),
    );

    return ClipRRect(
      borderRadius: borderRadius,
      child: reduceTransparency
          ? surface
          : BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: surface,
            ),
    );
  }
}

class MayhemGlassControl extends MayhemGlass {
  const MayhemGlassControl({
    super.key,
    required super.child,
    super.borderRadius = MayhemRadii.pill,
    super.padding,
  }) : super(kind: MayhemGlassKind.control);
}
