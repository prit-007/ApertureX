import 'dart:math' as math;
import 'dart:ui';

/// A single tile address in the image tile field.
class TileCoord {
  const TileCoord(this.col, this.row);

  final int col;
  final int row;

  @override
  bool operator ==(Object other) =>
      other is TileCoord && other.col == col && other.row == row;

  @override
  int get hashCode => Object.hash(col, row);

  @override
  String toString() => 'TileCoord($col,$row)';
}

/// A tile that intersects the visible region, plus the portion on screen.
class VisibleTile {
  const VisibleTile({
    required this.coord,
    required this.worldRect,
    required this.visibleWorldRect,
  });

  final TileCoord coord;

  /// Full tile extent in world (image pixel) space.
  final Rect worldRect;

  /// Intersection of the tile with the visible world rect.
  final Rect visibleWorldRect;
}

/// Immutable tile field over an image of `imageWidth`×`imageHeight`, cut into
/// `tileSize` squares (edge tiles may be smaller). Pure geometry — no I/O.
class TileGrid {
  TileGrid({
    required this.imageWidth,
    required this.imageHeight,
    this.tileSize = 512,
  }) : assert(imageWidth > 0 && imageHeight > 0),
       assert(tileSize > 0);

  final int imageWidth;
  final int imageHeight;
  final int tileSize;

  int get cols => (imageWidth / tileSize).ceil();
  int get rows => (imageHeight / tileSize).ceil();
  int get tileCount => cols * rows;

  Rect get imageBounds =>
      Rect.fromLTWH(0, 0, imageWidth.toDouble(), imageHeight.toDouble());

  /// World-space extent of tile (col,row), clamped to the image bounds so edge
  /// tiles are smaller than `tileSize`.
  Rect tileRect(int col, int row) {
    final left = col * tileSize;
    final top = row * tileSize;
    final right = math.min(left + tileSize, imageWidth);
    final bottom = math.min(top + tileSize, imageHeight);
    return Rect.fromLTRB(
      left.toDouble(),
      top.toDouble(),
      right.toDouble(),
      bottom.toDouble(),
    );
  }

  /// Tiles whose extent overlaps [visibleWorld] (in world/image space).
  ///
  /// [visibleWorld] is clamped to the image first, so a viewport panned past
  /// the edge never requests tiles outside the image. Boundary regions are
  /// resolved by real area overlap, not index arithmetic, so a rect sitting
  /// exactly on a tile seam does not pull in the neighbouring tile.
  List<VisibleTile> visibleTiles(Rect visibleWorld) {
    final clamped = visibleWorld.intersect(imageBounds);
    if (clamped.width <= 0 || clamped.height <= 0) return const [];

    final colStart = (clamped.left / tileSize).floor().clamp(0, cols - 1);
    final colEnd = (clamped.right / tileSize).floor().clamp(0, cols - 1);
    final rowStart = (clamped.top / tileSize).floor().clamp(0, rows - 1);
    final rowEnd = (clamped.bottom / tileSize).floor().clamp(0, rows - 1);

    final out = <VisibleTile>[];
    for (var row = rowStart; row <= rowEnd; row++) {
      for (var col = colStart; col <= colEnd; col++) {
        final tile = tileRect(col, row);
        final overlap = tile.intersect(clamped);
        if (overlap.width > 0 && overlap.height > 0) {
          out.add(
            VisibleTile(
              coord: TileCoord(col, row),
              worldRect: tile,
              visibleWorldRect: overlap,
            ),
          );
        }
      }
    }
    return out;
  }
}
