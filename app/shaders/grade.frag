#version 460 core
// ApertureX grading shader (full parametric pipeline).
//
// Grading chain: exposure (EV) -> temperature/tint -> contrast -> saturation
// -> vibrance -> highlights/shadows.
//
// Float uniform slots: uSize(0,1), uExposure(2), uContrast(3), uSaturation(4),
// uTemperature(5), uTint(6), uVibrance(7), uHighlights(8), uShadows(9).
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

out vec4 fragColor;

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;

#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif

  vec4 src = texture(uTexture, uv);
  vec3 col = src.rgb;

  // Exposure (EV): col *= 2^EV
  col *= pow(2.0, uExposure);

  // Temperature: blue <-> yellow (-1 .. 1)
  // Tint:      green <-> magenta (-1 .. 1)
  col *= vec3(1.0 + uTint * 0.1, 1.0, 1.0 - uTint * 0.1);
  col *= vec3(1.0 - uTemperature * 0.1, 1.0, 1.0 + uTemperature * 0.1);

  // Contrast around mid-grey (0.5)
  col = (col - 0.5) * (1.0 + uContrast) + 0.5;

  // Saturation (linear, 0 = grayscale)
  float luma = dot(col, vec3(0.2126, 0.7152, 0.0722));
  col = mix(vec3(luma), col, 1.0 + uSaturation);

  // Vibrance: adaptive saturation, stronger on muted pixels
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
