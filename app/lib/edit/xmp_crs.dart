import 'recipe.dart';

/// One `crs:` attribute ↔ recipe field binding.
///
/// This table is the **single source of truth shared by the importer
/// (`parseXmpPreset`) and the exporter (`writeXmp`)** so the #77 round-trip
/// `parse(write(recipe)) ~= recipe` holds *by construction*: neither side can
/// define a mapping the other lacks, and a scale change in one direction is
/// mirrored in the other.
///
/// Direction of conversion:
/// * write: Lightroom value = recipe value ÷ [scale]  (via [toCrs])
/// * read:  recipe value = Lightroom value × [scale], clamped to the
///   recipe's valid range ([min]..[max])  (via [fromCrs])
class CrsBinding {
  const CrsBinding({
    required this.key,
    required this.label,
    required this.scale,
    required this.get,
    required this.set,
    this.min,
    this.max,
    this.approximated = false,
  });

  /// The Lightroom attribute name, e.g. `Exposure2012` (emitted as
  /// `crs:Exposure2012`).
  final String key;

  /// Human label used in the preset compatibility report.
  final String label;

  /// Lightroom scale factor: ours = raw × [scale], raw = ours ÷ [scale].
  final double scale;

  /// Reads the current recipe value for this attribute.
  final double Function(EditRecipe recipe) get;

  /// Returns a copy of [recipe] with this attribute set to [value].
  final EditRecipe Function(EditRecipe recipe, double value) set;

  /// Clamp bounds applied when *reading* (our valid range), so foreign presets
  /// can never push a field outside what the renderer accepts.
  final double? min;
  final double? max;

  /// True when the Lightroom semantics differ from ours in kind, not just in
  /// scale (shown as "approximated" in the compatibility report).
  final bool approximated;

  /// Recipe → Lightroom attribute value (the inverse of [fromCrs]).
  double toCrs(double ours) => ours / scale;

  /// Lightroom attribute → recipe value, clamped to [min]..[max].
  double fromCrs(double raw) {
    final value = raw * scale;
    if (min == null && max == null) return value;
    return value.clamp(min ?? -1e9, max ?? 1e9).toDouble();
  }
}

/// Every scalar `crs:` attribute ApertureX maps, in compatibility-report
/// order. Keys the writer emits and the reader understands are exactly this
/// set — plus the composite Crop/Rotation handling in `xmp_preset.dart`.
///
/// Scales follow Lightroom's published ranges (ACR process-2012 sliders are
/// -100..100 integers for contrast/tone/effects, ±4 EV reals for exposure,
/// Tint -150..150, Temperature 2000..50000 K).
final List<CrsBinding> crsBindings = <CrsBinding>[
  CrsBinding(
    key: 'Exposure2012',
    label: 'Exposure',
    scale: 1,
    get: (r) => r.exposure,
    set: (r, v) => r.copyWith(exposure: v),
  ),
  CrsBinding(
    key: 'Contrast2012',
    label: 'Contrast',
    scale: 0.01,
    get: (r) => r.contrast,
    set: (r, v) => r.copyWith(contrast: v),
  ),
  CrsBinding(
    key: 'Highlights2012',
    label: 'Highlights',
    scale: 0.01,
    get: (r) => r.highlights,
    set: (r, v) => r.copyWith(highlights: v),
  ),
  CrsBinding(
    key: 'Shadows2012',
    label: 'Shadows',
    scale: 0.01,
    get: (r) => r.shadows,
    set: (r, v) => r.copyWith(shadows: v),
  ),
  CrsBinding(
    key: 'Whites2012',
    label: 'Whites',
    scale: 0.01,
    get: (r) => r.whites,
    set: (r, v) => r.copyWith(whites: v),
  ),
  CrsBinding(
    key: 'Blacks2012',
    label: 'Blacks',
    scale: 0.01,
    get: (r) => r.blacks,
    set: (r, v) => r.copyWith(blacks: v),
  ),
  CrsBinding(
    key: 'Vibrance',
    label: 'Vibrance',
    scale: 0.01,
    get: (r) => r.vibrance,
    set: (r, v) => r.copyWith(vibrance: v),
  ),
  CrsBinding(
    key: 'Saturation',
    label: 'Saturation',
    scale: 0.01,
    get: (r) => r.saturation,
    set: (r, v) => r.copyWith(saturation: v),
  ),
  CrsBinding(
    key: 'Clarity2012',
    label: 'Clarity',
    scale: 0.01,
    get: (r) => r.clarity,
    set: (r, v) => r.copyWith(clarity: v),
  ),
  CrsBinding(
    key: 'Texture',
    label: 'Texture',
    scale: 0.01,
    get: (r) => r.texture,
    set: (r, v) => r.copyWith(texture: v),
  ),
  CrsBinding(
    key: 'Dehaze',
    label: 'Dehaze',
    scale: 0.01,
    get: (r) => r.dehaze,
    set: (r, v) => r.copyWith(dehaze: v),
  ),
  // Vignette sign: Lightroom darkens with a *negative* PostCropVignetteAmount,
  // our recipe darkens with a positive one — hence scale -0.01 (an exact
  // inverse, so the round-trip still holds).
  CrsBinding(
    key: 'PostCropVignetteAmount',
    label: 'Vignette',
    scale: -0.01,
    get: (r) => r.vignette,
    set: (r, v) => r.copyWith(vignette: v),
  ),
  CrsBinding(
    key: 'PostCropVignetteMidpoint',
    label: 'Vignette midpoint',
    scale: 0.01,
    get: (r) => r.vignetteMidpoint,
    set: (r, v) => r.copyWith(vignetteMidpoint: v),
    min: 0,
    max: 1,
  ),
  CrsBinding(
    key: 'PostCropVignetteFeather',
    label: 'Vignette feather',
    scale: 0.01,
    get: (r) => r.vignetteFeather,
    set: (r, v) => r.copyWith(vignetteFeather: v),
    min: 0,
    max: 1,
  ),
  CrsBinding(
    key: 'PostCropVignetteRoundness',
    label: 'Vignette roundness',
    scale: 0.01,
    get: (r) => r.vignetteRoundness,
    set: (r, v) => r.copyWith(vignetteRoundness: v),
    min: -1,
    max: 1,
  ),
  CrsBinding(
    key: 'PostCropVignetteHighlightContrast',
    label: 'Vignette highlights',
    scale: 0.01,
    get: (r) => r.vignetteHighlights,
    set: (r, v) => r.copyWith(vignetteHighlights: v),
    min: 0,
    max: 1,
  ),
  CrsBinding(
    key: 'GrainAmount',
    label: 'Grain',
    scale: 0.01,
    get: (r) => r.grain,
    set: (r, v) => r.copyWith(grain: v),
    min: 0,
    max: 1,
  ),
  CrsBinding(
    key: 'GrainSize',
    label: 'Grain size',
    scale: 0.01,
    get: (r) => r.grainSize,
    set: (r, v) => r.copyWith(grainSize: v),
    min: 0.1,
    max: 1,
  ),
  CrsBinding(
    key: 'GrainFrequency',
    label: 'Grain roughness',
    scale: 0.01,
    get: (r) => r.grainRoughness,
    set: (r, v) => r.copyWith(grainRoughness: v),
    min: 0,
    max: 1,
  ),
  CrsBinding(
    key: 'Tint',
    label: 'Tint',
    scale: 0.0067,
    get: (r) => r.tint,
    set: (r, v) => r.copyWith(tint: v),
    min: -1,
    max: 1,
  ),
  // Temperature is an absolute Kelvin value in Lightroom; we approximate it as
  // a relative -1..1 shift (reported as approximated, both directions).
  CrsBinding(
    key: 'Temperature',
    label: 'Temperature',
    scale: 0.0002,
    get: (r) => r.temperature,
    set: (r, v) => r.copyWith(temperature: v),
    min: -1,
    max: 1,
    approximated: true,
  ),
];

/// The crop corners, in [EditRecipe.crop] order (left, top, right, bottom).
const List<String> crsCropKeys = <String>[
  'CropLeft',
  'CropTop',
  'CropRight',
  'CropBottom',
];

/// One Lightroom-style rotation angle in degrees: the quarter-turn [rotation]
/// folded together with the [straighten] angle (ACR stores a single
/// `crs:Rotation`).
double rotationDegrees(int rotation, double straighten) =>
    rotation * 90 + straighten;

/// Inverse of [rotationDegrees]: splits an angle back into quarter turns and
/// the remaining straighten angle (|straighten| ≤ 45 by construction).
///
/// Exact-representation caveat: `45°` on top of a quarter turn is
/// indistinguishable from `-45°` on the next one — the transform is identical,
/// only the tuple differs (round-trip stays lossless for every other value).
(int rotation, double straighten) rotationFromDegrees(double degrees) {
  final quarter = ((degrees / 90).round() % 4 + 4) % 4;
  return (quarter, degrees - quarter * 90);
}
