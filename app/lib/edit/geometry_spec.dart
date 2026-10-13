import '../edit/recipe.dart';

/// The non-destructive geometry transform taken from a recipe: flip, 90°-step
/// rotation, and straighten. Build with [GeometrySpec.fromRecipe].
class GeometrySpec {
  const GeometrySpec({
    this.rotation = 0,
    this.flipH = false,
    this.flipV = false,
    this.straighten = 0,
  });

  final int rotation; // quarter turns clockwise
  final bool flipH;
  final bool flipV;
  final double straighten; // degrees

  bool get isNeutral =>
      rotation % 4 == 0 && !flipH && !flipV && straighten == 0;

  factory GeometrySpec.fromRecipe(EditRecipe recipe) => GeometrySpec(
    rotation: recipe.rotation,
    flipH: recipe.flipH,
    flipV: recipe.flipV,
    straighten: recipe.straighten,
  );
}
