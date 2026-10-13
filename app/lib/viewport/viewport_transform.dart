import 'dart:math' as math;
import 'dart:ui';

/// Pure world↔screen mapping for the tile viewport.
///
/// "World" is image pixel space (origin top-left, `imageWidth`×`imageHeight`).
/// "Screen" is the viewport widget's logical pixel space. The transform is the
/// pair (`scale`, `offset`) such that `screen = world * scale + offset`, i.e.
/// `offset` is where world origin lands on screen. Immutable; every gesture
/// produces a new instance.
class ViewportTransform {
  const ViewportTransform({required this.scale, required this.offset});

  final double scale;
  final Offset offset;

  Offset worldToScreen(Offset world) => Offset(
    world.dx * scale + offset.dx,
    world.dy * scale + offset.dy,
  );

  Offset screenToWorld(Offset screen) => Offset(
    (screen.dx - offset.dx) / scale,
    (screen.dy - offset.dy) / scale,
  );

  /// World-space rect visible in a viewport of [viewportSize].
  Rect visibleWorld(Size viewportSize) {
    final topLeft = screenToWorld(Offset.zero);
    final bottomRight = screenToWorld(
      Offset(viewportSize.width, viewportSize.height),
    );
    return Rect.fromPoints(topLeft, bottomRight);
  }

  /// Scales so an image of [imageSize] exactly fits a viewport of
  /// [viewportSize] (letterboxed on the longer axis).
  static double fitScale(Size imageSize, Size viewportSize) =>
      math.min(viewportSize.width / imageSize.width, viewportSize.height / imageSize.height);

  /// Zooms to [newScale] (clamped) keeping the world point under [focalScreen]
  /// pinned to that same screen point — the standard pinch-zoom anchor.
  ViewportTransform zoomed({
    required double newScale,
    required Offset focalScreen,
    required double minScale,
    required double maxScale,
  }) {
    final clampedScale = newScale.clamp(minScale, maxScale);
    final worldFocal = screenToWorld(focalScreen);
    return ViewportTransform(
      scale: clampedScale,
      offset: Offset(
        focalScreen.dx - worldFocal.dx * clampedScale,
        focalScreen.dy - worldFocal.dy * clampedScale,
      ),
    );
  }

  /// Pans by a screen-space [delta].
  ViewportTransform panned(Offset delta) =>
      ViewportTransform(scale: scale, offset: offset + delta);

  /// Returns a transform with [offset] clamped so the image behaves like a
  /// normal image viewer: when the scaled image is larger than the viewport it
  /// covers it entirely; when smaller it is centred.
  ViewportTransform clampToImage(Size imageSize, Size viewportSize) {
    final scaledW = imageSize.width * scale;
    final scaledH = imageSize.height * scale;

    final double dx;
    if (scaledW <= viewportSize.width) {
      dx = (viewportSize.width - scaledW) / 2;
    } else {
      dx = offset.dx.clamp(viewportSize.width - scaledW, 0.0);
    }

    final double dy;
    if (scaledH <= viewportSize.height) {
      dy = (viewportSize.height - scaledH) / 2;
    } else {
      dy = offset.dy.clamp(viewportSize.height - scaledH, 0.0);
    }

    return ViewportTransform(scale: scale, offset: Offset(dx, dy));
  }
}
