import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import 'package:aperturex/viewport/image_canvas.dart' show ImageCanvas;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The [ImageCanvas]'s current view transform (fitted image rect + pan/zoom),
/// published so overlays living *outside* the canvas — the selective-editing
/// node overlay (issue #25) — can map normalised image coordinates to screen
/// coordinates and back.
///
/// The canvas writes it whenever the layout/zoom/pan changes; consumers must
/// treat `null` as "no image loaded (yet)".
class CanvasTransform {
  const CanvasTransform({
    required this.fitted,
    required this.offset,
    required this.scale,
  });

  /// Contain-fit display size of the image within the canvas bounds.
  final Size fitted;

  /// Pan offset applied before scaling (letterbox centring).
  final Offset offset;

  /// Zoom factor (1 = fitted).
  final double scale;

  /// Image aspect ratio (fitted preserves the source aspect).
  double get aspect => fitted.width / fitted.height;

  /// Screen (overlay-local) position of a normalised image point.
  Offset toScreen(Offset normalized) => Offset(
    offset.dx + normalized.dx * fitted.width * scale,
    offset.dy + normalized.dy * fitted.height * scale,
  );

  /// Normalised image point (0..1, may fall outside for off-image positions)
  /// for a screen position; null when the transform cannot map (no area).
  Offset? toNormalized(Offset screen) {
    if (fitted.width <= 0 || fitted.height <= 0 || scale <= 0) return null;
    return Offset(
      (screen.dx - offset.dx) / (fitted.width * scale),
      (screen.dy - offset.dy) / (fitted.height * scale),
    );
  }

  /// On-screen radius in pixels of a normalised x-radius [rx].
  double radiusOf(double rx) => rx * fitted.width * scale;

  /// Returns the normalized image coordinate of the center of [viewportSize],
  /// clamped to [0.05..0.95]. If [viewportSize] is null or transform is invalid, returns (0.5, 0.5).
  Offset viewportCenterNormalized([Size? viewportSize]) {
    if (viewportSize == null || viewportSize.width <= 0 || viewportSize.height <= 0) {
      return const Offset(0.5, 0.5);
    }
    final center = Offset(viewportSize.width / 2, viewportSize.height / 2);
    final norm = toNormalized(center);
    if (norm == null) return const Offset(0.5, 0.5);
    return Offset(norm.dx.clamp(0.05, 0.95), norm.dy.clamp(0.05, 0.95));
  }

  @override
  bool operator ==(Object other) =>
      other is CanvasTransform &&
      other.fitted == fitted &&
      other.offset == offset &&
      other.scale == scale;

  @override
  int get hashCode => Object.hash(fitted, offset, scale);
}

/// Gesture event dispatched by interactive overlays (Retouch, NodeOverlay) to pan/zoom
/// the underlying ImageCanvas seamlessly.
class CanvasGestureEvent {
  const CanvasGestureEvent({
    this.focalPoint,
    this.scaleDelta = 1.0,
    this.focalDelta = Offset.zero,
    this.isStart = false,
    this.isEnd = false,
  });

  final Offset? focalPoint;
  final double scaleDelta;
  final Offset focalDelta;
  final bool isStart;
  final bool isEnd;
}

class CanvasGestureNotifier extends Notifier<CanvasGestureEvent?> {
  @override
  CanvasGestureEvent? build() => null;

  void start(Offset focalPoint) {
    state = CanvasGestureEvent(focalPoint: focalPoint, isStart: true);
  }

  void update({
    required Offset focalPoint,
    required double scaleDelta,
    required Offset focalDelta,
  }) {
    state = CanvasGestureEvent(
      focalPoint: focalPoint,
      scaleDelta: scaleDelta,
      focalDelta: focalDelta,
    );
  }

  void end() {
    state = const CanvasGestureEvent(isEnd: true);
  }
}

final canvasGestureProvider =
    NotifierProvider<CanvasGestureNotifier, CanvasGestureEvent?>(
  CanvasGestureNotifier.new,
);

class CanvasTransformNotifier extends Notifier<CanvasTransform?> {
  @override
  CanvasTransform? build() => null;

  void set(CanvasTransform? transform) {
    if (state == transform) return;
    state = transform;
  }
}

/// Current view transform of the shared canvas, or null before an image loads
/// (or after one fails).
final canvasTransformProvider =
    NotifierProvider<CanvasTransformNotifier, CanvasTransform?>(
      CanvasTransformNotifier.new,
    );

/// Callback function that samples normalized luminance (0.0..1.0) at normalized coordinates (u, v).
typedef PixelLumaSampler = double? Function(double u, double v);

class PixelSamplerNotifier extends Notifier<PixelLumaSampler?> {
  @override
  PixelLumaSampler? build() => null;

  void setSampler(PixelLumaSampler? sampler) {
    state = sampler;
  }
}

/// Active pixel luminance sampler provided by the image canvas.
final pixelSamplerProvider =
    NotifierProvider<PixelSamplerNotifier, PixelLumaSampler?>(
  PixelSamplerNotifier.new,
);

/// Computes the next viewport transform when double-tapping on the canvas.
///
/// Toggles between Fit (1.0x) and 100% 1:1 sensor resolution (or 2.5x-4.0x)
/// centered precisely on [tapPosition].
CanvasTransform computeDoubleTapZoom({
  required double currentScale,
  required Offset currentOffset,
  required Offset tapPosition,
  required Size fitted,
  required Size bounds,
  int fullWidth = 0,
}) {
  if (currentScale > 1.05) {
    // Already zoomed in; reset to fitted 1.0x view.
    return CanvasTransform(
      fitted: fitted,
      scale: 1.0,
      offset: Offset(
        (bounds.width - fitted.width) / 2,
        (bounds.height - fitted.height) / 2,
      ),
    );
  }

  final pos = tapPosition == Offset.zero
      ? Offset(bounds.width / 2, bounds.height / 2)
      : tapPosition;

  // 1:1 sensor view target scale
  final targetScale = (fullWidth > 0 && fitted.width > 0)
      ? math.max(2.0, fullWidth / fitted.width).clamp(1.5, 4.0)
      : 2.5;

  final worldX = (pos.dx - currentOffset.dx) / currentScale;
  final worldY = (pos.dy - currentOffset.dy) / currentScale;
  final newOffset = Offset(
    pos.dx - worldX * targetScale,
    pos.dy - worldY * targetScale,
  );

  final cw = fitted.width * targetScale;
  final ch = fitted.height * targetScale;
  final cx = cw <= bounds.width
      ? (bounds.width - cw) / 2
      : newOffset.dx.clamp(bounds.width - cw, 0.0);
  final cy = ch <= bounds.height
      ? (bounds.height - ch) / 2
      : newOffset.dy.clamp(bounds.height - ch, 0.0);

  return CanvasTransform(
    fitted: fitted,
    scale: targetScale,
    offset: Offset(cx, cy),
  );
}

