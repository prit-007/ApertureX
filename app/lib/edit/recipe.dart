import 'package:flutter/foundation.dart' show listEquals;

import 'adjustment_layer.dart';
import 'depth_sidecar.dart';
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
    this.outputSharpenMedia = 0,
    this.outputSharpen = 0,
    this.denoiseLuma = 0,
    this.denoiseChroma = 0,
    this.aiDenoise = 0,
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
    this.maskGroups = const <MaskGroup>[],
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
    this.blurBackgroundBlur = false,
    this.blurSampleCount = 12,
    this.depthSidecar,
    this.depthSidecarPath,
    this.depthField,
    // Film emulation physics.
    this.filmHalation = 0,
    this.filmHalationRadius = 0.5,
    this.filmHalationThreshold = 0.8,
    this.filmBloom = 0,
    this.filmBloomRadius = 0.5,
    this.filmBloomThreshold = 0.75,
    this.filmDust = 0,
    this.filmScratches = 0,
    // Shader Lab.
    this.shaderLabPreset = 0,
    this.shaderParam1 = 0,
    this.shaderParam2 = 0,
    this.shaderParam3 = 0,
    // Camera Calibration.
    this.calibrationShadowTint = 0,
    this.calibrationRedHue = 0,
    this.calibrationRedSat = 0,
    this.calibrationGreenHue = 0,
    this.calibrationGreenSat = 0,
    this.calibrationBlueHue = 0,
    this.calibrationBlueSat = 0,
    // Point Color.
    this.pointColors = const <PointColorDef>[],
    // Double Exposure.
    this.doubleExposure,
  });

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
      outputSharpenMedia: (json['outputSharpenMedia'] as num?)?.toInt() ?? 0,
      outputSharpen: asDouble('outputSharpen'),
      denoiseLuma: asDouble('denoiseLuma'),
      denoiseChroma: asDouble('denoiseChroma'),
      aiDenoise: asDouble('aiDenoise'),
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
      hsl: () {
        final parsed = (json['hsl'] as List?)?.map((e) => (e as num).toDouble()).toList();
        if (parsed == null) return neutralHsl;
        if (parsed.length != 24) {
          throw FormatException(
            'Invalid recipe: hsl must contain 24 values, got ${parsed.length}',
          );
        }
        return parsed;
      }(),
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
      maskGroups:
          (json['maskGroups'] as List?)
              ?.map(
                (e) => MaskGroup.fromJson((e as Map).cast<String, Object?>()),
              )
              .toList() ??
          const <MaskGroup>[],
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
      blurBackgroundBlur: json['blurBackgroundBlur'] as bool? ?? false,
      blurSampleCount: (json['blurSampleCount'] as num?)?.toInt() ?? 12,
      depthSidecar: (json['depthSidecar'] ??
              json['depth_sidecar'] ??
              json['depthSidecarPath'] ??
              json['depth_field_path']) as String?,
      depthSidecarPath: (json['depthSidecarPath'] ??
              json['depth_sidecar'] ??
              json['depthSidecar'] ??
              json['depth_field_path']) as String?,
      depthField: json['depth_field'] is Map
          ? DepthSidecarData.fromJson(
              (json['depth_field'] as Map).cast<String, Object?>(),
            )
          : (json['depthField'] is Map
              ? DepthSidecarData.fromJson(
                  (json['depthField'] as Map).cast<String, Object?>(),
                )
              : null),
      filmHalation: asDouble('filmHalation'),
      filmHalationRadius:
          (json['filmHalationRadius'] as num?)?.toDouble() ?? 0.5,
      filmHalationThreshold:
          (json['filmHalationThreshold'] as num?)?.toDouble() ?? 0.8,
      filmBloom: asDouble('filmBloom'),
      filmBloomRadius: (json['filmBloomRadius'] as num?)?.toDouble() ?? 0.5,
      filmBloomThreshold:
          (json['filmBloomThreshold'] as num?)?.toDouble() ?? 0.75,
      filmDust: asDouble('filmDust'),
      filmScratches: asDouble('filmScratches'),
      shaderLabPreset: (json['shaderLabPreset'] as num?)?.toInt() ?? 0,
      shaderParam1: asDouble('shaderParam1'),
      shaderParam2: asDouble('shaderParam2'),
      shaderParam3: asDouble('shaderParam3'),
      calibrationShadowTint: asDouble('calibrationShadowTint'),
      calibrationRedHue: asDouble('calibrationRedHue'),
      calibrationRedSat: asDouble('calibrationRedSat'),
      calibrationGreenHue: asDouble('calibrationGreenHue'),
      calibrationGreenSat: asDouble('calibrationGreenSat'),
      calibrationBlueHue: asDouble('calibrationBlueHue'),
      calibrationBlueSat: asDouble('calibrationBlueSat'),
      pointColors: (json['pointColors'] as List?)
              ?.map((e) => PointColorDef.fromJson((e as Map).cast<String, Object?>()))
              .toList() ??
          const <PointColorDef>[],
      doubleExposure: json['doubleExposure'] is Map
          ? DoubleExposureLayer.fromJson(
              (json['doubleExposure'] as Map).cast<String, Object?>(),
            )
          : null,
    ).clamped();
  }

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
  /// v19: adds photochemical film physics (halation, bloom, dust/scratches) and shader lab.
  /// v20: adds global Amount slider (0–200%) to adjustment layers.
  /// v21: adds mask group architecture (ADR 0013) with boolean coverage algebra.
  /// v22: adds per-mask 3-way color wheels and pointwise highlights/shadows (#94).
  /// `fromJson` always migrates to this.
  static const int currentSchemaVersion = 22;

  /// All-neutral recipe: applying it is an identity transform.
  static const EditRecipe neutral = EditRecipe();

  final int schemaVersion;

  // Light.
  final double exposure; // EV, neutral 0.
  final double contrast; // unitless, neutral 0.
  final double highlights; // unitless, neutral 0 (spatial edge-aware curve).
  final double shadows; // unitless, neutral 0 (spatial edge-aware curve).
  final double whites; // unitless, neutral 0.
  final double blacks; // unitless, neutral 0.
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
  final int outputSharpenMedia; // 0=screen, 1=printMatte, 2=printGlossy, 3=web
  final double outputSharpen; // output sharpening amount, 0..1, neutral 0.
  final double denoiseLuma; // spatial pass, neutral 0.
  final double denoiseChroma; // spatial pass, neutral 0.
  final double aiDenoise; // neural spatial pass, 0..1, neutral 0.

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

  /// Local adjustment mask groups (ADR 0013).
  final List<MaskGroup> maskGroups;

  /// Retouch patches (healing brush & clone stamp), applied in order.
  final List<RetouchPatch> retouchPatches;

  // Lens blur.
  final bool blurEnabled;
  final double blurAmount;
  final double blurFocalPoint;
  final double blurFocalRange;
  final int blurBokehShape;
  final double blurBokehBoost;
  final bool blurBackgroundBlur;
  final int blurSampleCount;
  final String? depthSidecar;
  final String? depthSidecarPath;
  final DepthSidecarData? depthField;
  // Film emulation physics.
  final double filmHalation;
  final double filmHalationRadius;
  final double filmHalationThreshold;
  final double filmBloom;
  final double filmBloomRadius;
  final double filmBloomThreshold;
  final double filmDust;
  final double filmScratches;

  // Shader Lab creative tools.
  final int shaderLabPreset;
  final double shaderParam1;
  final double shaderParam2;
  final double shaderParam3;

  // Perspective & skew geometry (GPU Matrix4 preview, Rust resample on export).
  final double perspectiveX; // horizontal perspective, neutral 0, range ~[-1,1]
  final double perspectiveY; // vertical perspective, neutral 0, range ~[-1,1]
  final double skewX; // horizontal skew, neutral 0, range ~[-1,1]
  final double skewY; // vertical skew, neutral 0, range ~[-1,1]

  // Camera Calibration.
  final double calibrationShadowTint;
  final double calibrationRedHue;
  final double calibrationRedSat;
  final double calibrationGreenHue;
  final double calibrationGreenSat;
  final double calibrationBlueHue;
  final double calibrationBlueSat;

  // Point Color.
  final List<PointColorDef> pointColors;

  // Double Exposure.
  final DoubleExposureLayer? doubleExposure;

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
    int? outputSharpenMedia,
    double? outputSharpen,
    double? denoiseLuma,
    double? denoiseChroma,
    double? aiDenoise,
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
    List<MaskGroup>? maskGroups,
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
    bool? blurBackgroundBlur,
    int? blurSampleCount,
    String? depthSidecar,
    String? depthSidecarPath,
    DepthSidecarData? depthField,
    double? filmHalation,
    double? filmHalationRadius,
    double? filmHalationThreshold,
    double? filmBloom,
    double? filmBloomRadius,
    double? filmBloomThreshold,
    double? filmDust,
    double? filmScratches,
    int? shaderLabPreset,
    double? shaderParam1,
    double? shaderParam2,
    double? shaderParam3,
    double? calibrationShadowTint,
    double? calibrationRedHue,
    double? calibrationRedSat,
    double? calibrationGreenHue,
    double? calibrationGreenSat,
    double? calibrationBlueHue,
    double? calibrationBlueSat,
    List<PointColorDef>? pointColors,
    DoubleExposureLayer? doubleExposure,
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
      outputSharpenMedia: outputSharpenMedia ?? this.outputSharpenMedia,
      outputSharpen: outputSharpen ?? this.outputSharpen,
      denoiseLuma: denoiseLuma ?? this.denoiseLuma,
      denoiseChroma: denoiseChroma ?? this.denoiseChroma,
      aiDenoise: aiDenoise ?? this.aiDenoise,
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
      maskGroups: maskGroups ?? this.maskGroups,
      retouchPatches: retouchPatches ?? this.retouchPatches,
      blurEnabled: blurEnabled ?? this.blurEnabled,
      blurAmount: blurAmount ?? this.blurAmount,
      blurFocalPoint: blurFocalPoint ?? this.blurFocalPoint,
      blurFocalRange: blurFocalRange ?? this.blurFocalRange,
      blurBokehShape: blurBokehShape ?? this.blurBokehShape,
      blurBokehBoost: blurBokehBoost ?? this.blurBokehBoost,
      blurBackgroundBlur: blurBackgroundBlur ?? this.blurBackgroundBlur,
      blurSampleCount: blurSampleCount ?? this.blurSampleCount,
      depthSidecar: depthSidecar ?? this.depthSidecar,
      depthSidecarPath: depthSidecarPath ?? this.depthSidecarPath,
      depthField: depthField ?? this.depthField,
      filmHalation: filmHalation ?? this.filmHalation,
      filmHalationRadius: filmHalationRadius ?? this.filmHalationRadius,
      filmHalationThreshold: filmHalationThreshold ?? this.filmHalationThreshold,
      filmBloom: filmBloom ?? this.filmBloom,
      filmBloomRadius: filmBloomRadius ?? this.filmBloomRadius,
      filmBloomThreshold: filmBloomThreshold ?? this.filmBloomThreshold,
      filmDust: filmDust ?? this.filmDust,
      filmScratches: filmScratches ?? this.filmScratches,
      shaderLabPreset: shaderLabPreset ?? this.shaderLabPreset,
      shaderParam1: shaderParam1 ?? this.shaderParam1,
      shaderParam2: shaderParam2 ?? this.shaderParam2,
      shaderParam3: shaderParam3 ?? this.shaderParam3,
      calibrationShadowTint:
          calibrationShadowTint ?? this.calibrationShadowTint,
      calibrationRedHue: calibrationRedHue ?? this.calibrationRedHue,
      calibrationRedSat: calibrationRedSat ?? this.calibrationRedSat,
      calibrationGreenHue: calibrationGreenHue ?? this.calibrationGreenHue,
      calibrationGreenSat: calibrationGreenSat ?? this.calibrationGreenSat,
      calibrationBlueHue: calibrationBlueHue ?? this.calibrationBlueHue,
      calibrationBlueSat: calibrationBlueSat ?? this.calibrationBlueSat,
      pointColors: pointColors ?? this.pointColors,
      doubleExposure: doubleExposure ?? this.doubleExposure,
    );
  }

  /// Returns a copy of this recipe with all numeric parameters clamped to their
  /// valid ranges.
  EditRecipe clamped() {
    return copyWith(
      exposure: exposure.clamp(-4.0, 4.0),
      contrast: contrast.clamp(-1.0, 1.0),
      highlights: highlights.clamp(-1.0, 1.0),
      shadows: shadows.clamp(-1.0, 1.0),
      whites: whites.clamp(-1.0, 1.0),
      blacks: blacks.clamp(-1.0, 1.0),
      clarity: clarity.clamp(-1.0, 1.0),
      texture: texture.clamp(-1.0, 1.0),
      dehaze: dehaze.clamp(-1.0, 1.0),
      vignette: vignette.clamp(-1.0, 1.0),
      vignetteMidpoint: vignetteMidpoint.clamp(0.0, 1.0),
      vignetteFeather: vignetteFeather.clamp(0.0, 1.0),
      vignetteRoundness: vignetteRoundness.clamp(-1.0, 1.0),
      vignetteHighlights: vignetteHighlights.clamp(0.0, 1.0),
      grain: grain.clamp(0.0, 1.0),
      grainSize: grainSize.clamp(0.1, 1.0),
      grainRoughness: grainRoughness.clamp(0.0, 1.0),
      sharpen: sharpen.clamp(0.0, 1.0),
      sharpenRadius: sharpenRadius.clamp(0.5, 3.0),
      sharpenDetail: sharpenDetail.clamp(0.0, 1.0),
      sharpenMasking: sharpenMasking.clamp(0.0, 1.0),
      outputSharpenMedia: outputSharpenMedia.clamp(0, 3),
      outputSharpen: outputSharpen.clamp(0.0, 1.0),
      denoiseLuma: denoiseLuma.clamp(0.0, 1.0),
      denoiseChroma: denoiseChroma.clamp(0.0, 1.0),
      aiDenoise: aiDenoise.clamp(0.0, 1.0),
      temperature: temperature.clamp(-1.0, 1.0),
      tint: tint.clamp(-1.0, 1.0),
      vibrance: vibrance.clamp(-1.0, 1.0),
      saturation: saturation.clamp(-1.0, 1.0),
      gradeShadowHue: gradeShadowHue.clamp(0.0, 360.0),
      gradeShadowSat: gradeShadowSat.clamp(0.0, 1.0),
      gradeShadowLum: gradeShadowLum.clamp(-1.0, 1.0),
      gradeMidHue: gradeMidHue.clamp(0.0, 360.0),
      gradeMidSat: gradeMidSat.clamp(0.0, 1.0),
      gradeMidLum: gradeMidLum.clamp(-1.0, 1.0),
      gradeHighlightHue: gradeHighlightHue.clamp(0.0, 360.0),
      gradeHighlightSat: gradeHighlightSat.clamp(0.0, 1.0),
      gradeHighlightLum: gradeHighlightLum.clamp(-1.0, 1.0),
      gradeBlending: gradeBlending.clamp(0.0, 1.0),
      gradeBalance: gradeBalance.clamp(-1.0, 1.0),
      hsl: hsl.map((e) => e.clamp(-1.0, 1.0)).toList(),
      rotation: (rotation % 4 + 4) % 4,
      straighten: straighten.clamp(-45.0, 45.0),
      crop: crop.length == 4
          ? crop.map((e) => e.clamp(0.0, 1.0)).toList()
          : fullCrop,
      perspectiveX: perspectiveX.clamp(-1.0, 1.0),
      perspectiveY: perspectiveY.clamp(-1.0, 1.0),
      skewX: skewX.clamp(-1.0, 1.0),
      skewY: skewY.clamp(-1.0, 1.0),
      defringePurpleAmount: defringePurpleAmount.clamp(0.0, 1.0),
      defringePurpleHueMin: defringePurpleHueMin.clamp(0.0, 1.0),
      defringePurpleHueMax: defringePurpleHueMax.clamp(0.0, 1.0),
      defringeGreenAmount: defringeGreenAmount.clamp(0.0, 1.0),
      defringeGreenHueMin: defringeGreenHueMin.clamp(0.0, 1.0),
      defringeGreenHueMax: defringeGreenHueMax.clamp(0.0, 1.0),
      profileDistortion: profileDistortion.clamp(0.0, 2.0),
      profileVignetting: profileVignetting.clamp(0.0, 2.0),
      blurAmount: blurAmount.clamp(0.0, 1.0),
      blurFocalPoint: blurFocalPoint.clamp(0.0, 1.0),
      blurFocalRange: blurFocalRange.clamp(0.01, 1.0),
      blurBokehShape: blurBokehShape.clamp(0, 6),
      blurBokehBoost: blurBokehBoost.clamp(0.0, 1.0),
      blurSampleCount: blurSampleCount.clamp(1, 64),
      filmHalation: filmHalation.clamp(0.0, 1.0),
      filmHalationRadius: filmHalationRadius.clamp(0.1, 1.0),
      filmHalationThreshold: filmHalationThreshold.clamp(0.1, 1.0),
      filmBloom: filmBloom.clamp(0.0, 1.0),
      filmBloomRadius: filmBloomRadius.clamp(0.1, 1.0),
      filmBloomThreshold: filmBloomThreshold.clamp(0.1, 1.0),
      filmDust: filmDust.clamp(0.0, 1.0),
      filmScratches: filmScratches.clamp(0.0, 1.0),
      shaderLabPreset: shaderLabPreset.clamp(0, 10),
      shaderParam1: shaderParam1.clamp(0.0, 1.0),
      shaderParam2: shaderParam2.clamp(0.0, 1.0),
      shaderParam3: shaderParam3.clamp(0.0, 1.0),
      calibrationShadowTint: calibrationShadowTint.clamp(-100.0, 100.0),
      calibrationRedHue: calibrationRedHue.clamp(-100.0, 100.0),
      calibrationRedSat: calibrationRedSat.clamp(-100.0, 100.0),
      calibrationGreenHue: calibrationGreenHue.clamp(-100.0, 100.0),
      calibrationGreenSat: calibrationGreenSat.clamp(-100.0, 100.0),
      calibrationBlueHue: calibrationBlueHue.clamp(-100.0, 100.0),
      calibrationBlueSat: calibrationBlueSat.clamp(-100.0, 100.0),
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
    'outputSharpenMedia': outputSharpenMedia,
    'outputSharpen': outputSharpen,
    'denoiseLuma': denoiseLuma,
    'denoiseChroma': denoiseChroma,
    'aiDenoise': aiDenoise,
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
    'maskGroups': [for (final group in maskGroups) group.toJson()],
    'retouchPatches': [for (final patch in retouchPatches) patch.toJson()],
    'blurEnabled': blurEnabled,
    'blurAmount': blurAmount,
    'blurFocalPoint': blurFocalPoint,
    'blurFocalRange': blurFocalRange,
    'blurBokehShape': blurBokehShape,
    'blurBokehBoost': blurBokehBoost,
    'blurBackgroundBlur': blurBackgroundBlur,
    'blurSampleCount': blurSampleCount,
    if (depthSidecar != null) 'depthSidecar': depthSidecar,
    if (depthSidecarPath != null) 'depthSidecarPath': depthSidecarPath,
    if (depthSidecar != null || depthSidecarPath != null)
      'depth_sidecar': depthSidecar ?? depthSidecarPath,
    if (depthField != null) 'depth_field': depthField!.toJson(),
    'filmHalation': filmHalation,
    'filmHalationRadius': filmHalationRadius,
    'filmHalationThreshold': filmHalationThreshold,
    'filmBloom': filmBloom,
    'filmBloomRadius': filmBloomRadius,
    'filmBloomThreshold': filmBloomThreshold,
    'filmDust': filmDust,
    'filmScratches': filmScratches,
    'shaderLabPreset': shaderLabPreset,
    'shaderParam1': shaderParam1,
    'shaderParam2': shaderParam2,
    'shaderParam3': shaderParam3,
    if (calibrationShadowTint != 0)
      'calibrationShadowTint': calibrationShadowTint,
    if (calibrationRedHue != 0) 'calibrationRedHue': calibrationRedHue,
    if (calibrationRedSat != 0) 'calibrationRedSat': calibrationRedSat,
    if (calibrationGreenHue != 0) 'calibrationGreenHue': calibrationGreenHue,
    if (calibrationGreenSat != 0) 'calibrationGreenSat': calibrationGreenSat,
    if (calibrationBlueHue != 0) 'calibrationBlueHue': calibrationBlueHue,
    if (calibrationBlueSat != 0) 'calibrationBlueSat': calibrationBlueSat,
    if (pointColors.isNotEmpty)
      'pointColors': [for (final p in pointColors) p.toJson()],
    if (doubleExposure != null) 'doubleExposure': doubleExposure!.toJson(),
  };

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
      other.outputSharpenMedia == outputSharpenMedia &&
      other.outputSharpen == outputSharpen &&
      other.denoiseLuma == denoiseLuma &&
      other.denoiseChroma == denoiseChroma &&
      other.aiDenoise == aiDenoise &&
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
      listEquals(other.maskGroups, maskGroups) &&
      listEquals(other.retouchPatches, retouchPatches) &&
      other.blurEnabled == blurEnabled &&
      other.blurAmount == blurAmount &&
      other.blurFocalPoint == blurFocalPoint &&
      other.blurFocalRange == blurFocalRange &&
      other.blurBokehShape == blurBokehShape &&
      other.blurBokehBoost == blurBokehBoost &&
      other.blurBackgroundBlur == blurBackgroundBlur &&
      other.blurSampleCount == blurSampleCount &&
      other.depthSidecar == depthSidecar &&
      other.depthSidecarPath == depthSidecarPath &&
      other.depthField == depthField &&
      other.filmHalation == filmHalation &&
      other.filmHalationRadius == filmHalationRadius &&
      other.filmHalationThreshold == filmHalationThreshold &&
      other.filmBloom == filmBloom &&
      other.filmBloomRadius == filmBloomRadius &&
      other.filmBloomThreshold == filmBloomThreshold &&
      other.filmDust == filmDust &&
      other.filmScratches == filmScratches &&
      other.shaderLabPreset == shaderLabPreset &&
      other.shaderParam1 == shaderParam1 &&
      other.shaderParam2 == shaderParam2 &&
      other.shaderParam3 == shaderParam3 &&
      other.calibrationShadowTint == calibrationShadowTint &&
      other.calibrationRedHue == calibrationRedHue &&
      other.calibrationRedSat == calibrationRedSat &&
      other.calibrationGreenHue == calibrationGreenHue &&
      other.calibrationGreenSat == calibrationGreenSat &&
      other.calibrationBlueHue == calibrationBlueHue &&
      other.calibrationBlueSat == calibrationBlueSat &&
      listEquals(other.pointColors, pointColors) &&
      other.doubleExposure == doubleExposure;

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
      outputSharpenMedia,
      outputSharpen,
      denoiseLuma,
      denoiseChroma,
      aiDenoise,
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
      Object.hashAll(maskGroups),
      Object.hashAll(retouchPatches),
      blurEnabled,
      blurAmount,
      blurFocalPoint,
      blurFocalRange,
      blurBokehShape,
      blurBokehBoost,
      blurBackgroundBlur,
      blurSampleCount,
      depthSidecar,
      depthSidecarPath,
      depthField,
    ),
    Object.hash(
      filmHalation,
      filmHalationRadius,
      filmHalationThreshold,
      filmBloom,
      filmBloomRadius,
      filmBloomThreshold,
      filmDust,
      filmScratches,
      shaderLabPreset,
      shaderParam1,
      shaderParam2,
      shaderParam3,
      Object.hash(
        calibrationShadowTint,
        calibrationRedHue,
        calibrationRedSat,
        calibrationGreenHue,
        calibrationGreenSat,
        calibrationBlueHue,
        calibrationBlueSat,
        Object.hashAll(pointColors),
        doubleExposure,
      ),
    ),
  );

  @override
  String toString() =>
      'EditRecipe(v$schemaVersion, exposure: $exposure, contrast: $contrast, '
      'saturation: $saturation)';
}

/// Point Color adjustment definition targeting a specific hue, saturation, and
/// luminance range with customizable falloff and shifts.
class PointColorDef {
  const PointColorDef({
    this.targetHue = 0.0,
    this.targetSat = 0.5,
    this.targetLum = 0.5,
    this.rangeHue = 0.1,
    this.rangeSat = 0.3,
    this.rangeLum = 0.3,
    this.falloff = 0.5,
    this.hueShift = 0.0,
    this.satShift = 0.0,
    this.lumShift = 0.0,
  });

  factory PointColorDef.fromJson(Map<String, Object?> json) {
    double d(String k, double fallback) => (json[k] as num?)?.toDouble() ?? fallback;
    return PointColorDef(
      targetHue: d('targetHue', 0.0),
      targetSat: d('targetSat', 0.5),
      targetLum: d('targetLum', 0.5),
      rangeHue: d('rangeHue', 0.1),
      rangeSat: d('rangeSat', 0.3),
      rangeLum: d('rangeLum', 0.3),
      falloff: d('falloff', 0.5),
      hueShift: d('hueShift', 0.0),
      satShift: d('satShift', 0.0),
      lumShift: d('lumShift', 0.0),
    );
  }

  final double targetHue;
  final double targetSat;
  final double targetLum;
  final double rangeHue;
  final double rangeSat;
  final double rangeLum;
  final double falloff;
  final double hueShift;
  final double satShift;
  final double lumShift;

  Map<String, Object?> toJson() => {
    'targetHue': targetHue,
    'targetSat': targetSat,
    'targetLum': targetLum,
    'rangeHue': rangeHue,
    'rangeSat': rangeSat,
    'rangeLum': rangeLum,
    'falloff': falloff,
    'hueShift': hueShift,
    'satShift': satShift,
    'lumShift': lumShift,
  };

  PointColorDef copyWith({
    double? targetHue,
    double? targetSat,
    double? targetLum,
    double? rangeHue,
    double? rangeSat,
    double? rangeLum,
    double? falloff,
    double? hueShift,
    double? satShift,
    double? lumShift,
  }) => PointColorDef(
    targetHue: targetHue ?? this.targetHue,
    targetSat: targetSat ?? this.targetSat,
    targetLum: targetLum ?? this.targetLum,
    rangeHue: rangeHue ?? this.rangeHue,
    rangeSat: rangeSat ?? this.rangeSat,
    rangeLum: rangeLum ?? this.rangeLum,
    falloff: falloff ?? this.falloff,
    hueShift: hueShift ?? this.hueShift,
    satShift: satShift ?? this.satShift,
    lumShift: lumShift ?? this.lumShift,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PointColorDef &&
          other.targetHue == targetHue &&
          other.targetSat == targetSat &&
          other.targetLum == targetLum &&
          other.rangeHue == rangeHue &&
          other.rangeSat == rangeSat &&
          other.rangeLum == rangeLum &&
          other.falloff == falloff &&
          other.hueShift == hueShift &&
          other.satShift == satShift &&
          other.lumShift == lumShift;

  @override
  int get hashCode => Object.hash(
    targetHue,
    targetSat,
    targetLum,
    rangeHue,
    rangeSat,
    rangeLum,
    falloff,
    hueShift,
    satShift,
    lumShift,
  );
}

/// A double exposure layer composited over the image.
class DoubleExposureLayer {
  const DoubleExposureLayer({
    this.assetId,
    this.imagePath,
    this.blendModeIndex = 1,
    this.opacity = 0.5,
    this.scale = 1.0,
    this.offsetX = 0.0,
    this.offsetY = 0.0,
  });

  factory DoubleExposureLayer.fromJson(Map<String, Object?> json) {
    return DoubleExposureLayer(
      assetId: json['assetId'] as String?,
      imagePath: json['imagePath'] as String?,
      blendModeIndex: (json['blendModeIndex'] as num?)?.toInt() ?? 1,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 0.5,
      scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
      offsetX: (json['offsetX'] as num?)?.toDouble() ?? 0.0,
      offsetY: (json['offsetY'] as num?)?.toDouble() ?? 0.0,
    );
  }

  final String? assetId;
  final String? imagePath;
  final int blendModeIndex;
  final double opacity;
  final double scale;
  final double offsetX;
  final double offsetY;

  Map<String, Object?> toJson() => {
    'assetId': assetId,
    'imagePath': imagePath,
    'blendModeIndex': blendModeIndex,
    'opacity': opacity,
    'scale': scale,
    'offsetX': offsetX,
    'offsetY': offsetY,
  };

  DoubleExposureLayer copyWith({
    String? assetId,
    String? imagePath,
    int? blendModeIndex,
    double? opacity,
    double? scale,
    double? offsetX,
    double? offsetY,
  }) => DoubleExposureLayer(
    assetId: assetId ?? this.assetId,
    imagePath: imagePath ?? this.imagePath,
    blendModeIndex: blendModeIndex ?? this.blendModeIndex,
    opacity: opacity ?? this.opacity,
    scale: scale ?? this.scale,
    offsetX: offsetX ?? this.offsetX,
    offsetY: offsetY ?? this.offsetY,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DoubleExposureLayer &&
          other.assetId == assetId &&
          other.imagePath == imagePath &&
          other.blendModeIndex == blendModeIndex &&
          other.opacity == opacity &&
          other.scale == scale &&
          other.offsetX == offsetX &&
          other.offsetY == offsetY;

  @override
  int get hashCode => Object.hash(
    assetId,
    imagePath,
    blendModeIndex,
    opacity,
    scale,
    offsetX,
    offsetY,
  );
}
