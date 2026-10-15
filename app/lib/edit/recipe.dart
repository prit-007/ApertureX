import 'package:flutter/foundation.dart' show listEquals;

import 'adjustment_layer.dart';
import 'retouch_patch.dart';
import 'tone_curve.dart';

/// Neutral HSL mix: 8 bands × (hue, saturation, luminance), all zero.
const List<double> neutralHsl = <double>[
  0, 0, 0, //
  0, 0, 0,
  0, 0, 0,
  0, 0, 0,
  0, 0, 0,
  0, 0, 0,
  0, 0, 0,
  0, 0, 0,
];

/// A crop covering the whole frame: normalized `[left, top, right, bottom]`.
const List<double> fullCrop = <double>[0, 0, 1, 1];

/// The non-destructive edit recipe — the single source of truth every UI shell
/// reads and writes (ARCHITECTURE §16, ADR 0008).
///
/// Versioned JSON. The schema is a **Lightroom-aligned superset**; this slice
/// models the Light, Color, and Color-Grading groups. Fields the renderer
/// cannot yet apply are carried **forward-compatible**: stored, round-tripped
/// and equal-tested, but not yet applied.
///
/// Values are neutral-at-zero so an all-zero recipe is an identity transform.
class EditRecipe {
  const EditRecipe({
    this.schemaVersion = currentSchemaVersion,
    this.exposure = 0,
    this.contrast = 0,
    this.highlights = 0,
    this.shadows = 0,
    this.whites = 0,
    this.blacks = 0,
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
    this.denoiseLuma = 0,
    this.denoiseChroma = 0,
    this.temperature = 0,
    this.tint = 0,
    this.vibrance = 0,
    this.saturation = 0,
    // Color grading (split toning / 3-way color wheels): hue, saturation, luminance, plus blending and balance.
    this.gradeShadowHue = 0,
    this.gradeShadowSat = 0,
    this.gradeShadowLum = 0,
    this.gradeMidHue = 0,
    this.gradeMidSat = 0,
    this.gradeMidLum = 0,
    this.gradeHighlightHue = 0,
    this.gradeHighlightSat = 0,
    this.gradeHighlightLum = 0,
    this.gradeBlending = 0.5,
    this.gradeBalance = 0,
    // Tone curves (master + per-channel). Identity by default.
    this.masterCurve = ToneCurve.identity,
    this.redCurve = ToneCurve.identity,
    this.greenCurve = ToneCurve.identity,
    this.blueCurve = ToneCurve.identity,
    this.hsl = neutralHsl,
    // Geometry.
    this.rotation = 0,
    this.flipH = false,
    this.flipV = false,
    this.straighten = 0,
    this.crop = fullCrop,
    this.perspectiveX = 0,
    this.perspectiveY = 0,
    this.skewX = 0,
    this.skewY = 0,
    this.layers = const <AdjustmentLayer>[],
    // Optics.
    this.removeChromaticAberration = false,
    this.defringePurpleAmount = 0,
    this.defringePurpleHueMin = 0.70,
    this.defringePurpleHueMax = 0.95,
    this.defringeGreenAmount = 0,
    this.defringeGreenHueMin = 0.17,
    this.defringeGreenHueMax = 0.50,
    this.profileCorrections = false,
    this.profileDistortion = 1.0,
    this.profileVignetting = 1.0,
    this.retouchPatches = const <RetouchPatch>[],
    // Lens blur.
    this.blurEnabled = false,
    this.blurAmount = 0,
    this.blurFocalPoint = 0.5,
    this.blurFocalRange = 0.2,
    this.blurBokehShape = 0,
    this.blurBokehBoost = 0,
  });

  /// Bumped only on a breaking schema change (ARCHITECTURE §16).
  ///
  /// v2: grouped, catalog-driven parameter model (JSON still flat, v1 keys
  /// unchanged). v3: adds color-grading (split-tone) fields; older recipes read
  /// forward with those fields neutral. v13: adds 3-way color wheel luminance,
  /// blending, and balance. v14: adds advanced sharpen radius, detail, masking.
  /// v15: adds advanced vignette and grain controls.
  /// v16: adds optics, chromatic aberration, defringe, and lens profile controls.
  /// v17: adds retouch patches (healing brush & clone stamp).
  /// v18: adds depth-aware lens blur and synthetic bokeh.
  /// `fromJson` always migrates to this.
  static const int currentSchemaVersion = 18;

  /// All-neutral recipe: applying it is an identity transform.
  static const EditRecipe neutral = EditRecipe();

  final int schemaVersion;

  // Light.
  final double exposure; // EV, neutral 0.
  final double contrast; // unitless, neutral 0.
  final double highlights; // unitless, neutral 0 (not yet rendered).
  final double shadows; // unitless, neutral 0 (not yet rendered).
  final double whites; // unitless, neutral 0 (not yet rendered).
  final double blacks; // unitless, neutral 0 (not yet rendered).
  final double clarity; // spatial pass, neutral 0.
  final double texture; // spatial pass, neutral 0.
  final double dehaze; // spatial pass, neutral 0.
  final double vignette; // spatial pass: >0 darkens edges, neutral 0.
  final double vignetteMidpoint; // spatial pass: 0..1, neutral 0.5.
  final double vignetteFeather; // spatial pass: 0..1, neutral 0.5.
  final double vignetteRoundness; // spatial pass: -1..1, neutral 0.
  final double vignetteHighlights; // spatial pass: 0..1, neutral 0.
  final double grain; // spatial pass, 0..1 neutral 0.
  final double grainSize; // spatial pass: 0.1..1, neutral 0.25.
  final double grainRoughness; // spatial pass: 0..1, neutral 0.5.
  final double sharpen; // spatial pass, neutral 0.
  final double sharpenRadius; // spatial pass, 0.5..3.0, neutral 1.0.
  final double sharpenDetail; // spatial pass, 0..1, neutral 0.25.
  final double sharpenMasking; // spatial pass, 0..1, neutral 0.
  final double denoiseLuma; // spatial pass, neutral 0.
  final double denoiseChroma; // spatial pass, neutral 0.

  // Optics.
  final bool removeChromaticAberration;
  final double defringePurpleAmount;
  final double defringePurpleHueMin;
  final double defringePurpleHueMax;
  final double defringeGreenAmount;
  final double defringeGreenHueMin;
  final double defringeGreenHueMax;
  final bool profileCorrections;
  final double profileDistortion;
  final double profileVignetting;

  // Color.
  final double temperature; // unitless, neutral 0.
  final double tint; // unitless, neutral 0.
  final double vibrance; // unitless, neutral 0.
  final double saturation; // unitless, neutral 0.

  // Color grading (3-way color wheels): hue 0..1, sat 0..1, lum -1..1, blending 0..1, balance -1..1.
  final double gradeShadowHue;
  final double gradeShadowSat;
  final double gradeShadowLum;
  final double gradeMidHue;
  final double gradeMidSat;
  final double gradeMidLum;
  final double gradeHighlightHue;
  final double gradeHighlightSat;
  final double gradeHighlightLum;
  final double gradeBlending;
  final double gradeBalance;

  // Tone curves.
  final ToneCurve masterCurve;
  final ToneCurve redCurve;
  final ToneCurve greenCurve;
  final ToneCurve blueCurve;

  /// HSL color mixer: 8 bands × (hue, saturation, luminance), each `[-1,1]`.
  final List<double> hsl;

  // Geometry.
  final int rotation; // quarter turns clockwise (0..3).
  final bool flipH;
  final bool flipV;
  final double straighten; // degrees, -45..45.

  /// Crop rect, normalized `[left, top, right, bottom]` in the transformed frame.
  final List<double> crop;

  /// Local adjustment layers (masking, P2.5), applied in order.
  final List<AdjustmentLayer> layers;

  /// Retouch patches (healing brush & clone stamp), applied in order.
  final List<RetouchPatch> retouchPatches;

  // Lens blur.
  final bool blurEnabled;
  final double blurAmount;
  final double blurFocalPoint;
  final double blurFocalRange;
  final int blurBokehShape;
  final double blurBokehBoost;

  // Perspective & skew geometry (GPU Matrix4 preview, Rust resample on export).
  final double perspectiveX; // horizontal perspective, neutral 0, range ~[-1,1]
  final double perspectiveY; // vertical perspective, neutral 0, range ~[-1,1]
  final double skewX; // horizontal skew, neutral 0, range ~[-1,1]
  final double skewY; // vertical skew, neutral 0, range ~[-1,1]

  /// Returns a copy with the given fields replaced. Fields left `null` keep
  /// their current value; the receiver is never mutated.
  EditRecipe copyWith({
    int? schemaVersion,
    double? exposure,
    double? contrast,
    double? highlights,
    double? shadows,
    double? whites,
    double? blacks,
    double? clarity,
    double? texture,
    double? dehaze,
    double? vignette,
    double? vignetteMidpoint,
    double? vignetteFeather,
    double? vignetteRoundness,
    double? vignetteHighlights,
    double? grain,
    double? grainSize,
    double? grainRoughness,
    double? sharpen,
    double? sharpenRadius,
    double? sharpenDetail,
    double? sharpenMasking,
    double? denoiseLuma,
    double? denoiseChroma,
    double? temperature,
    double? tint,
    double? vibrance,
    double? saturation,
    double? gradeShadowHue,
    double? gradeShadowSat,
    double? gradeShadowLum,
    double? gradeMidHue,
    double? gradeMidSat,
    double? gradeMidLum,
    double? gradeHighlightHue,
    double? gradeHighlightSat,
    double? gradeHighlightLum,
    double? gradeBlending,
    double? gradeBalance,
    ToneCurve? masterCurve,
    ToneCurve? redCurve,
    ToneCurve? greenCurve,
    ToneCurve? blueCurve,
    List<double>? hsl,
    int? rotation,
    bool? flipH,
    bool? flipV,
    double? straighten,
    List<double>? crop,
    double? perspectiveX,
    double? perspectiveY,
    double? skewX,
    double? skewY,
    List<AdjustmentLayer>? layers,
    List<RetouchPatch>? retouchPatches,
    bool? removeChromaticAberration,
    double? defringePurpleAmount,
    double? defringePurpleHueMin,
    double? defringePurpleHueMax,
    double? defringeGreenAmount,
    double? defringeGreenHueMin,
    double? defringeGreenHueMax,
    bool? profileCorrections,
    double? profileDistortion,
    double? profileVignetting,
    bool? blurEnabled,
    double? blurAmount,
    double? blurFocalPoint,
    double? blurFocalRange,
    int? blurBokehShape,
    double? blurBokehBoost,
  }) {
    return EditRecipe(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      exposure: exposure ?? this.exposure,
      contrast: contrast ?? this.contrast,
      highlights: highlights ?? this.highlights,
      shadows: shadows ?? this.shadows,
      whites: whites ?? this.whites,
      blacks: blacks ?? this.blacks,
      clarity: clarity ?? this.clarity,
      texture: texture ?? this.texture,
      dehaze: dehaze ?? this.dehaze,
      vignette: vignette ?? this.vignette,
      vignetteMidpoint: vignetteMidpoint ?? this.vignetteMidpoint,
      vignetteFeather: vignetteFeather ?? this.vignetteFeather,
      vignetteRoundness: vignetteRoundness ?? this.vignetteRoundness,
      vignetteHighlights: vignetteHighlights ?? this.vignetteHighlights,
      grain: grain ?? this.grain,
      grainSize: grainSize ?? this.grainSize,
      grainRoughness: grainRoughness ?? this.grainRoughness,
      sharpen: sharpen ?? this.sharpen,
      sharpenRadius: sharpenRadius ?? this.sharpenRadius,
      sharpenDetail: sharpenDetail ?? this.sharpenDetail,
      sharpenMasking: sharpenMasking ?? this.sharpenMasking,
      denoiseLuma: denoiseLuma ?? this.denoiseLuma,
      denoiseChroma: denoiseChroma ?? this.denoiseChroma,
      removeChromaticAberration:
          removeChromaticAberration ?? this.removeChromaticAberration,
      defringePurpleAmount: defringePurpleAmount ?? this.defringePurpleAmount,
      defringePurpleHueMin: defringePurpleHueMin ?? this.defringePurpleHueMin,
      defringePurpleHueMax: defringePurpleHueMax ?? this.defringePurpleHueMax,
      defringeGreenAmount: defringeGreenAmount ?? this.defringeGreenAmount,
      defringeGreenHueMin: defringeGreenHueMin ?? this.defringeGreenHueMin,
      defringeGreenHueMax: defringeGreenHueMax ?? this.defringeGreenHueMax,
      profileCorrections: profileCorrections ?? this.profileCorrections,
      profileDistortion: profileDistortion ?? this.profileDistortion,
      profileVignetting: profileVignetting ?? this.profileVignetting,
      temperature: temperature ?? this.temperature,
      tint: tint ?? this.tint,
      vibrance: vibrance ?? this.vibrance,
      saturation: saturation ?? this.saturation,
      gradeShadowHue: gradeShadowHue ?? this.gradeShadowHue,
      gradeShadowSat: gradeShadowSat ?? this.gradeShadowSat,
      gradeShadowLum: gradeShadowLum ?? this.gradeShadowLum,
      gradeMidHue: gradeMidHue ?? this.gradeMidHue,
      gradeMidSat: gradeMidSat ?? this.gradeMidSat,
      gradeMidLum: gradeMidLum ?? this.gradeMidLum,
      gradeHighlightHue: gradeHighlightHue ?? this.gradeHighlightHue,
      gradeHighlightSat: gradeHighlightSat ?? this.gradeHighlightSat,
      gradeHighlightLum: gradeHighlightLum ?? this.gradeHighlightLum,
      gradeBlending: gradeBlending ?? this.gradeBlending,
      gradeBalance: gradeBalance ?? this.gradeBalance,
      masterCurve: masterCurve ?? this.masterCurve,
      redCurve: redCurve ?? this.redCurve,
      greenCurve: greenCurve ?? this.greenCurve,
      blueCurve: blueCurve ?? this.blueCurve,
      hsl: hsl ?? this.hsl,
      rotation: rotation ?? this.rotation,
      flipH: flipH ?? this.flipH,
      flipV: flipV ?? this.flipV,
      straighten: straighten ?? this.straighten,
      crop: crop ?? this.crop,
      perspectiveX: perspectiveX ?? this.perspectiveX,
      perspectiveY: perspectiveY ?? this.perspectiveY,
      skewX: skewX ?? this.skewX,
      skewY: skewY ?? this.skewY,
      layers: layers ?? this.layers,
      retouchPatches: retouchPatches ?? this.retouchPatches,
      blurEnabled: blurEnabled ?? this.blurEnabled,
      blurAmount: blurAmount ?? this.blurAmount,
      blurFocalPoint: blurFocalPoint ?? this.blurFocalPoint,
      blurFocalRange: blurFocalRange ?? this.blurFocalRange,
      blurBokehShape: blurBokehShape ?? this.blurBokehShape,
      blurBokehBoost: blurBokehBoost ?? this.blurBokehBoost,
    );
  }

  /// Serialises to a plain JSON-ready map (flat keys).
  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'exposure': exposure,
    'contrast': contrast,
    'highlights': highlights,
    'shadows': shadows,
    'whites': whites,
    'blacks': blacks,
    'clarity': clarity,
    'texture': texture,
    'dehaze': dehaze,
    'vignette': vignette,
    'vignetteMidpoint': vignetteMidpoint,
    'vignetteFeather': vignetteFeather,
    'vignetteRoundness': vignetteRoundness,
    'vignetteHighlights': vignetteHighlights,
    'grain': grain,
    'grainSize': grainSize,
    'grainRoughness': grainRoughness,
    'sharpen': sharpen,
    'sharpenRadius': sharpenRadius,
    'sharpenDetail': sharpenDetail,
    'sharpenMasking': sharpenMasking,
    'denoiseLuma': denoiseLuma,
    'denoiseChroma': denoiseChroma,
    'removeChromaticAberration': removeChromaticAberration,
    'defringePurpleAmount': defringePurpleAmount,
    'defringePurpleHueMin': defringePurpleHueMin,
    'defringePurpleHueMax': defringePurpleHueMax,
    'defringeGreenAmount': defringeGreenAmount,
    'defringeGreenHueMin': defringeGreenHueMin,
    'defringeGreenHueMax': defringeGreenHueMax,
    'profileCorrections': profileCorrections,
    'profileDistortion': profileDistortion,
    'profileVignetting': profileVignetting,
    'temperature': temperature,
    'tint': tint,
    'vibrance': vibrance,
    'saturation': saturation,
    'gradeShadowHue': gradeShadowHue,
    'gradeShadowSat': gradeShadowSat,
    'gradeShadowLum': gradeShadowLum,
    'gradeMidHue': gradeMidHue,
    'gradeMidSat': gradeMidSat,
    'gradeMidLum': gradeMidLum,
    'gradeHighlightHue': gradeHighlightHue,
    'gradeHighlightSat': gradeHighlightSat,
    'gradeHighlightLum': gradeHighlightLum,
    'gradeBlending': gradeBlending,
    'gradeBalance': gradeBalance,
    'masterCurve': masterCurve.toJson(),
    'redCurve': redCurve.toJson(),
    'greenCurve': greenCurve.toJson(),
    'blueCurve': blueCurve.toJson(),
    'hsl': hsl,
    'rotation': rotation,
    'flipH': flipH,
    'flipV': flipV,
    'straighten': straighten,
    'crop': crop,
    'perspectiveX': perspectiveX,
    'perspectiveY': perspectiveY,
    'skewX': skewX,
    'skewY': skewY,
    'layers': [for (final layer in layers) layer.toJson()],
    'retouchPatches': [for (final patch in retouchPatches) patch.toJson()],
    'blurEnabled': blurEnabled,
    'blurAmount': blurAmount,
    'blurFocalPoint': blurFocalPoint,
    'blurFocalRange': blurFocalRange,
    'blurBokehShape': blurBokehShape,
    'blurBokehBoost': blurBokehBoost,
  };

  /// Deserialises from [json], tolerating missing keys (default to neutral) and
  /// ignoring unknown keys. Any supported version migrates forward to
  /// [currentSchemaVersion].
  factory EditRecipe.fromJson(Map<String, Object?> json) {
    double asDouble(String key) => (json[key] as num?)?.toDouble() ?? 0;
    return EditRecipe(
      schemaVersion: currentSchemaVersion,
      exposure: asDouble('exposure'),
      contrast: asDouble('contrast'),
      highlights: asDouble('highlights'),
      shadows: asDouble('shadows'),
      whites: asDouble('whites'),
      blacks: asDouble('blacks'),
      clarity: asDouble('clarity'),
      texture: asDouble('texture'),
      dehaze: asDouble('dehaze'),
      vignette: asDouble('vignette'),
      vignetteMidpoint: (json['vignetteMidpoint'] as num?)?.toDouble() ?? 0.5,
      vignetteFeather: (json['vignetteFeather'] as num?)?.toDouble() ?? 0.5,
      vignetteRoundness: asDouble('vignetteRoundness'),
      vignetteHighlights: asDouble('vignetteHighlights'),
      grain: asDouble('grain'),
      grainSize: (json['grainSize'] as num?)?.toDouble() ?? 0.25,
      grainRoughness: (json['grainRoughness'] as num?)?.toDouble() ?? 0.5,
      sharpen: asDouble('sharpen'),
      sharpenRadius: (json['sharpenRadius'] as num?)?.toDouble() ?? 1.0,
      sharpenDetail: (json['sharpenDetail'] as num?)?.toDouble() ?? 0.25,
      sharpenMasking: asDouble('sharpenMasking'),
      denoiseLuma: asDouble('denoiseLuma'),
      denoiseChroma: asDouble('denoiseChroma'),
      removeChromaticAberration:
          json['removeChromaticAberration'] as bool? ?? false,
      defringePurpleAmount: asDouble('defringePurpleAmount'),
      defringePurpleHueMin:
          (json['defringePurpleHueMin'] as num?)?.toDouble() ?? 0.70,
      defringePurpleHueMax:
          (json['defringePurpleHueMax'] as num?)?.toDouble() ?? 0.95,
      defringeGreenAmount: asDouble('defringeGreenAmount'),
      defringeGreenHueMin:
          (json['defringeGreenHueMin'] as num?)?.toDouble() ?? 0.17,
      defringeGreenHueMax:
          (json['defringeGreenHueMax'] as num?)?.toDouble() ?? 0.50,
      profileCorrections: json['profileCorrections'] as bool? ?? false,
      profileDistortion:
          (json['profileDistortion'] as num?)?.toDouble() ?? 1.0,
      profileVignetting:
          (json['profileVignetting'] as num?)?.toDouble() ?? 1.0,
      temperature: asDouble('temperature'),
      tint: asDouble('tint'),
      vibrance: asDouble('vibrance'),
      saturation: asDouble('saturation'),
      gradeShadowHue: asDouble('gradeShadowHue'),
      gradeShadowSat: asDouble('gradeShadowSat'),
      gradeShadowLum: asDouble('gradeShadowLum'),
      gradeMidHue: asDouble('gradeMidHue'),
      gradeMidSat: asDouble('gradeMidSat'),
      gradeMidLum: asDouble('gradeMidLum'),
      gradeHighlightHue: asDouble('gradeHighlightHue'),
      gradeHighlightSat: asDouble('gradeHighlightSat'),
      gradeHighlightLum: asDouble('gradeHighlightLum'),
      gradeBlending: (json['gradeBlending'] as num?)?.toDouble() ?? 0.5,
      gradeBalance: asDouble('gradeBalance'),
      masterCurve: ToneCurve.fromJson(json['masterCurve']),
      redCurve: ToneCurve.fromJson(json['redCurve']),
      greenCurve: ToneCurve.fromJson(json['greenCurve']),
      blueCurve: ToneCurve.fromJson(json['blueCurve']),
      hsl:
          (json['hsl'] as List?)?.map((e) => (e as num).toDouble()).toList() ??
          neutralHsl,
      rotation: (json['rotation'] as num?)?.toInt() ?? 0,
      flipH: json['flipH'] as bool? ?? false,
      flipV: json['flipV'] as bool? ?? false,
      straighten: asDouble('straighten'),
      crop:
          (json['crop'] as List?)?.map((e) => (e as num).toDouble()).toList() ??
          fullCrop,
      perspectiveX: asDouble('perspectiveX'),
      perspectiveY: asDouble('perspectiveY'),
      skewX: asDouble('skewX'),
      skewY: asDouble('skewY'),
      layers:
          (json['layers'] as List?)
              ?.map(
                (e) => AdjustmentLayer.fromJson((e as Map).cast<String, Object?>()),
              )
              .toList() ??
          const <AdjustmentLayer>[],
      retouchPatches:
          (json['retouchPatches'] as List?)
              ?.map(
                (e) => RetouchPatch.fromJson((e as Map).cast<String, Object?>()),
              )
              .toList() ??
          const <RetouchPatch>[],
      blurEnabled: json['blurEnabled'] as bool? ?? false,
      blurAmount: asDouble('blurAmount'),
      blurFocalPoint: (json['blurFocalPoint'] as num?)?.toDouble() ?? 0.5,
      blurFocalRange: (json['blurFocalRange'] as num?)?.toDouble() ?? 0.2,
      blurBokehShape: (json['blurBokehShape'] as num?)?.toInt() ?? 0,
      blurBokehBoost: asDouble('blurBokehBoost'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is EditRecipe &&
      other.schemaVersion == schemaVersion &&
      other.exposure == exposure &&
      other.contrast == contrast &&
      other.highlights == highlights &&
      other.shadows == shadows &&
      other.whites == whites &&
      other.blacks == blacks &&
      other.clarity == clarity &&
      other.texture == texture &&
      other.dehaze == dehaze &&
      other.vignette == vignette &&
      other.vignetteMidpoint == vignetteMidpoint &&
      other.vignetteFeather == vignetteFeather &&
      other.vignetteRoundness == vignetteRoundness &&
      other.vignetteHighlights == vignetteHighlights &&
      other.grain == grain &&
      other.grainSize == grainSize &&
      other.grainRoughness == grainRoughness &&
      other.sharpen == sharpen &&
      other.sharpenRadius == sharpenRadius &&
      other.sharpenDetail == sharpenDetail &&
      other.sharpenMasking == sharpenMasking &&
      other.denoiseLuma == denoiseLuma &&
      other.denoiseChroma == denoiseChroma &&
      other.removeChromaticAberration == removeChromaticAberration &&
      other.defringePurpleAmount == defringePurpleAmount &&
      other.defringePurpleHueMin == defringePurpleHueMin &&
      other.defringePurpleHueMax == defringePurpleHueMax &&
      other.defringeGreenAmount == defringeGreenAmount &&
      other.defringeGreenHueMin == defringeGreenHueMin &&
      other.defringeGreenHueMax == defringeGreenHueMax &&
      other.profileCorrections == profileCorrections &&
      other.profileDistortion == profileDistortion &&
      other.profileVignetting == profileVignetting &&
      other.temperature == temperature &&
      other.tint == tint &&
      other.vibrance == vibrance &&
      other.saturation == saturation &&
      other.gradeShadowHue == gradeShadowHue &&
      other.gradeShadowSat == gradeShadowSat &&
      other.gradeShadowLum == gradeShadowLum &&
      other.gradeMidHue == gradeMidHue &&
      other.gradeMidSat == gradeMidSat &&
      other.gradeMidLum == gradeMidLum &&
      other.gradeHighlightHue == gradeHighlightHue &&
      other.gradeHighlightSat == gradeHighlightSat &&
      other.gradeHighlightLum == gradeHighlightLum &&
      other.gradeBlending == gradeBlending &&
      other.gradeBalance == gradeBalance &&
      other.masterCurve == masterCurve &&
      other.redCurve == redCurve &&
      other.greenCurve == greenCurve &&
      other.blueCurve == blueCurve &&
      listEquals(other.hsl, hsl) &&
      other.rotation == rotation &&
      other.flipH == flipH &&
      other.flipV == flipV &&
      other.straighten == straighten &&
      listEquals(other.crop, crop) &&
      other.perspectiveX == perspectiveX &&
      other.perspectiveY == perspectiveY &&
      other.skewX == skewX &&
      other.skewY == skewY &&
      listEquals(other.layers, layers) &&
      listEquals(other.retouchPatches, retouchPatches) &&
      other.blurEnabled == blurEnabled &&
      other.blurAmount == blurAmount &&
      other.blurFocalPoint == blurFocalPoint &&
      other.blurFocalRange == blurFocalRange &&
      other.blurBokehShape == blurBokehShape &&
      other.blurBokehBoost == blurBokehBoost;

  @override
  int get hashCode => Object.hash(
    schemaVersion,
    exposure,
    contrast,
    highlights,
    shadows,
    whites,
    blacks,
    Object.hash(
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
    ),
    temperature,
    tint,
    vibrance,
    saturation,
    Object.hash(
      removeChromaticAberration,
      defringePurpleAmount,
      defringePurpleHueMin,
      defringePurpleHueMax,
      defringeGreenAmount,
      defringeGreenHueMin,
      defringeGreenHueMax,
      profileCorrections,
      profileDistortion,
      profileVignetting,
    ),
    Object.hash(
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
    ),
    Object.hash(masterCurve, redCurve, greenCurve, blueCurve),
    Object.hashAll(hsl),
    Object.hash(
      Object.hash(rotation, flipH, flipV, straighten),
      Object.hashAll(crop),
      Object.hash(perspectiveX, perspectiveY, skewX, skewY),
      Object.hashAll(layers),
      Object.hashAll(retouchPatches),
      blurEnabled,
      blurAmount,
      blurFocalPoint,
      blurFocalRange,
      blurBokehShape,
      blurBokehBoost,
    ),
  );

  @override
  String toString() =>
      'EditRecipe(v$schemaVersion, exposure: $exposure, contrast: $contrast, '
      'saturation: $saturation)';
}
