import 'package:flutter/services.dart';

/// The haptic a value change should fire (ADR 0011, "zero-gravity haptics").
enum HapticTick { none, neutralCross, limit }

/// Decides the haptic for a value move from [previous] to [next] over
/// `[min, max]`. Pure and unit-testable.
///
/// * reaching/leaving an end-stop → [HapticTick.limit] (heavy thud)
/// * passing through — or landing exactly on — neutral → [HapticTick.neutralCross]
HapticTick hapticFor(double previous, double next, double min, double max) {
  if (next != previous && (next <= min || next >= max)) {
    return HapticTick.limit;
  }
  if (next == 0.0 && previous != 0.0) {
    return HapticTick.neutralCross;
  }
  if (previous != 0.0 && next != 0.0 && previous.sign != next.sign) {
    return HapticTick.neutralCross;
  }
  return HapticTick.none;
}

/// Fires the platform haptic for a [HapticTick].
void fireHaptic(HapticTick tick) {
  switch (tick) {
    case HapticTick.neutralCross:
      HapticFeedback.mediumImpact();
    case HapticTick.limit:
      HapticFeedback.heavyImpact();
    case HapticTick.none:
      break;
  }
}

/// Intensity (0..1) of the "smart snap" haptic gradient for [value] over
/// `[min, max]`. Pure and unit-testable.
///
/// 0 while safely inside the range; ramps up as the value approaches either
/// hard limit — faint pulses that get quicker the closer you get, so the
/// user *feels* the data starting to clip (ADR 0011, "zero-gravity haptics").
///
/// [safeFraction] is how much of the half-range stays silent (measured from
/// the centre). The default `0.75` means an exposure of ±4 EV only starts
/// pulsing past ±3 EV.
double hapticGradientIntensity(
  double value,
  double min,
  double max, {
  double safeFraction = 0.75,
}) {
  if (max <= min || safeFraction >= 1) return 0;
  final half = (max - min) / 2;
  if (half <= 0) return 0;
  final center = (min + max) / 2;
  final offset = (value - center).abs() / half;
  if (offset <= safeFraction) return 0;
  return ((offset - safeFraction) / (1 - safeFraction)).clamp(0.0, 1.0);
}

/// Pulse spacing for a gradient [intensity]: faint and slow just past the
/// safe zone (~140 ms), rapid and firm at the limit (~45 ms).
Duration hapticGradientInterval(double intensity) {
  final i = intensity.clamp(0.0, 1.0);
  return Duration(microseconds: (140000 - 95000 * i).round());
}

/// Accumulates drag time between value ticks and decides when a gradient
/// pulse fires. Pure — the caller supplies the real elapsed time, so the
/// whole behaviour is unit-testable without platform haptics.
class HapticGradientPacer {
  Duration _sinceLast = Duration.zero;
  double intensity = 0;

  /// Feeds the time [elapsed] since the previous tick and the current
  /// [value]; returns true when a faint `selectionClick` should fire now.
  bool tick(
    Duration elapsed, {
    required double value,
    required double min,
    required double max,
    double safeFraction = 0.75,
  }) {
    intensity = hapticGradientIntensity(
      value,
      min,
      max,
      safeFraction: safeFraction,
    );
    if (intensity <= 0) {
      _sinceLast = Duration.zero;
      return false;
    }
    _sinceLast += elapsed;
    if (_sinceLast >= hapticGradientInterval(intensity)) {
      _sinceLast = Duration.zero;
      return true;
    }
    return false;
  }

  /// Drops any accumulated time (a new gesture started).
  void reset() {
    _sinceLast = Duration.zero;
    intensity = 0;
  }
}
