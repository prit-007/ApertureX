import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Hue centres (in `[0,1)`) of the eight HSL mixer bands — must match the Rust
/// `HSL_BANDS`.
const List<double> hslBandHues = [
  0.0,
  30 / 360,
  60 / 360,
  120 / 360,
  180 / 360,
  240 / 360,
  270 / 360,
  300 / 360,
];

/// Index of the HSL band whose hue centre is closest to [hue] (wrap-aware).
int nearestHslBand(double hue) {
  var best = 0;
  var bestD = double.infinity;
  for (var i = 0; i < hslBandHues.length; i++) {
    final d = (hue - hslBandHues[i]).abs();
    final wrapped = math.min(d, 1 - d);
    if (wrapped < bestD) {
      bestD = wrapped;
      best = i;
    }
  }
  return best;
}

/// HSV hue of an 8-bit RGB triple, in `[0,1)`. Greys return 0.
double hueOf(int r, int g, int b) {
  final rf = r / 255.0;
  final gf = g / 255.0;
  final bf = b / 255.0;
  final max = math.max(rf, math.max(gf, bf));
  final min = math.min(rf, math.min(gf, bf));
  final d = max - min;
  if (d < 1e-6) return 0;
  final h = max == rf
      ? ((gf - bf) / d + (gf < bf ? 6 : 0)) / 6
      : max == gf
      ? ((bf - rf) / d + 2) / 6
      : ((rf - gf) / d + 4) / 6;
  return h.remainder(1.0);
}

/// Whether the Target Adjustment Tool is active (drag the image to target the
/// HSL band under the pointer).
class TatMode extends Notifier<bool> {
  @override
  bool build() => false;
  void toggle() => state = !state;
  void set(bool value) => state = value;
}

final tatModeProvider = NotifierProvider<TatMode, bool>(TatMode.new);

/// Which HSL component the Target Adjustment Tool edits: 0 hue, 1 saturation,
/// 2 luminance.
const List<String> tatComponentLabels = ['Hue', 'Saturation', 'Luminance'];

class TatComponent extends Notifier<int> {
  @override
  int build() => 1; // saturation is the most-used
  void set(int value) => state = value.clamp(0, 2);
  void cycle() => state = (state + 1) % 3;
}

final tatComponentProvider = NotifierProvider<TatComponent, int>(
  TatComponent.new,
);
