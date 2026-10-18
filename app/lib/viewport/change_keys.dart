import '../color/blur_spec.dart';
import '../edit/recipe.dart';

/// Change-detection keys for the preview bake pipeline.
///
/// [baseKeyOf] covers every recipe field baked into the CPU base frame
/// (geometry flags, spatial pass, optics, lens blur, crop, mask layers);
/// [gradeKeyOf] covers everything fed through the pointwise grade / 3D LUT.
/// A slider absent from the matching key never triggers a rebake, so both
/// keys must track every field the corresponding spec consumes.
int baseKeyOf(EditRecipe r) => Object.hash(
  Object.hash(
    r.rotation,
    r.flipH,
    r.flipV,
    r.shadows,
    r.highlights,
    r.clarity,
    r.texture,
    r.dehaze,
    r.vignette,
    r.vignetteMidpoint,
    r.vignetteFeather,
    r.vignetteRoundness,
    r.vignetteHighlights,
  ),
  Object.hash(
    r.grain,
    r.grainSize,
    r.grainRoughness,
    r.sharpen,
    r.sharpenRadius,
    r.sharpenDetail,
    r.sharpenMasking,
    r.denoiseLuma,
    r.denoiseChroma,
    r.removeChromaticAberration,
    r.defringePurpleAmount,
    r.defringePurpleHueMin,
    r.defringePurpleHueMax,
    r.defringeGreenAmount,
    r.defringeGreenHueMin,
    r.defringeGreenHueMax,
  ),
  Object.hash(
    r.profileCorrections,
    r.profileDistortion,
    r.profileVignetting,
    r.filmHalation,
    r.filmBloom,
    r.filmDust,
    r.filmScratches,
    LensBlurSpec.fromRecipe(r),
    Object.hashAll(r.crop),
    Object.hashAll(r.layers),
    Object.hashAll(r.maskGroups),
    Object.hashAll(r.retouchPatches),
  ),
);

int gradeKeyOf(EditRecipe r) => Object.hash(
  Object.hash(
    r.exposure,
    r.contrast,
    r.saturation,
    r.temperature,
    r.tint,
    r.vibrance,
    r.whites,
    r.blacks,
    r.gradeShadowHue,
    r.gradeShadowSat,
    r.gradeShadowLum,
    r.gradeMidHue,
    r.gradeMidSat,
    r.gradeMidLum,
    r.gradeHighlightHue,
    r.gradeHighlightSat,
    r.gradeHighlightLum,
    r.gradeBlending,
    r.gradeBalance,
  ),
  Object.hash(
    r.masterCurve,
    r.redCurve,
    r.greenCurve,
    r.blueCurve,
    Object.hashAll(r.hsl),
  ),
);
