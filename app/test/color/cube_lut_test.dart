import 'package:flutter_test/flutter_test.dart';
import 'package:tessera/color/cube_lut.dart';

const _identity2 = '''
# a 2x2x2 identity LUT
TITLE "identity"
LUT_3D_SIZE 2
DOMAIN_MIN 0 0 0
DOMAIN_MAX 1 1 1
0 0 0
1 0 0
0 1 0
1 1 0
0 0 1
1 0 1
0 1 1
1 1 1
''';

void main() {
  group('CubeLut.parse', () {
    test('reads size and title', () {
      final lut = CubeLut.parse(_identity2);
      expect(lut.size, 2);
      expect(lut.title, 'identity');
      expect(lut.data.length, 2 * 2 * 2 * 3);
    });

    test('packs into the shader atlas layout', () {
      final rgba = CubeLut.parse(_identity2).toAtlasRgba();
      expect(rgba.length, 4 * 2 * 4); // width 4, height 2

      // Texel for slice b=1, g=0, r=1 -> x = b*2 + r = 3, y = 0.
      final o = (0 * 4 + 3) * 4;
      expect(rgba[o], 255); // R
      expect(rgba[o + 1], 0); // G
      expect(rgba[o + 2], 255); // B
      expect(rgba[o + 3], 255); // A
    });

    test('rejects a missing size', () {
      expect(
        () => CubeLut.parse('0 0 0\n1 1 1'),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a wrong entry count', () {
      expect(
        () => CubeLut.parse('LUT_3D_SIZE 2\n0 0 0\n'),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects 1D LUTs', () {
      expect(
        () => CubeLut.parse('LUT_1D_SIZE 16\n'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
