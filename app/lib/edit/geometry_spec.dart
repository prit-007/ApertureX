import 'package:flutter/foundation.dart' show listEquals;

import '../edit/recipe.dart';

/// The non-destructive geometry transform taken from a recipe: flip, 90°-step
/// rotation, straighten, and crop. Build with [GeometrySpec.fromRecipe].
class GeometrySpec {
  const GeometrySpec({
    this.rotation = 0,
    this.flipH = false,
    this.flipV = false,
    this.straighten = 0,
    this.crop = fullCrop,
  });

  final int rotation; // quarter turns clockwise
  final bool flipH;
  final bool flipV;
  final double straighten; // degrees
  final List<double> crop; // normalized [l, t, r, b]

  bool get isNeutral =>
      rotation % 4 == 0 &&
      !flipH &&
      !flipV &&
      straighten == 0 &&
      listEquals(crop, fullCrop);

  factory GeometrySpec.fromRecipe(EditRecipe recipe) => GeometrySpec(
    rotation: recipe.rotation,
    flipH: recipe.flipH,
    flipV: recipe.flipV,
    straighten: recipe.straighten,
    crop: recipe.crop,
  );
}
