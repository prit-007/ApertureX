import 'dart:math' as math;

import '../../edit/parameter.dart';

/// Pure value ↔ track-position math for [ParameterControl] (P2 Slice B).
///
/// Bidirectional parameters (neutral strictly above the min — e.g. exposure,
/// contrast) fill from their neutral point in the middle. Unidirectional ones
/// (neutral at the min — e.g. a future sharpening 0..1) fill from the left.
class SliderMath {
  const SliderMath(this.spec);

  final ParameterSpec spec;

  /// True when the neutral value sits inside the range (center-filled track).
  bool get bidirectional => spec.neutral > spec.min;

  double get span => spec.max - spec.min;

  /// Track position (0..1) for [value], clamped.
  double fractionOf(double value) {
    final v = value.clamp(spec.min, spec.max);
    if (spec.response == ResponseCurve.linear) {
      return (v - spec.min) / span;
    }
    // Piecewise-sqrt about neutral (issue #51): half-range each side gets a
    // sqrt ramp so the first ~10% of the range consumes ~7% of the track
    // (vs 1% linear) — fine control where subtle grades live.
    final half = (spec.max - spec.neutral).abs().clamp(1e-9, double.infinity);
    final d = (v - spec.neutral) / half; // -1..1
    return (0.5 + 0.5 * d.sign * math.sqrt(d.abs())).clamp(0.0, 1.0);
  }

  /// Value at a track position [fraction] (0..1), clamped.
  double valueAt(double fraction) {
    final f = fraction.clamp(0.0, 1.0);
    if (spec.response == ResponseCurve.linear) {
      return spec.min + f * span;
    }
    final half = (spec.max - spec.neutral).abs().clamp(1e-9, double.infinity);
    final d = (f - 0.5) * 2; // -1..1
    return (spec.neutral + d.sign * d.abs() * d.abs() * half).clamp(
      spec.min,
      spec.max,
    );
  }

  /// Where the neutral marker / fill origin sits on the track.
  double get neutralFraction => fractionOf(spec.neutral);

  /// The filled span between neutral and [value], as (start, end) fractions
  /// with `start <= end`.
  (double, double) fillRange(double value) {
    final f = fractionOf(value);
    final n = neutralFraction;
    return (f < n ? f : n, f < n ? n : f);
  }
}
