import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset;
import 'package:flutter/foundation.dart' show listEquals;

/// Mask kinds (must match the Rust `MASK_*` constants).
enum MaskKind { linear, radial, luminance, brush, subject, sky, bitmap }

/// Mask boolean operations (ADR 0013, matches Rust `JOIN_*` constants).
enum MaskJoinOp { add, subtract, intersect }

/// A local adjustment mask group (ADR 0013).
///
/// In Adobe Lightroom, member masks define geometry and selection coverage,
/// while the group owns the composite grade parameters, group amount (0–200%),
/// and group invert.
class MaskGroup {
  const MaskGroup({
    required this.id,
    this.name = 'Mask',
    this.inverted = false,
    this.amount = 1.0,
    this.exposure = 0,
    this.contrast = 0,
    this.saturation = 0,
    this.temperature = 0,
    this.tint = 0,
    this.highlights = 0,
    this.shadows = 0,
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
  });

  final String id;
  final String name;
  final bool inverted;
  final double amount;
  final double exposure;
  final double contrast;
  final double saturation;
  final double temperature;
  final double tint;
  final double highlights;
  final double shadows;
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

  MaskGroup copyWith({
    String? id,
    String? name,
    bool? inverted,
    double? amount,
    double? exposure,
    double? contrast,
    double? saturation,
    double? temperature,
    double? tint,
    double? highlights,
    double? shadows,
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
  }) => MaskGroup(
    id: id ?? this.id,
    name: name ?? this.name,
    inverted: inverted ?? this.inverted,
    amount: amount ?? this.amount,
    exposure: exposure ?? this.exposure,
    contrast: contrast ?? this.contrast,
    saturation: saturation ?? this.saturation,
    temperature: temperature ?? this.temperature,
    tint: tint ?? this.tint,
    highlights: highlights ?? this.highlights,
    shadows: shadows ?? this.shadows,
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
  );

  /// True while every grade field still equals its constructor default — the
  /// user has never graded this group, so it is safe to seed from a member's
  /// stamped defaults (ADR 0013 §2.2: the group owns the grade, members own
  /// coverage only).
  bool get isGradeNeutral =>
      exposure == 0 &&
      contrast == 0 &&
      saturation == 0 &&
      temperature == 0 &&
      tint == 0 &&
      highlights == 0 &&
      shadows == 0 &&
      gradeShadowHue == 0 &&
      gradeShadowSat == 0 &&
      gradeShadowLum == 0 &&
      gradeMidHue == 0 &&
      gradeMidSat == 0 &&
      gradeMidLum == 0 &&
      gradeHighlightHue == 0 &&
      gradeHighlightSat == 0 &&
      gradeHighlightLum == 0 &&
      gradeBalance == 0 &&
      gradeBlending == 0.5;

  /// Copies [layer]'s grade fields onto this group — used to seed a fresh
  /// group from the defaults of the first member added to it.
  MaskGroup withGradeOf(AdjustmentLayer layer) => copyWith(
    exposure: layer.exposure,
    contrast: layer.contrast,
    saturation: layer.saturation,
    temperature: layer.temperature,
    tint: layer.tint,
    highlights: layer.highlights,
    shadows: layer.shadows,
    gradeShadowHue: layer.gradeShadowHue,
    gradeShadowSat: layer.gradeShadowSat,
    gradeShadowLum: layer.gradeShadowLum,
    gradeMidHue: layer.gradeMidHue,
    gradeMidSat: layer.gradeMidSat,
    gradeMidLum: layer.gradeMidLum,
    gradeHighlightHue: layer.gradeHighlightHue,
    gradeHighlightSat: layer.gradeHighlightSat,
    gradeHighlightLum: layer.gradeHighlightLum,
    gradeBlending: layer.gradeBlending,
    gradeBalance: layer.gradeBalance,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'inverted': inverted,
    'amount': amount,
    'exposure': exposure,
    'contrast': contrast,
    'saturation': saturation,
    'temperature': temperature,
    'tint': tint,
    'highlights': highlights,
    'shadows': shadows,
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
  };

  factory MaskGroup.fromJson(Map<String, Object?> json) {
    double d(String k) => (json[k] as num?)?.toDouble() ?? 0;
    return MaskGroup(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Mask',
      inverted: (json['inverted'] as bool?) ?? false,
      amount: json.containsKey('amount') ? d('amount') : 1.0,
      exposure: d('exposure'),
      contrast: d('contrast'),
      saturation: d('saturation'),
      temperature: d('temperature'),
      tint: d('tint'),
      highlights: d('highlights'),
      shadows: d('shadows'),
      gradeShadowHue: d('gradeShadowHue'),
      gradeShadowSat: d('gradeShadowSat'),
      gradeShadowLum: d('gradeShadowLum'),
      gradeMidHue: d('gradeMidHue'),
      gradeMidSat: d('gradeMidSat'),
      gradeMidLum: d('gradeMidLum'),
      gradeHighlightHue: d('gradeHighlightHue'),
      gradeHighlightSat: d('gradeHighlightSat'),
      gradeHighlightLum: d('gradeHighlightLum'),
      gradeBlending: json.containsKey('gradeBlending') ? d('gradeBlending') : 0.5,
      gradeBalance: d('gradeBalance'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MaskGroup &&
      other.id == id &&
      other.name == name &&
      other.inverted == inverted &&
      other.amount == amount &&
      other.exposure == exposure &&
      other.contrast == contrast &&
      other.saturation == saturation &&
      other.temperature == temperature &&
      other.tint == tint &&
      other.highlights == highlights &&
      other.shadows == shadows &&
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
      other.gradeBalance == gradeBalance;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    inverted,
    amount,
    exposure,
    contrast,
    saturation,
    temperature,
    tint,
    highlights,
    shadows,
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
  );
}

/// Longest allowed side for a stored bitmap mask (#86): keeping masks at or
/// under this bound caps a base64-encoded layer at ~90 KB of recipe JSON and
/// ~65 KB of in-memory bytes, versus ~4.7 MB for the old inline double array.
const int kMaxBitmapMaskSide = 256;

/// Box-folds a `w×h` alpha byte map so the longest side is at most
/// [kMaxBitmapMaskSide], preserving aspect ratio. A plain box average (not
/// nearest-neighbour) so a constant field stays exactly constant — asserted by
/// the #86 tests — and mask edges stay smooth rather than aliased.
(Uint8List, int, int) _capBitmapMask(Uint8List bytes, int w, int h) {
  final longest = math.max(w, h);
  if (longest <= kMaxBitmapMaskSide) return (bytes, w, h);
  final scale = kMaxBitmapMaskSide / longest;
  final tw = math.max(1, (w * scale).round());
  final th = math.max(1, (h * scale).round());
  final out = Uint8List(tw * th);
  final sx = w / tw;
  final sy = h / th;
  for (var ty = 0; ty < th; ty++) {
    final y0 = (ty * sy).floor();
    final y1 = math.min(h, math.max(y0 + 1, ((ty + 1) * sy).ceil()));
    for (var tx = 0; tx < tw; tx++) {
      final x0 = (tx * sx).floor();
      final x1 = math.min(w, math.max(x0 + 1, ((tx + 1) * sx).ceil()));
      var sum = 0;
      var count = 0;
      for (var y = y0; y < y1; y++) {
        final row = y * w;
        for (var x = x0; x < x1; x++) {
          sum += bytes[row + x];
          count++;
        }
      }
      out[ty * tw + tx] = (sum / count).round();
    }
  }
  return (out, tw, th);
}

/// Reads the bitmap payload out of a serialized layer JSON, accepting both the
/// compact #86 format (`maskBlob` base64 + `maskParams: [w, h]`) and the legacy
/// pre-#86 inline double array (`[w, h, a0…]`). Returns the (possibly capped)
/// bytes and the matching dimensions. Throws [FormatException] on payloads
/// that cannot be trusted — the catalog/sidecar loaders already skip corrupt
/// entries one level up.
(Uint8List, int, int) _readBitmapPayload(Map<String, Object?> json, List<double> params) {
  final w = params.isNotEmpty ? params[0].toInt() : 0;
  final h = params.length > 1 ? params[1].toInt() : 0;
  if (w <= 0 || h <= 0) {
    throw FormatException('bitmap mask has no valid dimensions (${params.take(2).join(', ')})');
  }
  final encoded = json['maskBlob'];
  final Uint8List bytes;
  if (encoded is String) {
    bytes = base64Decode(encoded);
    if (bytes.length != w * h) {
      throw FormatException('bitmap mask blob is ${bytes.length} bytes, expected ${w * h}');
    }
  } else {
    // Legacy wire format: every alpha was an inline double after [w, h].
    if (params.length < 2 + w * h) {
      throw FormatException('bitmap mask params too short: ${params.length} for $w×$h');
    }
    bytes = Uint8List(w * h);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = (params[2 + i].clamp(0.0, 1.0) * 255).round();
    }
  }
  return _capBitmapMask(bytes, w, h);
}

/// A local adjustment layer (P2.5): an analytic mask + a point-wise sub-grade.
/// Non-destructive and small (parametric) — the Lightroom "local adjustment" /
/// Snapseed "Stack" model.
class AdjustmentLayer {
  const AdjustmentLayer({
    this.maskKind = MaskKind.radial,
    this.maskParams = const <double>[0.5, 0.5, 0.3, 0.3, 0.3],
    this.maskBlob,
    this.inverted = false,
    this.amount = 1.0,
    this.groupId,
    this.joinOp = MaskJoinOp.add,
    this.exposure = 0,
    this.contrast = 0,
    this.saturation = 0,
    this.temperature = 0,
    this.tint = 0,
    this.highlights = 0,
    this.shadows = 0,
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
    this.aiIntent,
    this.originAssetId,
  });

  /// Creates a local adjustment layer backed by an 8-bit alpha probability tensor / bitmap.
  ///
  /// [alphas] must be exactly `width × height` values in `0..1`. Storage is
  /// compact (#86): values are quantized to `u8`, the longest side is capped
  /// at [kMaxBitmapMaskSide] with box averaging, only `[width, height]` is
  /// kept in [maskParams], and the bytes live in [maskBlob] (base64 on the
  /// wire) — expanded to floats only at the FFI boundary.
  factory AdjustmentLayer.bitmap({
    required int width,
    required int height,
    required List<double> alphas,
    bool inverted = false,
    double amount = 1.0,
    String? groupId,
    MaskJoinOp joinOp = MaskJoinOp.add,
    double exposure = 0,
    double contrast = 0,
    double saturation = 0,
    double temperature = 0,
    double tint = 0,
    double highlights = 0,
    double shadows = 0,
    double gradeShadowHue = 0,
    double gradeShadowSat = 0,
    double gradeShadowLum = 0,
    double gradeMidHue = 0,
    double gradeMidSat = 0,
    double gradeMidLum = 0,
    double gradeHighlightHue = 0,
    double gradeHighlightSat = 0,
    double gradeHighlightLum = 0,
    double gradeBlending = 0.5,
    double gradeBalance = 0,
    String? aiIntent,
    String? originAssetId,
  }) {
    if (width <= 0 || height <= 0 || alphas.length != width * height) {
      throw ArgumentError(
        'bitmap mask expects $width×$height = ${width * height} alphas, got ${alphas.length}',
      );
    }
    final bytes = Uint8List(width * height);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = (alphas[i].clamp(0.0, 1.0) * 255).round();
    }
    final (capped, tw, th) = _capBitmapMask(bytes, width, height);
    return AdjustmentLayer(
      maskKind: MaskKind.bitmap,
      maskParams: <double>[tw.toDouble(), th.toDouble()],
      maskBlob: capped,
      inverted: inverted,
      amount: amount,
      groupId: groupId,
      joinOp: joinOp,
      exposure: exposure,
      contrast: contrast,
      saturation: saturation,
      temperature: temperature,
      tint: tint,
      highlights: highlights,
      shadows: shadows,
      gradeShadowHue: gradeShadowHue,
      gradeShadowSat: gradeShadowSat,
      gradeShadowLum: gradeShadowLum,
      gradeMidHue: gradeMidHue,
      gradeMidSat: gradeMidSat,
      gradeMidLum: gradeMidLum,
      gradeHighlightHue: gradeHighlightHue,
      gradeHighlightSat: gradeHighlightSat,
      gradeHighlightLum: gradeHighlightLum,
      gradeBlending: gradeBlending,
      gradeBalance: gradeBalance,
      aiIntent: aiIntent,
      originAssetId: originAssetId,
    );
  }

  final MaskKind maskKind;

  /// linear `[x0,y0,x1,y1]`, radial `[cx,cy,rx,ry,feather]`, luminance `[lo,hi]`,
  /// brush `[radius, feather, count, x0, y0, p0, ...]`, subject `[cx,cy,rx,ry,feather]`,
  /// sky `[horizon_y, feather, blue_weight]`, bitmap `[width, height]` (the
  /// alpha map itself lives in [maskBlob], compact per #86).
  final List<double> maskParams;

  /// For bitmap masks: quantized 8-bit alpha values, row-major, exactly
  /// `bitmapWidth * bitmapHeight` bytes; null for analytic mask kinds. The
  /// compact counterpart of what Rust samples in `MASK_BITMAP` — expanded to
  /// `[w, h, a0…]` floats only by [toBridgeMaskParams].
  final Uint8List? maskBlob;

  /// Whether the mask coverage should be inverted `(1.0 - coverage)`.
  final bool inverted;

  /// Global amount scalar for this layer (0.0–2.0, default 1.0 = 100%).
  final double amount;

  /// Optional ID of parent [MaskGroup] (ADR 0013). Null indicates an ungrouped layer.
  final String? groupId;

  /// Boolean operation to combine with preceding group members (ADR 0013).
  final MaskJoinOp joinOp;

  final double exposure;
  final double contrast;
  final double saturation;
  final double temperature;
  final double tint;
  final double highlights;
  final double shadows;
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

  /// Optional AI generation intent for this layer ('subject', 'sky', 'background').
  final String? aiIntent;

  /// ID of the asset where this layer was originally inferred.
  final String? originAssetId;

  AdjustmentLayer copyWith({
    MaskKind? maskKind,
    List<double>? maskParams,
    Uint8List? maskBlob,
    bool? inverted,
    double? amount,
    String? groupId,
    bool clearGroupId = false,
    MaskJoinOp? joinOp,
    double? exposure,
    double? contrast,
    double? saturation,
    double? temperature,
    double? tint,
    double? highlights,
    double? shadows,
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
    String? aiIntent,
    String? originAssetId,
  }) => AdjustmentLayer(
    maskKind: maskKind ?? this.maskKind,
    maskParams: maskParams ?? this.maskParams,
    maskBlob: maskBlob ?? this.maskBlob,
    inverted: inverted ?? this.inverted,
    amount: amount ?? this.amount,
    groupId: clearGroupId ? null : (groupId ?? this.groupId),
    joinOp: joinOp ?? this.joinOp,
    exposure: exposure ?? this.exposure,
    contrast: contrast ?? this.contrast,
    saturation: saturation ?? this.saturation,
    temperature: temperature ?? this.temperature,
    tint: tint ?? this.tint,
    highlights: highlights ?? this.highlights,
    shadows: shadows ?? this.shadows,
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
    aiIntent: aiIntent ?? this.aiIntent,
    originAssetId: originAssetId ?? this.originAssetId,
  );

  /// Grade fields reset to neutral. A grouped member hands its grade to the
  /// [MaskGroup] it joins (ADR 0013 §2.2) and keeps only coverage, so there
  /// is exactly one source of truth for what gets rendered.
  AdjustmentLayer get withoutGrade => copyWith(
    exposure: 0,
    contrast: 0,
    saturation: 0,
    temperature: 0,
    tint: 0,
    highlights: 0,
    shadows: 0,
    gradeShadowHue: 0,
    gradeShadowSat: 0,
    gradeShadowLum: 0,
    gradeMidHue: 0,
    gradeMidSat: 0,
    gradeMidLum: 0,
    gradeHighlightHue: 0,
    gradeHighlightSat: 0,
    gradeHighlightLum: 0,
    gradeBlending: 0.5,
    gradeBalance: 0,
  );

  /// For brush masks: base radius (default 0.06).
  double get brushRadius => maskParams.isNotEmpty ? maskParams[0] : 0.06;

  /// For brush masks: edge feather (0..1, default 0.25).
  double get brushFeather => maskParams.length > 1 ? maskParams[1] : 0.25;

  /// For brush masks: count of stroke points.
  int get brushPointCount => maskParams.length > 2 ? maskParams[2].toInt() : 0;

  /// Returns a copy with updated brush radius (clamped 0.01..0.5).
  AdjustmentLayer withBrushRadius(double radius) {
    final p = [...maskParams];
    if (p.isEmpty) {
      p.addAll([radius.clamp(0.01, 0.5), 0.25, 0]);
    } else {
      p[0] = radius.clamp(0.01, 0.5);
    }
    return copyWith(maskParams: p);
  }

  /// Returns a copy with updated brush feather (clamped 0.0..1.0).
  AdjustmentLayer withBrushFeather(double feather) {
    final p = [...maskParams];
    while (p.length < 2) {
      p.add(p.isEmpty ? 0.06 : 0.25);
    }
    p[1] = feather.clamp(0.0, 1.0);
    return copyWith(maskParams: p);
  }

  /// Clears all stroke points from a brush mask, preserving radius and feather.
  AdjustmentLayer withClearedStrokes() {
    final r = brushRadius;
    final f = brushFeather;
    return copyWith(maskParams: [r, f, 0.0]);
  }

  /// Erases stroke points within distance [eraseRadius] of normalized [nx], [ny].
  AdjustmentLayer withErasedNear(double nx, double ny, double eraseRadius) {
    if (maskParams.length < 3) return this;
    final r = brushRadius;
    final f = brushFeather;
    final count = brushPointCount;
    if (count == 0 || maskParams.length < 3 + count * 3) return this;

    final remaining = <double>[];
    final pts = maskParams.sublist(3, 3 + count * 3);
    final rSq = eraseRadius * eraseRadius;
    var lastErased = false;
    for (var i = 0; i < pts.length; i += 3) {
      final px = pts[i];
      final py = pts[i + 1];
      final pr = pts[i + 2];
      if (px < 0) {
        if (remaining.isNotEmpty && remaining[remaining.length - 3] >= 0) {
          remaining.addAll([-1.0, -1.0, -1.0]);
        }
        lastErased = false;
        continue;
      }
      final dx = px - nx;
      final dy = py - ny;
      final distSq = dx * dx + dy * dy;
      if (distSq > rSq) {
        if (lastErased && remaining.isNotEmpty && remaining[remaining.length - 3] >= 0) {
          remaining.addAll([-1.0, -1.0, -1.0]);
        }
        remaining.addAll([px, py, pr]);
        lastErased = false;
      } else {
        lastErased = true;
      }
    }
    while (remaining.length >= 3 && remaining[remaining.length - 3] < 0) {
      remaining.removeRange(remaining.length - 3, remaining.length);
    }
    final newCount = remaining.length ~/ 3;
    return copyWith(maskParams: [r, f, newCount.toDouble(), ...remaining]);
  }

  /// For linear gradient masks: start coordinate.
  Offset get linearStart =>
      maskParams.length >= 2 ? Offset(maskParams[0], maskParams[1]) : const Offset(0.5, 0.2);

  /// For linear gradient masks: end coordinate.
  Offset get linearEnd =>
      maskParams.length >= 4 ? Offset(maskParams[2], maskParams[3]) : const Offset(0.5, 0.8);

  /// Returns a copy with updated linear gradient start and end points.
  AdjustmentLayer withLinearPoints(Offset start, Offset end) => copyWith(
        maskParams: [
          start.dx.clamp(0.0, 1.0),
          start.dy.clamp(0.0, 1.0),
          end.dx.clamp(0.0, 1.0),
          end.dy.clamp(0.0, 1.0),
        ],
      );

  /// For subject masks: normalized center point.
  Offset get subjectCenter =>
      maskParams.length >= 2 ? Offset(maskParams[0], maskParams[1]) : const Offset(0.5, 0.5);

  /// For subject masks: horizontal radius.
  double get subjectRadiusX => maskParams.length >= 3 ? maskParams[2] : 0.28;

  /// For subject masks: vertical radius.
  double get subjectRadiusY => maskParams.length >= 4 ? maskParams[3] : 0.38;

  /// For subject masks: edge feather.
  double get subjectFeather => maskParams.length >= 5 ? maskParams[4] : 0.25;

  /// Returns a copy with updated subject mask bounds.
  AdjustmentLayer withSubjectBounds(
    Offset center,
    double rx,
    double ry, [
    double? feather,
  ]) =>
      copyWith(
        maskParams: [
          center.dx.clamp(0.0, 1.0),
          center.dy.clamp(0.0, 1.0),
          rx.clamp(0.02, 1.0),
          ry.clamp(0.02, 1.0),
          (feather ?? subjectFeather).clamp(0.01, 1.0),
        ],
      );

  /// For sky masks: horizon y position.
  double get skyHorizon => maskParams.isNotEmpty ? maskParams[0] : 0.5;

  /// For sky masks: edge transition feather.
  double get skyFeather => maskParams.length > 1 ? maskParams[1] : 0.15;

  /// For sky masks: chromaticity blue weight (0..1, default 0.6).
  double get skyBlueWeight => maskParams.length > 2 ? maskParams[2] : 0.6;

  /// Returns a copy with updated sky horizon position.
  AdjustmentLayer withSkyHorizon(double horizon) => copyWith(
        maskParams: [
          horizon.clamp(0.0, 1.0),
          skyFeather,
          skyBlueWeight,
        ],
      );

  /// Returns a copy with updated sky transition feather.
  AdjustmentLayer withSkyFeather(double feather) => copyWith(
        maskParams: [
          skyHorizon,
          feather.clamp(0.01, 1.0),
          skyBlueWeight,
        ],
      );

  /// Returns a copy with updated sky chromaticity blue weight.
  AdjustmentLayer withSkyBlueWeight(double blueWeight) => copyWith(
        maskParams: [
          skyHorizon,
          skyFeather,
          blueWeight.clamp(0.0, 1.0),
        ],
      );

  /// For luminance masks: minimum target luminance threshold (0..1).
  double get lumaMin =>
      maskKind == MaskKind.luminance && maskParams.isNotEmpty ? maskParams[0] : 0.0;

  /// For luminance masks: maximum target luminance threshold (0..1).
  double get lumaMax =>
      maskKind == MaskKind.luminance && maskParams.length > 1 ? maskParams[1] : 1.0;

  /// For luminance masks: feather/transition width on lower edge.
  double get lumaFeatherLo =>
      maskKind == MaskKind.luminance && maskParams.length > 2 ? maskParams[2] : 0.15;

  /// For luminance masks: feather/transition width on upper edge.
  double get lumaFeatherHi =>
      maskKind == MaskKind.luminance && maskParams.length > 3
          ? maskParams[3]
          : lumaFeatherLo;

  /// Approximates closest Ansel Adams Zone (0..10) based on target band center.
  int get lumaZone {
    final mid = (lumaMin + lumaMax) / 2.0;
    return (mid * 10.0).round().clamp(0, 10);
  }

  /// Returns a copy with updated luminance band parameters.
  AdjustmentLayer withLumaBand({
    double? min,
    double? max,
    double? featherLo,
    double? featherHi,
  }) {
    final newMin = (min ?? lumaMin).clamp(0.0, 1.0);
    final newMax = (max ?? lumaMax).clamp(0.0, 1.0);
    final lo = newMin <= newMax ? newMin : newMax;
    final hi = newMin <= newMax ? newMax : newMin;
    final fLo = (featherLo ?? lumaFeatherLo).clamp(0.01, 1.0);
    final fHi = (featherHi ?? lumaFeatherHi).clamp(0.01, 1.0);
    return copyWith(
      maskKind: MaskKind.luminance,
      maskParams: [lo, hi, fLo, fHi],
    );
  }

  /// Sets this luminance mask to target an Ansel Adams Zone (0..10).
  AdjustmentLayer withZone(int zone, {double width = 0.10, double feather = 0.10}) {
    final z = zone.clamp(0, 10);
    final double min;
    final double max;
    final double fLo;
    final double fHi;
    if (z == 0) {
      min = 0.0;
      max = 0.08;
      fLo = 0.01;
      fHi = feather;
    } else if (z == 10) {
      min = 0.92;
      max = 1.0;
      fLo = feather;
      fHi = 0.01;
    } else {
      final c = z / 10.0;
      min = (c - width / 2).clamp(0.0, 1.0);
      max = (c + width / 2).clamp(0.0, 1.0);
      fLo = feather;
      fHi = feather;
    }
    return withLumaBand(min: min, max: max, featherLo: fLo, featherHi: fHi);
  }

  /// For bitmap masks: pixel width of the alpha map.
  int get bitmapWidth => maskKind == MaskKind.bitmap && maskParams.isNotEmpty ? maskParams[0].toInt() : 0;

  /// For bitmap masks: pixel height of the alpha map.
  int get bitmapHeight => maskKind == MaskKind.bitmap && maskParams.length > 1 ? maskParams[1].toInt() : 0;

  /// Returns a new [MaskKind.bitmap] adjustment layer with the refined alpha plane
  /// while preserving all grading parameters, group bindings, and amount.
  AdjustmentLayer withRefinedAlphas(List<double> alphas, int width, int height) =>
      AdjustmentLayer.bitmap(
        width: width,
        height: height,
        alphas: alphas,
        inverted: inverted,
        amount: amount,
        groupId: groupId,
        joinOp: joinOp,
        exposure: exposure,
        contrast: contrast,
        saturation: saturation,
        temperature: temperature,
        tint: tint,
        highlights: highlights,
        shadows: shadows,
        gradeShadowHue: gradeShadowHue,
        gradeShadowSat: gradeShadowSat,
        gradeShadowLum: gradeShadowLum,
        gradeMidHue: gradeMidHue,
        gradeMidSat: gradeMidSat,
        gradeMidLum: gradeMidLum,
        gradeHighlightHue: gradeHighlightHue,
        gradeHighlightSat: gradeHighlightSat,
        gradeHighlightLum: gradeHighlightLum,
        gradeBlending: gradeBlending,
        gradeBalance: gradeBalance,
      );

  /// The `[width, height, alpha_0…]` float params the Rust `MASK_*` contract
  /// expects (`app/rust/src/mask.rs`), expanding [maskBlob] for bitmap layers
  /// and passing [maskParams] through unchanged for analytic kinds. This is
  /// the single place bitmap alphas become floats — the six bridge call sites
  /// in `engine.dart` all go through here (#86).
  Float32List toBridgeMaskParams() {
    if (maskKind != MaskKind.bitmap) return Float32List.fromList(maskParams);
    final blob = maskBlob ?? Uint8List(0);
    final out = Float32List(2 + blob.length);
    out[0] = bitmapWidth.toDouble();
    out[1] = bitmapHeight.toDouble();
    for (var i = 0; i < blob.length; i++) {
      out[2 + i] = blob[i] / 255.0;
    }
    return out;
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'maskKind': maskKind.index,
    'maskParams': maskParams,
    if (maskKind == MaskKind.bitmap && maskBlob != null)
      'maskBlob': base64Encode(maskBlob!),
    'inverted': inverted,
    'amount': amount,
    if (groupId != null) 'groupId': groupId,
    if (joinOp != MaskJoinOp.add) 'joinOp': joinOp.index,
    'exposure': exposure,
    'contrast': contrast,
    'saturation': saturation,
    'temperature': temperature,
    'tint': tint,
    'highlights': highlights,
    'shadows': shadows,
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
    if (aiIntent != null) 'aiIntent': aiIntent,
    if (originAssetId != null) 'originAssetId': originAssetId,
  };

  factory AdjustmentLayer.fromJson(Map<String, Object?> json) {
    double d(String k) => (json[k] as num?)?.toDouble() ?? 0;
    final kindIndex = (json['maskKind'] as num?)?.toInt() ?? 1;
    final kind = MaskKind.values[kindIndex.clamp(0, MaskKind.values.length - 1)];
    var params = (json['maskParams'] as List?)?.map((e) => (e as num).toDouble()).toList() ??
        const <double>[];
    Uint8List? blob;
    if (kind == MaskKind.bitmap) {
      // Both the compact #86 format and the legacy inline-double array land
      // here; corrupt payloads throw and get skipped by the catalog loader.
      final (bytes, w, h) = _readBitmapPayload(json, params);
      blob = bytes;
      params = <double>[w.toDouble(), h.toDouble()];
    }
    final rawJoinOp = json['joinOp'];
    final MaskJoinOp joinOp;
    if (rawJoinOp is String) {
      joinOp = MaskJoinOp.values.firstWhere(
        (e) => e.name == rawJoinOp,
        orElse: () => MaskJoinOp.add,
      );
    } else {
      final idx = (rawJoinOp as num?)?.toInt() ?? 0;
      joinOp = MaskJoinOp.values[idx.clamp(0, MaskJoinOp.values.length - 1)];
    }
    return AdjustmentLayer(
      maskKind: kind,
      maskParams: params,
      maskBlob: blob,
      inverted: (json['inverted'] as bool?) ?? false,
      amount: json.containsKey('amount') ? d('amount') : 1.0,
      groupId: json['groupId'] as String?,
      joinOp: joinOp,
      exposure: d('exposure'),
      contrast: d('contrast'),
      saturation: d('saturation'),
      temperature: d('temperature'),
      tint: d('tint'),
      highlights: d('highlights'),
      shadows: d('shadows'),
      gradeShadowHue: d('gradeShadowHue'),
      gradeShadowSat: d('gradeShadowSat'),
      gradeShadowLum: d('gradeShadowLum'),
      gradeMidHue: d('gradeMidHue'),
      gradeMidSat: d('gradeMidSat'),
      gradeMidLum: d('gradeMidLum'),
      gradeHighlightHue: d('gradeHighlightHue'),
      gradeHighlightSat: d('gradeHighlightSat'),
      gradeHighlightLum: d('gradeHighlightLum'),
      gradeBlending: json.containsKey('gradeBlending') ? d('gradeBlending') : 0.5,
      gradeBalance: d('gradeBalance'),
      aiIntent: json['aiIntent'] as String?,
      originAssetId: json['originAssetId'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AdjustmentLayer &&
      other.maskKind == maskKind &&
      listEquals(other.maskParams, maskParams) &&
      listEquals(other.maskBlob, maskBlob) &&
      other.inverted == inverted &&
      other.amount == amount &&
      other.groupId == groupId &&
      other.joinOp == joinOp &&
      other.exposure == exposure &&
      other.contrast == contrast &&
      other.saturation == saturation &&
      other.temperature == temperature &&
      other.tint == tint &&
      other.highlights == highlights &&
      other.shadows == shadows &&
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
      other.aiIntent == aiIntent &&
      other.originAssetId == originAssetId;

  /// Cached hash: [maskBlob] is up to tens of kilobytes and `hashCode` is
  /// consulted on every recipe tick (lists in `baseKeyOf`/`gradeKeyOf`).
  /// The layer is immutable, so the hash is computed once per instance.
  /// An [Expando] (not a field) keeps the class const-constructible.
  static final Expando<int> _hashCache = Expando<int>('AdjustmentLayer.hash');

  @override
  int get hashCode => _hashCache[this] ??= Object.hash(
    maskKind,
    Object.hashAll(maskParams),
    maskBlob == null ? 0 : Object.hashAll(maskBlob!),
    inverted,
    amount,
    groupId,
    joinOp,
    exposure,
    contrast,
    saturation,
    temperature,
    tint,
    highlights,
    shadows,
    aiIntent,
    originAssetId,
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
  );
}
