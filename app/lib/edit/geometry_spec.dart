import 'package:flutter/foundation.dart' show listEquals;

import '../edit/recipe.dart';

/// The non-destructive geometry transform taken from a recipe: flip, 90°-step
/// rotation, straighten, perspective, skew, and crop. Build with
/// [GeometrySpec.fromRecipe].
class GeometrySpec {
  const GeometrySpec({
    this.rotation = 0,
    this.flipH = false,
    this.flipV = false,
    this.straighten = 0,
    this.crop = fullCrop,
    this.perspectiveX = 0,
    this.perspectiveY = 0,
    this.skewX = 0,
    this.skewY = 0,
  });

  final int rotation; // quarter turns clockwise
  final bool flipH;
  final bool flipV;
  final double straighten; // degrees
  final List<double> crop; // normalized [l, t, r, b]
  final double perspectiveX; // horizontal perspective
  final double perspectiveY; // vertical perspective
  final double skewX; // horizontal skew
  final double skewY; // vertical skew

  bool get isNeutral =>
      rotation % 4 == 0 &&
      !flipH &&
      !flipV &&
      straighten == 0 &&
      listEquals(crop, fullCrop) &&
      perspectiveX == 0 &&
      perspectiveY == 0 &&
      skewX == 0 &&
      skewY == 0;

  factory GeometrySpec.fromRecipe(EditRecipe recipe) => GeometrySpec(
    rotation: recipe.rotation,
    flipH: recipe.flipH,
    flipV: recipe.flipV,
    straighten: recipe.straighten,
    crop: recipe.crop,
    perspectiveX: recipe.perspectiveX,
    perspectiveY: recipe.perspectiveY,
    skewX: recipe.skewX,
    skewY: recipe.skewY,
  );
}
