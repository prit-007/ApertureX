import 'recipe.dart';

/// The recipe's parameter groups (ARCHITECTURE §16, P2). Lightroom categories
/// map 1:1 onto sections; Snapseed tools map onto parameters *within* them.
enum RecipeSection { light, color, tone, retouch, blur, effects, detail, optics, geometry, masking, film, lab }

/// How a parameter is manipulated. The seed ships sliders only; the catalog is
/// the seam a future `curve` or `hueGrid` parameter slots into.
enum ParameterKind { slider }

/// Every editable scalar in the recipe — the seam both shells share. A
/// parameter exists here *before* either shell renders it.
enum Parameter {
  // Light
  exposure,
  contrast,
  highlights,
  shadows,
  whites,
  blacks,
  // Spatial (rendered by the Rust spatial pass, not the LUT).
  clarity,
  texture,
  dehaze,
  vignette,
  vignetteMidpoint,
  vignetteFeather,
  vignetteRoundness,
  vignetteHighlights,
  grain,
  grainSize,
  grainRoughness,
  sharpen,
  sharpenRadius,
  sharpenDetail,
  sharpenMasking,
  denoiseLuma,
  denoiseChroma,
  // Color
  temperature,
  tint,
  vibrance,
  saturation,
  // Color grading (split tone / 3-way color wheels): hue, saturation, luminance, blending, balance.
  gradeShadowHue,
  gradeShadowSat,
  gradeShadowLum,
  gradeMidHue,
  gradeMidSat,
  gradeMidLum,
  gradeHighlightHue,
  gradeHighlightSat,
  gradeHighlightLum,
  gradeBlending,
  gradeBalance,
  // Optics
  defringePurpleAmount,
  defringeGreenAmount,
  profileDistortion,
  profileVignetting,
  // Blur
  blurAmount,
  blurFocalPoint,
  blurFocalRange,
  blurBokehBoost,
  // Film Emulation
  filmHalation,
  filmHalationRadius,
  filmHalationThreshold,
  filmBloom,
  filmBloomRadius,
  filmBloomThreshold,
  filmDust,
  filmScratches,
  // Shader Lab
  shaderParam1,
  shaderParam2,
  shaderParam3,
}

/// Static metadata for a [Parameter].
class ParameterSpec {
  const ParameterSpec({
    required this.id,
    required this.section,
    required this.label,
    this.kind = ParameterKind.slider,
    required this.min,
    required this.max,
    this.neutral = 0,
    this.scale = 1,
    this.response = ResponseCurve.linear,
  }) : assert(min < max),
       assert(min <= neutral && neutral <= max);

  final Parameter id;
  final RecipeSection section;
  final String label;
  final ParameterKind kind;

  /// Inclusive slider range. Neutral lies within it.
  final double min;
  final double max;

  /// Value that leaves the image unchanged.
  final double neutral;

  /// Gesture/fine-control sensitivity: a unit delta moves the value by this
  /// (exposure is EV: a full Snapseed swipe = 2 EV via this scale).
  final double scale;

  /// Track-position ↔ value response curve (issue #51). Defaults to linear
  /// so existing behaviour is unchanged.
  final ResponseCurve response;
}

/// Optional non-linear track mapping (issue #51): fine control near neutral,
/// coarse near extremes. Must stay invertible.
enum ResponseCurve {
  /// fraction = (value - min) / span (the historical behaviour).
  linear,

  /// Piecewise-sqrt about neutral: fraction = 0.5 + sign·(|v−n|/half)^0.5·0.5
  /// where half = max(|max−n|, |n−min|). Symmetric, invertible, gives ~7%
  /// of track to the first 10% of a ±5 EV range (vs 1% linear).
  squareRootHalf,
}

const Map<Parameter, ParameterSpec> parameterSpecs = {
  Parameter.exposure: ParameterSpec(
    id: Parameter.exposure,
    section: RecipeSection.light,
    label: 'Exposure',
    min: -4,
    max: 4,
    scale: 2,
  ),
  Parameter.contrast: ParameterSpec(
    id: Parameter.contrast,
    section: RecipeSection.light,
    label: 'Contrast',
    min: -1,
    max: 1,
  ),
  Parameter.highlights: ParameterSpec(
    id: Parameter.highlights,
    section: RecipeSection.light,
    label: 'Highlights',
    min: -1,
    max: 1,
  ),
  Parameter.shadows: ParameterSpec(
    id: Parameter.shadows,
    section: RecipeSection.light,
    label: 'Shadows',
    min: -1,
    max: 1,
  ),
  Parameter.whites: ParameterSpec(
    id: Parameter.whites,
    section: RecipeSection.light,
    label: 'Whites',
    min: -1,
    max: 1,
  ),
  Parameter.blacks: ParameterSpec(
    id: Parameter.blacks,
    section: RecipeSection.light,
    label: 'Blacks',
    min: -1,
    max: 1,
  ),
  Parameter.clarity: ParameterSpec(
    id: Parameter.clarity,
    section: RecipeSection.effects,
    label: 'Clarity',
    min: -1,
    max: 1,
  ),
  Parameter.texture: ParameterSpec(
    id: Parameter.texture,
    section: RecipeSection.effects,
    label: 'Texture',
    min: -1,
    max: 1,
  ),
  Parameter.dehaze: ParameterSpec(
    id: Parameter.dehaze,
    section: RecipeSection.effects,
    label: 'Dehaze',
    min: -1,
    max: 1,
  ),
  Parameter.vignette: ParameterSpec(
    id: Parameter.vignette,
    section: RecipeSection.effects,
    label: 'Vignette',
    min: -1,
    max: 1,
  ),
  Parameter.vignetteMidpoint: ParameterSpec(
    id: Parameter.vignetteMidpoint,
    section: RecipeSection.effects,
    label: 'Midpoint',
    min: 0,
    max: 1,
    neutral: 0.5,
  ),
  Parameter.vignetteFeather: ParameterSpec(
    id: Parameter.vignetteFeather,
    section: RecipeSection.effects,
    label: 'Feather',
    min: 0,
    max: 1,
    neutral: 0.5,
  ),
  Parameter.vignetteRoundness: ParameterSpec(
    id: Parameter.vignetteRoundness,
    section: RecipeSection.effects,
    label: 'Roundness',
    min: -1,
    max: 1,
  ),
  Parameter.vignetteHighlights: ParameterSpec(
    id: Parameter.vignetteHighlights,
    section: RecipeSection.effects,
    label: 'Highlights',
    min: 0,
    max: 1,
  ),
  Parameter.grain: ParameterSpec(
    id: Parameter.grain,
    section: RecipeSection.effects,
    label: 'Grain',
    min: 0,
    max: 1,
  ),
  Parameter.grainSize: ParameterSpec(
    id: Parameter.grainSize,
    section: RecipeSection.effects,
    label: 'Size',
    min: 0.1,
    max: 1,
    neutral: 0.25,
  ),
  Parameter.grainRoughness: ParameterSpec(
    id: Parameter.grainRoughness,
    section: RecipeSection.effects,
    label: 'Roughness',
    min: 0,
    max: 1,
    neutral: 0.5,
  ),
  Parameter.sharpen: ParameterSpec(
    id: Parameter.sharpen,
    section: RecipeSection.detail,
    label: 'Sharpening',
    min: 0,
    max: 1,
  ),
  Parameter.sharpenRadius: ParameterSpec(
    id: Parameter.sharpenRadius,
    section: RecipeSection.detail,
    label: 'Radius',
    min: 0.5,
    max: 3.0,
    neutral: 1.0,
  ),
  Parameter.sharpenDetail: ParameterSpec(
    id: Parameter.sharpenDetail,
    section: RecipeSection.detail,
    label: 'Detail',
    min: 0,
    max: 1,
    neutral: 0.25,
  ),
  Parameter.sharpenMasking: ParameterSpec(
    id: Parameter.sharpenMasking,
    section: RecipeSection.detail,
    label: 'Masking',
    min: 0,
    max: 1,
  ),
  Parameter.denoiseLuma: ParameterSpec(
    id: Parameter.denoiseLuma,
    section: RecipeSection.detail,
    label: 'Noise (Luma)',
    min: 0,
    max: 1,
  ),
  Parameter.denoiseChroma: ParameterSpec(
    id: Parameter.denoiseChroma,
    section: RecipeSection.detail,
    label: 'Noise (Chroma)',
    min: 0,
    max: 1,
  ),
  Parameter.temperature: ParameterSpec(
    id: Parameter.temperature,
    section: RecipeSection.color,
    label: 'Temperature',
    min: -1,
    max: 1,
  ),
  Parameter.tint: ParameterSpec(
    id: Parameter.tint,
    section: RecipeSection.color,
    label: 'Tint',
    min: -1,
    max: 1,
  ),
  Parameter.vibrance: ParameterSpec(
    id: Parameter.vibrance,
    section: RecipeSection.color,
    label: 'Vibrance',
    min: -1,
    max: 1,
  ),
  Parameter.saturation: ParameterSpec(
    id: Parameter.saturation,
    section: RecipeSection.color,
    label: 'Saturation',
    min: -1,
    max: 1,
  ),
  Parameter.gradeShadowHue: ParameterSpec(
    id: Parameter.gradeShadowHue,
    section: RecipeSection.color,
    label: 'Shadow Hue',
    min: 0,
    max: 1,
  ),
  Parameter.gradeShadowSat: ParameterSpec(
    id: Parameter.gradeShadowSat,
    section: RecipeSection.color,
    label: 'Shadow Strength',
    min: 0,
    max: 1,
  ),
  Parameter.gradeShadowLum: ParameterSpec(
    id: Parameter.gradeShadowLum,
    section: RecipeSection.color,
    label: 'Shadow Luminance',
    min: -1,
    max: 1,
  ),
  Parameter.gradeMidHue: ParameterSpec(
    id: Parameter.gradeMidHue,
    section: RecipeSection.color,
    label: 'Midtone Hue',
    min: 0,
    max: 1,
  ),
  Parameter.gradeMidSat: ParameterSpec(
    id: Parameter.gradeMidSat,
    section: RecipeSection.color,
    label: 'Midtone Strength',
    min: 0,
    max: 1,
  ),
  Parameter.gradeMidLum: ParameterSpec(
    id: Parameter.gradeMidLum,
    section: RecipeSection.color,
    label: 'Midtone Luminance',
    min: -1,
    max: 1,
  ),
  Parameter.gradeHighlightHue: ParameterSpec(
    id: Parameter.gradeHighlightHue,
    section: RecipeSection.color,
    label: 'Highlight Hue',
    min: 0,
    max: 1,
  ),
  Parameter.gradeHighlightSat: ParameterSpec(
    id: Parameter.gradeHighlightSat,
    section: RecipeSection.color,
    label: 'Highlight Strength',
    min: 0,
    max: 1,
  ),
  Parameter.gradeHighlightLum: ParameterSpec(
    id: Parameter.gradeHighlightLum,
    section: RecipeSection.color,
    label: 'Highlight Luminance',
    min: -1,
    max: 1,
  ),
  Parameter.gradeBlending: ParameterSpec(
    id: Parameter.gradeBlending,
    section: RecipeSection.color,
    label: 'Blending',
    min: 0,
    max: 1,
    neutral: 0.5,
  ),
  Parameter.gradeBalance: ParameterSpec(
    id: Parameter.gradeBalance,
    section: RecipeSection.color,
    label: 'Balance',
    min: -1,
    max: 1,
  ),
  Parameter.defringePurpleAmount: ParameterSpec(
    id: Parameter.defringePurpleAmount,
    section: RecipeSection.optics,
    label: 'Purple Amount',
    min: 0,
    max: 1,
  ),
  Parameter.defringeGreenAmount: ParameterSpec(
    id: Parameter.defringeGreenAmount,
    section: RecipeSection.optics,
    label: 'Green Amount',
    min: 0,
    max: 1,
  ),
  Parameter.profileDistortion: ParameterSpec(
    id: Parameter.profileDistortion,
    section: RecipeSection.optics,
    label: 'Distortion',
    min: 0,
    max: 2,
    neutral: 1.0,
  ),
  Parameter.profileVignetting: ParameterSpec(
    id: Parameter.profileVignetting,
    section: RecipeSection.optics,
    label: 'Vignetting',
    min: 0,
    max: 2,
    neutral: 1.0,
  ),
  Parameter.blurAmount: ParameterSpec(
    id: Parameter.blurAmount,
    section: RecipeSection.blur,
    label: 'Blur Amount',
    min: 0,
    max: 1,
  ),
  Parameter.blurFocalPoint: ParameterSpec(
    id: Parameter.blurFocalPoint,
    section: RecipeSection.blur,
    label: 'Focal Point',
    min: 0,
    max: 1,
    neutral: 0.5,
  ),
  Parameter.blurFocalRange: ParameterSpec(
    id: Parameter.blurFocalRange,
    section: RecipeSection.blur,
    label: 'Focal Range',
    min: 0.01,
    max: 1,
    neutral: 0.2,
  ),
  Parameter.blurBokehBoost: ParameterSpec(
    id: Parameter.blurBokehBoost,
    section: RecipeSection.blur,
    label: 'Bokeh Boost',
    min: 0,
    max: 1,
  ),
  // Film Emulation
  Parameter.filmHalation: ParameterSpec(
    id: Parameter.filmHalation,
    section: RecipeSection.film,
    label: 'Halation',
    min: 0,
    max: 1,
  ),
  Parameter.filmHalationRadius: ParameterSpec(
    id: Parameter.filmHalationRadius,
    section: RecipeSection.film,
    label: 'Halation Radius',
    min: 0.1,
    max: 1,
    neutral: 0.5,
  ),
  Parameter.filmHalationThreshold: ParameterSpec(
    id: Parameter.filmHalationThreshold,
    section: RecipeSection.film,
    label: 'Halation Threshold',
    min: 0.1,
    max: 1,
    neutral: 0.8,
  ),
  Parameter.filmBloom: ParameterSpec(
    id: Parameter.filmBloom,
    section: RecipeSection.film,
    label: 'Bloom',
    min: 0,
    max: 1,
  ),
  Parameter.filmBloomRadius: ParameterSpec(
    id: Parameter.filmBloomRadius,
    section: RecipeSection.film,
    label: 'Bloom Radius',
    min: 0.1,
    max: 1,
    neutral: 0.5,
  ),
  Parameter.filmBloomThreshold: ParameterSpec(
    id: Parameter.filmBloomThreshold,
    section: RecipeSection.film,
    label: 'Bloom Threshold',
    min: 0.1,
    max: 1,
    neutral: 0.75,
  ),
  Parameter.filmDust: ParameterSpec(
    id: Parameter.filmDust,
    section: RecipeSection.film,
    label: 'Dust Flecks',
    min: 0,
    max: 1,
  ),
  Parameter.filmScratches: ParameterSpec(
    id: Parameter.filmScratches,
    section: RecipeSection.film,
    label: 'Film Scratches',
    min: 0,
    max: 1,
  ),
  // Shader Lab
  Parameter.shaderParam1: ParameterSpec(
    id: Parameter.shaderParam1,
    section: RecipeSection.lab,
    label: 'Intensity',
    min: 0,
    max: 1,
  ),
  Parameter.shaderParam2: ParameterSpec(
    id: Parameter.shaderParam2,
    section: RecipeSection.lab,
    label: 'Dispersion / Freq',
    min: 0,
    max: 1,
  ),
  Parameter.shaderParam3: ParameterSpec(
    id: Parameter.shaderParam3,
    section: RecipeSection.lab,
    label: 'Noise / Jitter',
    min: 0,
    max: 1,
  ),
};

/// The [ParameterSpec] for [p]. Always present — the catalog covers the enum.
ParameterSpec specOf(Parameter p) => parameterSpecs[p]!;

/// Clamps [value] to [p]'s inclusive range.
double clampParameter(Parameter p, double value) {
  final s = specOf(p);
  return value.clamp(s.min, s.max);
}

/// The current [p] value on [recipe].
double valueOf(EditRecipe recipe, Parameter p) => switch (p) {
  Parameter.exposure => recipe.exposure,
  Parameter.contrast => recipe.contrast,
  Parameter.highlights => recipe.highlights,
  Parameter.shadows => recipe.shadows,
  Parameter.whites => recipe.whites,
  Parameter.blacks => recipe.blacks,
  Parameter.clarity => recipe.clarity,
  Parameter.texture => recipe.texture,
  Parameter.dehaze => recipe.dehaze,
  Parameter.vignette => recipe.vignette,
  Parameter.vignetteMidpoint => recipe.vignetteMidpoint,
  Parameter.vignetteFeather => recipe.vignetteFeather,
  Parameter.vignetteRoundness => recipe.vignetteRoundness,
  Parameter.vignetteHighlights => recipe.vignetteHighlights,
  Parameter.grain => recipe.grain,
  Parameter.grainSize => recipe.grainSize,
  Parameter.grainRoughness => recipe.grainRoughness,
  Parameter.sharpen => recipe.sharpen,
  Parameter.sharpenRadius => recipe.sharpenRadius,
  Parameter.sharpenDetail => recipe.sharpenDetail,
  Parameter.sharpenMasking => recipe.sharpenMasking,
  Parameter.denoiseLuma => recipe.denoiseLuma,
  Parameter.denoiseChroma => recipe.denoiseChroma,
  Parameter.temperature => recipe.temperature,
  Parameter.tint => recipe.tint,
  Parameter.vibrance => recipe.vibrance,
  Parameter.saturation => recipe.saturation,
  Parameter.gradeShadowHue => recipe.gradeShadowHue,
  Parameter.gradeShadowSat => recipe.gradeShadowSat,
  Parameter.gradeShadowLum => recipe.gradeShadowLum,
  Parameter.gradeMidHue => recipe.gradeMidHue,
  Parameter.gradeMidSat => recipe.gradeMidSat,
  Parameter.gradeMidLum => recipe.gradeMidLum,
  Parameter.gradeHighlightHue => recipe.gradeHighlightHue,
  Parameter.gradeHighlightSat => recipe.gradeHighlightSat,
  Parameter.gradeHighlightLum => recipe.gradeHighlightLum,
  Parameter.gradeBlending => recipe.gradeBlending,
  Parameter.gradeBalance => recipe.gradeBalance,
  Parameter.defringePurpleAmount => recipe.defringePurpleAmount,
  Parameter.defringeGreenAmount => recipe.defringeGreenAmount,
  Parameter.profileDistortion => recipe.profileDistortion,
  Parameter.profileVignetting => recipe.profileVignetting,
  Parameter.blurAmount => recipe.blurAmount,
  Parameter.blurFocalPoint => recipe.blurFocalPoint,
  Parameter.blurFocalRange => recipe.blurFocalRange,
  Parameter.blurBokehBoost => recipe.blurBokehBoost,
  Parameter.filmHalation => recipe.filmHalation,
  Parameter.filmHalationRadius => recipe.filmHalationRadius,
  Parameter.filmHalationThreshold => recipe.filmHalationThreshold,
  Parameter.filmBloom => recipe.filmBloom,
  Parameter.filmBloomRadius => recipe.filmBloomRadius,
  Parameter.filmBloomThreshold => recipe.filmBloomThreshold,
  Parameter.filmDust => recipe.filmDust,
  Parameter.filmScratches => recipe.filmScratches,
  Parameter.shaderParam1 => recipe.shaderParam1,
  Parameter.shaderParam2 => recipe.shaderParam2,
  Parameter.shaderParam3 => recipe.shaderParam3,
};

/// A copy of [recipe] with [p] set to [value] (clamped). Pure.
EditRecipe withValue(EditRecipe recipe, Parameter p, double value) {
  final v = clampParameter(p, value);
  return switch (p) {
    Parameter.exposure => recipe.copyWith(exposure: v),
    Parameter.contrast => recipe.copyWith(contrast: v),
    Parameter.highlights => recipe.copyWith(highlights: v),
    Parameter.shadows => recipe.copyWith(shadows: v),
    Parameter.whites => recipe.copyWith(whites: v),
    Parameter.blacks => recipe.copyWith(blacks: v),
    Parameter.clarity => recipe.copyWith(clarity: v),
    Parameter.texture => recipe.copyWith(texture: v),
    Parameter.dehaze => recipe.copyWith(dehaze: v),
    Parameter.vignette => recipe.copyWith(vignette: v),
    Parameter.vignetteMidpoint => recipe.copyWith(vignetteMidpoint: v),
    Parameter.vignetteFeather => recipe.copyWith(vignetteFeather: v),
    Parameter.vignetteRoundness => recipe.copyWith(vignetteRoundness: v),
    Parameter.vignetteHighlights => recipe.copyWith(vignetteHighlights: v),
    Parameter.grain => recipe.copyWith(grain: v),
    Parameter.grainSize => recipe.copyWith(grainSize: v),
    Parameter.grainRoughness => recipe.copyWith(grainRoughness: v),
    Parameter.sharpen => recipe.copyWith(sharpen: v),
    Parameter.sharpenRadius => recipe.copyWith(sharpenRadius: v),
    Parameter.sharpenDetail => recipe.copyWith(sharpenDetail: v),
    Parameter.sharpenMasking => recipe.copyWith(sharpenMasking: v),
    Parameter.denoiseLuma => recipe.copyWith(denoiseLuma: v),
    Parameter.denoiseChroma => recipe.copyWith(denoiseChroma: v),
    Parameter.temperature => recipe.copyWith(temperature: v),
    Parameter.tint => recipe.copyWith(tint: v),
    Parameter.vibrance => recipe.copyWith(vibrance: v),
    Parameter.saturation => recipe.copyWith(saturation: v),
    Parameter.gradeShadowHue => recipe.copyWith(gradeShadowHue: v),
    Parameter.gradeShadowSat => recipe.copyWith(gradeShadowSat: v),
    Parameter.gradeShadowLum => recipe.copyWith(gradeShadowLum: v),
    Parameter.gradeMidHue => recipe.copyWith(gradeMidHue: v),
    Parameter.gradeMidSat => recipe.copyWith(gradeMidSat: v),
    Parameter.gradeMidLum => recipe.copyWith(gradeMidLum: v),
    Parameter.gradeHighlightHue => recipe.copyWith(gradeHighlightHue: v),
    Parameter.gradeHighlightSat => recipe.copyWith(gradeHighlightSat: v),
    Parameter.gradeHighlightLum => recipe.copyWith(gradeHighlightLum: v),
    Parameter.gradeBlending => recipe.copyWith(gradeBlending: v),
    Parameter.gradeBalance => recipe.copyWith(gradeBalance: v),
    Parameter.defringePurpleAmount =>
      recipe.copyWith(defringePurpleAmount: v),
    Parameter.defringeGreenAmount => recipe.copyWith(defringeGreenAmount: v),
    Parameter.profileDistortion => recipe.copyWith(profileDistortion: v),
    Parameter.profileVignetting => recipe.copyWith(profileVignetting: v),
    Parameter.blurAmount => recipe.copyWith(blurAmount: v),
    Parameter.blurFocalPoint => recipe.copyWith(blurFocalPoint: v),
    Parameter.blurFocalRange => recipe.copyWith(blurFocalRange: v),
    Parameter.blurBokehBoost => recipe.copyWith(blurBokehBoost: v),
    Parameter.filmHalation => recipe.copyWith(filmHalation: v),
    Parameter.filmHalationRadius => recipe.copyWith(filmHalationRadius: v),
    Parameter.filmHalationThreshold => recipe.copyWith(filmHalationThreshold: v),
    Parameter.filmBloom => recipe.copyWith(filmBloom: v),
    Parameter.filmBloomRadius => recipe.copyWith(filmBloomRadius: v),
    Parameter.filmBloomThreshold => recipe.copyWith(filmBloomThreshold: v),
    Parameter.filmDust => recipe.copyWith(filmDust: v),
    Parameter.filmScratches => recipe.copyWith(filmScratches: v),
    Parameter.shaderParam1 => recipe.copyWith(shaderParam1: v),
    Parameter.shaderParam2 => recipe.copyWith(shaderParam2: v),
    Parameter.shaderParam3 => recipe.copyWith(shaderParam3: v),
  };
}
/// A preview copy of [recipe] with every parameter in [muted] neutralised —
/// the "tap-to-mute" bypass (issue #31). Pure; the receiver is never touched
/// and an empty [muted] returns the same instance.
EditRecipe withMuted(EditRecipe recipe, Set<Parameter> muted) {
  if (muted.isEmpty) return recipe;
  var out = recipe;
  for (final p in muted) {
    out = withValue(out, p, specOf(p).neutral);
  }
  return out;
}

/// Returns true if any parameter or setting in [section] differs from neutral.
bool isSectionModified(EditRecipe recipe, RecipeSection section) {
  return switch (section) {
    RecipeSection.light =>
      recipe.exposure != 0 ||
          recipe.contrast != 0 ||
          recipe.highlights != 0 ||
          recipe.shadows != 0 ||
          recipe.whites != 0 ||
          recipe.blacks != 0,
    RecipeSection.color =>
      recipe.temperature != 0 ||
          recipe.tint != 0 ||
          recipe.vibrance != 0 ||
          recipe.saturation != 0 ||
          recipe.hsl != neutralHsl ||
          !recipe.masterCurve.isIdentity ||
          !recipe.redCurve.isIdentity ||
          !recipe.greenCurve.isIdentity ||
          !recipe.blueCurve.isIdentity ||
          recipe.gradeShadowHue != 0 ||
          recipe.gradeShadowSat != 0 ||
          recipe.gradeShadowLum != 0 ||
          recipe.gradeMidHue != 0 ||
          recipe.gradeMidSat != 0 ||
          recipe.gradeMidLum != 0 ||
          recipe.gradeHighlightHue != 0 ||
          recipe.gradeHighlightSat != 0 ||
          recipe.gradeHighlightLum != 0 ||
          recipe.gradeBlending != 0.5 ||
          recipe.gradeBalance != 0,
    RecipeSection.tone =>
      !recipe.masterCurve.isIdentity ||
          !recipe.redCurve.isIdentity ||
          !recipe.greenCurve.isIdentity ||
          !recipe.blueCurve.isIdentity,
    RecipeSection.retouch => recipe.retouchPatches.isNotEmpty,
    RecipeSection.blur => recipe.blurEnabled || recipe.blurAmount != 0,
    RecipeSection.effects =>
      recipe.clarity != 0 ||
          recipe.texture != 0 ||
          recipe.dehaze != 0 ||
          recipe.vignette != 0 ||
          recipe.vignetteMidpoint != 0.5 ||
          recipe.vignetteFeather != 0.5 ||
          recipe.vignetteRoundness != 0 ||
          recipe.vignetteHighlights != 0 ||
          recipe.grain != 0 ||
          recipe.grainSize != 0.25 ||
          recipe.grainRoughness != 0.5,
    RecipeSection.detail =>
      recipe.sharpen != 0 ||
          recipe.sharpenRadius != 1.0 ||
          recipe.sharpenDetail != 0.25 ||
          recipe.sharpenMasking != 0 ||
          recipe.denoiseLuma != 0 ||
          recipe.denoiseChroma != 0,
    RecipeSection.optics =>
      recipe.removeChromaticAberration ||
          recipe.defringePurpleAmount != 0 ||
          recipe.defringeGreenAmount != 0 ||
          recipe.profileCorrections ||
          recipe.profileDistortion != 1.0 ||
          recipe.profileVignetting != 1.0,
    RecipeSection.geometry =>
      recipe.rotation != 0 ||
          recipe.flipH ||
          recipe.flipV ||
          recipe.straighten != 0 ||
          recipe.crop != fullCrop ||
          recipe.perspectiveX != 0 ||
          recipe.perspectiveY != 0 ||
          recipe.skewX != 0 ||
          recipe.skewY != 0,
    RecipeSection.masking => recipe.layers.isNotEmpty,
    RecipeSection.film =>
      recipe.filmHalation != 0 ||
          recipe.filmBloom != 0 ||
          recipe.filmDust != 0 ||
          recipe.filmScratches != 0,
    RecipeSection.lab =>
      recipe.shaderLabPreset != 0 ||
          recipe.shaderParam1 != 0 ||
          recipe.shaderParam2 != 0 ||
          recipe.shaderParam3 != 0,
  };
}
