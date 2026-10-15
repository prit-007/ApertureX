import 'dart:math' as math;
import 'dart:ui';

import '../edit/recipe.dart';

/// Halo-expanded decode rect for one tile: the tile's own extent grown by
/// [halo] pixels on each side and clamped to the image bounds. The spatial
/// chain (`apply_spatial_rect`) needs this context on all four sides so
/// interior tile pixels see true neighbours — except at the image edges,
/// where the rect is clamped and the bake treats the boundary as its own
/// context.
///
/// Returns the tile rect at `[x, y, tileW, tileH]` when [halo] is 0.
Rect tileDecodeRect(
  Rect tile, {
  required int imageW,
  required int imageH,
  required int halo,
}) {
  final x0 = tile.left.toInt();
  final y0 = tile.top.toInt();
  final tw = tile.width.toInt();
  final th = tile.height.toInt();
  if (halo <= 0) return Rect.fromLTWH(x0.toDouble(), y0.toDouble(), tw.toDouble(), th.toDouble());
  final dx = math.max(0, x0 - halo);
  final dy = math.max(0, y0 - halo);
  final dw = math.min(imageW, x0 + tw + halo) - dx;
  final dh = math.min(imageH, y0 + th + halo) - dy;
  return Rect.fromLTWH(dx.toDouble(), dy.toDouble(), dw.toDouble(), dh.toDouble());
}

/// High-zoom ROI overlay planning (issue #55).
///
/// At deep zoom the proxy (~1.3K) would be magnified past its native density
/// and turn soft. The fix is a full-resolution **tile field** of the
/// original frame composited over the proxy:
///
///  * **full-width strips** because the spatial bake machinery
///    (`apply_spatial_band`) consumes full-width row bands, giving every
///    output pixel its true halo context — seam-free by construction;
///  * **geometry gate** — rotation/crop/warp are baked into or applied over
///    the proxy, so a band of the *original* frame would not align while any
///    geometry edit is active;
///  * **memory budget** — a >100 MP frame decoded full-width at once must not
///    blow the band budget, so the row count is capped to a byte ceiling.
class RoiOverlayPlan {
  const RoiOverlayPlan({
    required this.bandTop,
    required this.bandBottom,
    required this.dstRect,
    required this.decodeW,
    required this.decodeH,
  });

  /// Source band, inclusive top / exclusive bottom, in image pixels.
  final int bandTop;
  final int bandBottom;

  /// Where the visible part of the band draws, in world (width-fit) pixels.
  /// A sub-rect of the band's full-width world strip.
  final Rect dstRect;

  /// Source pixels to decode: the full image width × [decodeH] band rows.
  final int decodeW;
  final int decodeH;
}

/// Default ceiling for one decoded band: 32 MiB of RGBA.
const int kDefaultRoiBandBytes = 32 << 20;

/// True when recipe geometry would make a raw source band misalign with the
/// baked proxy — rotation/crop/warp are applied to the proxy (baked in, or
/// GPU-warped live), while the band is cut from the original frame. The
/// overlay must stay off for any of these (#55 gate).
bool roiBlockedByGeometry(EditRecipe recipe) =>
    recipe.rotation != 0 ||
    recipe.flipH ||
    recipe.flipV ||
    recipe.straighten != 0.0 ||
    recipe.crop[0] != fullCrop[0] ||
    recipe.crop[1] != fullCrop[1] ||
    recipe.crop[2] != fullCrop[2] ||
    recipe.crop[3] != fullCrop[3] ||
    recipe.perspectiveX != 0.0 ||
    recipe.perspectiveY != 0.0 ||
    recipe.skewX != 0.0 ||
    recipe.skewY != 0.0;

/// World-space rect of the decoded band's full-width strip: the overlay draw
/// surface. X spans the whole width-fit content (the viewport transform
/// positions it); Y follows the band's rows in the full frame.
Rect roiStripRect(
  RoiOverlayPlan plan, {
  required int fullHeight,
  required Size fitted,
}) {
  final top = plan.bandTop / fullHeight * fitted.height;
  final height =
      (plan.bandBottom - plan.bandTop) / fullHeight * fitted.height;
  return Rect.fromLTWH(0, top, fitted.width, height);
}

/// Plans the high-zoom ROI overlay, or returns null when none should show.
///
/// Inactive when: the proxy is still at native density, geometry edits are
/// active, the source has no region decoder (RAW), or the viewport misses the
/// image. The caller debounces — this is a pure function of viewport state.
RoiOverlayPlan? planRoiOverlay({
  required int imageW,
  required int imageH,
  required int proxyW,
  required Size fitted,
  required double scale,
  required Offset offset,
  required Size viewport,
  int maxRoiBandBytes = kDefaultRoiBandBytes,
  bool geometryActive = false,
  bool roiSupported = true,
}) {
  if (geometryActive || !roiSupported) return null;
  if (imageW <= 0 || imageH <= 0 || fitted.width <= 0 || fitted.height <= 0) {
    return null;
  }
  // The proxy only loses sharpness once the image is displayed wider than the
  // proxy has pixels — that is exactly where a full-res band adds detail.
  if (scale * fitted.width < proxyW) return null;
  if (scale <= 0) return null;

  // Inverse of the viewport transform (translate(offset) * scale, topLeft):
  // world = (screen - offset) / scale.
  final visible = Rect.fromLTWH(
    -offset.dx / scale,
    -offset.dy / scale,
    viewport.width / scale,
    viewport.height / scale,
  );
  final fittedRect = Rect.fromLTWH(0, 0, fitted.width, fitted.height);
  final world = visible.intersect(fittedRect);
  if (world.width <= 0 || world.height <= 0) return null;

  // World → image pixels.
  final rowsNeeded = math.max(
    1,
    (world.height / fitted.height * imageH).ceil(),
  );
  var bandRows = rowsNeeded;
  if (imageW > 0) {
    final budgetRows = math.max(1, maxRoiBandBytes ~/ (4 * imageW));
    bandRows = math.min(bandRows, budgetRows);
  }

  final top = math.min(
    imageH - 1,
    math.max(0, (world.top / fitted.height * imageH).floor()),
  );
  final bottom = math.min(imageH, top + bandRows);

  return RoiOverlayPlan(
    bandTop: top,
    bandBottom: bottom,
    dstRect: world,
    decodeW: imageW,
    decodeH: bottom - top,
  );
}
