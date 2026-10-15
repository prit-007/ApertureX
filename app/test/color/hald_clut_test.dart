import 'dart:io';
import 'dart:typed_data';

import 'package:aperturex/color/hald_clut.dart';
import 'package:aperturex/color/lut_atlas.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('isHaldPng is false for empty and non-cube images', () {
    expect(HaldClut.isHaldPng(Uint8List(0)), isFalse);
  });

  test('detects a level-2 HALD PNG', () async {
    final bytes = await File(
      'test/color/hald_level2_identity.png',
    ).readAsBytes();
    expect(HaldClut.isHaldPng(bytes), isTrue);
  });

  test('extracts a level-2 identity cube (4 values/channel)', () async {
    final bytes = await File(
      'test/color/hald_level2_identity.png',
    ).readAsBytes();
    final hald = HaldClut.extract(bytes);
    expect(hald.level, 2);
    expect(hald.size, 4);
    expect(hald.imageSize, 8);
    expect(hald.data.length, 4 * 4 * 4 * 3);

    // Identity: entry (r,g,b) == (r,g,b)/(size-1).
    for (var b = 0; b < 4; b++) {
      for (var g = 0; g < 4; g++) {
        for (var r = 0; r < 4; r++) {
          final i = (r + g * 4 + b * 16) * 3;
          expect(hald.data[i], closeTo(r / 3, 1e-6), reason: 'r($r,$g,$b)');
          expect(hald.data[i + 1], closeTo(g / 3, 1e-6), reason: 'g($r,$g,$b)');
          expect(hald.data[i + 2], closeTo(b / 3, 1e-6), reason: 'b($r,$g,$b)');
        }
      }
    }
  });

  test('extracts a level-4 identity cube (16 values/channel)', () async {
    final bytes = await File(
      'test/color/hald_level4_identity.png',
    ).readAsBytes();
    final hald = HaldClut.extract(bytes);
    expect(hald.level, 4);
    expect(hald.size, 16);
    expect(hald.imageSize, 64);
    // Spot-check the corners of the cube.
    int at(int r, int g, int b, int c) =>
        (r + g * 16 + b * 256) * 3 + c;
    expect(hald.data[at(0, 0, 0, 0)], 0.0);
    expect(hald.data[at(15, 15, 15, 0)], closeTo(1.0, 1e-6));
    expect(hald.data[at(15, 0, 0, 0)], closeTo(1.0, 1e-6));
    expect(hald.data[at(0, 15, 0, 1)], closeTo(1.0, 1e-6));
    expect(hald.data[at(0, 0, 15, 2)], closeTo(1.0, 1e-6));
  });

  test('rejects a non-cube square PNG', () {
    // An 8x8 image is a valid level-2 HALD; a 9x9 is not a cube at all.
    expect(HaldClut.isHaldPng(_solidPng(9)), isFalse);
    expect(HaldClut.isHaldPng(_solidPng(7)), isFalse);
  });

  test('toAtlasRgba packs the identity cube at the expected layout', () async {
    final bytes = await File(
      'test/color/hald_level2_identity.png',
    ).readAsBytes();
    final hald = HaldClut.extract(bytes);
    final atlas = hald.toAtlasRgba();
    const n = 4;
    final w = n * n;
    // Texel for (r,g,b) lives at x = b*n + r, y = g.
    void check(int r, int g, int b) {
      final o = (g * w + (b * n + r)) * 4;
      expect(atlas[o], (r / 3 * 255 + 0.5).toInt());
      expect(atlas[o + 1], (g / 3 * 255 + 0.5).toInt());
      expect(atlas[o + 2], (b / 3 * 255 + 0.5).toInt());
      expect(atlas[o + 3], 255);
    }

    check(0, 0, 0);
    check(3, 3, 3);
    check(1, 2, 3);
  });

  test('a HALD atlas sampled through LutAtlas is identity', () async {
    final bytes = await File(
      'test/color/hald_level4_identity.png',
    ).readAsBytes();
    final hald = HaldClut.extract(bytes);
    final atlas = LutAtlas(size: hald.size, rgba: hald.toAtlasRgba());
    for (final v in [0.0, 0.25, 0.5, 0.75, 1.0]) {
      final out = atlas.sample(v, v, v);
      expect(out[0], closeTo(v, 1.0 / 15 + 1e-6), reason: 'r $v');
      expect(out[1], closeTo(v, 1.0 / 15 + 1e-6), reason: 'g $v');
      expect(out[2], closeTo(v, 1.0 / 15 + 1e-6), reason: 'b $v');
    }
  });
}

Uint8List _solidPng(int side) {
  final image = img.Image(width: side, height: side);
  return Uint8List.fromList(img.encodePng(image));
}
