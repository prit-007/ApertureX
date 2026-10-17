#version 460 core
// LUT-sampling grading shader (P2 Slice D spike).
//
// The full colour pipeline (linear exposure, S-curve contrast, saturation, …)
// is baked on the CPU into a 3D LUT and packed as a 2D atlas:
//   width = N*N, height = N; blue slice b at columns [b*N, b*N+N);
//   within a slice x = red index, y = green index.
// This shader samples that atlas with manual trilinear interpolation, so the
// whole grade costs one texture path per pixel and stays 60fps at any size.
//
// Samples are taken at texel centres (+0.5), so the GPU sampler's filter mode
// is irrelevant: bilinear filtering at a texel centre returns that texel
// exactly, keeping the manual interpolation authoritative.
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;          // drawn rect size (px)   — floats 0,1
uniform float uLutSize;      // N                       — float 2
uniform float uMaskBlend;    // 0 = graded, 1 = mask view (auto-peek, #27)
uniform float uSrcW;         // source image width (px)  — float 4
uniform float uSrcH;         // source image height (px) — float 5
uniform float uZoneLo;       // min luminance for zone mask (negative if inactive) — float 6
uniform float uZoneHi;       // max luminance for zone mask (negative if inactive) — float 7
uniform sampler2D uTexture;  // source image            — sampler 0
uniform sampler2D uLut;      // LUT atlas               — sampler 1

out vec4 fragColor;

vec3 lutSlice(vec2 s, float bi, float n) {
  float x0 = floor(s.x);
  float x1 = min(x0 + 1.0, n - 1.0);
  float y0 = floor(s.y);
  float y1 = min(y0 + 1.0, n - 1.0);
  float fx = s.x - x0;
  float fy = s.y - y0;

  vec2 inv = vec2(1.0 / (n * n), 1.0 / n);
  vec2 base = vec2(bi * n, 0.0);

  vec3 c00 = texture(uLut, (base + vec2(x0, y0) + 0.5) * inv).rgb;
  vec3 c10 = texture(uLut, (base + vec2(x1, y0) + 0.5) * inv).rgb;
  vec3 c01 = texture(uLut, (base + vec2(x0, y1) + 0.5) * inv).rgb;
  vec3 c11 = texture(uLut, (base + vec2(x1, y1) + 0.5) * inv).rgb;

  return mix(mix(c00, c10, fx), mix(c01, c11, fx), fy);
}

vec3 lutLookup(vec3 c) {
  float n = uLutSize;
  vec2 s = c.rg * (n - 1.0);
  float bf = c.b * (n - 1.0);
  float b0 = floor(bf);
  float b1 = min(b0 + 1.0, n - 1.0);
  return mix(lutSlice(s, b0, n), lutSlice(s, b1, n), bf - b0);
}

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif

  vec4 src = texture(uTexture, uv);
  vec3 graded = lutLookup(clamp(src.rgb, 0.0, 1.0));
  vec3 color = graded;

  // Auto-peeking mask view (#27) & Haptic Zone Masking:
  // A high-contrast B/W base with red rubylith glow over targeted zone or detail edges.
  if (uMaskBlend > 0.001) {
    float l0 = dot(src.rgb, vec3(0.299, 0.587, 0.114));
    vec3 mask = mix(vec3(0.08), vec3(0.92), l0);

    float redHighlight = 0.0;
    if (uZoneHi >= 0.0 && uZoneLo >= 0.0) {
      // Zone masking targeting: isolate pixels between uZoneLo and uZoneHi with smooth feather
      float fLo = 0.08;
      float fHi = 0.08;
      redHighlight = smoothstep(uZoneLo - fLo, uZoneLo, l0) * (1.0 - smoothstep(uZoneHi, uZoneHi + fHi, l0));
    } else {
      // Fallback detail edge peek (#27)
      vec2 texel = vec2(1.0 / max(uSrcW, 1.0), 1.0 / max(uSrcH, 1.0));
      float lx = dot(texture(uTexture, uv + vec2(texel.x, 0.0)).rgb, vec3(0.299, 0.587, 0.114));
      float ly = dot(texture(uTexture, uv + vec2(0.0, texel.y)).rgb, vec3(0.299, 0.587, 0.114));
      redHighlight = smoothstep(0.015, 0.22, length(vec2(lx - l0, ly - l0)) * 3.0);
    }

    mask = mix(mask, vec3(1.0, 0.12, 0.12), clamp(redHighlight * 0.85, 0.0, 1.0));
    color = mix(graded, mask, uMaskBlend);
  }

  fragColor = vec4(clamp(color, 0.0, 1.0), src.a);
}
