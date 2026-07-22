import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mayhem_mobile/core/debug/debug_visual_overlays.dart';

void main() {
  test('distributed debug previews start without paint diagnostics', () {
    debugPaintBaselinesEnabled = true;
    debugPaintLayerBordersEnabled = true;
    debugPaintPointersEnabled = true;
    debugPaintSizeEnabled = true;
    debugRepaintRainbowEnabled = true;

    resetMayhemDebugVisualOverlays();

    expect(mayhemDebugVisualOverlaysDisabled, isTrue);
  });
}
