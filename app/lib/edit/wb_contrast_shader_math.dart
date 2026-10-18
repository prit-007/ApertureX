import 'dart:math' as math;

/// Bradford RGB→LMS cone-response matrix — mirrors rust/src/color.rs::BRADFORD.
const List<List<double>> bradford = [
  [0.8951, 0.2664, -0.1614],
  [-0.7502, 1.7135, 0.0367],
  [0.0389, -0.0685, 1.0296],
];

/// Inverse of [`bradford`] — mirrors rust/src/color.rs::BRADFORD_INV.
const List<List<double>> bradfordInv = [
  [0.9869929, -0.1470543, 0.1599627],
  [0.4323053, 0.5183603, 0.0492912],
  [-0.0085287, 0.0400428, 0.9684867],
];

List<double> mul3(List<List<double>> m, List<double> v) {
  return [
    m[0][0] * v[0] + m[0][1] * v[1] + m[0][2] * v[2],
    m[1][0] * v[0] + m[1][1] * v[1] + m[1][2] * v[2],
    m[2][0] * v[0] + m[2][1] * v[1] + m[2][2] * v[2],
  ];
}

/// Von Kries white balance: scale the LMS cone responses, then back to RGB.
/// Temperature pushes warm (more L, less S); tint pushes magenta (less M).
/// Mirrors rust/src/color.rs::white_balance.
List<double> applyWhiteBalance(List<double> lin, double temperature, double tint) {
  if (temperature == 0.0 && tint == 0.0) {
    return List<double>.from(lin);
  }
  final lms = mul3(bradford, lin);
  final gain = [
    (1.0 + 0.20 * temperature).clamp(0.0, double.infinity),
    (1.0 - 0.20 * tint).clamp(0.0, double.infinity),
    (1.0 - 0.30 * temperature).clamp(0.0, double.infinity),
  ];
  return mul3(
    bradfordInv,
    [lms[0] * gain[0], lms[1] * gain[1], lms[2] * gain[2]],
  );
}

/// Smooth contrast around mid-grey via a smoothstep S-curve. 0 is identity;
/// positive blends toward the S, negative toward its exact inverse.
/// Mirrors rust/src/color.rs::contrast_curve.
double applyContrast(double x, double contrast) {
  final xx = x.clamp(0.0, 1.0);
  final s = xx * xx * (3.0 - 2.0 * xx);
  if (contrast >= 0.0) {
    return xx + (s - xx) * contrast;
  } else {
    final inv = 0.5 - math.asin((1.0 - 2.0 * xx).clamp(-1.0, 1.0)) / 3.0;
    return xx + (inv - xx) * (-contrast);
  }
}
