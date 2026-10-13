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
  double fractionOf(double value) =>
      ((value - spec.min) / span).clamp(0.0, 1.0);

  /// Value at a track position [fraction] (0..1), clamped.
  double valueAt(double fraction) =>
      spec.min + fraction.clamp(0.0, 1.0) * span;

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
