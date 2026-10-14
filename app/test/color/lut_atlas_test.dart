import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/color/lut_atlas.dart';

/// A `size³` identity LUT (output == input) for the documented layout.
LutAtlas identityAtlas(int size) {
  final rgba = Uint8List(size * size * size * 4);
  for (var bi = 0; bi < size; bi++) {
    for (var gi = 0; gi < size; gi++) {
      for (var ri = 0; ri < size; ri++) {
        final idx = (gi * size * size + bi * size + ri) * 4;
        rgba[idx] = (ri * 255 / (size - 1)).round();
        rgba[idx + 1] = (gi * 255 / (size - 1)).round();
        rgba[idx + 2] = (bi * 255 / (size - 1)).round();
        rgba[idx + 3] = 255;
      }
    }
  }
  return LutAtlas(size: size, rgba: rgba);
}

/// A LUT where every lattice point maps to the same colour.
LutAtlas constantAtlas(int size, int r, int g, int b) {
  final rgba = Uint8List(size * size * size * 4);
  for (var i = 0; i < size * size * size; i++) {
    rgba[i * 4] = r;
    rgba[i * 4 + 1] = g;
    rgba[i * 4 + 2] = b;
    rgba[i * 4 + 3] = 255;
  }
  return LutAtlas(size: size, rgba: rgba);
}

void main() {
  group('layout', () {
    test('the atlas is size*size wide and size tall', () {
      final a = identityAtlas(8);
      expect(a.width, 64);
      expect(a.height, 8);
      expect(a.rgba.length, 8 * 8 * 8 * 4);
    });

    test('rejects a wrongly-sized buffer', () {
      expect(() => LutAtlas(size: 4, rgba: Uint8List(10)), throwsA(isA<AssertionError>()));
    });
  });

  group('sample (CPU reference of the shader)', () {
    test('an identity LUT reproduces its input', () {
      final a = identityAtlas(33);
      for (final c in [
        [0.0, 0.0, 0.0],
        [1.0, 1.0, 1.0],
        [0.5, 0.5, 0.5],
        [0.2, 0.7, 0.4],
        [0.13, 0.88, 0.51],
      ]) {
        final out = a.sample(c[0], c[1], c[2]);
        expect(out[0], closeTo(c[0], 2 / 255));
        expect(out[1], closeTo(c[1], 2 / 255));
        expect(out[2], closeTo(c[2], 2 / 255));
      }
    });

    test('a constant LUT returns that colour for any input', () {
      final a = constantAtlas(8, 128, 64, 32);
      final out = a.sample(0.9, 0.1, 0.5);
      expect(out[0], closeTo(128 / 255, 1e-6));
      expect(out[1], closeTo(64 / 255, 1e-6));
      expect(out[2], closeTo(32 / 255, 1e-6));
    });

    test('inputs are clamped to [0,1]', () {
      final a = identityAtlas(17);
      final low = a.sample(-1, -1, -1);
      final zero = a.sample(0, 0, 0);
      final high = a.sample(2, 2, 2);
      final one = a.sample(1, 1, 1);
      expect(low, zero);
      expect(high, one);
    });

    test('interpolates between lattice points (mid-point of identity)', () {
      // A coarse 3-point LUT: mid values 0.5 land between lattice hits.
      final a = identityAtlas(3);
      final out = a.sample(0.5, 0.5, 0.5);
      expect(out[0], closeTo(0.5, 2 / 255));
    });
  });
}
