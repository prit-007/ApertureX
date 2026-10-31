// Nature and scenario-optimized grading presets with subject-aware depth.
//
// These presets ship as [ToolDefinition] entries so they can be applied from
// the Looks Sheet like any built-in look. Each preset carries tailored depth /
// lens-blur parameters (`blurEnabled`, `blurAmount`, `blurFocalPoint`,
// `blurFocalRange`, `blurBokehShape`, `blurBokehBoost`, `blurBackgroundBlur`)
// routing through the Depth Anything V2 monocular depth model (bundled ONNX)
// via `estimateDepthMapWithModel` and `applyLensBlur`.
import '../../edit/tool_definition.dart';

/// A scenario-optimized nature/portrait look with optional depth directives.
class NatureLook {
  const NatureLook({
    required this.name,
    required this.description,
    required this.scenario,
    required this.params,
    this.hsl,
    this.depthHint,
    this.focalPoint = 0.5,
    this.focalRange = 0.25,
    this.bokehShape = 0,
    this.blurAmount = 0.0,
  });

  final String name;
  final String description;
  final String scenario;
  final Map<String, double> params;
  final List<double>? hsl; // 8-band HSL: [r_h, r_s, r_l, ...]
  final String? depthHint; // e.g. 'subject', 'eyes', 'foreground'
  final double focalPoint;
  final double focalRange;
  final int bokehShape; // 0: circle, 1: pentagon, 2: hexagon, 3: septagon, 4: catsEye, 5: soapBubble, 6: swirl
  final double blurAmount;

  ToolDefinition toToolDefinition() {
    return ToolDefinition(
      name: name,
      description: '$description  •  $scenario',
      params: {
        ...params,
        if (blurAmount > 0) 'blurEnabled': 1.0,
        if (blurAmount > 0) 'blurAmount': blurAmount,
        if (blurAmount > 0) 'blurFocalPoint': focalPoint,
        if (blurAmount > 0) 'blurFocalRange': focalRange,
        if (blurAmount > 0) 'blurBokehShape': bokehShape.toDouble(),
        if (blurAmount > 0) 'blurBokehBoost': 0.25,
        if (blurAmount > 0) 'blurBackgroundBlur': 0.0,
      },
      hsl: hsl,
    );
  }
}

/// Scenario-tuned nature and environmental grading presets.
const List<NatureLook> natureLooks = [
  // ──────────────────────────────────────────────────────────────
  // 1. Greenery Forest — deep moss shadows, rich emerald canopy, subdued yellow-greens
  NatureLook(
    name: 'Greenery Forest',
    description:
        'Lush woodlands: rich emerald foliage, dampened neon yellows, deep earthy bark shadows',
    scenario: 'Forest & Woodlands',
    depthHint: 'path / wildlife',
    focalPoint: 0.45,
    focalRange: 0.25,
    bokehShape: 0, // circle
    blurAmount: 0.22,
    params: {
      'exposure': -0.02,
      'contrast': 0.14,
      'highlights': -0.22,
      'shadows': 0.16,
      'whites': 0.06,
      'blacks': -0.10,
      'clarity': 0.18,
      'texture': 0.22,
      'dehaze': 0.08,
      'temperature': 0.04,
      'tint': -0.10,
      'vibrance': 0.32,
      'saturation': 0.12,
      'gradeShadowHue': 0.35,
      'gradeShadowSat': 0.26,
      'gradeShadowLum': -0.06,
      'gradeHighlightHue': 0.18,
      'gradeHighlightSat': 0.20,
      'gradeHighlightLum': 0.04,
      'gradeMidHue': 0.32,
      'gradeMidSat': 0.22,
      'gradeMidLum': 0.0,
      'gradeBlending': 0.60,
      'gradeBalance': -0.04,
      'filmBloom': 0.10,
    },
    hsl: [
      0.02, 0.18, 0.04,  // Red: red berries / autumn leaves
      0.00, 0.22, 0.06,  // Orange: tree bark & soil
      -0.08, -0.15, 0.02,// Yellow: subdued sickly neon foliage
      0.04, 0.45, 0.08,  // Green: deep organic pine & fern emerald
      0.02, 0.25, 0.02,  // Aqua: forest stream water
      -0.04, 0.15, -0.04,// Blue: sky glimpses through canopy
      0.00, -0.10, 0.00, // Purple: wild flowers
      0.00, -0.10, 0.00, // Magenta: neutral
    ],
  ),

  // ──────────────────────────────────────────────────────────────
  // 2. Beach & Ocean — vibrant tropical cyan, warm sunlit sands, polarized sky
  NatureLook(
    name: 'Beach & Ocean',
    description:
        'Tropical coast: vibrant turquoise waters, sun-drenched golden sand, deep polarized skies',
    scenario: 'Coastal & Marine',
    depthHint: 'shoreline / swimmer',
    focalPoint: 0.48,
    focalRange: 0.35,
    bokehShape: 0, // circle
    blurAmount: 0.15,
    params: {
      'exposure': 0.08,
      'contrast': 0.18,
      'highlights': -0.16,
      'shadows': 0.14,
      'whites': 0.12,
      'blacks': -0.08,
      'clarity': 0.20,
      'texture': 0.16,
      'dehaze': 0.16,
      'temperature': 0.06,
      'tint': -0.02,
      'vibrance': 0.42,
      'saturation': 0.20,
      'gradeShadowHue': 0.58,
      'gradeShadowSat': 0.28,
      'gradeShadowLum': -0.04,
      'gradeHighlightHue': 0.12,
      'gradeHighlightSat': 0.28,
      'gradeHighlightLum': 0.06,
      'gradeMidHue': 0.52,
      'gradeMidSat': 0.24,
      'gradeMidLum': 0.02,
      'gradeBlending': 0.55,
      'gradeBalance': 0.06,
      'filmBloom': 0.12,
    },
    hsl: [
      0.04, 0.25, 0.06,  // Red: swimsuit & umbrella accents
      0.02, 0.35, 0.14,  // Orange: golden sun-tanned skin
      0.02, 0.38, 0.16,  // Yellow: warm glistening sand
      0.06, 0.20, 0.04,  // Green: coastal palm trees
      0.02, 0.58, 0.10,  // Aqua: vibrant Caribbean turquoise
      -0.02, 0.45, 0.04, // Blue: deep clear ocean horizon
      0.00, -0.15, 0.00, // Purple: neutral
      0.04, 0.20, 0.05,  // Magenta: sunset tint
    ],
  ),

  // ──────────────────────────────────────────────────────────────
  // 3. Alpine Mountains — atmospheric haze reduction, granite clarity, cold peaks
  NatureLook(
    name: 'Alpine Mountains',
    description:
        'Glacial peaks: atmospheric haze cut, sculpted granite ridges, crisp high-altitude azure',
    scenario: 'Mountains & Ridges',
    depthHint: 'mountain ridge',
    focalPoint: 0.60,
    focalRange: 0.40,
    bokehShape: 2, // hexagon
    blurAmount: 0.10,
    params: {
      'exposure': 0.04,
      'contrast': 0.22,
      'highlights': -0.18,
      'shadows': 0.10,
      'whites': 0.15,
      'blacks': -0.12,
      'clarity': 0.32,
      'texture': 0.28,
      'dehaze': 0.26,
      'temperature': -0.12,
      'tint': 0.02,
      'vibrance': 0.26,
      'saturation': 0.08,
      'gradeShadowHue': 0.62,
      'gradeShadowSat': 0.30,
      'gradeShadowLum': -0.06,
      'gradeHighlightHue': 0.10,
      'gradeHighlightSat': 0.14,
      'gradeHighlightLum': 0.06,
      'gradeMidHue': 0.58,
      'gradeMidSat': 0.18,
      'gradeMidLum': 0.0,
      'gradeBlending': 0.50,
      'gradeBalance': 0.12,
      'grain': 0.10,
      'grainSize': 0.12,
    },
    hsl: [
      -0.02, 0.10, 0.02, // Red: alpine cabin accents
      0.00, 0.15, 0.04,  // Orange: warm morning alpenglow
      -0.04, 0.18, 0.08, // Yellow: sunlit rock faces
      -0.02, 0.20, -0.04,// Green: high alpine pastures
      0.00, 0.28, -0.02, // Aqua: glacial meltwater tarns
      0.00, 0.36, -0.04, // Blue: crisp ultraviolet sky
      -0.04, -0.10, 0.00,// Purple: shadow haze
      0.00, -0.10, 0.00, // Magenta: neutral
    ],
  ),

  // ──────────────────────────────────────────────────────────────
  // 4. Golden Outdoors — sunset rim light, warm side-illumination, soft contrast
  NatureLook(
    name: 'Golden Outdoors',
    description:
        'Magic hour: glowing amber rim illumination, warm side-lighting, organic soft contrast',
    scenario: 'Golden Hour & Sunset',
    depthHint: 'subject',
    focalPoint: 0.42,
    focalRange: 0.24,
    bokehShape: 0, // circle
    blurAmount: 0.28,
    params: {
      'exposure': 0.06,
      'contrast': 0.08,
      'highlights': -0.12,
      'shadows': 0.18,
      'whites': 0.08,
      'blacks': -0.04,
      'clarity': 0.06,
      'texture': 0.12,
      'temperature': 0.22,
      'tint': 0.06,
      'vibrance': 0.38,
      'saturation': 0.18,
      'gradeShadowHue': 0.12,
      'gradeShadowSat': 0.26,
      'gradeShadowLum': 0.02,
      'gradeHighlightHue': 0.10,
      'gradeHighlightSat': 0.42,
      'gradeHighlightLum': 0.08,
      'gradeMidHue': 0.11,
      'gradeMidSat': 0.30,
      'gradeMidLum': 0.04,
      'gradeBlending': 0.65,
      'gradeBalance': -0.12,
      'filmBloom': 0.20,
      'filmHalation': 0.16,
    },
    hsl: [
      0.04, 0.35, 0.08,  // Red: warm rim backlight
      0.05, 0.44, 0.14,  // Orange: radiant golden rays
      0.02, 0.40, 0.18,  // Yellow: backlit meadow grass
      0.06, 0.22, 0.02,  // Green: sunlit foliage
      -0.04, -0.20, 0.00,// Aqua: subdued
      -0.08, -0.30, -0.05,// Blue: sunset sky gradient
      0.04, 0.18, 0.04,  // Purple: twilight horizon
      0.08, 0.25, 0.08,  // Magenta: sunset cloud glow
    ],
  ),

  // ──────────────────────────────────────────────────────────────
  // 5. Natural Portrait — flattering creamy skin, gentle highlight rolloff, f/1.8 bokeh
  NatureLook(
    name: 'Natural Portrait',
    description:
        'Flattering portraiture: creamy skin tone rolloff, gentle micro-contrast, f/1.8 subject bokeh',
    scenario: 'Portraits & People',
    depthHint: 'eyes',
    focalPoint: 0.38,
    focalRange: 0.14,
    bokehShape: 0, // circle
    blurAmount: 0.45,
    params: {
      'exposure': 0.08,
      'contrast': -0.05,
      'highlights': -0.15,
      'shadows': 0.14,
      'whites': 0.04,
      'blacks': 0.02,
      'clarity': -0.08,
      'texture': 0.04,
      'temperature': 0.06,
      'tint': 0.04,
      'vibrance': 0.20,
      'saturation': 0.06,
      'gradeShadowHue': 0.60,
      'gradeShadowSat': 0.18,
      'gradeShadowLum': 0.02,
      'gradeHighlightHue': 0.10,
      'gradeHighlightSat': 0.20,
      'gradeHighlightLum': 0.04,
      'gradeMidHue': 0.08,
      'gradeMidSat': 0.16,
      'gradeMidLum': 0.02,
      'gradeBlending': 0.60,
      'gradeBalance': -0.04,
      'filmBloom': 0.12,
    },
    hsl: [
      0.02, 0.18, 0.04,  // Red: healthy natural lip tone
      0.01, 0.16, 0.08,  // Orange: even, flattering skin anchor
      -0.02, 0.10, 0.05, // Yellow: warm hair highlight
      0.00, -0.10, 0.00, // Green: soft background
      0.00, -0.10, 0.00, // Aqua: neutral background
      -0.02, 0.12, 0.00, // Blue: denim & eye iris pop
      0.00, 0.10, 0.02,  // Purple: gentle shadows
      0.04, 0.16, 0.04,  // Magenta: natural blush
    ],
  ),

  // ──────────────────────────────────────────────────────────────
  // 6. Dramatic Backlight — silhouette recovery, warm halo bloom, shadow compression
  NatureLook(
    name: 'Dramatic Backlight',
    description:
        'High dynamic backlight: rescued shadow detail, glowing halo halation, controlled solar flare',
    scenario: 'Backlight & Silhouettes',
    depthHint: 'silhouette rim',
    focalPoint: 0.40,
    focalRange: 0.20,
    bokehShape: 5, // soap bubble specular
    blurAmount: 0.35,
    params: {
      'exposure': 0.12,
      'contrast': 0.16,
      'highlights': -0.35,
      'shadows': 0.38,
      'whites': 0.10,
      'blacks': -0.08,
      'clarity': 0.12,
      'texture': 0.16,
      'dehaze': -0.06,
      'temperature': 0.16,
      'tint': 0.04,
      'vibrance': 0.32,
      'saturation': 0.14,
      'gradeShadowHue': 0.10,
      'gradeShadowSat': 0.22,
      'gradeShadowLum': 0.08,
      'gradeHighlightHue': 0.12,
      'gradeHighlightSat': 0.38,
      'gradeHighlightLum': 0.10,
      'gradeMidHue': 0.11,
      'gradeMidSat': 0.26,
      'gradeMidLum': 0.04,
      'gradeBlending': 0.65,
      'gradeBalance': -0.10,
      'filmBloom': 0.30,
      'filmHalation': 0.25,
    },
    hsl: [
      0.04, 0.32, 0.08,  // Red: rim glow around hair
      0.05, 0.40, 0.15,  // Orange: warm light wrap
      0.02, 0.36, 0.20,  // Yellow: intense solar corona
      0.00, 0.15, 0.02,  // Green: rim-lit foliage
      -0.04, -0.25, 0.00,// Aqua: muted
      -0.06, -0.35, -0.05,// Blue: washed sky gradient
      0.02, 0.14, 0.04,  // Purple: shadow rolloff
      0.06, 0.22, 0.08,  // Magenta: lens flare
    ],
  ),

  // ──────────────────────────────────────────────────────────────
  // 7. Moody Indoor — warm intimate tungsten ambient, shadow fade, gentle film grain
  NatureLook(
    name: 'Moody Indoor',
    description:
        'Intimate interior: warm 2800K tungsten ambient, lifted matte shadows, cozy film grain',
    scenario: 'Indoor & Low-Light',
    depthHint: 'center subject',
    focalPoint: 0.40,
    focalRange: 0.18,
    bokehShape: 0, // circle
    blurAmount: 0.30,
    params: {
      'exposure': 0.02,
      'contrast': 0.10,
      'highlights': -0.20,
      'shadows': 0.15,
      'whites': -0.02,
      'blacks': 0.08,
      'clarity': 0.06,
      'texture': 0.14,
      'temperature': 0.24,
      'tint': 0.08,
      'vibrance': 0.18,
      'saturation': 0.08,
      'gradeShadowHue': 0.08,
      'gradeShadowSat': 0.24,
      'gradeShadowLum': 0.04,
      'gradeHighlightHue': 0.11,
      'gradeHighlightSat': 0.32,
      'gradeHighlightLum': 0.04,
      'gradeMidHue': 0.10,
      'gradeMidSat': 0.22,
      'gradeMidLum': 0.02,
      'gradeBlending': 0.60,
      'gradeBalance': -0.15,
      'grain': 0.22,
      'grainSize': 0.22,
      'vignette': -0.25,
      'vignetteMidpoint': 0.45,
    },
    hsl: [
      0.02, 0.25, 0.04,  // Red: warm textiles & mahogany
      0.04, 0.34, 0.10,  // Orange: incandescent lamp glow
      0.02, 0.28, 0.12,  // Yellow: warm candlelight
      -0.04, -0.15, -0.02,// Green: house plants
      -0.08, -0.35, -0.08,// Aqua: suppressed
      -0.12, -0.50, -0.15,// Blue: cold window darkness
      0.00, -0.15, 0.00, // Purple: neutral
      0.04, 0.16, 0.02,  // Magenta: lampshade glow
    ],
  ),

  // ──────────────────────────────────────────────────────────────
  // 8. Action & Sports — high-shutter crisp clarity, boosted dynamic range, punchy primary colors
  NatureLook(
    name: 'Action & Sports',
    description:
        'Dynamic athletics: high-shutter micro-contrast, punchy jersey primaries, razor-sharp textures',
    scenario: 'Sports & Motion',
    depthHint: 'athlete in action',
    focalPoint: 0.45,
    focalRange: 0.20,
    bokehShape: 3, // septagon
    blurAmount: 0.35,
    params: {
      'exposure': 0.05,
      'contrast': 0.26,
      'highlights': -0.15,
      'shadows': 0.18,
      'whites': 0.14,
      'blacks': -0.12,
      'clarity': 0.34,
      'texture': 0.30,
      'dehaze': 0.18,
      'temperature': 0.0,
      'tint': 0.0,
      'vibrance': 0.40,
      'saturation': 0.18,
      'gradeShadowHue': 0.60,
      'gradeShadowSat': 0.22,
      'gradeShadowLum': -0.04,
      'gradeHighlightHue': 0.10,
      'gradeHighlightSat': 0.15,
      'gradeHighlightLum': 0.06,
      'gradeMidHue': 0.55,
      'gradeMidSat': 0.14,
      'gradeMidLum': 0.02,
      'gradeBlending': 0.50,
      'gradeBalance': 0.08,
      'sharpen': 0.25,
      'sharpenDetail': 0.20,
    },
    hsl: [
      0.00, 0.45, 0.08,  // Red: team jersey red
      0.02, 0.32, 0.06,  // Orange: basketball / athletic skin
      0.00, 0.38, 0.10,  // Yellow: turf markers & tennis ball
      0.04, 0.48, 0.08,  // Green: pristine stadium turf
      0.02, 0.38, 0.06,  // Aqua: swimming pool lane lines
      0.00, 0.42, 0.04,  // Blue: clear open sky / stadium blue
      0.04, 0.30, 0.04,  // Purple: sports graphics
      0.06, 0.35, 0.08,  // Magenta: athletic shoes
    ],
  ),
];

/// Helper returning [natureLooks] as a flat list of [ToolDefinition] instances.
List<ToolDefinition> natureLookTools() =>
    natureLooks.map((l) => l.toToolDefinition()).toList();
