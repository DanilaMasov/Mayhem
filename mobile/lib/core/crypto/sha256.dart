import 'dart:convert';
import 'dart:typed_data';

abstract final class Sha256 {
  static String hexOfString(String value) => hex(utf8.encode(value));

  static String hex(List<int> input) {
    final bytes = BytesBuilder(copy: false)..add(input);
    final bitLength = input.length * 8;
    bytes.addByte(0x80);
    while (bytes.length % 64 != 56) {
      bytes.addByte(0);
    }
    final lengthBytes = ByteData(8)..setUint64(0, bitLength, Endian.big);
    bytes.add(lengthBytes.buffer.asUint8List());

    final hash = List<int>.from(_initialHash);
    final data = bytes.takeBytes();
    for (var offset = 0; offset < data.length; offset += 64) {
      final words = List<int>.filled(64, 0);
      final block = ByteData.sublistView(data, offset, offset + 64);
      for (var index = 0; index < 16; index += 1) {
        words[index] = block.getUint32(index * 4, Endian.big);
      }
      for (var index = 16; index < 64; index += 1) {
        final s0 =
            _rotateRight(words[index - 15], 7) ^
            _rotateRight(words[index - 15], 18) ^
            (words[index - 15] >>> 3);
        final s1 =
            _rotateRight(words[index - 2], 17) ^
            _rotateRight(words[index - 2], 19) ^
            (words[index - 2] >>> 10);
        words[index] = _u32(words[index - 16] + s0 + words[index - 7] + s1);
      }

      var a = hash[0];
      var b = hash[1];
      var c = hash[2];
      var d = hash[3];
      var e = hash[4];
      var f = hash[5];
      var g = hash[6];
      var h = hash[7];
      for (var index = 0; index < 64; index += 1) {
        final sum1 =
            _rotateRight(e, 6) ^ _rotateRight(e, 11) ^ _rotateRight(e, 25);
        final choose = (e & f) ^ ((~e) & g);
        final temp1 = _u32(
          h + sum1 + choose + _constants[index] + words[index],
        );
        final sum0 =
            _rotateRight(a, 2) ^ _rotateRight(a, 13) ^ _rotateRight(a, 22);
        final majority = (a & b) ^ (a & c) ^ (b & c);
        final temp2 = _u32(sum0 + majority);
        h = g;
        g = f;
        f = e;
        e = _u32(d + temp1);
        d = c;
        c = b;
        b = a;
        a = _u32(temp1 + temp2);
      }
      hash[0] = _u32(hash[0] + a);
      hash[1] = _u32(hash[1] + b);
      hash[2] = _u32(hash[2] + c);
      hash[3] = _u32(hash[3] + d);
      hash[4] = _u32(hash[4] + e);
      hash[5] = _u32(hash[5] + f);
      hash[6] = _u32(hash[6] + g);
      hash[7] = _u32(hash[7] + h);
    }
    return hash.map((word) => word.toRadixString(16).padLeft(8, '0')).join();
  }

  static int _rotateRight(int value, int amount) =>
      _u32((value >>> amount) | (value << (32 - amount)));

  static int _u32(int value) => value & 0xffffffff;

  static const _initialHash = <int>[
    0x6a09e667,
    0xbb67ae85,
    0x3c6ef372,
    0xa54ff53a,
    0x510e527f,
    0x9b05688c,
    0x1f83d9ab,
    0x5be0cd19,
  ];

  static const _constants = <int>[
    0x428a2f98,
    0x71374491,
    0xb5c0fbcf,
    0xe9b5dba5,
    0x3956c25b,
    0x59f111f1,
    0x923f82a4,
    0xab1c5ed5,
    0xd807aa98,
    0x12835b01,
    0x243185be,
    0x550c7dc3,
    0x72be5d74,
    0x80deb1fe,
    0x9bdc06a7,
    0xc19bf174,
    0xe49b69c1,
    0xefbe4786,
    0x0fc19dc6,
    0x240ca1cc,
    0x2de92c6f,
    0x4a7484aa,
    0x5cb0a9dc,
    0x76f988da,
    0x983e5152,
    0xa831c66d,
    0xb00327c8,
    0xbf597fc7,
    0xc6e00bf3,
    0xd5a79147,
    0x06ca6351,
    0x14292967,
    0x27b70a85,
    0x2e1b2138,
    0x4d2c6dfc,
    0x53380d13,
    0x650a7354,
    0x766a0abb,
    0x81c2c92e,
    0x92722c85,
    0xa2bfe8a1,
    0xa81a664b,
    0xc24b8b70,
    0xc76c51a3,
    0xd192e819,
    0xd6990624,
    0xf40e3585,
    0x106aa070,
    0x19a4c116,
    0x1e376c08,
    0x2748774c,
    0x34b0bcb5,
    0x391c0cb3,
    0x4ed8aa4a,
    0x5b9cca4f,
    0x682e6ff3,
    0x748f82ee,
    0x78a5636f,
    0x84c87814,
    0x8cc70208,
    0x90befffa,
    0xa4506ceb,
    0xbef9a3f7,
    0xc67178f2,
  ];
}

String canonicalJson(Object? value) {
  if (value is Map) {
    if (value.keys.any((key) => key is! String)) {
      throw const FormatException('Canonical JSON object keys must be strings');
    }
    final keys = value.keys.cast<String>().toList()..sort();
    return '{${keys.map((key) => '${jsonEncode(key)}:${canonicalJson(value[key])}').join(',')}}';
  }
  if (value is Iterable) {
    return '[${value.map(canonicalJson).join(',')}]';
  }
  if (value == null || value is bool || value is num || value is String) {
    return jsonEncode(value);
  }
  throw FormatException(
    'Unsupported canonical JSON value: ${value.runtimeType}',
  );
}
