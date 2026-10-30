import 'dart:ui';

import 'recipe.dart' show fullCrop;

/// Pure geometry helpers for the crop tool (normalized `[0,1]` rect space).

List<double> rectToList(Rect r) => [r.left, r.top, r.right, r.bottom];

Rect listToRect(List<double> v) =>
    Rect.fromLTRB(v[0], v[1], v[2], v[3]);

/// Fits a rect of pixel [aspect] (`w/h`) centred inside [within] (normalized),
/// given the image's pixel [imageSize]. `aspect <= 0` returns [within] as-is.
Rect fitAspectWithin(Rect within, double aspect, Size imageSize) {
  if (aspect <= 0 || imageSize.width <= 0 || imageSize.height <= 0) {
    return within;
  }
  final normalizedAspect = aspect * imageSize.height / imageSize.width;
  var w = within.width;
  var h = w / normalizedAspect;
  if (h > within.height) {
    h = within.height;
    w = h * normalizedAspect;
  }
  return Rect.fromCenter(center: within.center, width: w, height: h);
}

/// Clamps a normalised crop rect to the unit square with a minimum [min] size.
Rect clampNormalized(Rect r, {double min = 0.05}) {
  final l = r.left.clamp(0.0, 1.0 - min);
  final t = r.top.clamp(0.0, 1.0 - min);
  final rr = r.right.clamp(l + min, 1.0);
  final b = r.bottom.clamp(t + min, 1.0);
  return Rect.fromLTRB(l, t, rr, b);
}

/// True when [crop] covers the whole frame ([fullCrop]).
bool isFullCrop(List<double> crop) =>
    crop.length == 4 &&
    crop[0] == fullCrop[0] &&
    crop[1] == fullCrop[1] &&
    crop[2] == fullCrop[2] &&
    crop[3] == fullCrop[3];

/// Calculates an intelligent photographic crop (Auto-Frame) based on detected subject
/// bounding parameters [cx, cy, rx, ry] adhering to the Rule of Thirds (Phase 2 Pro feature).
List<double> calculateAutoFrameCrop({
  required double cx,
  required double cy,
  required double rx,
  required double ry,
  double? targetAspect,
}) {
  // Safe bounds check
  final safeCx = cx.clamp(0.05, 0.95);
  final safeCy = cy.clamp(0.05, 0.95);
  final safeRx = rx.clamp(0.05, 0.45);
  final safeRy = ry.clamp(0.05, 0.45);

  // Photographic placement:
  // If subject is towards left, place on left 1/3 line; if towards right, place on right 1/3 line.
  // Vertically, eyes/upper body should fall near the top 1/3 line.
  final double targetThirdX = safeCx < 0.42
      ? 1.0 / 3.0
      : safeCx > 0.58
          ? 2.0 / 3.0
          : 0.5;
  const double targetThirdY = 0.36; // Golden ratio upper third

  // Determine crop dimensions with sufficient breathing room around subject
  double cropW = (safeRx * 2.8).clamp(0.40, 1.0);
  double cropH = (safeRy * 2.6).clamp(0.45, 1.0);

  // If a specific aspect ratio is requested, conform dimensions
  if (targetAspect != null && targetAspect > 0) {
    if (cropW / cropH > targetAspect) {
      cropH = (cropW / targetAspect).clamp(0.35, 1.0);
    } else {
      cropW = (cropH * targetAspect).clamp(0.35, 1.0);
    }
  }

  // Anchor crop box to target third coordinates
  double l = safeCx - cropW * targetThirdX;
  double t = safeCy - cropH * targetThirdY;

  // Shift crop box so it stays strictly within [0.0, 1.0] unit square
  if (l < 0.0) l = 0.0;
  if (t < 0.0) t = 0.0;
  if (l + cropW > 1.0) l = 1.0 - cropW;
  if (t + cropH > 1.0) t = 1.0 - cropH;

  // Ensure the subject's core bounding box is contained
  final sL = (safeCx - safeRx * 1.05).clamp(0.0, 1.0);
  final sT = (safeCy - safeRy * 1.05).clamp(0.0, 1.0);
  final sR = (safeCx + safeRx * 1.05).clamp(0.0, 1.0);
  final sB = (safeCy + safeRy * 1.05).clamp(0.0, 1.0);

  l = l.clamp(0.0, sL);
  t = t.clamp(0.0, sT);
  final r = (l + cropW).clamp(sR, 1.0);
  final b = (t + cropH).clamp(sB, 1.0);

  return [l, t, r, b];
}
