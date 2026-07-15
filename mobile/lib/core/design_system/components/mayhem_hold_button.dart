import 'package:flutter/material.dart';

import '../accessibility/mayhem_motion_preferences.dart';
import '../motion/mayhem_curves.dart';
import '../motion/mayhem_durations.dart';
import '../motion/mayhem_haptics.dart';
import '../tokens/tokens.dart';
import 'mayhem_text.dart';

class MayhemHoldButton extends StatefulWidget {
  const MayhemHoldButton({
    super.key,
    required this.label,
    required this.onCompleted,
    this.onCanceled,
    this.enabled = true,
    this.threshold = MayhemDurations.slow,
    this.semanticHint = 'Double tap to confirm without holding',
    this.completedLabel = 'CHALLENGE ACCEPTED',
  });

  final String label;
  final VoidCallback onCompleted;
  final VoidCallback? onCanceled;
  final bool enabled;
  final Duration threshold;
  final String semanticHint;
  final String completedLabel;

  @override
  State<MayhemHoldButton> createState() => _MayhemHoldButtonState();
}

class _MayhemHoldButtonState extends State<MayhemHoldButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _pointerDown = false;
  bool _didComplete = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.threshold)
      ..addStatusListener(_handleStatus);
  }

  @override
  void didUpdateWidget(MayhemHoldButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.threshold != widget.threshold) {
      _controller.duration = widget.threshold;
    }
    if (oldWidget.enabled && !widget.enabled) {
      _cancel(notify: false);
    }
  }

  void _handleStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _complete();
  }

  void _start(PointerDownEvent event) {
    if (!widget.enabled || _didComplete || _pointerDown) return;
    _pointerDown = true;
    MayhemHaptics.touch();
    _controller.forward();
  }

  void _end(PointerEvent event) {
    if (!_pointerDown || _didComplete) return;
    _cancel(notify: true);
  }

  void _cancel({required bool notify}) {
    if (!_pointerDown && _controller.value == 0) return;
    _pointerDown = false;
    _controller.animateBack(
      0,
      duration: MayhemDurations.standard,
      curve: MayhemCurves.enter,
    );
    if (notify) widget.onCanceled?.call();
  }

  void _complete() {
    if (_didComplete || !widget.enabled) return;
    _didComplete = true;
    _pointerDown = false;
    MayhemHaptics.confirm();
    widget.onCompleted();
    if (mounted) setState(() {});
  }

  void _completeByAccessibility() {
    if (!widget.enabled || _didComplete) return;
    _controller.value = 1;
    _complete();
  }

  @override
  void dispose() {
    _controller
      ..removeStatusListener(_handleStatus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preferences = MayhemAccessibility.of(context);
    final foreground = !widget.enabled
        ? MayhemColors.textDisabled
        : (_didComplete ? MayhemColors.textInverse : MayhemColors.textPrimary);

    return Semantics(
      container: true,
      button: true,
      enabled: widget.enabled && !_didComplete,
      label: widget.label,
      hint: widget.semanticHint,
      value: _didComplete ? 'Accepted' : 'Hold to confirm',
      onTap: widget.enabled && !_didComplete ? _completeByAccessibility : null,
      child: ExcludeSemantics(
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _start,
          onPointerUp: _end,
          onPointerCancel: _end,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final progress = _controller.value;
              final scale = preferences.reduceMotion
                  ? 1.0
                  : 1 - (progress * 0.015);
              return Transform.scale(
                scale: scale,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 64),
                  child: ClipRRect(
                    borderRadius: MayhemRadii.medium,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: widget.enabled
                            ? MayhemColors.surfaceHigh
                            : MayhemColors.surfaceBase,
                        border: Border.all(color: MayhemColors.lineStrong),
                      ),
                      child: Stack(
                        fit: StackFit.passthrough,
                        children: [
                          Positioned.fill(
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: progress,
                              child: const ColoredBox(
                                color: MayhemColors.brandVoid,
                              ),
                            ),
                          ),
                          if (_didComplete)
                            const Positioned.fill(
                              child: ColoredBox(
                                color: MayhemColors.brandColdLight,
                              ),
                            ),
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: MayhemSpacing.x5,
                                vertical: MayhemSpacing.x4,
                              ),
                              child: MayhemText(
                                _didComplete
                                    ? widget.completedLabel
                                    : widget.label,
                                variant: MayhemTextVariant.labelLarge,
                                color: foreground,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
