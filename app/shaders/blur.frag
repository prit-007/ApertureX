#version 460 core
// ApertureX Lens Blur GPU Gather Shader (Phase 5 Spike).
//
// Gathers depth-weighted bokeh samples on the GPU for instant 60/120 FPS
// viewport interactive preview. Uses continuous optical diopter mapping,
// linear-light accumulation, and occlusion guards.
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;          // Viewport canvas dimensions (px)
uniform float uFocalPoint;   // Focal plane depth [0.0, 1.0]
uniform float uFocalRange;   // In-focus depth-of-field range [0.01, 1.0]
uniform float uBlurAmount;   // Normalized blur intensity [0.0, 1.0]
uniform float uBokehShape;   // Shape index (0=circle, 1=5-blade, 2=6-blade, etc.)
uniform float uBokehBoost;   // Specular highlight boost [0.0, 1.0]
uniform sampler2D uTexture;  // Source photo RGBA
uniform sampler2D uDepthMap; // Monocular / metric depth map

out vec4 fragColor;

const float PI = 3.14159265359;
const float TAU = 6.28318530718;
const float GOLDEN_ANGLE = 2.399963229728653; // TAU * (1.0 - 1.0 / 1.61803398875)

// Converts an sRGB component to linear light
float srgbToLinear(float c) {
  return (c <= 0.04045) ? (c / 12.92) : pow((c + 0.055) / 1.055, 2.4);
}

vec3 srgbToLinearVec(vec3 c) {
  return vec3(srgbToLinear(c.r), srgbToLinear(c.g), srgbToLinear(c.b));
}

// Converts a linear light component back to sRGB
float linearToSrgb(float c) {
  c = clamp(c, 0.0, 1.0);
  return (c <= 0.0031308) ? (c * 12.92) : (1.055 * pow(c, 1.0 / 2.4) - 0.055);
}

vec3 linearToSrgbVec(vec3 c) {
  return vec3(linearToSrgb(c.r), linearToSrgb(c.g), linearToSrgb(c.b));
}

// Evaluates thin-lens Circle of Confusion (CoC) in optical diopter space
float computeCoc(float depth, float focalPoint, float focalRange, float amount) {
  float halfRange = max(focalRange * 0.5, 0.005);
  float nearEdge = max(focalPoint - halfRange, 0.0);
  float farEdge = min(focalPoint + halfRange, 1.0);

  if (depth >= nearEdge && depth <= farEdge) {
    return 0.0;
  }

  float diff = (depth < nearEdge) ? ((nearEdge - depth) / max(nearEdge, 0.005))
                                  : ((depth - farEdge) / max(1.0 - farEdge, 0.005));

  // Cubic Hermite smoothstep falloff for continuous optical transition
  float t = clamp(diff, 0.0, 1.0);
  float smoothT = t * t * (3.0 - 2.0 * t);
  return smoothT * amount;
}

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  vec4 centerColor = texture(uTexture, uv);
  float centerDepth = texture(uDepthMap, uv).r;

  float coc = computeCoc(centerDepth, uFocalPoint, uFocalRange, uBlurAmount);
  if (coc <= 0.001 || uBlurAmount <= 0.001) {
    fragColor = centerColor;
    return;
  }

  // Maximum radius in pixels (scaled with diagonal)
  float diag = length(uSize);
  float maxRadius = max(pow(uBlurAmount, 2.0) * diag * 0.045, 1.0);
  float kernelRadius = coc * maxRadius;

  // 16-sample golden-angle Fermat spiral on GPU
  const int NUM_SAMPLES = 16;
  vec3 accumColor = vec3(0.0);
  float totalWeight = 0.0;

  for (int i = 0; i < NUM_SAMPLES; i++) {
    float fi = float(i);
    float theta = fi * GOLDEN_ANGLE;
    float r = sqrt((fi + 0.5) / float(NUM_SAMPLES));
    vec2 offset = vec2(cos(theta), sin(theta)) * (r * kernelRadius) / uSize;
    vec2 sampleUv = clamp(uv + offset, vec2(0.0), vec2(1.0));

    vec4 sColor = texture(uTexture, sampleUv);
    float sDepth = texture(uDepthMap, sampleUv).r;

    // Asymmetric occlusion weight: background samples behind center are culled
    float depthDelta = sDepth - centerDepth;
    float occlusionWeight = (depthDelta > 0.08) ? 0.0 : 1.0;

    // Foreground bleed: out-of-focus foreground naturally bleeds over in-focus pixels
    if (depthDelta < -0.08) {
      float sCoc = computeCoc(sDepth, uFocalPoint, uFocalRange, uBlurAmount);
      occlusionWeight = clamp(sCoc / max(coc, 0.01), 0.0, 1.0);
    }

    if (occlusionWeight <= 0.0) continue;

    vec3 sLinear = srgbToLinearVec(sColor.rgb);

    // Specular highlight boost
    float luma = dot(sLinear, vec3(0.2126, 0.7152, 0.0722));
    if (uBokehBoost > 0.0 && luma > 0.60) {
      float boost = 1.0 + uBokehBoost * 2.0 * ((luma - 0.60) / 0.40);
      sLinear *= boost;
    }

    accumColor += sLinear * occlusionWeight;
    totalWeight += occlusionWeight;
  }

  if (totalWeight > 0.0) {
    vec3 resultLinear = accumColor / totalWeight;
    fragColor = vec4(linearToSrgbVec(resultLinear), centerColor.a);
  } else {
    fragColor = centerColor;
  }
}
