import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';
import 'mayhem_glass.dart';
import 'mayhem_icon.dart';
import 'mayhem_pressable.dart';
import 'mayhem_text.dart';

class MayhemNavigationDestination {
  const MayhemNavigationDestination({required this.icon, required this.label});

  final MayhemGlyph icon;
  final String label;
}

class MayhemBottomNavigation extends StatelessWidget {
  const MayhemBottomNavigation({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    this.compact = false,
    this.semanticLabel = 'Primary navigation',
  }) : assert(destinations.length == 3),
       assert(selectedIndex >= 0 && selectedIndex < 3);

  final List<MayhemNavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool compact;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: semanticLabel,
      child: MayhemGlass(
        kind: MayhemGlassKind.navigation,
        borderRadius: MayhemRadii.large,
        padding: const EdgeInsets.all(MayhemSpacing.x1),
        child: SizedBox(
          height: compact ? 52 : 64,
          child: Row(
            children: [
              for (var index = 0; index < destinations.length; index++)
                Expanded(
                  child: _Destination(
                    destination: destinations[index],
                    selected: index == selectedIndex,
                    compact: compact,
                    onPressed: () => onSelected(index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Destination extends StatelessWidget {
  const _Destination({
    required this.destination,
    required this.selected,
    required this.compact,
    required this.onPressed,
  });

  final MayhemNavigationDestination destination;
  final bool selected;
  final bool compact;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? MayhemColors.textPrimary
        : MayhemColors.textTertiary;
    return MayhemPressable(
      semanticLabel: destination.label,
      onPressed: onPressed,
      borderRadius: MayhemRadii.medium,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? MayhemColors.surfaceHigh : null,
          borderRadius: MayhemRadii.medium,
          border: selected
              ? const Border.fromBorderSide(
                  BorderSide(color: MayhemColors.lineStrong),
                )
              : null,
        ),
        child: SizedBox.expand(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              MayhemIcon(
                destination.icon,
                semanticLabel: '',
                decorative: true,
                size: 22,
                color: color,
              ),
              if (!compact) ...[
                const SizedBox(height: MayhemSpacing.x1),
                MayhemText(
                  destination.label,
                  variant: MayhemTextVariant.labelMicro,
                  color: color,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
