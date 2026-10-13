import 'package:flutter/foundation.dart' show listEquals;

import 'adjustment_layer.dart';
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
    this.sharpen = 0,
    this.denoiseLuma = 0,
    this.denoiseChroma = 0,
    this.temperature = 0,
    this.tint = 0,
    this.vibrance = 0,
    this.saturation = 0,
    // Color grading (split toning): hue + strength per tonal zone.
    this.gradeShadowHue = 0,
    this.gradeShadowSat = 0,
    this.gradeMidHue = 0,
    this.gradeMidSat = 0,
    this.gradeHighlightHue = 0,
    this.gradeHighlightSat = 0,
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
    this.layers = const <AdjustmentLayer>[],
  });

  /// Bumped only on a breaking schema change (ARCHITECTURE §16).
  ///
  /// v2: grouped, catalog-driven parameter model (JSON still flat, v1 keys
  /// unchanged). v3: adds color-grading (split-tone) fields; older recipes read
  /// forward with those fields neutral. `fromJson` always migrates to this.
  static const int currentSchemaVersion = 8;

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
  final double sharpen; // spatial pass, neutral 0.
  final double denoiseLuma; // spatial pass, neutral 0.
  final double denoiseChroma; // spatial pass, neutral 0.

  // Color.
  final double temperature; // unitless, neutral 0.
  final double tint; // unitless, neutral 0.
  final double vibrance; // unitless, neutral 0.
  final double saturation; // unitless, neutral 0.

  // Color grading (split toning): hue 0..1, strength 0..1, neutral 0.
  final double gradeShadowHue;
  final double gradeShadowSat;
  final double gradeMidHue;
  final double gradeMidSat;
  final double gradeHighlightHue;
  final double gradeHighlightSat;

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

  /// Local adjustment layers (masking, P2.5), applied in order.
  final List<AdjustmentLayer> layers;

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
    double? sharpen,
    double? denoiseLuma,
    double? denoiseChroma,
    double? temperature,
    double? tint,
    double? vibrance,
    double? saturation,
    double? gradeShadowHue,
    double? gradeShadowSat,
    double? gradeMidHue,
    double? gradeMidSat,
    double? gradeHighlightHue,
    double? gradeHighlightSat,
    ToneCurve? masterCurve,
    ToneCurve? redCurve,
    ToneCurve? greenCurve,
    ToneCurve? blueCurve,
    List<double>? hsl,
    int? rotation,
    bool? flipH,
    bool? flipV,
    double? straighten,
    List<AdjustmentLayer>? layers,
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
      sharpen: sharpen ?? this.sharpen,
      denoiseLuma: denoiseLuma ?? this.denoiseLuma,
      denoiseChroma: denoiseChroma ?? this.denoiseChroma,
      temperature: temperature ?? this.temperature,
      tint: tint ?? this.tint,
      vibrance: vibrance ?? this.vibrance,
      saturation: saturation ?? this.saturation,
      gradeShadowHue: gradeShadowHue ?? this.gradeShadowHue,
      gradeShadowSat: gradeShadowSat ?? this.gradeShadowSat,
      gradeMidHue: gradeMidHue ?? this.gradeMidHue,
      gradeMidSat: gradeMidSat ?? this.gradeMidSat,
      gradeHighlightHue: gradeHighlightHue ?? this.gradeHighlightHue,
      gradeHighlightSat: gradeHighlightSat ?? this.gradeHighlightSat,
      masterCurve: masterCurve ?? this.masterCurve,
      redCurve: redCurve ?? this.redCurve,
      greenCurve: greenCurve ?? this.greenCurve,
      blueCurve: blueCurve ?? this.blueCurve,
      hsl: hsl ?? this.hsl,
      rotation: rotation ?? this.rotation,
      flipH: flipH ?? this.flipH,
      flipV: flipV ?? this.flipV,
      straighten: straighten ?? this.straighten,
      layers: layers ?? this.layers,
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
    'sharpen': sharpen,
    'denoiseLuma': denoiseLuma,
    'denoiseChroma': denoiseChroma,
    'temperature': temperature,
    'tint': tint,
    'vibrance': vibrance,
    'saturation': saturation,
    'gradeShadowHue': gradeShadowHue,
    'gradeShadowSat': gradeShadowSat,
    'gradeMidHue': gradeMidHue,
    'gradeMidSat': gradeMidSat,
    'gradeHighlightHue': gradeHighlightHue,
    'gradeHighlightSat': gradeHighlightSat,
    'masterCurve': masterCurve.toJson(),
    'redCurve': redCurve.toJson(),
    'greenCurve': greenCurve.toJson(),
    'blueCurve': blueCurve.toJson(),
    'hsl': hsl,
    'rotation': rotation,
    'flipH': flipH,
    'flipV': flipV,
    'straighten': straighten,
    'layers': [for (final layer in layers) layer.toJson()],
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
      sharpen: asDouble('sharpen'),
      denoiseLuma: asDouble('denoiseLuma'),
      denoiseChroma: asDouble('denoiseChroma'),
      temperature: asDouble('temperature'),
      tint: asDouble('tint'),
      vibrance: asDouble('vibrance'),
      saturation: asDouble('saturation'),
      gradeShadowHue: asDouble('gradeShadowHue'),
      gradeShadowSat: asDouble('gradeShadowSat'),
      gradeMidHue: asDouble('gradeMidHue'),
      gradeMidSat: asDouble('gradeMidSat'),
      gradeHighlightHue: asDouble('gradeHighlightHue'),
      gradeHighlightSat: asDouble('gradeHighlightSat'),
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
      layers:
          (json['layers'] as List?)
              ?.map(
                (e) => AdjustmentLayer.fromJson((e as Map).cast<String, Object?>()),
              )
              .toList() ??
          const <AdjustmentLayer>[],
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
      other.sharpen == sharpen &&
      other.denoiseLuma == denoiseLuma &&
      other.denoiseChroma == denoiseChroma &&
      other.temperature == temperature &&
      other.tint == tint &&
      other.vibrance == vibrance &&
      other.saturation == saturation &&
      other.gradeShadowHue == gradeShadowHue &&
      other.gradeShadowSat == gradeShadowSat &&
      other.gradeMidHue == gradeMidHue &&
      other.gradeMidSat == gradeMidSat &&
      other.gradeHighlightHue == gradeHighlightHue &&
      other.gradeHighlightSat == gradeHighlightSat &&
      other.masterCurve == masterCurve &&
      other.redCurve == redCurve &&
      other.greenCurve == greenCurve &&
      other.blueCurve == blueCurve &&
      listEquals(other.hsl, hsl) &&
      other.rotation == rotation &&
      other.flipH == flipH &&
      other.flipV == flipV &&
      other.straighten == straighten &&
      listEquals(other.layers, layers);

  @override
  int get hashCode => Object.hash(
    schemaVersion,
    exposure,
    contrast,
    highlights,
    shadows,
    whites,
    blacks,
    clarity,
    texture,
    sharpen,
    denoiseLuma,
    denoiseChroma,
    temperature,
    tint,
    vibrance,
    saturation,
    Object.hash(
      gradeShadowHue,
      gradeShadowSat,
      gradeMidHue,
      gradeMidSat,
      gradeHighlightHue,
      gradeHighlightSat,
    ),
    Object.hash(masterCurve, redCurve, greenCurve, blueCurve),
    Object.hashAll(hsl),
    Object.hash(
      Object.hash(rotation, flipH, flipV, straighten),
      Object.hashAll(layers),
    ),
  );

  @override
  String toString() =>
      'EditRecipe(v$schemaVersion, exposure: $exposure, contrast: $contrast, '
      'saturation: $saturation)';
}
