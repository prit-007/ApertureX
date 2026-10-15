import 'package:flutter/foundation.dart' show listEquals;

/// Mask kinds (must match the Rust `MASK_*` constants).
enum MaskKind { linear, radial, luminance, brush, subject, sky }

/// A local adjustment layer (P2.5): an analytic mask + a point-wise sub-grade.
/// Non-destructive and small (parametric) — the Lightroom "local adjustment" /
/// Snapseed "Stack" model.
class AdjustmentLayer {
  const AdjustmentLayer({
    this.maskKind = MaskKind.radial,
    this.maskParams = const <double>[0.5, 0.5, 0.3, 0.3, 0.3],
    this.inverted = false,
    this.exposure = 0,
    this.contrast = 0,
    this.saturation = 0,
    this.temperature = 0,
    this.tint = 0,
    this.highlights = 0,
    this.shadows = 0,
  });

  final MaskKind maskKind;

  /// linear `[x0,y0,x1,y1]`, radial `[cx,cy,rx,ry,feather]`, luminance `[lo,hi]`,
  /// brush `[radius, feather, count, x0, y0, p0, ...]`, subject `[cx,cy,rx,ry,feather]`,
  /// sky `[horizon_y, feather, blue_weight]`.
  final List<double> maskParams;

  /// Whether the mask coverage should be inverted `(1.0 - coverage)`.
  final bool inverted;

  final double exposure;
  final double contrast;
  final double saturation;
  final double temperature;
  final double tint;
  final double highlights;
  final double shadows;

  AdjustmentLayer copyWith({
    MaskKind? maskKind,
    List<double>? maskParams,
    bool? inverted,
    double? exposure,
    double? contrast,
    double? saturation,
    double? temperature,
    double? tint,
    double? highlights,
    double? shadows,
  }) => AdjustmentLayer(
    maskKind: maskKind ?? this.maskKind,
    maskParams: maskParams ?? this.maskParams,
    inverted: inverted ?? this.inverted,
    exposure: exposure ?? this.exposure,
    contrast: contrast ?? this.contrast,
    saturation: saturation ?? this.saturation,
    temperature: temperature ?? this.temperature,
    tint: tint ?? this.tint,
    highlights: highlights ?? this.highlights,
    shadows: shadows ?? this.shadows,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'maskKind': maskKind.index,
    'maskParams': maskParams,
    'inverted': inverted,
    'exposure': exposure,
    'contrast': contrast,
    'saturation': saturation,
    'temperature': temperature,
    'tint': tint,
    'highlights': highlights,
    'shadows': shadows,
  };

  factory AdjustmentLayer.fromJson(Map<String, Object?> json) {
    double d(String k) => (json[k] as num?)?.toDouble() ?? 0;
    final kindIndex = (json['maskKind'] as num?)?.toInt() ?? 1;
    return AdjustmentLayer(
      maskKind: MaskKind.values[kindIndex.clamp(0, MaskKind.values.length - 1)],
      maskParams:
          (json['maskParams'] as List?)?.map((e) => (e as num).toDouble()).toList() ??
          const <double>[],
      inverted: (json['inverted'] as bool?) ?? false,
      exposure: d('exposure'),
      contrast: d('contrast'),
      saturation: d('saturation'),
      temperature: d('temperature'),
      tint: d('tint'),
      highlights: d('highlights'),
      shadows: d('shadows'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AdjustmentLayer &&
      other.maskKind == maskKind &&
      listEquals(other.maskParams, maskParams) &&
      other.inverted == inverted &&
      other.exposure == exposure &&
      other.contrast == contrast &&
      other.saturation == saturation &&
      other.temperature == temperature &&
      other.tint == tint &&
      other.highlights == highlights &&
      other.shadows == shadows;

  @override
  int get hashCode => Object.hash(
    maskKind,
    Object.hashAll(maskParams),
    inverted,
    exposure,
    contrast,
    saturation,
    temperature,
    tint,
    highlights,
    shadows,
  );
}
