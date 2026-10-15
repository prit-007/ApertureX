/// Retouch repair mode: heal (Poisson gradient blending) vs clone (direct copy).
enum RetouchMode { heal, clone }

/// A single retouch patch for blemish removal / healing.
///
/// Non-destructive, parametric, normalized `[0..1]` coordinates.
class RetouchPatch {
  const RetouchPatch({
    required this.targetX,
    required this.targetY,
    required this.sourceX,
    required this.sourceY,
    this.radius = 0.05,
    this.feather = 0.5,
    this.opacity = 1.0,
    this.mode = RetouchMode.heal,
  });

  /// Target center X `0..1` (the blemish to remove).
  final double targetX;

  /// Target center Y `0..1`.
  final double targetY;

  /// Source center X `0..1` (the clean area to sample texture from).
  final double sourceX;

  /// Source center Y `0..1`.
  final double sourceY;

  /// Normalized radius `0.005..0.5` relative to min(width, height).
  final double radius;

  /// Edge softness falloff `0..1`.
  final double feather;

  /// Patch opacity `0..1`.
  final double opacity;

  /// Repair mode (`heal` or `clone`).
  final RetouchMode mode;

  RetouchPatch copyWith({
    double? targetX,
    double? targetY,
    double? sourceX,
    double? sourceY,
    double? radius,
    double? feather,
    double? opacity,
    RetouchMode? mode,
  }) => RetouchPatch(
    targetX: targetX ?? this.targetX,
    targetY: targetY ?? this.targetY,
    sourceX: sourceX ?? this.sourceX,
    sourceY: sourceY ?? this.sourceY,
    radius: radius ?? this.radius,
    feather: feather ?? this.feather,
    opacity: opacity ?? this.opacity,
    mode: mode ?? this.mode,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'targetX': targetX,
    'targetY': targetY,
    'sourceX': sourceX,
    'sourceY': sourceY,
    'radius': radius,
    'feather': feather,
    'opacity': opacity,
    'mode': mode.index,
  };

  factory RetouchPatch.fromJson(Map<String, Object?> json) {
    double d(String k, [double def = 0]) => (json[k] as num?)?.toDouble() ?? def;
    final modeIdx = (json['mode'] as num?)?.toInt() ?? 0;
    return RetouchPatch(
      targetX: d('targetX'),
      targetY: d('targetY'),
      sourceX: d('sourceX'),
      sourceY: d('sourceY'),
      radius: d('radius', 0.05),
      feather: d('feather', 0.5),
      opacity: d('opacity', 1.0),
      mode: RetouchMode.values[modeIdx.clamp(0, RetouchMode.values.length - 1)],
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RetouchPatch &&
          other.targetX == targetX &&
          other.targetY == targetY &&
          other.sourceX == sourceX &&
          other.sourceY == sourceY &&
          other.radius == radius &&
          other.feather == feather &&
          other.opacity == opacity &&
          other.mode == mode;

  @override
  int get hashCode => Object.hash(
    targetX,
    targetY,
    sourceX,
    sourceY,
    radius,
    feather,
    opacity,
    mode,
  );
}
