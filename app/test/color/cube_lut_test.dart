import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/color/cube_lut.dart';

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

const _identity1d = '''
TITLE "identity-1d"
LUT_1D_SIZE 2
0 0 0
1 1 1
''';

// A 2³ identity LUT in the .3dl convention: blue varies fastest, values are
// 10-bit integers (0..1023), declared by a coordinate ladder.
const _identity3dl = '''
# 10
0 1023
0 0 0
0 0 1023
0 1023 0
0 1023 1023
1023 0 0
1023 0 1023
1023 1023 0
1023 1023 1023
''';

const _identity3dlMesh = '''
Mesh 2 10
0 0 0
0 0 1023
0 1023 0
0 1023 1023
1023 0 0
1023 0 1023
1023 1023 0
1023 1023 1023
''';

void main() {
  group('CubeLut.parse (3D)', () {
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
  });

  group('CubeLut.parse (1D)', () {
    test('expands a 2-point identity curve into an identity 3D atlas', () {
      final lut = CubeLut.parse(_identity1d);
      expect(lut.size, 2);
      expect(lut.title, 'identity-1d');
      expect(lut.toAtlasRgba(), CubeLut.parse(_identity2).toAtlasRgba());
    });

    test('resamples larger 1D curves and stays identity-ish', () {
      final lut = CubeLut.parse('LUT_1D_SIZE 3\n0 0 0\n0.5 0.5 0.5\n1 1 1\n');
      expect(lut.size, 3);
      // Corner (r=2,g=2,b=2) should still be white.
      final o = (2 * 9 + (2 * 3 + 2)) * 4; // slice b=2, x=b*3+r=8? see layout
      expect(lut.toAtlasRgba()[o], 255);
    });

    test('rejects a wrong 1D entry count', () {
      expect(
        () => CubeLut.parse('LUT_1D_SIZE 4\n0 0 0\n'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('CubeLut.parse3dl', () {
    test('reads a coordinate-ladder file with blue-fastest ordering', () {
      final lut = CubeLut.parse3dl(_identity3dl);
      expect(lut.size, 2);
      // Red-fastest in memory: index = r + g*2 + b*4, so (r=1,g=0,b=1) -> 5.
      final i = (1 + 0 * 2 + 1 * 4) * 3;
      expect(lut.data[i], closeTo(1, 1e-6));
      expect(lut.data[i + 1], closeTo(0, 1e-6));
      expect(lut.data[i + 2], closeTo(1, 1e-6));
    });

    test('matches an equivalent .cube identity', () {
      final lut = CubeLut.parse3dl(_identity3dl);
      // 1023/1023 == 1.0, and 0/1023 == 0, so it round-trips to identity.
      expect(lut.toAtlasRgba(), CubeLut.parse(_identity2).toAtlasRgba());
    });

    test('supports a Mesh header instead of a ladder', () {
      final lut = CubeLut.parse3dl(_identity3dlMesh);
      expect(lut.size, 2);
      expect(lut.toAtlasRgba(), CubeLut.parse(_identity2).toAtlasRgba());
    });

    test('rejects a wrong entry count', () {
      expect(
        () => CubeLut.parse3dl('Mesh 2 10\n0 0 0\n'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('CubeLut.parseAuto', () {
    test('sniffs .cube', () {
      expect(CubeLut.parseAuto(_identity2).size, 2);
      expect(CubeLut.parseAuto(_identity1d).size, 2);
    });

    test('sniffs .3dl', () {
      expect(CubeLut.parseAuto(_identity3dl).title, isNull);
      expect(CubeLut.parseAuto(_identity3dl).data.length, 8 * 3);
    });
  });

  group('CubeLut.toCubeText', () {
    test('exports standard .cube format that round-trips through parse', () {
      final original = CubeLut.parse(_identity2);
      final text = original.toCubeText(title: 'Exported Grade');
      expect(text, contains('TITLE "Exported Grade"'));
      expect(text, contains('LUT_3D_SIZE 2'));
      expect(text, contains('DOMAIN_MIN 0.0 0.0 0.0'));
      expect(text, contains('DOMAIN_MAX 1.0 1.0 1.0'));

      final parsed = CubeLut.parse(text);
      expect(parsed.size, 2);
      expect(parsed.title, 'Exported Grade');
      expect(parsed.toAtlasRgba(), original.toAtlasRgba());
    });
  });
}
