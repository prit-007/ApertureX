import 'dart:math' as math;
import 'dart:typed_data';

import 'roi_decoder.dart';
import 'tile_pyramid.dart';

/// A tile fetched from a [TileSource]: tightly packed RGBA8, `width × height`.
///
/// [level]/[col]/[row] echo the request, except [level]: a source serves the
/// deepest pyramid level whose native footprint fits its byte budget, so a
/// request for level 5 may deliver level 3 — the viewport must paint the tile
/// at the delivered level's world rect (never the requested one).
class DecodedTile {
  const DecodedTile({
    required this.level,
    required this.col,
    required this.row,
    required this.width,
    required this.height,
    required this.rgba,
  });

  final int level;
  final int col;
  final int row;
  final int width;
  final int height;

  /// RGBA8 pixels, length always `width * height * 4`.
  final Uint8List rgba;
}

/// On-demand decode of image tiles — the abstraction that lets the viewport
/// render a >100 MP frame without ever materialising it (#16).
///
/// Implementations must be deterministic: fetching the same tile twice (or a
/// rect via any containing window) returns identical bytes, which is what the
/// seam validation in `tile_source_test.dart` and the on-device corpus
/// harness rely on.
abstract class TileSource {
  int get imageWidth;
  int get imageHeight;
  int get tileSize;
  TilePyramid get pyramid;

  /// Deepest pyramid level whose worst-case (full) tile footprint fits the
  /// source's byte budget. Requests deeper than this are served here instead.
  int get maxFeasibleLevel;

  /// Fetches tile (col,row) at [level], clamped to [maxFeasibleLevel]; null
  /// when the tile is out of range for its (possibly clamped) level.
  Future<DecodedTile?> fetchTile(int level, int col, int row);
}

/// Source-space footprint of one pyramid tile: the level-0 rect the tile
/// covers, the power-of-two downsample factor, and the output tile size
/// (ceil-divided, so odd image sizes still tile exactly).
class TileFootprint {
  const TileFootprint({
    required this.srcX,
    required this.srcY,
    required this.srcW,
    required this.srcH,
    required this.factor,
    required this.outW,
    required this.outH,
  });

  final int srcX;
  final int srcY;
  final int srcW;
  final int srcH;

  /// `1 << level` — the box-downsample factor from source px to tile px.
  final int factor;

  final int outW;
  final int outH;

  /// RGBA bytes the native decode of this footprint produces.
  int get sourceBytes => srcW * srcH * 4;
}

/// Footprint of tile (col,row) at [level]: the tile's level-k rect scaled to
/// level 0 and clamped to the image, so edge tiles never over-decode.
TileFootprint footprintForTile(
  TilePyramid pyramid, {
  required int tileSize,
  required int level,
  required int col,
  required int row,
}) {
  final size = pyramid.levelSize(level);
  final lw = size.width.round();
  final lh = size.height.round();
  final factor = 1 << level;

  final left = col * tileSize;
  final top = row * tileSize;
  final right = math.min((col + 1) * tileSize, lw);
  final bottom = math.min((row + 1) * tileSize, lh);

  final srcX = left * factor;
  final srcY = top * factor;
  // Clamp the scaled edge to the image: level sizes ceil-divide, so the last
  // level-k pixel can cover a partial source pixel (odd image sizes).
  final srcW = math.min(right * factor, pyramid.imageWidth) - srcX;
  final srcH = math.min(bottom * factor, pyramid.imageHeight) - srcY;
  return TileFootprint(
    srcX: srcX,
    srcY: srcY,
    srcW: srcW,
    srcH: srcH,
    factor: factor,
    outW: (srcW / factor).ceil(),
    outH: (srcH / factor).ceil(),
  );
}

/// Box (average) downsample of [src] (`w × h` RGBA8) by [factor]: output
/// pixel (i,j) averages the `factor × factor` block at (i·factor, j·factor),
/// with partial blocks at the right/bottom edges averaging only existing
/// pixels. Block windows never straddle tile seams (footprint origins are
/// factor-aligned), so adjacent tiles downsample from disjoint, contiguous
/// windows and stay seam-free by construction.
///
/// Returns the input unchanged (same buffer) when [factor] <= 1.
({Uint8List rgba, int width, int height}) downsampleBox(
  Uint8List src,
  int w,
  int h,
  int factor,
) {
  if (factor <= 1) return (rgba: src, width: w, height: h);
  final ow = (w / factor).ceil();
  final oh = (h / factor).ceil();
  final out = Uint8List(ow * oh * 4);
  for (var oy = 0; oy < oh; oy++) {
    final y0 = oy * factor;
    final y1 = math.min(y0 + factor, h);
    for (var ox = 0; ox < ow; ox++) {
      final x0 = ox * factor;
      final x1 = math.min(x0 + factor, w);
      var r = 0, g = 0, b = 0, a = 0;
      for (var y = y0; y < y1; y++) {
        var i = (y * w + x0) * 4;
        for (var x = x0; x < x1; x++) {
          r += src[i];
          g += src[i + 1];
          b += src[i + 2];
          a += src[i + 3];
          i += 4;
        }
      }
      final n = (x1 - x0) * (y1 - y0);
      final o = (oy * ow + ox) * 4;
      out[o] = (r / n).round();
      out[o + 1] = (g / n).round();
      out[o + 2] = (b / n).round();
      out[o + 3] = (a / n).round();
    }
  }
  return (rgba: out, width: ow, height: oh);
}

/// A coarse-ancestor tile address: the level-`target` tile whose world extent
/// covers the level-`level` tile (col,row). Ancestors step by halving:
/// (level+1, col>>1, row>>1), (level+2, col>>2, row>>2), …
class AncestorTile {
  const AncestorTile(this.level, this.col, this.row);

  final int level;
  final int col;
  final int row;

  @override
  bool operator ==(Object other) =>
      other is AncestorTile &&
      other.level == level &&
      other.col == col &&
      other.row == row;

  @override
  int get hashCode => Object.hash(level, col, row);
}

/// Coarse ancestors of (level,col,row), nearest first, up to [maxLevel].
/// The viewport paints the first cached ancestor while the fine tile decodes.
List<AncestorTile> coarseAncestors({
  required int level,
  required int col,
  required int row,
  required int maxLevel,
}) {
  final out = <AncestorTile>[];
  for (var l = level + 1; l <= maxLevel; l++) {
    final shift = l - level;
    out.add(AncestorTile(l, col >> shift, row >> shift));
  }
  return out;
}

/// Decodes JPEG tiles on demand through [RoiDecoder] (native region decoder
/// on-device, Rust in-process fallback elsewhere), pyramid-scaled (#16).
///
/// Level 0 tiles decode their exact footprint; deeper levels decode the
/// tile's full source footprint in one native call and box-downsample —
/// both Android (`BitmapRegionDecoder`) and iOS (`CGImageSource`) inflate
/// only the touched MCUs, so peak memory is one tile footprint, never the
/// frame. Requests deeper than [maxFeasibleLevel] are served at
/// [maxFeasibleLevel] (tagged with the delivered level).
class JpegTileSource implements TileSource {
  JpegTileSource({
    required this.jpeg,
    required this.imageWidth,
    required this.imageHeight,
    this.tileSize = 512,
    this.maxLevels = 6,
    this.maxTileSourceBytes = 64 << 20,
    RoiDecoder? decoder,
    this.fetchRect,
  }) : _decoder = decoder ?? RoiDecoder();

  final Uint8List jpeg;
  @override
  final int imageWidth;
  @override
  final int imageHeight;
  @override
  final int tileSize;
  final int maxLevels;

  /// Ceiling for one tile's native decode: `srcW × srcH × 4` RGBA bytes.
  final int maxTileSourceBytes;

  /// Test seam: replaces the [RoiDecoder] rect fetch with a pure function
  /// (null → the real decoder: platform channel with Rust fallback).
  final Future<RoiBand?> Function({
    required Uint8List bytes,
    required int imageW,
    required int imageH,
    required int x,
    required int y,
    required int width,
    required int height,
  })?
  fetchRect;

  final RoiDecoder _decoder;

  @override
  late final TilePyramid pyramid = TilePyramid(
    imageWidth: imageWidth,
    imageHeight: imageHeight,
    baseTileSize: tileSize,
    maxLevels: maxLevels,
  );

  @override
  late final int maxFeasibleLevel = () {
    for (var k = pyramid.levelCount - 1; k >= 0; k--) {
      final factor = 1 << k;
      final w = math.min(tileSize * factor, imageWidth);
      final h = math.min(tileSize * factor, imageHeight);
      if (w * h * 4 <= maxTileSourceBytes) return k;
    }
    return 0;
  }();

  @override
  Future<DecodedTile?> fetchTile(int level, int col, int row) async {
    final l = level.clamp(0, maxFeasibleLevel);
    final size = pyramid.levelSize(l);
    final cols = (size.width / tileSize).ceil();
    final rows = (size.height / tileSize).ceil();
    if (col < 0 || row < 0 || col >= cols || row >= rows) return null;

    final fp = footprintForTile(
      pyramid,
      tileSize: tileSize,
      level: l,
      col: col,
      row: row,
    );
    final band = await _fetch(bytes: jpeg, imageW: imageWidth, imageH: imageHeight, x: fp.srcX, y: fp.srcY, width: fp.srcW, height: fp.srcH);
    if (band == null) return null;
    final down = downsampleBox(band.rgba, band.width, band.height, fp.factor);
    return DecodedTile(
      level: l,
      col: col,
      row: row,
      width: down.width,
      height: down.height,
      rgba: down.rgba,
    );
  }

  Future<RoiBand?> _fetch({
    required Uint8List bytes,
    required int imageW,
    required int imageH,
    required int x,
    required int y,
    required int width,
    required int height,
  }) {
    final injected = fetchRect;
    if (injected != null) {
      return injected(
        bytes: bytes,
        imageW: imageW,
        imageH: imageH,
        x: x,
        y: y,
        width: width,
        height: height,
      );
    }
    return _decoder.decodeRect(
      bytes: bytes,
      imageW: imageW,
      imageH: imageH,
      x: x,
      y: y,
      width: width,
      height: height,
    );
  }
}
