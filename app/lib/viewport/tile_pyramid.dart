import 'dart:math' as math;
import 'dart:ui' show Size;

/// A multi-level (mip) pyramid over an image: level 0 is full resolution, each
/// next level halves it. Zoomed-out views sample a lower level, so the viewport
/// never decodes/renders more source than it shows (P1).
class TilePyramid {
  TilePyramid({
    required this.imageWidth,
    required this.imageHeight,
    this.baseTileSize = 512,
    this.maxLevels = 6,
  }) : assert(imageWidth > 0 && imageHeight > 0),
       assert(baseTileSize > 0),
       assert(maxLevels >= 1);

  final int imageWidth;
  final int imageHeight;
  final int baseTileSize;
  final int maxLevels;

  /// Number of levels that still have at least one pixel.
  int get levelCount {
    var count = 1;
    var w = imageWidth;
    var h = imageHeight;
    while (count < maxLevels && (w > 1 || h > 1)) {
      w = (w + 1) ~/ 2;
      h = (h + 1) ~/ 2;
      count++;
    }
    return count;
  }

  /// Source dimensions at [level].
  Size levelSize(int level) {
    final k = level.clamp(0, levelCount - 1);
    final divisor = 1 << k;
    return Size(
      (imageWidth / divisor).ceilToDouble(),
      (imageHeight / divisor).ceilToDouble(),
    );
  }

  /// The level whose source resolution best matches a viewport [scale] (1.0 =
  /// one image pixel per screen pixel). Zoomed out → lower detail level.
  int levelForScale(double scale) {
    if (scale <= 0) return levelCount - 1;
    final k = (-math.log(scale) / math.ln2).floor();
    return k.clamp(0, levelCount - 1);
  }

  /// Tiles per axis at [level] with [baseTileSize].
  int tilesAcross(int level) =>
      (levelSize(level).width / baseTileSize).ceil();
  int tilesDown(int level) => (levelSize(level).height / baseTileSize).ceil();
}
