import '../color/blur_spec.dart';
import '../color/spatial_spec.dart';
import '../edit/recipe.dart';
import '../src/rust/api/preview.dart';

/// Builds the CPU-baked base spec for the preview from [recipe].
///
/// Straighten/perspective/skew are absent on purpose — issues #36/#52 warp
/// those live on the GPU (`PreviewBaseSpec` module docs), so baking them here
/// would double-apply the warp. Every field present here must be tracked by
/// `baseKeyOf` (`change_keys.dart`) or its slider never triggers a rebake.
PreviewBaseSpec baseSpecFromRecipe(EditRecipe recipe) {
  final spatial = SpatialSpec.fromRecipe(recipe);
  final blur = LensBlurSpec.fromRecipe(recipe);
  return PreviewBaseSpec(
    flipH: recipe.flipH,
    flipV: recipe.flipV,
    turns: recipe.rotation,
    cropL: recipe.crop[0],
    cropT: recipe.crop[1],
    cropR: recipe.crop[2],
    cropB: recipe.crop[3],
    shadows: spatial.shadows,
    highlights: spatial.highlights,
    clarity: spatial.clarity,
    texture: spatial.texture,
    sharpen: spatial.sharpen,
    sharpenRadius: spatial.sharpenRadius,
    sharpenDetail: spatial.sharpenDetail,
    sharpenMasking: spatial.sharpenMasking,
    denoiseLuma: spatial.denoiseLuma,
    denoiseChroma: spatial.denoiseChroma,
    dehaze: spatial.dehaze,
    vignette: spatial.vignette,
    vignetteMidpoint: spatial.vignetteMidpoint,
    vignetteFeather: spatial.vignetteFeather,
    vignetteRoundness: spatial.vignetteRoundness,
    vignetteHighlights: spatial.vignetteHighlights,
    grain: spatial.grain,
    grainSize: spatial.grainSize,
    grainRoughness: spatial.grainRoughness,
    filmHalation: 0.0,
    filmHalationRadius: 0.5,
    filmHalationThreshold: 0.8,
    filmBloom: 0.0,
    filmBloomRadius: 0.5,
    filmBloomThreshold: 0.75,
    filmDust: 0.0,
    filmScratches: 0.0,
    removeChromaticAberration: recipe.removeChromaticAberration,
    defringePurpleAmount: recipe.defringePurpleAmount,
    defringePurpleHueMin: recipe.defringePurpleHueMin,
    defringePurpleHueMax: recipe.defringePurpleHueMax,
    defringeGreenAmount: recipe.defringeGreenAmount,
    defringeGreenHueMin: recipe.defringeGreenHueMin,
    defringeGreenHueMax: recipe.defringeGreenHueMax,
    profileCorrections: recipe.profileCorrections,
    profileDistortion: recipe.profileDistortion,
    profileVignetting: recipe.profileVignetting,
    shaderLabPreset: 0,
    shaderParam1: 0.0,
    shaderParam2: 0.0,
    shaderParam3: 0.0,
    blurEnabled: blur.enabled,
    blurAmount: blur.amount,
    blurFocalPoint: blur.focalPoint,
    blurFocalRange: blur.focalRange,
    blurBokehShape: blur.bokehShape.index,
    blurBokehBoost: blur.bokehBoost,
  );

}
