import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

/// Keeps distributed debug previews free from Flutter Inspector paint aids.
///
/// The preview APK intentionally uses a debug runtime while release signing is
/// unavailable. Inspector flags are process-global and can otherwise leave
/// baselines or layout diagnostics painted over the product UI.
void resetMayhemDebugVisualOverlays() {
  assert(() {
    debugPaintBaselinesEnabled = false;
    debugPaintLayerBordersEnabled = false;
    debugPaintPointersEnabled = false;
    debugPaintSizeEnabled = false;
    debugRepaintRainbowEnabled = false;
    return true;
  }());
}

@visibleForTesting
bool get mayhemDebugVisualOverlaysDisabled =>
    !debugPaintBaselinesEnabled &&
    !debugPaintLayerBordersEnabled &&
    !debugPaintPointersEnabled &&
    !debugPaintSizeEnabled &&
    !debugRepaintRainbowEnabled;
