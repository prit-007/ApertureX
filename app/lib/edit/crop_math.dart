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
