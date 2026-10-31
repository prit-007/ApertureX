// Universal brilliance, Indian cultural/wedding, and travel tourist grading presets.
//
// These presets ship as [ToolDefinition] entries so they can be applied from
// the Looks Sheet like any built-in look. Each preset carries tailored depth /
// lens-blur parameters (`blurEnabled`, `blurAmount`, `blurFocalPoint`,
// `blurFocalRange`, `blurBokehShape`, `blurBokehBoost`, `blurBackgroundBlur`)
// routing through the Depth Anything V2 monocular depth model (bundled ONNX)
// via `estimateDepthMapWithModel` and `applyLensBlur`.
import '../../edit/tool_definition.dart';

/// A look tailored for universal enhancement, cultural festivities, or travel.
class CulturalTravelLook {
  const CulturalTravelLook({
    required this.name,
    required this.description,
    required this.theme,
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
  final String theme; // 'Universal', 'Indian Festive', 'Travel'
  final Map<String, double> params;
  final List<double>? hsl; // 8-band HSL: [r_h, r_s, r_l, ...]
  final String? depthHint;
  final double focalPoint;
  final double focalRange;
  final int bokehShape; // 0: circle, 1: pentagon, 2: hexagon, 3: septagon, 4: catsEye, 5: soapBubble, 6: swirl
  final double blurAmount;

  ToolDefinition toToolDefinition() {
    return ToolDefinition(
      name: name,
      description: '$description  •  $theme',
      params: {
        ...params,
        if (blurAmount > 0) 'blurEnabled': 1.0,
        if (blurAmount > 0) 'blurAmount': blurAmount,
        if (blurAmount > 0) 'blurFocalPoint': focalPoint,
        if (blurAmount > 0) 'blurFocalRange': focalRange,
        if (blurAmount > 0) 'blurBokehShape': bokehShape.toDouble(),
        if (blurAmount > 0) 'blurBokehBoost': 0.28,
        if (blurAmount > 0) 'blurBackgroundBlur': 0.0,
      },
      hsl: hsl,
    );
  }
}

/// Universal, Indian cultural, and global travel presets.
const List<CulturalTravelLook> culturalTravelLooks = [
  // ──────────────────────────────────────────────────────────────
  // 1. Golden Brilliance (Universal Master) — makes any photo look stunning
  CulturalTravelLook(
    name: 'Universal Brilliance',
    description:
        'All-rounder master grade: rescues muddy shadows, organic micro-contrast, vibrant natural tones',
    theme: 'Universal All-Rounder',
    depthHint: 'main subject',
    focalPoint: 0.45,
    focalRange: 0.25,
    bokehShape: 0, // circle
    blurAmount: 0.20,
    params: {
      'exposure': 0.06,
      'contrast': 0.14,
      'highlights': -0.16,
      'shadows': 0.18,
      'whites': 0.08,
      'blacks': -0.08,
      'clarity': 0.12,
      'texture': 0.14,
      'dehaze': 0.06,
      'temperature': 0.04,
      'tint': 0.02,
      'vibrance': 0.28,
      'saturation': 0.10,
      'gradeShadowHue': 0.60,
      'gradeShadowSat': 0.16,
      'gradeShadowLum': -0.02,
      'gradeHighlightHue': 0.10,
      'gradeHighlightSat': 0.20,
      'gradeHighlightLum': 0.04,
      'gradeMidHue': 0.08,
      'gradeMidSat': 0.14,
      'gradeMidLum': 0.02,
      'gradeBlending': 0.60,
      'gradeBalance': 0.0,
      'filmBloom': 0.08,
    },
    hsl: [
      0.02, 0.18, 0.04,  // Red: healthy vitality
      0.01, 0.22, 0.06,  // Orange: warm radiant skin
      -0.02, 0.15, 0.06, // Yellow: clean sunlight
      0.04, 0.25, 0.04,  // Green: fresh foliage
      0.00, 0.24, 0.02,  // Aqua: clear water
      -0.02, 0.26, 0.02, // Blue: balanced sky
      0.00, 0.12, 0.00,  // Purple: neutral
      0.02, 0.16, 0.04,  // Magenta: pleasant floral
    ],
  ),

  // ──────────────────────────────────────────────────────────────
  // 2. Clean Editorial Pop — high-key clarity, crisp neutral magazine finish
  CulturalTravelLook(
    name: 'Clean Editorial Pop',
    description:
        'Modern editorial: crisp neutral whites, sculpted shadows, high micro-detail for any scene',
    theme: 'Universal All-Rounder',
    depthHint: 'center subject',
    focalPoint: 0.42,
    focalRange: 0.22,
    bokehShape: 2, // hexagon
    blurAmount: 0.25,
    params: {
      'exposure': 0.04,
      'contrast': 0.20,
      'highlights': -0.12,
      'shadows': 0.10,
      'whites': 0.12,
      'blacks': -0.10,
      'clarity': 0.24,
      'texture': 0.22,
      'temperature': -0.02,
      'tint': 0.0,
      'vibrance': 0.20,
      'saturation': 0.06,
      'gradeShadowHue': 0.62,
      'gradeShadowSat': 0.15,
      'gradeShadowLum': -0.04,
      'gradeHighlightHue': 0.10,
      'gradeHighlightSat': 0.12,
      'gradeHighlightLum': 0.04,
      'gradeMidHue': 0.55,
      'gradeMidSat': 0.10,
      'gradeMidLum': 0.0,
      'gradeBlending': 0.50,
      'gradeBalance': 0.05,
      'sharpen': 0.20,
      'sharpenDetail': 0.18,
    },
    hsl: [
      0.00, 0.15, 0.02,  // Red
      0.00, 0.14, 0.04,  // Orange
      -0.02, 0.10, 0.04, // Yellow
      0.00, 0.18, 0.02,  // Green
      0.00, 0.20, 0.02,  // Aqua
      0.00, 0.22, -0.02, // Blue
      0.00, 0.10, 0.00,  // Purple
      0.00, 0.12, 0.02,  // Magenta
    ],
  ),

  // ──────────────────────────────────────────────────────────────
  // 3. Royal Indian Wedding — bridal vermilion, opulent jewelry gold, radiant skin
  CulturalTravelLook(
    name: 'Royal Indian Wedding',
    description:
        'Shaadi opulence: rich bridal vermilion, glistening jewelry gold, warm luminous skin glow',
    theme: 'Indian Cultural & Wedding',
    depthHint: 'bride & groom',
    focalPoint: 0.40,
    focalRange: 0.15,
    bokehShape: 5, // soap bubble specular for jewelry bokeh
    blurAmount: 0.42,
    params: {
      'exposure': 0.08,
      'contrast': 0.16,
      'highlights': -0.18,
      'shadows': 0.20,
      'whites': 0.10,
      'blacks': -0.10,
      'clarity': 0.14,
      'texture': 0.18,
      'temperature': 0.12,
      'tint': 0.08,
      'vibrance': 0.44,
      'saturation': 0.22,
      'gradeShadowHue': 0.05,
      'gradeShadowSat': 0.25,
      'gradeShadowLum': -0.02,
      'gradeHighlightHue': 0.11,
      'gradeHighlightSat': 0.42,
      'gradeHighlightLum': 0.08,
      'gradeMidHue': 0.09,
      'gradeMidSat': 0.28,
      'gradeMidLum': 0.04,
      'gradeBlending': 0.65,
      'gradeBalance': -0.08,
      'filmBloom': 0.25,
      'filmHalation': 0.22,
    },
    hsl: [
      0.02, 0.58, 0.10,  // Red: deep bridal lehenga vermilion & sindoor
      0.04, 0.42, 0.12,  // Orange: warm radiant South-Asian skin tone
      0.02, 0.48, 0.18,  // Yellow: 24k gold jewelry & marigold garlands
      0.06, 0.28, 0.04,  // Green: emerald jewelry & mehendi green
      0.00, 0.22, 0.02,  // Aqua: silk border accents
      -0.02, 0.32, -0.04,// Blue: sherwani royal navy
      0.06, 0.35, 0.08,  // Purple: Banarasi silk sarees
      0.08, 0.46, 0.14,  // Magenta: rani pink silk & rose petals
    ],
  ),

  // ──────────────────────────────────────────────────────────────
  // 4. Desi Festive (Diwali & Holi) — diya glow, gulal powder, rich celebratory energy
  CulturalTravelLook(
    name: 'Desi Festive: Diwali & Holi',
    description:
        'Utsav radiance: glowing clay diya amber, explosive gulal powder primaries, festive joy',
    theme: 'Indian Cultural & Wedding',
    depthHint: 'celebration subject',
    focalPoint: 0.44,
    focalRange: 0.22,
    bokehShape: 0, // circle
    blurAmount: 0.32,
    params: {
      'exposure': 0.06,
      'contrast': 0.22,
      'highlights': -0.15,
      'shadows': 0.16,
      'whites': 0.14,
      'blacks': -0.08,
      'clarity': 0.22,
      'texture': 0.24,
      'temperature': 0.14,
      'tint': 0.06,
      'vibrance': 0.52,
      'saturation': 0.28,
      'gradeShadowHue': 0.08,
      'gradeShadowSat': 0.28,
      'gradeShadowLum': 0.0,
      'gradeHighlightHue': 0.11,
      'gradeHighlightSat': 0.46,
      'gradeHighlightLum': 0.10,
      'gradeMidHue': 0.08,
      'gradeMidSat': 0.32,
      'gradeMidLum': 0.04,
      'gradeBlending': 0.60,
      'gradeBalance': -0.06,
      'filmBloom': 0.28,
      'filmHalation': 0.20,
    },
    hsl: [
      0.04, 0.55, 0.12,  // Red: gulal red powder
      0.05, 0.48, 0.15,  // Orange: glowing diya flame & saffron
      0.02, 0.52, 0.18,  // Yellow: turmeric & marigold flowers
      0.06, 0.42, 0.08,  // Green: festive foliage & gulal green
      0.02, 0.46, 0.08,  // Aqua: peacock feathers
      0.00, 0.44, 0.04,  // Blue: festive rangoli
      0.06, 0.42, 0.10,  // Purple: night festival sky
      0.10, 0.58, 0.18,  // Magenta: vibrant Holi magenta
    ],
  ),

  // ──────────────────────────────────────────────────────────────
  // 5. Royal Heritage (Rajasthan Forts) — sandstone amber, desert warmth, Jodhpur blue
  CulturalTravelLook(
    name: 'Royal Heritage: Rajasthan',
    description:
        'Heritage stone: golden Thar sandstone, ancient palace textures, Jodhpur blue accents',
    theme: 'Indian Cultural & Wedding',
    depthHint: 'monument / archway',
    focalPoint: 0.52,
    focalRange: 0.35,
    bokehShape: 3, // septagon
    blurAmount: 0.18,
    params: {
      'exposure': 0.04,
      'contrast': 0.18,
      'highlights': -0.20,
      'shadows': 0.14,
      'whites': 0.08,
      'blacks': -0.12,
      'clarity': 0.28,
      'texture': 0.30,
      'dehaze': 0.14,
      'temperature': 0.16,
      'tint': 0.02,
      'vibrance': 0.34,
      'saturation': 0.16,
      'gradeShadowHue': 0.10,
      'gradeShadowSat': 0.28,
      'gradeShadowLum': -0.06,
      'gradeHighlightHue': 0.12,
      'gradeHighlightSat': 0.36,
      'gradeHighlightLum': 0.06,
      'gradeMidHue': 0.11,
      'gradeMidSat': 0.26,
      'gradeMidLum': 0.02,
      'gradeBlending': 0.55,
      'gradeBalance': -0.10,
      'grain': 0.14,
      'grainSize': 0.16,
    },
    hsl: [
      0.02, 0.35, 0.06,  // Red: Rajasthani turban red
      0.04, 0.42, 0.14,  // Orange: golden Thar sandstone
      0.02, 0.38, 0.16,  // Yellow: sunlit palace courtyards
      -0.04, -0.20, -0.04,// Green: dry desert scrub
      0.02, 0.48, 0.06,  // Aqua: fresco murals
      0.00, 0.52, 0.04,  // Blue: iconic Jodhpur blue city walls
      0.02, 0.20, 0.02,  // Purple: evening desert shadows
      0.05, 0.28, 0.06,  // Magenta: block-print textiles
    ],
  ),

  // ──────────────────────────────────────────────────────────────
  // 6. Tourist Travel Postcard — turns any holiday photo into a vivid postcard
  CulturalTravelLook(
    name: 'Tourist Travel Postcard',
    description:
        'Vacation postcard: rich azure sky, vibrant greenery, warm natural sunlight, crisp clarity',
    theme: 'Travel & Tourism',
    depthHint: 'tourist / landscape',
    focalPoint: 0.48,
    focalRange: 0.32,
    bokehShape: 0, // circle
    blurAmount: 0.18,
    params: {
      'exposure': 0.08,
      'contrast': 0.16,
      'highlights': -0.22,
      'shadows': 0.18,
      'whites': 0.12,
      'blacks': -0.08,
      'clarity': 0.22,
      'texture': 0.20,
      'dehaze': 0.16,
      'temperature': 0.06,
      'tint': -0.02,
      'vibrance': 0.40,
      'saturation': 0.18,
      'gradeShadowHue': 0.58,
      'gradeShadowSat': 0.22,
      'gradeShadowLum': -0.02,
      'gradeHighlightHue': 0.11,
      'gradeHighlightSat': 0.28,
      'gradeHighlightLum': 0.06,
      'gradeMidHue': 0.50,
      'gradeMidSat': 0.18,
      'gradeMidLum': 0.02,
      'gradeBlending': 0.55,
      'gradeBalance': 0.04,
      'filmBloom': 0.10,
    },
    hsl: [
      0.02, 0.28, 0.06,  // Red: landmark accents
      0.02, 0.30, 0.10,  // Orange: tourist skin in natural daylight
      -0.02, 0.32, 0.14, // Yellow: bright sunny weather
      0.04, 0.42, 0.06,  // Green: lush holiday gardens & parks
      0.02, 0.45, 0.08,  // Aqua: pool & sea waters
      0.00, 0.50, 0.06,  // Blue: deep polarized travel postcard sky
      0.00, 0.15, 0.02,  // Purple: mountain shadows
      0.04, 0.22, 0.06,  // Magenta: souvenir flowers
    ],
  ),

  // ──────────────────────────────────────────────────────────────
  // 7. Wanderlust Golden Hour — romantic travel memories, warm sunset glow
  CulturalTravelLook(
    name: 'Wanderlust Sunset',
    description:
        'Golden wanderlust: honey sunset side-light, dreamy highlight diffusion, nostalgic warmth',
    theme: 'Travel & Tourism',
    depthHint: 'traveler silhouette',
    focalPoint: 0.42,
    focalRange: 0.20,
    bokehShape: 0, // circle
    blurAmount: 0.32,
    params: {
      'exposure': 0.06,
      'contrast': 0.10,
      'highlights': -0.16,
      'shadows': 0.20,
      'whites': 0.08,
      'blacks': -0.04,
      'clarity': 0.08,
      'texture': 0.12,
      'temperature': 0.20,
      'tint': 0.08,
      'vibrance': 0.36,
      'saturation': 0.16,
      'gradeShadowHue': 0.10,
      'gradeShadowSat': 0.24,
      'gradeShadowLum': 0.02,
      'gradeHighlightHue': 0.10,
      'gradeHighlightSat': 0.40,
      'gradeHighlightLum': 0.08,
      'gradeMidHue': 0.11,
      'gradeMidSat': 0.28,
      'gradeMidLum': 0.04,
      'gradeBlending': 0.65,
      'gradeBalance': -0.10,
      'filmBloom': 0.22,
      'filmHalation': 0.18,
    },
    hsl: [
      0.04, 0.36, 0.08,  // Red: setting sun halo
      0.05, 0.45, 0.14,  // Orange: golden hour glow on traveler
      0.02, 0.40, 0.16,  // Yellow: horizon shimmer
      0.04, 0.20, 0.02,  // Green: warm landscape
      -0.02, -0.15, 0.00,// Aqua: soft coastal haze
      -0.06, -0.22, -0.04,// Blue: gradient twilight sky
      0.04, 0.22, 0.04,  // Purple: dusk horizon
      0.08, 0.28, 0.08,  // Magenta: sunset cloud rim
    ],
  ),

  // ──────────────────────────────────────────────────────────────
  // 8. Street Market & Spice Bazaar — vibrant spices, textile colors, daylight warmth
  CulturalTravelLook(
    name: 'Bazaar & Spice Market',
    description:
        'Bustling marketplace: saturated turmeric & paprika spices, vibrant textiles, ambient warmth',
    theme: 'Travel & Tourism',
    depthHint: 'merchant / stall',
    focalPoint: 0.40,
    focalRange: 0.20,
    bokehShape: 1, // pentagon
    blurAmount: 0.28,
    params: {
      'exposure': 0.04,
      'contrast': 0.20,
      'highlights': -0.14,
      'shadows': 0.15,
      'whites': 0.10,
      'blacks': -0.10,
      'clarity': 0.26,
      'texture': 0.28,
      'dehaze': 0.10,
      'temperature': 0.10,
      'tint': 0.04,
      'vibrance': 0.42,
      'saturation': 0.22,
      'gradeShadowHue': 0.08,
      'gradeShadowSat': 0.26,
      'gradeShadowLum': -0.04,
      'gradeHighlightHue': 0.11,
      'gradeHighlightSat': 0.32,
      'gradeHighlightLum': 0.06,
      'gradeMidHue': 0.09,
      'gradeMidSat': 0.24,
      'gradeMidLum': 0.02,
      'gradeBlending': 0.55,
      'gradeBalance': -0.06,
      'grain': 0.12,
      'grainSize': 0.14,
    },
    hsl: [
      0.02, 0.52, 0.10,  // Red: chili pepper & crimson textiles
      0.04, 0.50, 0.14,  // Orange: saffron & terracotta pots
      0.02, 0.46, 0.16,  // Yellow: turmeric piles & brass lanterns
      0.06, 0.35, 0.04,  // Green: fresh mint & cilantro herbs
      0.02, 0.32, 0.04,  // Aqua: ceramic glazed tiles
      -0.02, 0.30, -0.02,// Blue: canopy tarps
      0.04, 0.32, 0.06,  // Purple: woven rugs
      0.06, 0.38, 0.10,  // Magenta: exotic floral garlands
    ],
  ),

  // ──────────────────────────────────────────────────────────────
  // 9. Ancient Monuments & Heritage Stone — sculpted weathered masonry, high clarity
  CulturalTravelLook(
    name: 'Ancient Monuments',
    description:
        'Heritage architecture: sculpted carved relief, weathered marble & stone, clear sky separation',
    theme: 'Travel & Tourism',
    depthHint: 'monument facade',
    focalPoint: 0.55,
    focalRange: 0.35,
    bokehShape: 2, // hexagon
    blurAmount: 0.14,
    params: {
      'exposure': 0.02,
      'contrast': 0.22,
      'highlights': -0.25,
      'shadows': 0.18,
      'whites': 0.12,
      'blacks': -0.14,
      'clarity': 0.32,
      'texture': 0.32,
      'dehaze': 0.20,
      'temperature': 0.02,
      'tint': -0.02,
      'vibrance': 0.24,
      'saturation': 0.08,
      'gradeShadowHue': 0.60,
      'gradeShadowSat': 0.22,
      'gradeShadowLum': -0.06,
      'gradeHighlightHue': 0.10,
      'gradeHighlightSat': 0.18,
      'gradeHighlightLum': 0.04,
      'gradeMidHue': 0.55,
      'gradeMidSat': 0.14,
      'gradeMidLum': 0.0,
      'gradeBlending': 0.50,
      'gradeBalance': 0.08,
      'grain': 0.12,
      'grainSize': 0.14,
    },
    hsl: [
      0.00, 0.16, 0.02,  // Red: red brick & terracotta
      0.02, 0.24, 0.08,  // Orange: warm limestone & sandstone
      0.00, 0.22, 0.10,  // Yellow: sunlit marble
      -0.02, 0.18, -0.02,// Green: temple courtyard trees
      0.00, 0.26, 0.02,  // Aqua: reflective temple pools
      0.00, 0.38, 0.04,  // Blue: backdrop sky
      -0.02, 0.10, 0.00, // Purple: shaded stone carvings
      0.00, 0.10, 0.00,  // Magenta: neutral
    ],
  ),

  // ──────────────────────────────────────────────────────────────
  // 10. Vivid HDR Radiance — maximum dynamic range recovery for high-contrast scenes
  CulturalTravelLook(
    name: 'Vivid HDR Radiance',
    description:
        'Balanced HDR: recovers harsh highlights and deep shadows with natural vibrance and zero halos',
    theme: 'Universal All-Rounder',
    depthHint: 'center scene',
    focalPoint: 0.50,
    focalRange: 0.30,
    bokehShape: 0, // circle
    blurAmount: 0.12,
    params: {
      'exposure': 0.02,
      'contrast': 0.10,
      'highlights': -0.35,
      'shadows': 0.32,
      'whites': 0.08,
      'blacks': -0.08,
      'clarity': 0.20,
      'texture': 0.22,
      'dehaze': 0.12,
      'temperature': 0.02,
      'tint': 0.0,
      'vibrance': 0.36,
      'saturation': 0.14,
      'gradeShadowHue': 0.60,
      'gradeShadowSat': 0.18,
      'gradeShadowLum': 0.02,
      'gradeHighlightHue': 0.10,
      'gradeHighlightSat': 0.22,
      'gradeHighlightLum': 0.04,
      'gradeMidHue': 0.52,
      'gradeMidSat': 0.14,
      'gradeMidLum': 0.02,
      'gradeBlending': 0.55,
      'gradeBalance': 0.02,
    },
    hsl: [
      0.02, 0.24, 0.06,  // Red
      0.02, 0.26, 0.08,  // Orange
      0.00, 0.24, 0.10,  // Yellow
      0.04, 0.32, 0.06,  // Green
      0.02, 0.34, 0.06,  // Aqua
      0.00, 0.36, 0.04,  // Blue
      0.02, 0.18, 0.02,  // Purple
      0.04, 0.22, 0.06,  // Magenta
    ],
  ),

  // ──────────────────────────────────────────────────────────────
  // 11. Street Photography: Leica Monochrom — silver halide microcontrast & street grit
  CulturalTravelLook(
    name: 'Leica M Monochrom',
    description:
        'Legendary rangefinder black & white: punchy silver halide microcontrast, deep zone-0 blacks, crisp street documentary tone',
    theme: 'Film & Street Photography',
    depthHint: 'street subject',
    focalPoint: 0.42,
    focalRange: 0.22,
    bokehShape: 0, // circle
    blurAmount: 0.20,
    params: {
      'exposure': 0.02,
      'contrast': 0.32,
      'highlights': -0.10,
      'shadows': 0.04,
      'whites': 0.18,
      'blacks': -0.16,
      'clarity': 0.35,
      'texture': 0.38,
      'dehaze': 0.12,
      'saturation': -1.0, // pure monochrome
      'vibrance': -1.0,
      'grain': 0.24,
      'grainSize': 0.16,
    },
    hsl: [
      0.0, -1.0, -0.05, // Red: dark punch
      0.0, -1.0, 0.06,  // Orange: bright skin zone
      0.0, -1.0, 0.10,  // Yellow: bright daylight zone
      0.0, -1.0, -0.08, // Green: deep foliage
      0.0, -1.0, -0.04, // Aqua: sky contrast
      0.0, -1.0, -0.12, // Blue: deep dramatic sky
      0.0, -1.0, -0.06, // Purple
      0.0, -1.0, -0.04, // Magenta
    ],
  ),

  // ──────────────────────────────────────────────────────────────
  // 12. Vintage Kodachrome 64 — legendary warm red pop & cyan sky nostalgia
  CulturalTravelLook(
    name: 'Vintage Kodachrome 64',
    description:
        'National Geographic legend: warm saturated reds and yellows, signature cyan sky bias, timeless documentary contrast',
    theme: 'Film & Vintage',
    depthHint: 'subject',
    focalPoint: 0.48,
    focalRange: 0.25,
    bokehShape: 1, // pentagon
    blurAmount: 0.22,
    params: {
      'exposure': 0.04,
      'contrast': 0.22,
      'highlights': -0.08,
      'shadows': 0.06,
      'whites': 0.12,
      'blacks': -0.10,
      'clarity': 0.16,
      'texture': 0.22,
      'temperature': 0.14,
      'tint': 0.06,
      'vibrance': 0.28,
      'saturation': 0.18,
      'gradeShadowHue': 0.52, // cyan shadow bias
      'gradeShadowSat': 0.18,
      'gradeShadowLum': -0.02,
      'gradeHighlightHue': 0.12, // warm golden yellow
      'gradeHighlightSat': 0.24,
      'gradeHighlightLum': 0.06,
      'gradeMidHue': 0.08,
      'gradeMidSat': 0.16,
      'gradeMidLum': 0.02,
      'gradeBlending': 0.58,
      'gradeBalance': 0.04,
      'grain': 0.18,
      'grainSize': 0.18,
      'filmBloom': 0.10,
    },
    hsl: [
      0.02, 0.48, 0.10,  // Red: classic Kodachrome red pop
      0.04, 0.36, 0.12,  // Orange: warm documentary portraits
      -0.02, 0.40, 0.14, // Yellow: saturated sunlight
      0.04, 0.18, -0.02, // Green: organic natural greens
      0.02, 0.30, 0.04,  // Aqua: nostalgic cyan sky transition
      -0.04, 0.22, -0.06,// Blue: deep vintage sky
      0.02, 0.15, 0.02,  // Purple: soft shadows
      0.04, 0.22, 0.06,  // Magenta: subtle warmth
    ],
  ),

  // ──────────────────────────────────────────────────────────────
  // 13. Fuji Velvia 50 Landscape — ultra-saturated emerald greens & royal blues
  CulturalTravelLook(
    name: 'Fuji Velvia 50',
    description:
        'The landscape benchmark: hyper-saturated emerald greens, deep royal cobalt blues, and razor-sharp outdoor clarity',
    theme: 'Nature & Landscape Film',
    depthHint: 'scenic horizon',
    focalPoint: 0.55,
    focalRange: 0.40,
    bokehShape: 0, // circle
    blurAmount: 0.10,
    params: {
      'exposure': 0.00,
      'contrast': 0.26,
      'highlights': -0.14,
      'shadows': 0.08,
      'whites': 0.16,
      'blacks': -0.12,
      'clarity': 0.28,
      'texture': 0.32,
      'dehaze': 0.16,
      'temperature': -0.02,
      'tint': 0.04,
      'vibrance': 0.42,
      'saturation': 0.26,
      'gradeShadowHue': 0.62,
      'gradeShadowSat': 0.22,
      'gradeShadowLum': -0.04,
      'gradeHighlightHue': 0.14,
      'gradeHighlightSat': 0.20,
      'gradeHighlightLum': 0.04,
      'gradeMidHue': 0.38, // lush green/cyan midtones
      'gradeMidSat': 0.20,
      'gradeMidLum': 0.02,
      'gradeBlending': 0.55,
      'gradeBalance': 0.00,
      'grain': 0.10,
      'grainSize': 0.14,
    },
    hsl: [
      0.00, 0.30, 0.04,  // Red: rock and canyon pop
      0.02, 0.32, 0.08,  // Orange: autumn leaves
      0.00, 0.36, 0.12,  // Yellow: golden alpine meadows
      0.06, 0.60, 0.14,  // Green: hyper-saturated Velvia emerald
      0.02, 0.52, 0.08,  // Aqua: glacial lakes
      -0.02, 0.56, -0.04,// Blue: deep cobalt sky
      0.04, 0.26, 0.02,  // Purple: twilight alpine glow
      0.04, 0.28, 0.04,  // Magenta: sunset highlights
    ],
  ),

  // ──────────────────────────────────────────────────────────────
  // 14. Cinestill 800T Night Halation — tungsten blue shadows & glowing red bloom
  CulturalTravelLook(
    name: 'Cinestill 800T',
    description:
        'Tungsten cinema night look: cool cyan-teal shadow base, glowing red-orange halation bloom around street lamps and neon',
    theme: 'Urban & Night Film',
    depthHint: 'night subject',
    focalPoint: 0.44,
    focalRange: 0.22,
    bokehShape: 5, // soap bubble (optical bloom)
    blurAmount: 0.32,
    params: {
      'exposure': 0.02,
      'contrast': 0.24,
      'highlights': 0.08,
      'shadows': -0.08,
      'whites': 0.14,
      'blacks': -0.14,
      'clarity': 0.18,
      'texture': 0.20,
      'dehaze': 0.08,
      'temperature': -0.16, // cool tungsten balance
      'tint': 0.08,
      'vibrance': 0.28,
      'saturation': 0.16,
      'gradeShadowHue': 0.56, // cool cyan-blue tungsten shadows
      'gradeShadowSat': 0.32,
      'gradeShadowLum': -0.06,
      'gradeHighlightHue': 0.06, // warm red-orange halation
      'gradeHighlightSat': 0.36,
      'gradeHighlightLum': 0.10,
      'gradeMidHue': 0.54,
      'gradeMidSat': 0.18,
      'gradeMidLum': -0.02,
      'gradeBlending': 0.65,
      'gradeBalance': -0.08,
      'grain': 0.26,
      'grainSize': 0.22,
      'filmBloom': 0.30,
      'filmHalation': 0.32, // signature Cinestill red halation
    },
    hsl: [
      0.04, 0.52, 0.14,  // Red: intense halation glow around lights
      0.04, 0.44, 0.12,  // Orange: sodium street lights
      0.00, 0.28, 0.10,  // Yellow: warm shop windows
      -0.02, 0.14, -0.02,// Green: cool traffic signals
      0.02, 0.34, 0.02,  // Aqua: wet city street reflections
      -0.02, 0.40, -0.10,// Blue: deep midnight sky
      0.06, 0.30, 0.02,  // Purple: neon signs
      0.08, 0.38, 0.08,  // Magenta: night club glow
    ],
  ),

  // ──────────────────────────────────────────────────────────────
  // 15. Kerala Backwaters & Monsoon — lush tropical emerald & rain-soaked mist
  CulturalTravelLook(
    name: 'Kerala Monsoon & Backwaters',
    description:
        'Lush tropical moisture: rich deep emerald palms, mist-diffused soft highlights, reflective rain water, calm tranquil mood',
    theme: 'Indian Heritage & Travel',
    depthHint: 'houseboat / subject',
    focalPoint: 0.48,
    focalRange: 0.30,
    bokehShape: 0, // circle
    blurAmount: 0.22,
    params: {
      'exposure': 0.04,
      'contrast': 0.14,
      'highlights': -0.18,
      'shadows': 0.12,
      'whites': 0.06,
      'blacks': -0.06,
      'clarity': 0.14,
      'texture': 0.24,
      'dehaze': -0.04, // slight dreamy mist
      'temperature': 0.02,
      'tint': -0.04,
      'vibrance': 0.34,
      'saturation': 0.16,
      'gradeShadowHue': 0.46, // teal-emerald shadows
      'gradeShadowSat': 0.20,
      'gradeShadowLum': 0.02,
      'gradeHighlightHue': 0.14, // soft diffused light
      'gradeHighlightSat': 0.18,
      'gradeHighlightLum': 0.04,
      'gradeMidHue': 0.36,
      'gradeMidSat': 0.18,
      'gradeMidLum': 0.02,
      'gradeBlending': 0.56,
      'gradeBalance': 0.02,
      'filmBloom': 0.12,
    },
    hsl: [
      0.00, 0.22, 0.04,  // Red: houseboat wood & terracotta tiles
      0.02, 0.28, 0.06,  // Orange: warm spice drying
      0.00, 0.26, 0.10,  // Yellow: ripe coconut & banana trees
      0.04, 0.52, 0.10,  // Green: lush rain-soaked tropical palms
      0.02, 0.40, 0.06,  // Aqua: lagoon backwater reflections
      -0.02, 0.30, 0.00, // Blue: monsoon storm clouds
      0.02, 0.16, 0.02,  // Purple: water lilies
      0.04, 0.20, 0.04,  // Magenta: lotus flowers
    ],
  ),

  // ──────────────────────────────────────────────────────────────
  // 16. Bollywood Masala Golden Hour — saffron sunset glow & radiant portrait pop
  CulturalTravelLook(
    name: 'Bollywood Golden Hour',
    description:
        'Saffron-gold sunset: radiant warm skin tones, glowing rim light, punchy jewel saturation, cinematic Indian drama',
    theme: 'Indian Festive & Portraits',
    depthHint: 'portrait face',
    focalPoint: 0.42,
    focalRange: 0.22,
    bokehShape: 5, // soap bubble (glamorous backlight)
    blurAmount: 0.34,
    params: {
      'exposure': 0.08,
      'contrast': 0.20,
      'highlights': 0.04,
      'shadows': 0.08,
      'whites': 0.14,
      'blacks': -0.10,
      'clarity': 0.12,
      'texture': 0.18,
      'temperature': 0.18, // deep warm sunset
      'tint': 0.06,
      'vibrance': 0.38,
      'saturation': 0.22,
      'gradeShadowHue': 0.08, // warm chocolate shadows
      'gradeShadowSat': 0.20,
      'gradeShadowLum': -0.02,
      'gradeHighlightHue': 0.11, // saffron gold backlight
      'gradeHighlightSat': 0.38,
      'gradeHighlightLum': 0.10,
      'gradeMidHue': 0.09,
      'gradeMidSat': 0.24,
      'gradeMidLum': 0.04,
      'gradeBlending': 0.60,
      'gradeBalance': 0.06,
      'grain': 0.12,
      'grainSize': 0.16,
      'filmBloom': 0.22,
      'filmHalation': 0.20,
    },
    hsl: [
      0.02, 0.42, 0.10,  // Red: vermilion bindi & wedding dupattas
      0.04, 0.44, 0.14,  // Orange: glowing Indian skin tones & marigolds
      -0.02, 0.48, 0.18, // Yellow: pure saffron sunset backlighting
      0.04, 0.26, 0.06,  // Green: royal emerald silks
      0.02, 0.24, 0.04,  // Aqua: peacock feather highlights
      -0.02, 0.32, -0.04,// Blue: royal blue attire
      0.06, 0.38, 0.10,  // Purple: magenta-purple lehengas
      0.08, 0.42, 0.12,  // Magenta: fuchsia festive silk
    ],
  ),
];

/// Helper returning [culturalTravelLooks] as a flat list of [ToolDefinition] instances.
List<ToolDefinition> culturalTravelLookTools() =>
    culturalTravelLooks.map((l) => l.toToolDefinition()).toList();
