import '../edit/recipe.dart';

/// The spatial pass strengths taken from a recipe. These are rendered by the
/// Rust spatial pass (not the point-wise LUT), because they need neighbour
/// pixels. Build with [SpatialSpec.fromRecipe].
class SpatialSpec {
  const SpatialSpec({
    this.shadows = 0,
    this.highlights = 0,
    this.clarity = 0,
    this.texture = 0,
    this.sharpen = 0,
    this.denoiseLuma = 0,
    this.denoiseChroma = 0,
  });

  final double shadows;
  final double highlights;
  final double clarity;
  final double texture;
  final double sharpen;
  final double denoiseLuma;
  final double denoiseChroma;

  bool get isNeutral =>
      shadows == 0 &&
      highlights == 0 &&
      clarity == 0 &&
      texture == 0 &&
      sharpen == 0 &&
      denoiseLuma == 0 &&
      denoiseChroma == 0;

  factory SpatialSpec.fromRecipe(EditRecipe recipe) => SpatialSpec(
    shadows: recipe.shadows,
    highlights: recipe.highlights,
    clarity: recipe.clarity,
    texture: recipe.texture,
    sharpen: recipe.sharpen,
    denoiseLuma: recipe.denoiseLuma,
    denoiseChroma: recipe.denoiseChroma,
  );
}
