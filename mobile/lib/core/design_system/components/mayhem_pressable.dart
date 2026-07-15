import 'package:flutter/material.dart';

import '../accessibility/mayhem_motion_preferences.dart';
import '../motion/mayhem_curves.dart';
import '../motion/mayhem_durations.dart';

class MayhemPressable extends StatefulWidget {
  const MayhemPressable({
    super.key,
    required this.child,
    required this.semanticLabel,
    this.onPressed,
    this.enabled = true,
    this.loading = false,
    this.focusNode,
    this.borderRadius = BorderRadius.zero,
  });

  final Widget child;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final bool enabled;
  final bool loading;
  final FocusNode? focusNode;
  final BorderRadius borderRadius;

  @override
  State<MayhemPressable> createState() => _MayhemPressableState();
}

class _MayhemPressableState extends State<MayhemPressable> {
  bool _pressed = false;
  bool _focused = false;

  bool get _interactive =>
      widget.enabled && !widget.loading && widget.onPressed != null;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MayhemAccessibility.of(context).reduceMotion;
    final scale = _pressed && _interactive ? 0.985 : 1.0;

    return Semantics(
      button: true,
      enabled: _interactive,
      label: widget.semanticLabel,
      value: widget.loading ? 'Loading' : null,
      onTap: _interactive ? widget.onPressed : null,
      child: ExcludeSemantics(
        child: FocusableActionDetector(
          focusNode: widget.focusNode,
          enabled: _interactive,
          onShowFocusHighlight: (value) => setState(() => _focused = value),
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.onPressed?.call();
                return null;
              },
            ),
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: _interactive ? (_) => _setPressed(true) : null,
            onTapUp: _interactive ? (_) => _setPressed(false) : null,
            onTapCancel: _interactive ? () => _setPressed(false) : null,
            onTap: _interactive ? widget.onPressed : null,
            child: AnimatedScale(
              scale: scale,
              duration: reduceMotion ? Duration.zero : MayhemDurations.instant,
              curve: MayhemCurves.enter,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: widget.borderRadius,
                  border: _focused
                      ? Border.all(color: Theme.of(context).colorScheme.primary)
                      : null,
                ),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
