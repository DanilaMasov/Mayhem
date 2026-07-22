import 'dart:io';

import 'package:flutter/services.dart';

import 'package:mayhem_mobile/core/debug/debug_visual_overlays.dart';
import 'package:mayhem_mobile/core/design_system/tokens/tokens.dart';

String goldenTestPath(String fileName) {
  if (Platform.isLinux) {
    return 'goldens/linux/$fileName';
  }
  return 'goldens/$fileName';
}

Future<void> loadGoldenTestFonts() async {
  resetMayhemDebugVisualOverlays();
  final materialFonts = _findMaterialFontsDirectory();
  final projectRoot = _findProjectRoot();

  final body = FontLoader(MayhemTypography.bodyFontFamily)
    ..addFont(
      _fontData(
        File(
          '${projectRoot.path}/assets/fonts/manrope/'
          'Manrope-VariableFont_wght.ttf',
        ),
      ),
    );
  final display = FontLoader(MayhemTypography.displayFontFamily)
    ..addFont(
      _fontData(
        File(
          '${projectRoot.path}/assets/fonts/unbounded/'
          'Unbounded-VariableFont_wght.ttf',
        ),
      ),
    );
  final icons = FontLoader('MaterialIcons')
    ..addFont(
      _fontData(File('${materialFonts.path}/MaterialIcons-Regular.otf')),
    );

  await Future.wait([body.load(), display.load(), icons.load()]);
}

Directory _findProjectRoot() {
  var cursor = Directory.current;
  while (cursor.parent.path != cursor.path) {
    if (File('${cursor.path}/pubspec.yaml').existsSync()) return cursor;
    cursor = cursor.parent;
  }
  throw StateError('Mayhem Flutter project root was not found.');
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
