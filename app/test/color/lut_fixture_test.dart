import 'dart:io';

import 'package:aperturex/color/cube_lut.dart';
import 'package:flutter_test/flutter_test.dart';

/// Exercises the parsers against real on-disk LUT files (not inline strings),
/// so comment handling, headers, and DOMAIN lines are covered end to end.
String _read(String name) =>
    File('test/color/fixtures/$name').readAsStringSync();

void main() {
  test('parses a real 1D .cube fixture', () {
    final lut = CubeLut.parseAuto(_read('identity_1d.cube'));
    expect(lut.size, 3);
    expect(lut.title, 'identity-1d');
  });

  test('parses a real 3D .cube fixture (identity atlas corner)', () {
    final lut = CubeLut.parseAuto(_read('identity_3d_2.cube'));
    expect(lut.size, 2);
    final rgba = lut.toAtlasRgba();
    final o = (0 * 4 + 3) * 4; // slice b=1, g=0, r=1
    expect(rgba[o], 255);
    expect(rgba[o + 1], 0);
    expect(rgba[o + 2], 255);
  });

  test('parses a real .3dl fixture into red-fastest order', () {
    final lut = CubeLut.parseAuto(_read('identity_2.3dl'));
    expect(lut.size, 2);
    final i = (1 + 0 * 2 + 1 * 4) * 3; // r=1, g=0, b=1
    expect(lut.data[i], closeTo(1.0, 1e-6));
    expect(lut.data[i + 1], closeTo(0.0, 1e-6));
    expect(lut.data[i + 2], closeTo(1.0, 1e-6));
  });
}
