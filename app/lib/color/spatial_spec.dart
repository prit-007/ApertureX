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
    this.dehaze = 0,
    this.vignette = 0,
    this.vignetteMidpoint = 0.5,
    this.vignetteFeather = 0.5,
    this.vignetteRoundness = 0,
    this.vignetteHighlights = 0,
    this.grain = 0,
    this.grainSize = 0.25,
    this.grainRoughness = 0.5,
    this.sharpen = 0,
    this.sharpenRadius = 1.0,
    this.sharpenDetail = 0.25,
    this.sharpenMasking = 0,
    this.outputSharpenMedia = 0,
    this.outputSharpen = 0,
    this.denoiseLuma = 0,
    this.denoiseChroma = 0,
    this.aiDenoise = 0,
    // Film emulation parameters (halation, bloom, dust, scratches).
    this.filmHalation = 0,
    this.filmHalationRadius = 0.5,
    this.filmHalationThreshold = 0.8,
    this.filmBloom = 0,
    this.filmBloomRadius = 0.5,
    this.filmBloomThreshold = 0.75,
    this.filmDust = 0,
    this.filmScratches = 0,
  });

  factory SpatialSpec.fromRecipe(EditRecipe recipe) => SpatialSpec(
    shadows: recipe.shadows,
    highlights: recipe.highlights,
    clarity: recipe.clarity,
    texture: recipe.texture,
    dehaze: recipe.dehaze,
    vignette: recipe.vignette,
    vignetteMidpoint: recipe.vignetteMidpoint,
    vignetteFeather: recipe.vignetteFeather,
    vignetteRoundness: recipe.vignetteRoundness,
    vignetteHighlights: recipe.vignetteHighlights,
    grain: recipe.grain,
    grainSize: recipe.grainSize,
    grainRoughness: recipe.grainRoughness,
    sharpen: recipe.sharpen,
    sharpenRadius: recipe.sharpenRadius,
    sharpenDetail: recipe.sharpenDetail,
    sharpenMasking: recipe.sharpenMasking,
    outputSharpenMedia: recipe.outputSharpenMedia,
    outputSharpen: recipe.outputSharpen,
    denoiseLuma: recipe.denoiseLuma,
    denoiseChroma: recipe.denoiseChroma,
    aiDenoise: recipe.aiDenoise,
    filmHalation: recipe.filmHalation,
    filmHalationRadius: recipe.filmHalationRadius,
    filmHalationThreshold: recipe.filmHalationThreshold,
    filmBloom: recipe.filmBloom,
    filmBloomRadius: recipe.filmBloomRadius,
    filmBloomThreshold: recipe.filmBloomThreshold,
    filmDust: recipe.filmDust,
    filmScratches: recipe.filmScratches,
  );

  final double shadows;
  final double highlights;
  final double clarity;
  final double texture;
  final double dehaze;
  final double vignette;
  final double vignetteMidpoint;
  final double vignetteFeather;
  final double vignetteRoundness;
  final double vignetteHighlights;
  final double grain;
  final double grainSize;
  final double grainRoughness;
  final double sharpen;
  final double sharpenRadius;
  final double sharpenDetail;
  final double sharpenMasking;
  final int outputSharpenMedia;
  final double outputSharpen;
  final double denoiseLuma;
  final double denoiseChroma;
  final double aiDenoise;
  // Film emulation parameters.
  final double filmHalation;
  final double filmHalationRadius;
  final double filmHalationThreshold;
  final double filmBloom;
  final double filmBloomRadius;
  final double filmBloomThreshold;
  final double filmDust;
  final double filmScratches;

  bool get isNeutral =>
      shadows == 0 &&
      highlights == 0 &&
      clarity == 0 &&
      texture == 0 &&
      dehaze == 0 &&
      vignette == 0 &&
      grain == 0 &&
      sharpen == 0 &&
      outputSharpen == 0 &&
      denoiseLuma == 0 &&
      denoiseChroma == 0 &&
      aiDenoise == 0 &&
      filmHalation == 0 &&
      filmBloom == 0 &&
      filmDust == 0 &&
      filmScratches == 0;
}
