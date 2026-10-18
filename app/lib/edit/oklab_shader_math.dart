import 'dart:math' as math;

/// sRGB EOTF (encoded [0,1] -> linear [0,1]) — mirrors rust/src/color.rs.
double srgbToLinear(double c) {
  if (c <= 0.04045) {
    return c / 12.92;
  }
  return math.pow((c + 0.055) / 1.055, 2.4) as double;
}

/// sRGB OETF (linear [0,1] -> encoded [0,1]).
double linearToSrgb(double c) {
  if (c <= 0.0031308) {
    return c * 12.92;
  }
  return 1.055 * (math.pow(c, 1.0 / 2.4) as double) - 0.055;
}

/// Oklab LMS cone-response matrix (Ottosson 2020).
const List<List<double>> oklabLms = [
  [0.41222146, 0.53633255, 0.051445995],
  [0.2119035, 0.6806995, 0.10739696],
  [0.08830246, 0.28171885, 0.6299787],
];

/// Inverse Oklab LMS→RGB matrix.
const List<List<double>> oklabLmsInv = [
  [4.0767417, -3.3077116, 0.23096994],
  [-1.268438, 2.6097574, -0.34131938],
  [-0.004196086, -0.7034186, 1.7076147],
];

/// Oklab L→a,b opponent matrix.
const List<List<double>> oklabOpponent = [
  [0.21045426, 0.7936178, -0.004072047],
  [1.9779985, -2.4285922, 0.4505937],
  [0.025904037, 0.78277177, -0.80867577],
];

/// Inverse opponent matrix (used when converting back from L, a, b to LMS′).
const List<List<double>> oklabOpponentInv = [
  [1.0, 0.39633778, 0.21580376],
  [1.0, -0.105561346, -0.06385417],
  [1.0, -0.08948418, -1.2914855],
];

List<double> mul(List<List<double>> m, List<double> v) {
  return [
    m[0][0] * v[0] + m[0][1] * v[1] + m[0][2] * v[2],
    m[1][0] * v[0] + m[1][1] * v[1] + m[1][2] * v[2],
    m[2][0] * v[0] + m[2][1] * v[1] + m[2][2] * v[2],
  ];
}

/// Sign-preserving cube root — mirrors Rust's `f32::cbrt` (handles negatives).
double cbrt(double x) {
  if (x == 0.0) return 0.0;
  final sign = x < 0.0 ? -1.0 : 1.0;
  return sign * math.pow(x.abs(), 1.0 / 3.0);
}

/// Oklab saturation ported from rust/src/color.rs::saturate_oklab.
///
/// Scales chroma (`a`,`b`) uniformly in Oklab space so colours get richer
/// without shifting hue or blowing out skin tones — the area where HSL
/// "turns blue into purple" (the Oklab flex).
///
/// This is the Dart reference for the GLSL port in `shaders/grade.frag`.
List<double> saturateOklab(List<double> c, double amount) {
  if (amount == 0.0) return List<double>.from(c);

  // sRGB-encoded -> linear -> LMS cone responses.
  final lin = [srgbToLinear(c[0]), srgbToLinear(c[1]), srgbToLinear(c[2])];
  final lms = mul(oklabLms, lin);
  final l_ = cbrt(lms[0]);
  final m_ = cbrt(lms[1]);
  final s_ = cbrt(lms[2]);

  // LMS -> L, a, b (opponent space).
  final lab = mul(oklabOpponent, [l_, m_, s_]);

  // Scale chroma (a, b) uniformly.
  final f = 1.0 + amount;
  final labScaled = [lab[0], lab[1] * f, lab[2] * f];

  // L, a, b -> LMS' -> linear RGB -> sRGB-encoded.
  final lmsPrime = mul(oklabOpponentInv, labScaled);
  final (l3, m3, s3) = (lmsPrime[0] * lmsPrime[0] * lmsPrime[0],
      lmsPrime[1] * lmsPrime[1] * lmsPrime[1],
      lmsPrime[2] * lmsPrime[2] * lmsPrime[2]);
  final rgbLin = mul(oklabLmsInv, [l3, m3, s3]);

  return [
    linearToSrgb(rgbLin[0]).clamp(0.0, 1.0),
    linearToSrgb(rgbLin[1]).clamp(0.0, 1.0),
    linearToSrgb(rgbLin[2]).clamp(0.0, 1.0),
  ];
}

/// Hue angle in Oklab a-b plane (radians).
double oklabHue(List<double> c) {
  final lin = [srgbToLinear(c[0]), srgbToLinear(c[1]), srgbToLinear(c[2])];
  final lms = mul(oklabLms, lin);
  final lab = mul(oklabOpponent, [cbrt(lms[0]), cbrt(lms[1]), cbrt(lms[2])]);
  return math.atan2(lab[2], lab[1]);
}

/// Chroma in Oklab a-b plane.
double oklabChroma(List<double> c) {
  final lin = [srgbToLinear(c[0]), srgbToLinear(c[1]), srgbToLinear(c[2])];
  final lms = mul(oklabLms, lin);
  final lab = mul(oklabOpponent, [cbrt(lms[0]), cbrt(lms[1]), cbrt(lms[2])]);
  return math.sqrt(lab[1] * lab[1] + lab[2] * lab[2]);
}
