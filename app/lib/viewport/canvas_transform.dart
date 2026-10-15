import 'dart:ui' show Offset, Size;

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

  @override
  bool operator ==(Object other) =>
      other is CanvasTransform &&
      other.fitted == fitted &&
      other.offset == offset &&
      other.scale == scale;

  @override
  int get hashCode => Object.hash(fitted, offset, scale);
}

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
