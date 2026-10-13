import 'package:flutter/foundation.dart' show listEquals;

/// A tone curve: monotone control points in `[0,1]²` stored flat as
/// `[x0, y0, x1, y1, ...]`. Baking to a 256-entry LUT happens in Rust
/// (`color::curve_lut`), monotone-cubic.
class ToneCurve {
  const ToneCurve(this.points);

  /// Flat control points, sorted by x.
  final List<double> points;

  /// `[(0,0), (1,1)]` — maps x to x.
  static const ToneCurve identity = ToneCurve(<double>[0, 0, 1, 1]);

  bool get isIdentity => listEquals(points, identity.points);

  Map<String, Object?> toJson() => <String, Object?>{'points': points};

  factory ToneCurve.fromJson(Object? json) {
    if (json is Map && json['points'] is List) {
      return ToneCurve(
        (json['points'] as List).map((e) => (e as num).toDouble()).toList(),
      );
    }
    return identity;
  }

  @override
  bool operator ==(Object other) =>
      other is ToneCurve && listEquals(other.points, points);

  @override
  int get hashCode => Object.hashAll(points);

  @override
  String toString() => 'ToneCurve($points)';
}
