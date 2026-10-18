#version 460 core
// ApertureX grading shader (full parametric pipeline).
//
// Grading chain: linearize -> exposure (EV, linear) -> white balance
// (Bradford Von Kries, linear) -> encode sRGB -> contrast (smoothstep S-curve,
// perceptual) -> saturation (Oklab, hue-preserving) -> vibrance ->
// highlights/shadows.
//
// Float uniform slots: uSize(0,1), uExposure(2), uContrast(3), uSaturation(4),
// uTemperature(5), uTint(6), uVibrance(7), uHighlights(8), uShadows(9).
//
// Reference implementation: lib/edit/wb_contrast_shader_math.dart mirrors
// rust/src/color.rs::{white_balance, contrast_curve}; lib/edit/
// oklab_shader_math.dart mirrors rust/src/color.rs::saturate_oklab.
// This GLSL port must produce identical results so live scrub == baked
// LUT/export (preview == export parity).
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform sampler2D uTexture;
uniform float uExposure;
uniform float uContrast;
uniform float uSaturation;
uniform float uTemperature;
uniform float uTint;
uniform float uVibrance;
uniform float uHighlights;
uniform float uShadows;

// Sign-preserving cube root (matches Rust f32::cbrt, handles negatives).
vec3 cbrt3(vec3 v) {
  return sign(v) * pow(abs(v), vec3(1.0 / 3.0));
}

float srgbToLinear(float c) {
  return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4);
}

float linearToSrgb(float c) {
  return c <= 0.0031308 ? c * 12.92 : 1.055 * pow(c, 1.0 / 2.4) - 0.055;
}

// Bradford RGB->LMS cone-response matrix (rust/src/color.rs::BRADFORD).
const mat3 bradford = mat3(
  0.8951,   0.2664,  -0.1614,
  -0.7502,   1.7135,   0.0367,
  0.0389,  -0.0685,   1.0296
);

// Inverse of [`bradford`] (rust/src/color.rs::BRADFORD_INV).
const mat3 bradfordInv = mat3(
  0.9869929, -0.1470543,  0.1599627,
  0.4323053,  0.5183603,  0.0492912,
 -0.0085287,  0.0400428,  0.9684867
);

// Oklab matrices (Ottosson 2020).
const mat3 oklabLms = mat3(
  0.41222146,  0.53633255,  0.051445995,
  0.2119035,   0.6806995,   0.10739696,
  0.08830246,  0.28171885,  0.6299787
);

const mat3 oklabOpponent = mat3(
  0.21045426,   0.7936178,   -0.004072047,
  1.9779985,   -2.4285922,    0.4505937,
  0.025904037,  0.78277177,  -0.80867577
);

const mat3 oklabOpponentInv = mat3(
  1.0,          0.39633778,   0.21580376,
  1.0,         -0.105561346,  -0.06385417,
  1.0,         -0.08948418,   -1.2914855
);

const mat3 oklabLmsInv = mat3(
  4.0767417,   -3.3077116,    0.23096994,
  -1.268438,    2.6097574,   -0.34131938,
  -0.004196086, -0.7034186,    1.7076147
);

// Smooth contrast around mid-grey via a smoothstep S-curve (rust/src/
// color.rs::contrast_curve). 0 is identity; positive blends toward the S,
// negative toward its exact inverse.
float contrastCurve(float x, float contrast) {
  x = clamp(x, 0.0, 1.0);
  float s = x * x * (3.0 - 2.0 * x);
  if (contrast >= 0.0) {
    return x + (s - x) * contrast;
  } else {
    float inv = 0.5 - asin(clamp(1.0 - 2.0 * x, -1.0, 1.0)) / 3.0;
    return x + (inv - x) * (-contrast);
  }
}

out vec4 fragColor;

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;

#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif

  vec4 src = texture(uTexture, uv);
  vec3 col = src.rgb;

  // Linearize once (sRGB-encoded -> linear light).
  vec3 lin = vec3(
    srgbToLinear(col.r),
    srgbToLinear(col.g),
    srgbToLinear(col.b)
  );

  // Exposure (EV): linear, multiplicative — matches Rust grade_pixel_c.
  lin *= pow(2.0, uExposure);

  // White balance: Bradford Von Kries on linear light.
  // Temperature pushes warm (more L, less S); tint pushes magenta (less M).
  if (uTemperature != 0.0 || uTint != 0.0) {
    vec3 lms = bradford * lin;
    vec3 gain = vec3(
      max(1.0 + 0.20 * uTemperature, 0.0),
      max(1.0 - 0.20 * uTint, 0.0),
      max(1.0 - 0.30 * uTemperature, 0.0)
    );
    lms = lms * gain;
    lin = bradfordInv * lms;
  }

  // Encode back to sRGB for the perceptual stages.
  col = vec3(
    linearToSrgb(lin.r),
    linearToSrgb(lin.g),
    linearToSrgb(lin.b)
  );

  // Contrast: smoothstep S-curve around mid-grey — matches Rust.
  col = vec3(
    contrastCurve(col.r, uContrast),
    contrastCurve(col.g, uContrast),
    contrastCurve(col.b, uContrast)
  );

  // Saturation via Oklab: scale chroma (a,b) uniformly, preserving hue.
  // Skipped when neutral to avoid the per-pixel cost on every frame.
  if (uSaturation != 0.0) {
    vec3 linSat = vec3(
      srgbToLinear(col.r),
      srgbToLinear(col.g),
      srgbToLinear(col.b)
    );
    vec3 lms = oklabLms * linSat;
    vec3 lab = oklabOpponent * cbrt3(lms);
    lab = vec3(lab.r, lab.g * (1.0 + uSaturation), lab.b * (1.0 + uSaturation));
    vec3 lmsPrime = oklabOpponentInv * lab;
    vec3 linOut = oklabLmsInv * vec3(
      lmsPrime.r * lmsPrime.r * lmsPrime.r,
      lmsPrime.g * lmsPrime.g * lmsPrime.g,
      lmsPrime.b * lmsPrime.b * lmsPrime.b
    );
    col = vec3(
      linearToSrgb(linOut.r),
      linearToSrgb(linOut.g),
      linearToSrgb(linOut.b)
    );
  }

  // Vibrance: adaptive saturation, stronger on muted pixels
  float luma = dot(col, vec3(0.2126, 0.7152, 0.0722));
  col = mix(vec3(luma), col, 1.0 + uVibrance * (1.0 - luma));

  // Highlights: compress (+1) or expand (-1) bright tones
  float h = uHighlights;
  if (h > 0.0) {
    col = col * (1.0 - h * col);
  } else if (h < 0.0) {
    col = col * (1.0 - h * (1.0 - col));
  }

  // Shadows: lift (+1) or darken (-1) dark tones
  float s = uShadows;
  if (s > 0.0) {
    col = col + s * (1.0 - col) * (1.0 - col);
  } else if (s < 0.0) {
    col = col * (1.0 + s * col);
  }

  fragColor = vec4(clamp(col, 0.0, 1.0), src.a);
}
