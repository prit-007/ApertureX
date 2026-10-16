#version 460 core
// ApertureX grading shader (seed).
//
// Grading chain: exposure (EV) -> contrast (around mid-grey) -> saturation.
// Samples the bound image texture and is driven live by the gesture FSM.
//
// Flutter shader constraints honoured: no UBO/SSBO, sampler2D only, two-arg
// texture(), no uint/bool; UVs derive from FlutterFragCoord() with an explicit
// un-flip for the OpenGL ES backend (Impeller renders GLES y-down).
#include <flutter/runtime_effect.glsl>

// Float uniform slots: uSize(0,1), uExposure(2), uContrast(3), uSaturation(4).
// The sampler has its own index space (setImageSampler index 0).
uniform vec2 uSize;
uniform sampler2D uTexture;
uniform float uExposure;
uniform float uContrast;
uniform float uSaturation;

out vec4 fragColor;

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;

#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif

  vec4 src = texture(uTexture, uv);
  vec3 col = src.rgb;

  col *= pow(2.0, uExposure);                         // exposure
  col = (col - 0.5) * (1.0 + uContrast) + 0.5;        // contrast

  float luma = dot(col, vec3(0.2126, 0.7152, 0.0722)); // saturation
  col = mix(vec3(luma), col, 1.0 + uSaturation);

  fragColor = vec4(clamp(col, 0.0, 1.0), src.a);
}
