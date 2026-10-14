import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/viewport/tile_pyramid.dart';

void main() {
  group('TilePyramid', () {
    final pyramid = TilePyramid(imageWidth: 4000, imageHeight: 3000);

    test('chooses full resolution when zoomed in or at 1:1', () {
      expect(pyramid.levelForScale(2.0), 0);
      expect(pyramid.levelForScale(1.0), 0);
    });

    test('dropping scale by a power of two lowers the level', () {
      expect(pyramid.levelForScale(0.5), 1);
      expect(pyramid.levelForScale(0.25), 2);
      expect(pyramid.levelForScale(0.125), 3);
    });

    test('clamps to the available levels', () {
      expect(pyramid.levelForScale(0.0001), pyramid.levelCount - 1);
    });

    test('each level halves the source dimensions', () {
      expect(pyramid.levelSize(0).width, 4000);
      expect(pyramid.levelSize(1).width, 2000);
      expect(pyramid.levelSize(2).width, 1000);
      expect(pyramid.levelSize(2).height, 750);
    });

    test('tile counts shrink with the level', () {
      // 4000x3000 at 512 -> 8x6 = 48 tiles; level 1 -> 4x3 = 12.
      expect(pyramid.tilesAcross(0), 8);
      expect(pyramid.tilesDown(0), 6);
      expect(pyramid.tilesAcross(1), 4);
      expect(pyramid.tilesDown(1), 3);
    });

    test('a 1x1 image has a single level', () {
      final tiny = TilePyramid(imageWidth: 1, imageHeight: 1);
      expect(tiny.levelCount, 1);
      expect(tiny.levelSize(5).width, 1);
    });
  });
}
