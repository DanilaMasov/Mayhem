import 'dart:io';

import 'package:flutter/services.dart';

import 'package:mayhem_mobile/core/debug/debug_visual_overlays.dart';

String goldenTestPath(String fileName) {
  if (Platform.isLinux) {
    return 'goldens/linux/$fileName';
  }
  return 'goldens/$fileName';
}

Future<void> loadGoldenTestFonts() async {
  resetMayhemDebugVisualOverlays();
  final materialFonts = _findMaterialFontsDirectory();

  final text = FontLoader('MayhemGoldenRoboto')
    ..addFont(_fontData(File('${materialFonts.path}/Roboto-Regular.ttf')))
    ..addFont(_fontData(File('${materialFonts.path}/Roboto-Medium.ttf')))
    ..addFont(_fontData(File('${materialFonts.path}/Roboto-Bold.ttf')));
  final icons = FontLoader('MaterialIcons')
    ..addFont(
      _fontData(File('${materialFonts.path}/MaterialIcons-Regular.otf')),
    );

  await Future.wait([text.load(), icons.load()]);
}

Directory _findMaterialFontsDirectory() {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null) {
    final fromEnvironment = Directory(
      '$flutterRoot/bin/cache/artifacts/material_fonts',
    );
    if (fromEnvironment.existsSync()) {
      return fromEnvironment;
    }
  }

  var cursor = File(Platform.resolvedExecutable).parent;
  while (cursor.parent.path != cursor.path) {
    final candidate = Directory(
      '${cursor.path}/bin/cache/artifacts/material_fonts',
    );
    if (candidate.existsSync()) {
      return candidate;
    }
    cursor = cursor.parent;
  }

  throw StateError('Flutter material fonts were not found.');
}

Future<ByteData> _fontData(File file) async {
  final bytes = await file.readAsBytes();
  return ByteData.sublistView(Uint8List.fromList(bytes));
}
