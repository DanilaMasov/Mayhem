import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

const _canvasSize = 1024.0;
const _productionSvgPath = 'assets/brand/launcher_icon.svg';
const _stagingSvgPath = 'assets/brand/launcher_icon_staging.svg';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'generate deterministic production and staging launcher assets',
    () async {
      final generator = _LauncherAssetGenerator();
      await generator.generate();
      expect(
        File('assets/brand/launcher_icon_1024.png').lengthSync(),
        greaterThan(0),
      );
      expect(
        File('assets/brand/launcher_icon_staging_1024.png').lengthSync(),
        greaterThan(0),
      );
    },
  );
}

final class _LauncherAssetGenerator {
  final Map<(int, bool), Uint8List> _cache = {};

  Future<void> generate() async {
    await _writeText(_productionSvgPath, _svg(staging: false));
    await _writeText(_stagingSvgPath, _svg(staging: true));
    await _writePng(
      'assets/brand/launcher_icon_1024.png',
      await _icon(1024, staging: false),
    );
    await _writePng(
      'assets/brand/launcher_icon_staging_1024.png',
      await _icon(1024, staging: true),
    );
    await _generateAndroid();
    await _generateIos();
  }

  Future<void> _generateAndroid() async {
    const sizes = {
      'mipmap-mdpi': 48,
      'mipmap-hdpi': 72,
      'mipmap-xhdpi': 96,
      'mipmap-xxhdpi': 144,
      'mipmap-xxxhdpi': 192,
    };
    for (final MapEntry(key: density, value: size) in sizes.entries) {
      await _writePng(
        'android/app/src/main/res/$density/ic_launcher.png',
        await _icon(size, staging: false),
      );
      await _writePng(
        'android/app/src/staging/res/$density/ic_launcher.png',
        await _icon(size, staging: true),
      );
    }
  }

  Future<void> _generateIos() async {
    const assets = 'ios/Runner/Assets.xcassets';
    const production = '$assets/AppIcon.appiconset';
    const staging = '$assets/AppIconStaging.appiconset';
    final contents =
        jsonDecode(await File('$production/Contents.json').readAsString())
            as Map<String, Object?>;
    await _writeText(
      '$staging/Contents.json',
      '${const JsonEncoder.withIndent('  ').convert(contents)}\n',
    );

    for (final raw in contents['images']! as List<Object?>) {
      final image = raw! as Map<String, Object?>;
      final filename = image['filename'] as String?;
      if (filename == null) continue;
      final points = double.parse((image['size']! as String).split('x').first);
      final scale = int.parse(
        (image['scale']! as String).replaceFirst('x', ''),
      );
      final pixels = (points * scale).round();
      await _writePng(
        '$production/$filename',
        await _icon(pixels, staging: false),
      );
      await _writePng('$staging/$filename', await _icon(pixels, staging: true));
    }
  }

  Future<Uint8List> _icon(int size, {required bool staging}) async {
    final key = (size, staging);
    final cached = _cache[key];
    if (cached != null) return cached;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.scale(size / _canvasSize);
    canvas.drawRect(
      const ui.Rect.fromLTWH(0, 0, _canvasSize, _canvasSize),
      ui.Paint()..color = const ui.Color(0xFF07090C),
    );
    canvas.drawPath(
      _polygon(const [
        ui.Offset(156, 820),
        ui.Offset(156, 204),
        ui.Offset(310, 204),
        ui.Offset(512, 482),
        ui.Offset(714, 204),
        ui.Offset(868, 204),
        ui.Offset(868, 820),
        ui.Offset(706, 820),
        ui.Offset(706, 484),
        ui.Offset(512, 742),
        ui.Offset(318, 484),
        ui.Offset(318, 820),
      ]),
      ui.Paint()..color = const ui.Color(0xFFF4F6F8),
    );
    canvas.drawPath(
      _polygon(const [
        ui.Offset(512, 480),
        ui.Offset(594, 590),
        ui.Offset(512, 700),
        ui.Offset(430, 590),
      ]),
      ui.Paint()..color = const ui.Color(0xFFFF6A45),
    );
    if (staging) {
      canvas.drawPath(
        _polygon(const [
          ui.Offset(704, 0),
          ui.Offset(1024, 0),
          ui.Offset(1024, 320),
        ]),
        ui.Paint()..color = const ui.Color(0xFFFFC978),
      );
      canvas.drawLine(
        const ui.Offset(838, 70),
        const ui.Offset(930, 162),
        ui.Paint()
          ..color = const ui.Color(0xFF07090C)
          ..strokeWidth = 36,
      );
      canvas.drawCircle(
        const ui.Offset(968, 200),
        22,
        ui.Paint()..color = const ui.Color(0xFF07090C),
      );
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(size, size);
    final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    picture.dispose();
    if (rgba == null) throw StateError('Could not render launcher icon');
    final result = _encodeRgbPng(size, rgba.buffer.asUint8List());
    _cache[key] = result;
    return result;
  }

  ui.Path _polygon(List<ui.Offset> points) {
    final path = ui.Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    return path..close();
  }

  Future<void> _writePng(String path, Uint8List bytes) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
  }

  Future<void> _writeText(String path, String value) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(value, flush: true);
  }
}

Uint8List _encodeRgbPng(int size, Uint8List rgba) {
  final scanlines = BytesBuilder(copy: false);
  for (var y = 0; y < size; y++) {
    scanlines.addByte(0);
    for (var x = 0; x < size; x++) {
      final offset = (y * size + x) * 4;
      scanlines.add(rgba.sublist(offset, offset + 3));
    }
  }

  final header = ByteData(13)
    ..setUint32(0, size)
    ..setUint32(4, size)
    ..setUint8(8, 8)
    ..setUint8(9, 2)
    ..setUint8(10, 0)
    ..setUint8(11, 0)
    ..setUint8(12, 0);
  final png = BytesBuilder(copy: false)
    ..add(const [137, 80, 78, 71, 13, 10, 26, 10])
    ..add(_chunk('IHDR', header.buffer.asUint8List()))
    ..add(
      _chunk(
        'IDAT',
        Uint8List.fromList(
          ZLibEncoder(level: 9).convert(scanlines.takeBytes()),
        ),
      ),
    )
    ..add(_chunk('IEND', Uint8List(0)));
  return png.takeBytes();
}

Uint8List _chunk(String name, Uint8List data) {
  final type = ascii.encode(name);
  final result = BytesBuilder(copy: false)
    ..add(_uint32(data.length))
    ..add(type)
    ..add(data)
    ..add(_uint32(_crc32([...type, ...data])));
  return result.takeBytes();
}

Uint8List _uint32(int value) {
  final bytes = ByteData(4)..setUint32(0, value);
  return bytes.buffer.asUint8List();
}

int _crc32(List<int> bytes) {
  var crc = 0xFFFFFFFF;
  for (final byte in bytes) {
    crc ^= byte;
    for (var bit = 0; bit < 8; bit++) {
      crc = (crc & 1) == 1 ? 0xEDB88320 ^ (crc >> 1) : crc >> 1;
    }
  }
  return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}

String _svg({required bool staging}) =>
    '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">
  <rect width="1024" height="1024" fill="#07090c"/>
  <path
    d="M156 820V204H310L512 482L714 204H868V820H706V484L512 742L318 484V820Z"
    fill="#f4f6f8"
  />
  <path d="M512 480L594 590L512 700L430 590Z" fill="#ff6a45"/>
${staging ? '''  <path d="M704 0H1024V320Z" fill="#ffc978"/>
  <path d="M838 70L930 162" stroke="#07090c" stroke-width="36"/>
  <circle cx="968" cy="200" r="22" fill="#07090c"/>
''' : ''}</svg>
''';
