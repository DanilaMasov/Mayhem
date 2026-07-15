import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';

class MayhemScaffold extends StatelessWidget {
  const MayhemScaffold({
    super.key,
    required this.body,
    this.bottomNavigation,
    this.backgroundColor = MayhemColors.canvasBase,
    this.resizeToAvoidBottomInset = true,
  });

  final Widget body;
  final Widget? bottomNavigation;
  final Color backgroundColor;
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    final bottomInset = resizeToAvoidBottomInset
        ? MediaQuery.viewInsetsOf(context).bottom
        : 0.0;
    return ColoredBox(
      color: backgroundColor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: body,
          ),
          if (bottomNavigation != null)
            Positioned(
              left: MayhemSpacing.x4,
              right: MayhemSpacing.x4,
              bottom: MediaQuery.paddingOf(context).bottom + MayhemSpacing.x3,
              child: bottomNavigation!,
            ),
        ],
      ),
    );
  }
}
