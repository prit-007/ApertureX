import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/viewport/tile_grid.dart';

void main() {
  group('TileGrid', () {
    test('computes cols/rows/tileCount for exact multiples', () {
      final g = TileGrid(imageWidth: 1024, imageHeight: 1024, tileSize: 512);
      expect(g.cols, 2);
      expect(g.rows, 2);
      expect(g.tileCount, 4);
    });

    test('computes cols/rows with partial edge tiles', () {
      final g = TileGrid(imageWidth: 1000, imageHeight: 700, tileSize: 512);
      expect(g.cols, 2);
      expect(g.rows, 2);
      expect(g.tileCount, 4);
    });

    test('edge tile rects are clamped to image bounds', () {
      final g = TileGrid(imageWidth: 1000, imageHeight: 700, tileSize: 512);
      expect(g.tileRect(0, 0), const Rect.fromLTWH(0, 0, 512, 512));
      expect(g.tileRect(1, 0), const Rect.fromLTWH(512, 0, 488, 512));
      expect(g.tileRect(0, 1), const Rect.fromLTWH(0, 512, 512, 188));
      expect(g.tileRect(1, 1), const Rect.fromLTWH(512, 512, 488, 188));
    });

    test('full image rect selects every tile exactly once', () {
      final g = TileGrid(imageWidth: 1024, imageHeight: 1024, tileSize: 512);
      final tiles = g.visibleTiles(g.imageBounds);
      expect(tiles.length, 4);
      expect(tiles.map((t) => t.coord).toSet().length, 4);
    });

    test('a region spanning a seam returns the touching tiles', () {
      final g = TileGrid(imageWidth: 1024, imageHeight: 1024, tileSize: 512);
      final tiles = g.visibleTiles(const Rect.fromLTWH(400, 400, 300, 300));
      expect(tiles.map((t) => t.coord).toSet(), {
        const TileCoord(0, 0),
        const TileCoord(1, 0),
        const TileCoord(0, 1),
        const TileCoord(1, 1),
      });
    });

    test('a rect ending exactly on a seam does not pull the next tile', () {
      final g = TileGrid(imageWidth: 1024, imageHeight: 1024, tileSize: 512);
      final tiles = g.visibleTiles(const Rect.fromLTWH(0, 0, 512, 256));
      expect(tiles.map((t) => t.coord.col).toSet(), {0});
    });

    test('region entirely outside the image returns no tiles', () {
      final g = TileGrid(imageWidth: 100, imageHeight: 100, tileSize: 512);
      expect(g.visibleTiles(const Rect.fromLTWH(200, 200, 50, 50)), isEmpty);
    });

    test('region partially outside is clamped to the image', () {
      final g = TileGrid(imageWidth: 1000, imageHeight: 1000, tileSize: 512);
      final tiles = g.visibleTiles(const Rect.fromLTWH(600, 600, 500, 500));
      expect(tiles.map((t) => t.coord).toSet(), {const TileCoord(1, 1)});
    });

    test('single-tile image', () {
      final g = TileGrid(imageWidth: 100, imageHeight: 80, tileSize: 512);
      expect(g.tileCount, 1);
      expect(g.visibleTiles(g.imageBounds).single.coord, const TileCoord(0, 0));
    });

    test('coordinate scaling maps fitted dstRect (4000x3000 -> 1000x750) to correct image tiles', () {
      final g = TileGrid(imageWidth: 4000, imageHeight: 3000, tileSize: 512);
      // Visible rect in fitted coordinates (e.g. bottom-right 500x375 of 1000x750)
      const fittedRect = Rect.fromLTWH(500, 375, 500, 375);
      const fittedSize = Size(1000, 750);
      final sx = 4000 / fittedSize.width; // 4.0
      final sy = 3000 / fittedSize.height; // 4.0
      final imagePixelsRect = Rect.fromLTWH(
        fittedRect.left * sx,
        fittedRect.top * sy,
        fittedRect.width * sx,
        fittedRect.height * sy,
      );
      // Image pixel rect should be (2000, 1500, 2000, 1500)
      expect(imagePixelsRect, const Rect.fromLTWH(2000, 1500, 2000, 1500));
      final tiles = g.visibleTiles(imagePixelsRect);
      // 2000..4000 in X with 512 tile size spans cols 3..7
      // 1500..3000 in Y with 512 tile size spans rows 2..5
      final cols = tiles.map((t) => t.coord.col).toSet();
      final rows = tiles.map((t) => t.coord.row).toSet();
      expect(cols, containsAll([3, 4, 5, 6, 7]));
      expect(rows, containsAll([2, 3, 4, 5]));
      // Tile (0, 0) should NOT be in the bottom-right region
      expect(tiles.any((t) => t.coord.col == 0 && t.coord.row == 0), isFalse);
    });
  });
}

