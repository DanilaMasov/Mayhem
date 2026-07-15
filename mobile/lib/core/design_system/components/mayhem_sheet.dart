import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';
import 'mayhem_glass.dart';

class MayhemSheet extends StatelessWidget {
  const MayhemSheet({
    super.key,
    required this.child,
    this.showHandle = true,
    this.padding = const EdgeInsets.fromLTRB(
      MayhemSpacing.x5,
      MayhemSpacing.x3,
      MayhemSpacing.x5,
      MayhemSpacing.x6,
    ),
  });

  final Widget child;
  final bool showHandle;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return MayhemGlass(
      kind: MayhemGlassKind.sheet,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(MayhemRadii.xLargeValue),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showHandle) ...[
                Semantics(
                  label: 'Drag to resize or dismiss',
                  child: Container(
                    width: MayhemSpacing.x10,
                    height: MayhemSpacing.x1,
                    decoration: const BoxDecoration(
                      color: MayhemColors.lineStrong,
                      borderRadius: MayhemRadii.pill,
                    ),
                  ),
                ),
                const SizedBox(height: MayhemSpacing.x5),
              ],
              child,
            ],
          ),
        ),
      ),
    );
  }
}
