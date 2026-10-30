import 'package:flutter/foundation.dart' show listEquals;

import 'parameter.dart';
import 'recipe.dart';

/// Represents a set of recipe settings picked for copying and pasting.
class CopiedSettings {
  const CopiedSettings({
    required this.recipe,
    required this.sections,
  });

  /// Factory copying all sections.
  factory CopiedSettings.all(EditRecipe recipe) => CopiedSettings(
    recipe: recipe,
    sections: RecipeSection.values.toSet(),
  );

  /// Factory copying only the sections that differ from neutral.
  factory CopiedSettings.modifiedOnly(EditRecipe recipe) => CopiedSettings(
    recipe: recipe,
    sections: detectModifiedSections(recipe),
  );

  final EditRecipe recipe;
  final Set<RecipeSection> sections;

  bool includes(RecipeSection section) => sections.contains(section);

  /// Merges the selected sections of [recipe] into [target], leaving unselected
  /// target parameters completely untouched.
  EditRecipe applyTo(EditRecipe target) {
    var result = target;
    for (final section in sections) {
      result = _applySection(section, source: recipe, target: result);
    }
    return result;
  }

  /// Detects which parameter sections in [r] deviate from neutral.
  static Set<RecipeSection> detectModifiedSections(EditRecipe r) {
    final modified = <RecipeSection>{};

    // Light (Basic Tone)
    if (r.exposure != 0 ||
        r.contrast != 0 ||
        r.highlights != 0 ||
        r.shadows != 0 ||
        r.whites != 0 ||
        r.blacks != 0) {
      modified.add(RecipeSection.light);
    }

    // Color
    if (r.temperature != 0 ||
        r.tint != 0 ||
        r.vibrance != 0 ||
        r.saturation != 0 ||
        !listEquals(r.hsl, neutralHsl) ||
        r.gradeShadowHue != 0 ||
        r.gradeShadowSat != 0 ||
        r.gradeShadowLum != 0 ||
        r.gradeMidHue != 0 ||
        r.gradeMidSat != 0 ||
        r.gradeMidLum != 0 ||
        r.gradeHighlightHue != 0 ||
        r.gradeHighlightSat != 0 ||
        r.gradeHighlightLum != 0 ||
        r.gradeBlending != 0.5 ||
        r.gradeBalance != 0) {
      modified.add(RecipeSection.color);
    }

    // Tone Curve
    if (!r.masterCurve.isIdentity ||
        !r.redCurve.isIdentity ||
        !r.greenCurve.isIdentity ||
        !r.blueCurve.isIdentity) {
      modified.add(RecipeSection.tone);
    }

    // Effects
    if (r.clarity != 0 ||
        r.texture != 0 ||
        r.dehaze != 0 ||
        r.vignette != 0 ||
        r.grain != 0) {
      modified.add(RecipeSection.effects);
    }

    // Detail
    if (r.sharpen != 0 ||
        r.denoiseLuma != 0 ||
        r.denoiseChroma != 0 ||
        r.aiDenoise != 0) {
      modified.add(RecipeSection.detail);
    }

    // Optics
    if (r.removeChromaticAberration || r.profileCorrections) {
      modified.add(RecipeSection.optics);
    }

    // Geometry
    if (r.rotation != 0 ||
        r.flipH ||
        r.flipV ||
        r.straighten != 0 ||
        r.skewX != 0 ||
        r.skewY != 0 ||
        r.perspectiveX != 0 ||
        r.perspectiveY != 0 ||
        !listEquals(r.crop, fullCrop)) {
      modified.add(RecipeSection.geometry);
    }

    // Blur
    if (r.blurEnabled || r.blurAmount > 0) {
      modified.add(RecipeSection.blur);
    }

    // Masking
    if (r.layers.isNotEmpty || r.maskGroups.isNotEmpty) {
      modified.add(RecipeSection.masking);
    }

    // Retouch
    if (r.retouchPatches.isNotEmpty) {
      modified.add(RecipeSection.retouch);
    }

    // Film
    if (r.filmHalation != 0 ||
        r.filmBloom != 0 ||
        r.filmDust != 0 ||
        r.filmScratches != 0) {
      modified.add(RecipeSection.film);
    }

    // Lab
    if (r.shaderLabPreset != 0 || r.customGlslCode.isNotEmpty) {
      modified.add(RecipeSection.lab);
    }

    return modified;
  }

  static EditRecipe _applySection(
    RecipeSection section, {
    required EditRecipe source,
    required EditRecipe target,
  }) => switch (section) {
    RecipeSection.light => target.copyWith(
      exposure: source.exposure,
      contrast: source.contrast,
      highlights: source.highlights,
      shadows: source.shadows,
      whites: source.whites,
      blacks: source.blacks,
    ),
    RecipeSection.color => target.copyWith(
      temperature: source.temperature,
      tint: source.tint,
      vibrance: source.vibrance,
      saturation: source.saturation,
      hsl: source.hsl,
      gradeShadowHue: source.gradeShadowHue,
      gradeShadowSat: source.gradeShadowSat,
      gradeShadowLum: source.gradeShadowLum,
      gradeMidHue: source.gradeMidHue,
      gradeMidSat: source.gradeMidSat,
      gradeMidLum: source.gradeMidLum,
      gradeHighlightHue: source.gradeHighlightHue,
      gradeHighlightSat: source.gradeHighlightSat,
      gradeHighlightLum: source.gradeHighlightLum,
      gradeBlending: source.gradeBlending,
      gradeBalance: source.gradeBalance,
    ),
    RecipeSection.tone => target.copyWith(
      masterCurve: source.masterCurve,
      redCurve: source.redCurve,
      greenCurve: source.greenCurve,
      blueCurve: source.blueCurve,
    ),
    RecipeSection.effects => target.copyWith(
      clarity: source.clarity,
      texture: source.texture,
      dehaze: source.dehaze,
      vignette: source.vignette,
      vignetteMidpoint: source.vignetteMidpoint,
      vignetteFeather: source.vignetteFeather,
      vignetteRoundness: source.vignetteRoundness,
      vignetteHighlights: source.vignetteHighlights,
      grain: source.grain,
      grainSize: source.grainSize,
      grainRoughness: source.grainRoughness,
    ),
    RecipeSection.detail => target.copyWith(
      sharpen: source.sharpen,
      sharpenRadius: source.sharpenRadius,
      sharpenDetail: source.sharpenDetail,
      sharpenMasking: source.sharpenMasking,
      denoiseLuma: source.denoiseLuma,
      denoiseChroma: source.denoiseChroma,
      aiDenoise: source.aiDenoise,
    ),
    RecipeSection.optics => target.copyWith(
      removeChromaticAberration: source.removeChromaticAberration,
      defringePurpleAmount: source.defringePurpleAmount,
      defringePurpleHueMin: source.defringePurpleHueMin,
      defringePurpleHueMax: source.defringePurpleHueMax,
      defringeGreenAmount: source.defringeGreenAmount,
      defringeGreenHueMin: source.defringeGreenHueMin,
      defringeGreenHueMax: source.defringeGreenHueMax,
      profileCorrections: source.profileCorrections,
      profileDistortion: source.profileDistortion,
      profileVignetting: source.profileVignetting,
    ),
    RecipeSection.geometry => target.copyWith(
      crop: source.crop,
      rotation: source.rotation,
      flipH: source.flipH,
      flipV: source.flipV,
      straighten: source.straighten,
      skewX: source.skewX,
      skewY: source.skewY,
      perspectiveX: source.perspectiveX,
      perspectiveY: source.perspectiveY,
    ),
    RecipeSection.blur => target.copyWith(
      blurEnabled: source.blurEnabled,
      blurBokehShape: source.blurBokehShape,
      blurBokehBoost: source.blurBokehBoost,
      blurAmount: source.blurAmount,
      blurFocalPoint: source.blurFocalPoint,
      blurFocalRange: source.blurFocalRange,
    ),
    RecipeSection.masking => target.copyWith(
      layers: source.layers,
      maskGroups: source.maskGroups,
    ),
    RecipeSection.retouch => target.copyWith(
      retouchPatches: source.retouchPatches,
    ),
    RecipeSection.film => target.copyWith(
      filmHalation: source.filmHalation,
      filmHalationRadius: source.filmHalationRadius,
      filmHalationThreshold: source.filmHalationThreshold,
      filmBloom: source.filmBloom,
      filmBloomRadius: source.filmBloomRadius,
      filmBloomThreshold: source.filmBloomThreshold,
      filmDust: source.filmDust,
      filmScratches: source.filmScratches,
    ),
    RecipeSection.lab => target.copyWith(
      shaderLabPreset: source.shaderLabPreset,
      shaderParam1: source.shaderParam1,
      shaderParam2: source.shaderParam2,
      shaderParam3: source.shaderParam3,
      customGlslCode: source.customGlslCode,
    ),
  };
}

