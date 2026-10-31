// Movie and animation reference grading presets with subject-aware depth.
//
// These presets ship as [ToolDefinition] entries so they can be applied from
// the Looks Sheet like any built-in look. Each preset carries optional depth /
// lens-blur parameters (`blurEnabled`, `blurAmount`, `blurFocalPoint`,
// `blurFocalRange`, `blurBokehShape`, `blurBokehBoost`, `blurBackgroundBlur`)
// which, when applied, route through the Depth Anything V2 monocular depth
// model (bundled ONNX INT8) via `estimateDepthMapWithModel` and
// `applyLensBlur` with a real CoC thin-lens kernel — subject stays sharp,
// background falls off with physical bokeh (Circle / Pentagon / Hexagon /
// Septagon / CatsEye / SoapBubble).
//
// Each preset also carries a `depthHint` describing the intended subject
// plane, so the UI can suggest a focal point after applying.
import '../../edit/tool_definition.dart';

/// A look with optional depth / lens-blur instructions.
class MovieLook {
  const MovieLook({
    required this.name,
    required this.description,
    required this.reference,
    required this.params,
    this.hsl,
    this.depthHint,
    this.focalPoint = 0.5,
    this.focalRange = 0.25,
    this.bokehShape = 1,
    this.blurAmount = 0.0,
  });

  final String name;
  final String description;
  final String reference; // movie title + year / director
  final Map<String, double> params;
  final List<double>? hsl; // 8-band HSL mix: [r_h, r_s, r_l, ...]
  final String? depthHint; // e.g. 'eyes', 'face', 'subject center'
  final double focalPoint;   // 0..1 depth plane in focus
  final double focalRange;   // 0..1 DOF range
  final int bokehShape;      // 0 circle .. 5 soap bubble, 6 swirl
  final double blurAmount;   // 0..1 optical blur strength

  /// Converts to a [ToolDefinition] plus a post-apply depth directive.
  ToolDefinition toToolDefinition() {
    return ToolDefinition(
      name: name,
      description: '$description  •  $reference',
      params: {
        ...params,
        if (blurAmount > 0) 'blurEnabled': 1.0,
        if (blurAmount > 0) 'blurAmount': blurAmount,
        if (blurAmount > 0) 'blurFocalPoint': focalPoint,
        if (blurAmount > 0) 'blurFocalRange': focalRange,
        if (blurAmount > 0) 'blurBokehShape': bokehShape.toDouble(),
        if (blurAmount > 0) 'blurBokehBoost': 0.30,
        if (blurAmount > 0) 'blurBackgroundBlur': 0.0,
      },
      hsl: hsl,
    );
  }
}

/// Movie and animation reference grading presets with subject-aware depth fall-off.
const List<MovieLook> movieLooks = [
  // ──────────────────────────────────────────────────────────────
  // 1. Blade Runner 2049 — neon-noir, orange shadows, teal highlights
  MovieLook(
    name: 'Blade Runner 2049',
    description:
        'Neon-noir: crushed teal shadows, smoky orange highlights, shallow depth on face',
    reference: 'Blade Runner 2049 (2017) · Roger Deakins',
    depthHint: 'eyes',
    focalPoint: 0.45,
    focalRange: 0.20,
    bokehShape: 1, // pentagon
    blurAmount: 0.35,
    params: {
      'contrast': 0.22,
      'highlights': -0.25,
      'shadows': 0.15,
      'whites': 0.08,
      'blacks': -0.14,
      'clarity': 0.15,
      'texture': 0.10,
      'temperature': -0.08,
      'tint': 0.05,
      'vibrance': 0.22,
      'saturation': 0.10,
      'gradeShadowHue': 0.55,
      'gradeShadowSat': 0.42,
      'gradeShadowLum': -0.08,
      'gradeHighlightHue': 0.12,
      'gradeHighlightSat': 0.38,
      'gradeHighlightLum': 0.05,
      'gradeMidHue': 0.30,
      'gradeMidSat': 0.20,
      'gradeMidLum': 0.0,
      'gradeBlending': 0.55,
      'gradeBalance': 0.10,
      'grain': 0.18,
      'grainSize': 0.22,
      'filmHalation': 0.14,
      'filmBloom': 0.10,
    },
    hsl: [
      0.02, 0.25, -0.05, // Red: rich blood orange
      0.05, 0.30, 0.08,  // Orange: vibrant neon glow
      -0.08, -0.10, 0.05, // Yellow: muted tungsten
      0.15, -0.20, -0.10, // Green: suppressed
      -0.05, 0.35, 0.05, // Aqua: electric cyan pop
      -0.02, 0.28, -0.08, // Blue: deep atmospheric navy
      0.00, -0.15, 0.00, // Purple: neutral
      0.05, 0.20, 0.05,  // Magenta: subtle neon rim
    ],
  ),

  // ──────────────────────────────────────────────────────────────
  // 2. The Grand Budapest Hotel — symmetrical pastel pinks & golds
  MovieLook(
    name: 'Grand Budapest',
    description:
        'Pastel storybook: powdery rose pinks, warm cream whites, soft midtones',
    reference: 'The Grand Budapest Hotel (2014) · Robert Yeoman',
    depthHint: 'center portrait',
    focalPoint: 0.50,
    focalRange: 0.35,
    bokehShape: 0, // circle
    blurAmount: 0.15,
    params: {
      'exposure': 0.10,
      'contrast': -0.08,
      'highlights': 0.12,
      'shadows': 0.18,
      'whites': 0.05,
      'blacks': 0.08,
      'clarity': -0.05,
      'texture': 0.05,
      'temperature': 0.12,
      'tint': 0.15,
      'vibrance': 0.28,
      'saturation': 0.14,
      'gradeShadowHue': 0.95,
      'gradeShadowSat': 0.25,
      'gradeShadowLum': 0.05,
      'gradeHighlightHue': 0.10,
      'gradeHighlightSat': 0.22,
      'gradeHighlightLum': 0.08,
      'gradeMidHue': 0.05,
      'gradeMidSat': 0.18,
      'gradeMidLum': 0.02,
      'gradeBlending': 0.65,
      'gradeBalance': -0.10,
      'grain': 0.12,
      'grainSize': 0.15,
      'filmBloom': 0.12,
    },
    hsl: [
      0.08, 0.32, 0.12,  // Red: pastel strawberry
      0.04, 0.24, 0.15,  // Orange: warm apricot
      0.02, 0.20, 0.18,  // Yellow: soft butter cream
      -0.05, -0.15, 0.05,// Green: muted pistachio
      0.00, -0.25, 0.00, // Aqua: desaturated
      -0.10, -0.30, 0.05,// Blue: gentle sky pastel
      0.05, 0.25, 0.10,  // Purple: soft lavender
      0.08, 0.35, 0.14,  // Magenta: signature Wes Anderson pink
    ],
  ),

  // ──────────────────────────────────────────────────────────────
  // 3. Inception — slate blue architecture, crisp neutral skin
  MovieLook(
    name: 'Inception',
    description:
        'Architectural slate: steel blue urban shadows, clean skin tones, crisp speculars',
    reference: 'Inception (2010) · Wally Pfister',
    depthHint: 'center subject',
    focalPoint: 0.40,
    focalRange: 0.22,
    bokehShape: 2, // hexagon
    blurAmount: 0.30,
    params: {
      'exposure': -0.05,
      'contrast': 0.18,
      'highlights': -0.15,
      'shadows': -0.08,
      'whites': 0.10,
      'blacks': -0.10,
      'clarity': 0.22,
      'texture': 0.15,
      'dehaze': 0.08,
      'temperature': -0.10,
      'tint': -0.02,
      'vibrance': 0.10,
      'saturation': -0.05,
      'gradeShadowHue': 0.62,
      'gradeShadowSat': 0.32,
      'gradeShadowLum': -0.05,
      'gradeHighlightHue': 0.08,
      'gradeHighlightSat': 0.15,
      'gradeHighlightLum': 0.04,
      'gradeMidHue': 0.58,
      'gradeMidSat': 0.14,
      'gradeMidLum': 0.0,
      'gradeBlending': 0.50,
      'gradeBalance': 0.15,
      'grain': 0.10,
      'grainSize': 0.12,
    },
    hsl: [
      -0.02, 0.05, 0.00, // Red: natural skin anchor
      0.00, 0.10, 0.04,  // Orange: protected skin tone
      -0.05, -0.15, -0.02,// Yellow: muted streetlights
      0.00, -0.25, -0.05, // Green: desaturated foliage
      0.02, 0.20, -0.04,  // Aqua: architectural glass
      0.00, 0.25, -0.06,  // Blue: deep steel skyline
      -0.05, -0.20, 0.00, // Purple: neutral
      0.00, -0.15, 0.00,  // Magenta: neutral
    ],
  ),

  // ──────────────────────────────────────────────────────────────
  // 4. Amélie — warm vintage Paris, olive greens, golden amber
  MovieLook(
    name: 'Amélie',
    description:
        'Montmartre glow: rich emerald and olive greens, honey golden highlights, crimson pops',
    reference: 'Le Fabuleux Destin d\'Amélie Poulain (2001) · Bruno Delbonnel',
    depthHint: 'eyes',
    focalPoint: 0.42,
    focalRange: 0.18,
    bokehShape: 0, // circle
    blurAmount: 0.28,
    params: {
      'exposure': 0.05,
      'contrast': 0.14,
      'highlights': -0.10,
      'shadows': 0.12,
      'whites': 0.05,
      'blacks': -0.06,
      'clarity': 0.08,
      'texture': 0.12,
      'temperature': 0.18,
      'tint': -0.12,
      'vibrance': 0.35,
      'saturation': 0.18,
      'gradeShadowHue': 0.33,
      'gradeShadowSat': 0.35,
      'gradeShadowLum': -0.04,
      'gradeHighlightHue': 0.11,
      'gradeHighlightSat': 0.35,
      'gradeHighlightLum': 0.06,
      'gradeMidHue': 0.22,
      'gradeMidSat': 0.22,
      'gradeMidLum': 0.02,
      'gradeBlending': 0.60,
      'gradeBalance': -0.05,
      'grain': 0.15,
      'grainSize': 0.18,
      'filmBloom': 0.10,
    },
    hsl: [
      0.05, 0.40, 0.08,  // Red: signature cherry red cardigan
      0.02, 0.35, 0.10,  // Orange: warm honey skin
      -0.04, 0.30, 0.12, // Yellow: golden cafe illumination
      0.08, 0.32, -0.06, // Green: iconic rich emerald olive
      -0.10, -0.20, -0.05,// Aqua: suppressed
      -0.15, -0.40, -0.10,// Blue: deeply muted
      0.00, -0.30, 0.00, // Purple: suppressed
      0.10, 0.20, 0.05,  // Magenta: warm accent
    ],
  ),

  // ──────────────────────────────────────────────────────────────
  // 5. The Godfather — Prince of Darkness, sepia shadow rolloff
  MovieLook(
    name: 'The Godfather',
    description:
        'Chiaroscuro amber: deep velvety black shadows, warm golden tungsten portraits',
    reference: 'The Godfather (1972) · Gordon Willis',
    depthHint: 'eyes',
    focalPoint: 0.38,
    focalRange: 0.15,
    bokehShape: 3, // septagon
    blurAmount: 0.32,
    params: {
      'exposure': -0.12,
      'contrast': 0.25,
      'highlights': -0.28,
      'shadows': -0.20,
      'whites': -0.05,
      'blacks': -0.25,
      'clarity': 0.10,
      'texture': 0.14,
      'temperature': 0.22,
      'tint': 0.08,
      'vibrance': 0.08,
      'saturation': 0.02,
      'gradeShadowHue': 0.08,
      'gradeShadowSat': 0.28,
      'gradeShadowLum': -0.15,
      'gradeHighlightHue': 0.12,
      'gradeHighlightSat': 0.30,
      'gradeHighlightLum': -0.04,
      'gradeMidHue': 0.10,
      'gradeMidSat': 0.25,
      'gradeMidLum': -0.06,
      'gradeBlending': 0.45,
      'gradeBalance': -0.20,
      'grain': 0.24,
      'grainSize': 0.28,
      'vignette': -0.35,
      'vignetteMidpoint': 0.40,
    },
    hsl: [
      -0.02, 0.15, -0.08, // Red: deep burgundy
      0.02, 0.22, 0.02,   // Orange: low-key skin
      0.04, 0.18, -0.05,  // Yellow: warm brass
      -0.10, -0.40, -0.15,// Green: deeply suppressed
      -0.05, -0.50, -0.20,// Aqua: almost eliminated
      0.00, -0.60, -0.25, // Blue: extinguished
      0.00, -0.40, -0.10, // Purple: neutral
      -0.05, -0.20, -0.05,// Magenta: suppressed
    ],
  ),

  // ──────────────────────────────────────────────────────────────
  // 6. Dunkirk — desaturated maritime silver, cold ocean, pale sand
  MovieLook(
    name: 'Dunkirk',
    description:
        'Bleached maritime: icy silver ocean, desaturated beach sand, 65mm fine grain',
    reference: 'Dunkirk (2017) · Hoyte van Hoytema',
    depthHint: 'horizon',
    focalPoint: 0.55,
    focalRange: 0.40,
    bokehShape: 2, // hexagon
    blurAmount: 0.12,
    params: {
      'exposure': 0.05,
      'contrast': 0.12,
      'highlights': 0.10,
      'shadows': -0.05,
      'whites': 0.12,
      'blacks': -0.08,
      'clarity': 0.25,
      'texture': 0.20,
      'dehaze': 0.14,
      'temperature': -0.14,
      'tint': -0.04,
      'vibrance': -0.15,
      'saturation': -0.22,
      'gradeShadowHue': 0.58,
      'gradeShadowSat': 0.22,
      'gradeShadowLum': -0.02,
      'gradeHighlightHue': 0.14,
      'gradeHighlightSat': 0.10,
      'gradeHighlightLum': 0.05,
      'gradeMidHue': 0.55,
      'gradeMidSat': 0.12,
      'gradeMidLum': 0.0,
      'gradeBlending': 0.50,
      'gradeBalance': 0.18,
      'grain': 0.20,
      'grainSize': 0.16,
    },
    hsl: [
      -0.05, -0.25, -0.05,// Red: muted uniform
      -0.02, -0.15, 0.02, // Orange: pale skin
      -0.06, -0.20, 0.08, // Yellow: bleached pale sand
      0.00, -0.35, -0.05, // Green: cold sea grass
      0.02, 0.15, -0.02,  // Aqua: cold Channel waters
      0.00, 0.10, -0.04,  // Blue: slate grey sky
      0.00, -0.30, 0.00,  // Purple: neutral
      0.00, -0.30, 0.00,  // Magenta: neutral
    ],
  ),

  // ──────────────────────────────────────────────────────────────
  // 7. Moonlight — radiant royal blue and magenta Miami night
  MovieLook(
    name: 'Moonlight',
    description:
        'Miami neon glow: deep royal blue shadows, glowing magenta rims, radiant dark skin',
    reference: 'Moonlight (2016) · James Laxton',
    depthHint: 'face',
    focalPoint: 0.44,
    focalRange: 0.18,
    bokehShape: 0, // circle
    blurAmount: 0.38,
    params: {
      'exposure': 0.0,
      'contrast': 0.16,
      'highlights': -0.12,
      'shadows': 0.18,
      'whites': 0.08,
      'blacks': -0.12,
      'clarity': 0.12,
      'texture': 0.18,
      'temperature': -0.06,
      'tint': 0.14,
      'vibrance': 0.38,
      'saturation': 0.18,
      'gradeShadowHue': 0.65,
      'gradeShadowSat': 0.44,
      'gradeShadowLum': -0.06,
      'gradeHighlightHue': 0.88,
      'gradeHighlightSat': 0.32,
      'gradeHighlightLum': 0.08,
      'gradeMidHue': 0.72,
      'gradeMidSat': 0.24,
      'gradeMidLum': 0.02,
      'gradeBlending': 0.60,
      'gradeBalance': 0.05,
      'filmBloom': 0.15,
      'filmHalation': 0.12,
    },
    hsl: [
      0.04, 0.28, 0.05,  // Red: rich undertone
      0.02, 0.32, 0.10,  // Orange: radiant skin highlight
      -0.05, 0.15, 0.08, // Yellow: warm lamp glow
      0.10, -0.20, -0.10,// Green: suppressed
      0.04, 0.35, 0.05,  // Aqua: ocean night reflection
      0.02, 0.45, -0.02, // Blue: deep royal moonlight
      0.06, 0.38, 0.08,  // Purple: violet ambient
      0.08, 0.42, 0.12,  // Magenta: vibrant neon rim
    ],
  ),

  // ──────────────────────────────────────────────────────────────
  // 8. Mad Max: Fury Road — high-octane chrome & desert fire
  MovieLook(
    name: 'Mad Max: Fury Road',
    description:
        'Wasteland fire: searing cobalt sky, blazing orange ochre sand, extreme micro-contrast',
    reference: 'Mad Max: Fury Road (2015) · John Seale',
    depthHint: 'vehicle / subject',
    focalPoint: 0.48,
    focalRange: 0.28,
    bokehShape: 2, // hexagon
    blurAmount: 0.22,
    params: {
      'exposure': 0.08,
      'contrast': 0.32,
      'highlights': -0.18,
      'shadows': 0.10,
      'whites': 0.18,
      'blacks': -0.18,
      'clarity': 0.38,
      'texture': 0.30,
      'dehaze': 0.20,
      'temperature': 0.16,
      'tint': -0.02,
      'vibrance': 0.45,
      'saturation': 0.22,
      'gradeShadowHue': 0.58,
      'gradeShadowSat': 0.35,
      'gradeShadowLum': -0.10,
      'gradeHighlightHue': 0.10,
      'gradeHighlightSat': 0.45,
      'gradeHighlightLum': 0.08,
      'gradeMidHue': 0.08,
      'gradeMidSat': 0.32,
      'gradeMidLum': 0.04,
      'gradeBlending': 0.55,
      'gradeBalance': -0.12,
      'grain': 0.18,
      'grainSize': 0.20,
    },
    hsl: [
      0.06, 0.45, 0.08,  // Red: fiery rust & chrome reflections
      0.04, 0.50, 0.15,  // Orange: blazing desert ochre
      0.02, 0.40, 0.18,  // Yellow: intense sunlight
      -0.10, -0.50, -0.15,// Green: scorched wasteland
      0.05, 0.35, -0.05, // Aqua: electric turquoise edge
      0.00, 0.45, -0.08, // Blue: polarized searing cobalt sky
      -0.05, -0.30, 0.00,// Purple: neutral
      0.05, 0.25, 0.05,  // Magenta: heat shimmer
    ],
  ),

  // ──────────────────────────────────────────────────────────────
  // 9. Her — warm intimate red, absence of blue, soft daylight
  MovieLook(
    name: 'Her',
    description:
        'Warm melancholy: soft salmon pinks, deep scarlet red, complete blue suppression',
    reference: 'Her (2013) · Hoyte van Hoytema',
    depthHint: 'portrait',
    focalPoint: 0.42,
    focalRange: 0.16,
    bokehShape: 0, // circle
    blurAmount: 0.32,
    params: {
      'exposure': 0.08,
      'contrast': -0.06,
      'highlights': -0.12,
      'shadows': 0.16,
      'whites': 0.02,
      'blacks': 0.05,
      'clarity': -0.08,
      'texture': 0.06,
      'temperature': 0.25,
      'tint': 0.18,
      'vibrance': 0.24,
      'saturation': 0.12,
      'gradeShadowHue': 0.04,
      'gradeShadowSat': 0.28,
      'gradeShadowLum': 0.04,
      'gradeHighlightHue': 0.08,
      'gradeHighlightSat': 0.25,
      'gradeHighlightLum': 0.06,
      'gradeMidHue': 0.02,
      'gradeMidSat': 0.22,
      'gradeMidLum': 0.02,
      'gradeBlending': 0.65,
      'gradeBalance': -0.18,
      'grain': 0.14,
      'grainSize': 0.18,
      'filmBloom': 0.16,
    },
    hsl: [
      0.02, 0.48, 0.10,  // Red: signature Theodore scarlet shirt
      0.05, 0.38, 0.14,  // Orange: warm cozy interior
      0.02, 0.28, 0.12,  // Yellow: soft morning window light
      0.05, -0.20, 0.00, // Green: subdued
      -0.10, -0.65, -0.15,// Aqua: heavily suppressed
      -0.15, -0.85, -0.25,// Blue: eliminated (world without blue)
      0.08, 0.20, 0.05,  // Purple: warm mauve
      0.06, 0.35, 0.12,  // Magenta: romantic blush
    ],
  ),

  // ──────────────────────────────────────────────────────────────
  // 10. The Matrix — digital green phosphorus, lifted darks
  MovieLook(
    name: 'The Matrix',
    description:
        'Digital simulation: phosphorescent green cast, lifted darks, crisp dystopian contrast',
    reference: 'The Matrix (1999) · Bill Pope',
    depthHint: 'center figure',
    focalPoint: 0.45,
    focalRange: 0.24,
    bokehShape: 2, // hexagon
    blurAmount: 0.25,
    params: {
      'exposure': -0.04,
      'contrast': 0.26,
      'highlights': -0.18,
      'shadows': -0.05,
      'whites': 0.08,
      'blacks': -0.06,
      'clarity': 0.26,
      'texture': 0.20,
      'dehaze': 0.10,
      'temperature': -0.06,
      'tint': -0.32,
      'vibrance': 0.10,
      'saturation': -0.10,
      'gradeShadowHue': 0.34,
      'gradeShadowSat': 0.45,
      'gradeShadowLum': -0.02,
      'gradeHighlightHue': 0.32,
      'gradeHighlightSat': 0.28,
      'gradeHighlightLum': 0.05,
      'gradeMidHue': 0.35,
      'gradeMidSat': 0.36,
      'gradeMidLum': 0.0,
      'gradeBlending': 0.50,
      'gradeBalance': 0.0,
      'grain': 0.16,
      'grainSize': 0.14,
    },
    hsl: [
      -0.10, -0.30, -0.08,// Red: muted
      -0.08, -0.20, 0.00, // Orange: pale sickly skin
      0.08, 0.20, 0.05,   // Yellow: shifted to chartreuse
      0.02, 0.48, 0.08,   // Green: iconic CRT phosphorus green
      -0.05, 0.25, -0.02, // Aqua: matrix code tint
      -0.10, -0.40, -0.12,// Blue: heavily suppressed
      0.00, -0.40, 0.00,  // Purple: suppressed
      0.00, -0.35, 0.00,  // Magenta: suppressed
    ],
  ),

  // ──────────────────────────────────────────────────────────────
  // 11. Ready Player One — OASIS high-voltage neon & cyber speculars
  MovieLook(
    name: 'Ready Player One',
    description:
        'OASIS neon: high-voltage electric cyan, hot magenta speculars, cybernetic bloom',
    reference: 'Ready Player One (2018) · Janusz Kamiński',
    depthHint: 'avatar / eyes',
    focalPoint: 0.45,
    focalRange: 0.18,
    bokehShape: 4, // cat's eye anamorphic
    blurAmount: 0.36,
    params: {
      'exposure': 0.04,
      'contrast': 0.28,
      'highlights': -0.10,
      'shadows': 0.12,
      'whites': 0.16,
      'blacks': -0.16,
      'clarity': 0.30,
      'texture': 0.25,
      'dehaze': 0.15,
      'temperature': -0.08,
      'tint': 0.12,
      'vibrance': 0.42,
      'saturation': 0.24,
      'gradeShadowHue': 0.60,
      'gradeShadowSat': 0.40,
      'gradeShadowLum': -0.08,
      'gradeHighlightHue': 0.88,
      'gradeHighlightSat': 0.42,
      'gradeHighlightLum': 0.10,
      'gradeMidHue': 0.52,
      'gradeMidSat': 0.26,
      'gradeMidLum': 0.02,
      'gradeBlending': 0.55,
      'gradeBalance': 0.08,
      'filmBloom': 0.22,
      'filmHalation': 0.18,
    },
    hsl: [
      0.06, 0.38, 0.10,  // Red: laser crimson
      0.04, 0.28, 0.12,  // Orange: avatar UI display
      -0.05, 0.20, 0.15, // Yellow: coin glow
      0.12, 0.15, -0.05, // Green: virtual matrix
      0.02, 0.55, 0.12,  // Aqua: high-voltage OASIS cyan
      0.00, 0.42, 0.04,  // Blue: neon grid
      0.05, 0.45, 0.10,  // Purple: cyber violet
      0.08, 0.52, 0.16,  // Magenta: signature neon pop
    ],
  ),

  // ──────────────────────────────────────────────────────────────
  // 12. Avatar — Pandora bioluminescent flora & soap bubble speculars
  MovieLook(
    name: 'Avatar',
    description:
        'Pandora bioluminescence: glowing cyan flora, deep jungle greens, soap bubble bokeh',
    reference: 'Avatar (2009) · Mauro Fiore',
    depthHint: 'subject face',
    focalPoint: 0.40,
    focalRange: 0.16,
    bokehShape: 5, // soap bubble specular
    blurAmount: 0.40,
    params: {
      'exposure': 0.06,
      'contrast': 0.24,
      'highlights': -0.15,
      'shadows': 0.16,
      'whites': 0.12,
      'blacks': -0.14,
      'clarity': 0.22,
      'texture': 0.20,
      'dehaze': 0.12,
      'temperature': -0.12,
      'tint': -0.06,
      'vibrance': 0.45,
      'saturation': 0.20,
      'gradeShadowHue': 0.45,
      'gradeShadowSat': 0.42,
      'gradeShadowLum': -0.06,
      'gradeHighlightHue': 0.52,
      'gradeHighlightSat': 0.38,
      'gradeHighlightLum': 0.08,
      'gradeMidHue': 0.48,
      'gradeMidSat': 0.30,
      'gradeMidLum': 0.02,
      'gradeBlending': 0.60,
      'gradeBalance': 0.12,
      'filmBloom': 0.20,
    },
    hsl: [
      0.08, 0.15, 0.02,  // Red: exotic flora accent
      0.02, 0.18, 0.05,  // Orange: woodclan firelight
      -0.08, 0.30, 0.12, // Yellow: glowing spores
      0.05, 0.45, -0.05, // Green: lush Pandoran canopy
      0.04, 0.58, 0.10,  // Aqua: bioluminescent woodprites
      0.02, 0.48, 0.06,  // Blue: Na\'vi skin luminescence
      0.10, 0.35, 0.08,  // Purple: sacred Tree of Souls
      0.12, 0.40, 0.12,  // Magenta: glowing tendrils
    ],
  ),

  // ──────────────────────────────────────────────────────────────
  // 13. The Terminator — Tech-noir cold steel and harsh industrial grit
  MovieLook(
    name: 'The Terminator',
    description:
        'Tech-noir industrial: cold metallic steel blue, crushing contrast, cybernetic eye red',
    reference: 'The Terminator (1984) · Adam Greenberg',
    depthHint: 'chassis / face',
    focalPoint: 0.42,
    focalRange: 0.20,
    bokehShape: 1, // pentagon
    blurAmount: 0.30,
    params: {
      'exposure': -0.08,
      'contrast': 0.30,
      'highlights': -0.20,
      'shadows': -0.15,
      'whites': 0.14,
      'blacks': -0.20,
      'clarity': 0.32,
      'texture': 0.28,
      'dehaze': 0.18,
      'temperature': -0.18,
      'tint': 0.04,
      'vibrance': 0.12,
      'saturation': -0.08,
      'gradeShadowHue': 0.62,
      'gradeShadowSat': 0.38,
      'gradeShadowLum': -0.10,
      'gradeHighlightHue': 0.58,
      'gradeHighlightSat': 0.20,
      'gradeHighlightLum': 0.06,
      'gradeMidHue': 0.60,
      'gradeMidSat': 0.22,
      'gradeMidLum': -0.02,
      'gradeBlending': 0.50,
      'gradeBalance': 0.14,
      'grain': 0.25,
      'grainSize': 0.22,
      'filmHalation': 0.15,
    },
    hsl: [
      0.00, 0.50, 0.05,  // Red: piercing T-800 cybernetic eye
      -0.05, -0.15, 0.00,// Orange: muted skin
      -0.10, -0.30, -0.05,// Yellow: desaturated
      0.00, -0.40, -0.10,// Green: suppressed
      0.02, 0.32, -0.02, // Aqua: metallic hydraulic reflection
      0.00, 0.35, -0.06, // Blue: cold dystopian steel night
      -0.05, -0.20, 0.00,// Purple: neutral
      0.05, 0.20, 0.02,  // Magenta: Tech-noir nightclub laser
    ],
  ),

  // ──────────────────────────────────────────────────────────────
  // 14. John Wick — Continental neon red & shallow assassin isolation
  MovieLook(
    name: 'John Wick',
    description:
        'Continental noir: crimson neon, crushed velvet shadows, shallow depth on Wick',
    reference: 'John Wick (2014) · Jonathan Sela',
    depthHint: 'eyes',
    focalPoint: 0.42,
    focalRange: 0.16,
    bokehShape: 1, // pentagon
    blurAmount: 0.38,
    params: {
      'exposure': -0.06,
      'contrast': 0.26,
      'highlights': -0.22,
      'shadows': 0.08,
      'whites': 0.10,
      'blacks': -0.22,
      'clarity': 0.24,
      'texture': 0.20,
      'temperature': -0.06,
      'tint': 0.10,
      'vibrance': 0.32,
      'saturation': 0.15,
      'gradeShadowHue': 0.64,
      'gradeShadowSat': 0.38,
      'gradeShadowLum': -0.10,
      'gradeHighlightHue': 0.96,
      'gradeHighlightSat': 0.42,
      'gradeHighlightLum': 0.08,
      'gradeMidHue': 0.70,
      'gradeMidSat': 0.20,
      'gradeMidLum': 0.0,
      'gradeBlending': 0.55,
      'gradeBalance': 0.06,
      'filmBloom': 0.18,
      'filmHalation': 0.16,
    },
    hsl: [
      0.04, 0.45, 0.08,  // Red: Red Circle club neon
      0.02, 0.25, 0.05,  // Orange: warm bourbon reflection
      -0.05, 0.12, 0.04, // Yellow: gold hotel coin
      0.00, -0.30, -0.10,// Green: suppressed
      0.02, 0.35, 0.02,  // Aqua: rain reflection
      0.00, 0.38, -0.06, // Blue: tailored suit navy
      0.04, 0.30, 0.06,  // Purple: VIP club lounge
      0.08, 0.45, 0.10,  // Magenta: intense neon highlights
    ],
  ),

  // ──────────────────────────────────────────────────────────────
  // 15. John Wick 2 — Rome catacombs & mirror hall golden amber
  MovieLook(
    name: 'John Wick 2: Rome',
    description:
        'Catacombs gold: candlelit Roman amber, mirror hall speculars, deep navy suit blacks',
    reference: 'John Wick: Chapter 2 (2017) · Dan Laustsen',
    depthHint: 'face / weapon',
    focalPoint: 0.40,
    focalRange: 0.18,
    bokehShape: 2, // hexagon
    blurAmount: 0.35,
    params: {
      'exposure': -0.04,
      'contrast': 0.24,
      'highlights': -0.15,
      'shadows': -0.06,
      'whites': 0.12,
      'blacks': -0.18,
      'clarity': 0.26,
      'texture': 0.22,
      'temperature': 0.14,
      'tint': 0.06,
      'vibrance': 0.28,
      'saturation': 0.16,
      'gradeShadowHue': 0.60,
      'gradeShadowSat': 0.34,
      'gradeShadowLum': -0.08,
      'gradeHighlightHue': 0.11,
      'gradeHighlightSat': 0.40,
      'gradeHighlightLum': 0.08,
      'gradeMidHue': 0.10,
      'gradeMidSat': 0.26,
      'gradeMidLum': 0.02,
      'gradeBlending': 0.55,
      'gradeBalance': -0.08,
      'filmBloom': 0.14,
      'filmHalation': 0.12,
    },
    hsl: [
      0.02, 0.35, 0.06,  // Red: velvet curtain
      0.04, 0.42, 0.12,  // Orange: Roman candle illumination
      0.02, 0.36, 0.15,  // Yellow: gilded mirror reflections
      -0.08, -0.35, -0.10,// Green: suppressed
      0.00, 0.22, -0.04, // Aqua: glass refractions
      0.00, 0.32, -0.08, // Blue: tailored Italian wool
      -0.02, 0.20, 0.02, // Purple: museum ambient
      0.05, 0.25, 0.05,  // Magenta: subtle neon accent
    ],
  ),

  // ──────────────────────────────────────────────────────────────
  // 16. John Wick 3: Parabellum — Rain-soaked Manhattan night
  MovieLook(
    name: 'John Wick 3: Parabellum',
    description:
        'Parabellum rain: wet asphalt reflections, amber taxi glow, anamorphic blue flare',
    reference: 'John Wick: Chapter 3 – Parabellum (2019) · Dan Laustsen',
    depthHint: 'eyes',
    focalPoint: 0.42,
    focalRange: 0.18,
    bokehShape: 4, // cat's eye anamorphic
    blurAmount: 0.42,
    params: {
      'exposure': -0.02,
      'contrast': 0.28,
      'highlights': -0.18,
      'shadows': 0.12,
      'whites': 0.15,
      'blacks': -0.16,
      'clarity': 0.28,
      'texture': 0.24,
      'dehaze': 0.12,
      'temperature': -0.08,
      'tint': 0.08,
      'vibrance': 0.36,
      'saturation': 0.20,
      'gradeShadowHue': 0.62,
      'gradeShadowSat': 0.42,
      'gradeShadowLum': -0.08,
      'gradeHighlightHue': 0.11,
      'gradeHighlightSat': 0.44,
      'gradeHighlightLum': 0.10,
      'gradeMidHue': 0.58,
      'gradeMidSat': 0.24,
      'gradeMidLum': 0.0,
      'gradeBlending': 0.55,
      'gradeBalance': 0.04,
      'filmBloom': 0.24,
      'filmHalation': 0.20,
    },
    hsl: [
      0.04, 0.40, 0.08,  // Red: stoplight rain reflection
      0.05, 0.48, 0.14,  // Orange: NYC taxi amber glow
      0.02, 0.38, 0.16,  // Yellow: times square billboard
      -0.05, -0.25, -0.05,// Green: muted
      0.04, 0.45, 0.08,  // Aqua: puddle neon reflections
      0.00, 0.44, -0.02, // Blue: torrential rain night
      0.06, 0.32, 0.06,  // Purple: Continental lounge
      0.08, 0.42, 0.12,  // Magenta: street signage
    ],
  ),

  // ──────────────────────────────────────────────────────────────
  // 17. John Wick 4 — Osaka cherry blossom vermilion & tungsten gold
  MovieLook(
    name: 'John Wick 4: Osaka',
    description:
        'Osaka Continental: cherry blossom vermilion, tungsten gold vs midnight indigo, soap bubble bokeh',
    reference: 'John Wick: Chapter 4 (2023) · Dan Laustsen',
    depthHint: 'face / katana',
    focalPoint: 0.44,
    focalRange: 0.16,
    bokehShape: 5, // soap bubble specular
    blurAmount: 0.44,
    params: {
      'exposure': 0.02,
      'contrast': 0.30,
      'highlights': -0.16,
      'shadows': 0.14,
      'whites': 0.16,
      'blacks': -0.18,
      'clarity': 0.30,
      'texture': 0.25,
      'temperature': 0.06,
      'tint': 0.15,
      'vibrance': 0.42,
      'saturation': 0.24,
      'gradeShadowHue': 0.68,
      'gradeShadowSat': 0.45,
      'gradeShadowLum': -0.08,
      'gradeHighlightHue': 0.02,
      'gradeHighlightSat': 0.46,
      'gradeHighlightLum': 0.10,
      'gradeMidHue': 0.10,
      'gradeMidSat': 0.30,
      'gradeMidLum': 0.02,
      'gradeBlending': 0.60,
      'gradeBalance': -0.02,
      'filmBloom': 0.25,
      'filmHalation': 0.22,
    },
    hsl: [
      0.05, 0.55, 0.12,  // Red: Japanese vermilion lacquer
      0.04, 0.46, 0.14,  // Orange: traditional lantern warmth
      0.00, 0.35, 0.12,  // Yellow: gold leaf shoji screen
      0.08, -0.20, -0.08,// Green: bamboo grove
      0.02, 0.38, 0.05,  // Aqua: glass display case
      0.02, 0.45, -0.05, // Blue: Osaka midnight sky
      0.08, 0.40, 0.10,  // Purple: night garden
      0.10, 0.52, 0.18,  // Magenta: illuminated cherry blossom
    ],
  ),

  // ──────────────────────────────────────────────────────────────
  // 18. The Dark Knight (Bale / Nolan) — practical 35mm/IMAX realism
  MovieLook(
    name: 'The Dark Knight',
    description:
        'Batman Gotham realism: natural skin tones, controlled steel-blue shadows, neutral highlights',
    reference: 'The Dark Knight (Batman, 2008) · Christopher Nolan / Christian Bale',
    depthHint: 'eyes',
    focalPoint: 0.42,
    focalRange: 0.22,
    bokehShape: 2, // hexagon
    blurAmount: 0.26,
    params: {
      'exposure': -0.04,
      'contrast': 0.20,
      'highlights': -0.15,
      'shadows': -0.06,
      'whites': 0.08,
      'blacks': -0.12,
      'clarity': 0.18,
      'texture': 0.14,
      'temperature': -0.08,
      'tint': 0.02,
      'vibrance': 0.14,
      'saturation': 0.04,
      'gradeShadowHue': 0.60,
      'gradeShadowSat': 0.28,
      'gradeShadowLum': -0.06,
      'gradeHighlightHue': 0.10,
      'gradeHighlightSat': 0.16,
      'gradeHighlightLum': 0.04,
      'gradeMidHue': 0.58,
      'gradeMidSat': 0.16,
      'gradeMidLum': 0.0,
      'gradeBlending': 0.50,
      'gradeBalance': 0.10,
      'grain': 0.14,
      'grainSize': 0.16,
    },
    hsl: [
      0.00, 0.12, 0.02,  // Red: natural lip & blood
      0.02, 0.18, 0.04,  // Orange: realistic Caucasian skin
      -0.02, 0.10, 0.02, // Yellow: sodium streetlamp
      0.00, -0.15, -0.04,// Green: neutral park foliage
      0.00, 0.20, -0.02, // Aqua: skyscraper glass
      0.00, 0.24, -0.05, // Blue: Gotham nocturnal steel
      -0.04, -0.15, 0.00,// Purple: neutral
      0.00, -0.10, 0.00, // Magenta: neutral
    ],
  ),

  // ──────────────────────────────────────────────────────────────
  // 19. The Batman (Pattinson / Reeves) — sodium-vapor amber vs pitch black
  MovieLook(
    name: 'The Batman',
    description:
        'Vengeance noir: intense sodium-vapor amber against crushed pitch-black shadows, anamorphic falloff',
    reference: 'The Batman (2022) · Greig Fraser / Matt Reeves',
    depthHint: 'cowl / eyes',
    focalPoint: 0.40,
    focalRange: 0.16,
    bokehShape: 4, // cat's eye anamorphic
    blurAmount: 0.44,
    params: {
      'exposure': -0.14,
      'contrast': 0.36,
      'highlights': -0.30,
      'shadows': -0.22,
      'whites': 0.12,
      'blacks': -0.32,
      'clarity': 0.30,
      'texture': 0.26,
      'dehaze': 0.16,
      'temperature': 0.18,
      'tint': 0.12,
      'vibrance': 0.22,
      'saturation': 0.10,
      'gradeShadowHue': 0.05,
      'gradeShadowSat': 0.32,
      'gradeShadowLum': -0.18,
      'gradeHighlightHue': 0.10,
      'gradeHighlightSat': 0.48,
      'gradeHighlightLum': 0.06,
      'gradeMidHue': 0.08,
      'gradeMidSat': 0.35,
      'gradeMidLum': -0.08,
      'gradeBlending': 0.45,
      'gradeBalance': -0.22,
      'grain': 0.22,
      'grainSize': 0.24,
      'filmBloom': 0.26,
      'filmHalation': 0.24,
      'vignette': -0.40,
      'vignetteMidpoint': 0.35,
    },
    hsl: [
      0.02, 0.42, -0.05, // Red: flares & gunfire halation
      0.05, 0.52, 0.10,  // Orange: intense sodium-vapor streetlights
      0.02, 0.40, 0.12,  // Yellow: amber rain reflection
      -0.10, -0.50, -0.20,// Green: extinguished
      -0.05, -0.40, -0.15,// Aqua: heavily muted
      0.00, -0.45, -0.20, // Blue: crushed darks
      0.04, 0.15, -0.05, // Purple: smoke haze
      0.06, 0.25, 0.02,  // Magenta: emergency lights
    ],
  ),

  // ──────────────────────────────────────────────────────────────
  // 20. Batman v Superman (Affleck / Snyder) — desaturated bleach bypass
  MovieLook(
    name: 'Batman v Superman',
    description:
        'Bleach-bypass grit: heavy desaturation, sculpted silver highlights, harsh dramatic contrast',
    reference: 'Batman v Superman (2016) · Larry Fong / Zack Snyder',
    depthHint: 'chest crest / face',
    focalPoint: 0.44,
    focalRange: 0.22,
    bokehShape: 3, // septagon
    blurAmount: 0.28,
    params: {
      'exposure': -0.06,
      'contrast': 0.34,
      'highlights': 0.16,
      'shadows': -0.18,
      'whites': 0.20,
      'blacks': -0.24,
      'clarity': 0.36,
      'texture': 0.32,
      'dehaze': 0.22,
      'temperature': -0.06,
      'tint': -0.04,
      'vibrance': -0.25,
      'saturation': -0.35,
      'gradeShadowHue': 0.58,
      'gradeShadowSat': 0.26,
      'gradeShadowLum': -0.12,
      'gradeHighlightHue': 0.14,
      'gradeHighlightSat': 0.14,
      'gradeHighlightLum': 0.08,
      'gradeMidHue': 0.55,
      'gradeMidSat': 0.18,
      'gradeMidLum': -0.04,
      'gradeBlending': 0.48,
      'gradeBalance': 0.12,
      'grain': 0.28,
      'grainSize': 0.26,
      'filmHalation': 0.14,
    },
    hsl: [
      -0.04, -0.25, -0.06,// Red: desaturated cape
      -0.02, -0.20, -0.02,// Orange: pale sculpted skin
      -0.06, -0.30, 0.02, // Yellow: muted explosions
      0.00, -0.45, -0.10, // Green: suppressed
      0.02, 0.10, -0.04,  // Aqua: cold metallic reflections
      0.00, 0.15, -0.08,  // Blue: armored suit slate
      0.00, -0.35, 0.00,  // Purple: neutral
      0.00, -0.35, 0.00,  // Magenta: neutral
    ],
  ),

  // ──────────────────────────────────────────────────────────────
  // 21. Anime: Makoto Shinkai — hyper-vibrant skies, cherry blossom pink
  MovieLook(
    name: 'Anime: Shinkai Sky',
    description:
        'Shinkai radiant: hyper-vibrant lapis sky, glowing golden sunset clouds, blooming highlights',
    reference: 'Your Name / Weathering With You · Makoto Shinkai',
    depthHint: 'character / sky',
    focalPoint: 0.50,
    focalRange: 0.30,
    bokehShape: 0, // circle
    blurAmount: 0.24,
    params: {
      'exposure': 0.12,
      'contrast': 0.16,
      'highlights': -0.10,
      'shadows': 0.20,
      'whites': 0.14,
      'blacks': -0.06,
      'clarity': 0.14,
      'texture': 0.16,
      'temperature': 0.04,
      'tint': 0.12,
      'vibrance': 0.55,
      'saturation': 0.30,
      'gradeShadowHue': 0.65,
      'gradeShadowSat': 0.36,
      'gradeShadowLum': 0.02,
      'gradeHighlightHue': 0.12,
      'gradeHighlightSat': 0.40,
      'gradeHighlightLum': 0.12,
      'gradeMidHue': 0.58,
      'gradeMidSat': 0.28,
      'gradeMidLum': 0.04,
      'gradeBlending': 0.60,
      'gradeBalance': 0.06,
      'filmBloom': 0.28,
      'filmHalation': 0.15,
    },
    hsl: [
      0.06, 0.42, 0.12,  // Red: red braided cord & shrine gate
      0.04, 0.45, 0.16,  // Orange: glowing golden hour clouds
      0.02, 0.40, 0.20,  // Yellow: brilliant lens flare
      0.08, 0.35, 0.05,  // Green: vibrant countryside hills
      0.02, 0.60, 0.14,  // Aqua: crystal clear lake reflection
      0.00, 0.65, 0.08,  // Blue: deep signature Shinkai lapis sky
      0.08, 0.48, 0.14,  // Purple: twilight magic hour
      0.10, 0.55, 0.20,  // Magenta: radiant sakura blossoms
    ],
  ),

  // ──────────────────────────────────────────────────────────────
  // 22. Anime: Studio Ghibli — organic hand-painted greens & cream whites
  MovieLook(
    name: 'Anime: Ghibli Garden',
    description:
        'Ghibli organic: hand-painted emerald greens, nostalgic cream whites, gentle daylight warmth',
    reference: 'Spirited Away / Totoro · Hayao Miyazaki',
    depthHint: 'subject in nature',
    focalPoint: 0.45,
    focalRange: 0.28,
    bokehShape: 0, // circle
    blurAmount: 0.18,
    params: {
      'exposure': 0.08,
      'contrast': 0.04,
      'highlights': -0.06,
      'shadows': 0.18,
      'whites': 0.04,
      'blacks': 0.02,
      'clarity': -0.04,
      'texture': 0.10,
      'temperature': 0.14,
      'tint': -0.08,
      'vibrance': 0.36,
      'saturation': 0.20,
      'gradeShadowHue': 0.30,
      'gradeShadowSat': 0.28,
      'gradeShadowLum': 0.04,
      'gradeHighlightHue': 0.12,
      'gradeHighlightSat': 0.24,
      'gradeHighlightLum': 0.06,
      'gradeMidHue': 0.25,
      'gradeMidSat': 0.22,
      'gradeMidLum': 0.02,
      'gradeBlending': 0.65,
      'gradeBalance': -0.08,
      'grain': 0.10,
      'grainSize': 0.14,
      'filmBloom': 0.14,
    },
    hsl: [
      0.04, 0.32, 0.08,  // Red: classic train & lacquer bridges
      0.02, 0.35, 0.12,  // Orange: warm character skin
      0.04, 0.38, 0.15,  // Yellow: soft afternoon sunlight
      0.06, 0.52, 0.08,  // Green: lush hand-painted Totoro moss
      0.02, 0.28, 0.06,  // Aqua: flowing river waters
      -0.05, 0.25, 0.02, // Blue: nostalgic summer sky
      0.02, 0.15, 0.05,  // Purple: gentle wild flowers
      0.06, 0.22, 0.08,  // Magenta: bathhouse lanterns
    ],
  ),

  // ──────────────────────────────────────────────────────────────
  // 23. Anime: Cyberpunk Neo-Tokyo — high-contrast laser red & acid green
  MovieLook(
    name: 'Anime: Neo-Tokyo',
    description:
        'Cyberpunk 1988: motorcycle taillight red, acidic neon green, deep dystopian black',
    reference: 'Akira (1988) · Katsuhiro Otomo',
    depthHint: 'rider / bike',
    focalPoint: 0.44,
    focalRange: 0.18,
    bokehShape: 2, // hexagon
    blurAmount: 0.34,
    params: {
      'exposure': -0.02,
      'contrast': 0.32,
      'highlights': -0.15,
      'shadows': 0.08,
      'whites': 0.18,
      'blacks': -0.18,
      'clarity': 0.34,
      'texture': 0.28,
      'dehaze': 0.16,
      'temperature': -0.04,
      'tint': 0.08,
      'vibrance': 0.40,
      'saturation': 0.26,
      'gradeShadowHue': 0.62,
      'gradeShadowSat': 0.40,
      'gradeShadowLum': -0.10,
      'gradeHighlightHue': 0.0,
      'gradeHighlightSat': 0.48,
      'gradeHighlightLum': 0.12,
      'gradeMidHue': 0.40,
      'gradeMidSat': 0.28,
      'gradeMidLum': 0.0,
      'gradeBlending': 0.55,
      'gradeBalance': 0.02,
      'filmBloom': 0.24,
      'filmHalation': 0.26,
      'grain': 0.18,
      'grainSize': 0.20,
    },
    hsl: [
      0.00, 0.60, 0.14,  // Red: iconic Kaneda bike vermilion
      0.02, 0.35, 0.10,  // Orange: neon explosion flame
      -0.08, 0.25, 0.12, // Yellow: hazard stripes
      0.04, 0.52, 0.10,  // Green: acid laser telemetry
      0.00, 0.42, 0.04,  // Aqua: holographic displays
      -0.02, 0.35, -0.06,// Blue: Olympic stadium night
      0.05, 0.38, 0.08,  // Purple: underground lab
      0.08, 0.45, 0.12,  // Magenta: high-voltage capacitor
    ],
  ),

  // ──────────────────────────────────────────────────────────────
  // 24. Anime: Retro 90s Cel — warm vintage saturation & pastel shadows
  MovieLook(
    name: 'Anime: 90s Retro Cel',
    description:
        'Vintage cel animation: warm saturated primaries, soft pastel shadows, nostalgic grain',
    reference: 'Evangelion / Cowboy Bebop (1995–1998)',
    depthHint: 'character',
    focalPoint: 0.45,
    focalRange: 0.25,
    bokehShape: 0, // circle
    blurAmount: 0.20,
    params: {
      'exposure': 0.05,
      'contrast': 0.12,
      'highlights': -0.08,
      'shadows': 0.14,
      'whites': 0.06,
      'blacks': -0.04,
      'clarity': 0.08,
      'texture': 0.14,
      'temperature': 0.12,
      'tint': 0.06,
      'vibrance': 0.30,
      'saturation': 0.16,
      'gradeShadowHue': 0.58,
      'gradeShadowSat': 0.24,
      'gradeShadowLum': 0.02,
      'gradeHighlightHue': 0.10,
      'gradeHighlightSat': 0.26,
      'gradeHighlightLum': 0.06,
      'gradeMidHue': 0.08,
      'gradeMidSat': 0.20,
      'gradeMidLum': 0.02,
      'gradeBlending': 0.60,
      'gradeBalance': -0.06,
      'grain': 0.22,
      'grainSize': 0.24,
      'filmBloom': 0.12,
      'filmDust': 0.05,
    },
    hsl: [
      0.02, 0.38, 0.06,  // Red: plugsuit crimson
      0.04, 0.34, 0.10,  // Orange: warm apartment sunset
      0.00, 0.28, 0.12,  // Yellow: analog CRT monitors
      0.04, 0.30, 0.02,  // Green: GeoFront greenery
      -0.02, 0.26, 0.04, // Aqua: pastel shadow tint
      -0.02, 0.32, -0.02,// Blue: Tokyo-3 afternoon sky
      0.08, 0.40, 0.08,  // Purple: Unit-01 primary purple
      0.06, 0.32, 0.10,  // Magenta: sunset horizon
    ],
  ),

  // ──────────────────────────────────────────────────────────────
  // 25. Oppenheimer — 65mm IMAX silver halide split-tone & nuclear highlights
  MovieLook(
    name: 'Oppenheimer',
    description:
        '65mm IMAX split-tone: intense dynamic range, deep silver shadows, warm incandescent highlights, gritty microcontrast',
    reference: 'Oppenheimer (2023, Christopher Nolan / Hoyte van Hoytema)',
    depthHint: 'subject',
    focalPoint: 0.45,
    focalRange: 0.20,
    bokehShape: 2, // hexagon (IMAX aperture)
    blurAmount: 0.35,
    params: {
      'exposure': 0.04,
      'contrast': 0.28,
      'highlights': 0.14,
      'shadows': -0.16,
      'whites': 0.18,
      'blacks': -0.14,
      'clarity': 0.26,
      'texture': 0.30,
      'dehaze': 0.10,
      'temperature': 0.08,
      'tint': -0.04,
      'vibrance': -0.12,
      'saturation': -0.08,
      'gradeShadowHue': 0.60,
      'gradeShadowSat': 0.14,
      'gradeShadowLum': -0.06,
      'gradeHighlightHue': 0.12,
      'gradeHighlightSat': 0.30,
      'gradeHighlightLum': 0.10,
      'gradeMidHue': 0.08,
      'gradeMidSat': 0.12,
      'gradeMidLum': 0.00,
      'gradeBlending': 0.62,
      'gradeBalance': 0.10,
      'grain': 0.28,
      'grainSize': 0.18,
      'filmBloom': 0.16,
      'filmHalation': 0.18,
    },
    hsl: [
      0.00, 0.15, -0.04, // Red: muted flesh & fire
      0.02, 0.22, 0.08,  // Orange: warm desert incandescent glow
      -0.02, 0.18, 0.12, // Yellow: nuclear flash highlights
      -0.04, -0.30, -0.08,// Green: muted foliage
      0.00, -0.25, -0.05, // Aqua: suppressed sky
      0.04, -0.18, -0.12, // Blue: deep charcoal sky
      0.00, -0.20, -0.05, // Purple: neutral
      0.00, -0.15, 0.00,  // Magenta: neutral
    ],
  ),

  // ──────────────────────────────────────────────────────────────
  // 26. Interstellar — warm dust-bowl amber earth vs cold deep space
  MovieLook(
    name: 'Interstellar',
    description:
        'Warm dust-bowl amber earth tones against cold deep space cyan highlights, organic 70mm film halation',
    reference: 'Interstellar (2014, Christopher Nolan / Hoyte van Hoytema)',
    depthHint: 'spacewalker',
    focalPoint: 0.50,
    focalRange: 0.25,
    bokehShape: 0, // circle
    blurAmount: 0.30,
    params: {
      'exposure': 0.02,
      'contrast': 0.18,
      'highlights': -0.10,
      'shadows': 0.08,
      'whites': 0.10,
      'blacks': -0.08,
      'clarity': 0.16,
      'texture': 0.20,
      'dehaze': 0.08,
      'temperature': 0.14,
      'tint': 0.02,
      'vibrance': 0.16,
      'saturation': 0.06,
      'gradeShadowHue': 0.10,
      'gradeShadowSat': 0.22,
      'gradeShadowLum': -0.02,
      'gradeHighlightHue': 0.54,
      'gradeHighlightSat': 0.20,
      'gradeHighlightLum': 0.06,
      'gradeMidHue': 0.11,
      'gradeMidSat': 0.18,
      'gradeMidLum': 0.02,
      'gradeBlending': 0.58,
      'gradeBalance': -0.08,
      'grain': 0.20,
      'grainSize': 0.20,
      'filmBloom': 0.14,
      'filmHalation': 0.14,
    },
    hsl: [
      0.02, 0.25, 0.04,  // Red: earth dust
      0.04, 0.38, 0.08,  // Orange: cornfield harvest gold
      0.02, 0.32, 0.10,  // Yellow: warm sunlight
      0.00, -0.15, -0.04,// Green: dying crops
      0.02, 0.20, 0.06,  // Aqua: wormhole cyan
      -0.02, 0.28, -0.08,// Blue: gargantua accretion disk & cosmic void
      0.04, 0.12, 0.00,  // Purple: deep space
      0.00, 0.10, 0.02,  // Magenta: subtle rim
    ],
  ),

  // ──────────────────────────────────────────────────────────────
  // 27. Pulp Fiction — 90s saturated Technicolor pop & diner golden warmth
  MovieLook(
    name: 'Pulp Fiction',
    description:
        'Saturated 90s warm Technicolor: golden skin tones, rich diner reds, bold black shadows, punchy retro contrast',
    reference: 'Pulp Fiction (1994, Quentin Tarantino / Andrzej Sekuła)',
    depthHint: 'portrait',
    focalPoint: 0.45,
    focalRange: 0.25,
    bokehShape: 1, // pentagon
    blurAmount: 0.25,
    params: {
      'exposure': 0.06,
      'contrast': 0.24,
      'highlights': -0.06,
      'shadows': 0.06,
      'whites': 0.14,
      'blacks': -0.12,
      'clarity': 0.18,
      'texture': 0.16,
      'temperature': 0.16,
      'tint': 0.08,
      'vibrance': 0.26,
      'saturation': 0.18,
      'gradeShadowHue': 0.08,
      'gradeShadowSat': 0.16,
      'gradeShadowLum': -0.04,
      'gradeHighlightHue': 0.12,
      'gradeHighlightSat': 0.24,
      'gradeHighlightLum': 0.08,
      'gradeMidHue': 0.10,
      'gradeMidSat': 0.22,
      'gradeMidLum': 0.04,
      'gradeBlending': 0.55,
      'gradeBalance': 0.04,
      'grain': 0.18,
      'grainSize': 0.22,
      'filmBloom': 0.08,
    },
    hsl: [
      0.02, 0.45, 0.10,  // Red: diner vinyl booths & cherry milkshakes
      0.04, 0.38, 0.12,  // Orange: golden retro skin tones
      0.00, 0.32, 0.14,  // Yellow: glowing briefcase mystery
      -0.02, 0.10, 0.00, // Green: subtle palm trees
      -0.04, 0.05, 0.02, // Aqua: retro motel tile
      -0.02, 0.15, -0.08,// Blue: dark tailored suits
      0.02, 0.15, 0.02,  // Purple: night club neon
      0.04, 0.24, 0.06,  // Magenta: lipstick pop
    ],
  ),

  // ──────────────────────────────────────────────────────────────
  // 28. Fight Club — Fincher sickly yellow-green fluorescent & cold cyan base
  MovieLook(
    name: 'Fight Club',
    description:
        'Fincher aesthetic: sickly yellow-green fluorescent cast, cold cyan basement shadows, desaturated skin, gritty contrast',
    reference: 'Fight Club (1999, David Fincher / Jeff Cronenweth)',
    depthHint: 'face',
    focalPoint: 0.40,
    focalRange: 0.20,
    bokehShape: 1, // pentagon
    blurAmount: 0.22,
    params: {
      'exposure': -0.04,
      'contrast': 0.26,
      'highlights': -0.12,
      'shadows': -0.06,
      'whites': 0.08,
      'blacks': -0.14,
      'clarity': 0.30,
      'texture': 0.28,
      'dehaze': 0.12,
      'temperature': -0.06,
      'tint': -0.18, // heavy green cast
      'vibrance': -0.16,
      'saturation': -0.12,
      'gradeShadowHue': 0.50,
      'gradeShadowSat': 0.30,
      'gradeShadowLum': -0.06,
      'gradeHighlightHue': 0.22,
      'gradeHighlightSat': 0.32,
      'gradeHighlightLum': 0.04,
      'gradeMidHue': 0.24,
      'gradeMidSat': 0.24,
      'gradeMidLum': -0.02,
      'gradeBlending': 0.65,
      'gradeBalance': -0.10,
      'grain': 0.24,
      'grainSize': 0.20,
    },
    hsl: [
      -0.02, -0.10, -0.04,// Red: bruised flesh
      -0.04, -0.14, 0.00, // Orange: pale insomniac skin
      0.06, 0.30, 0.08,  // Yellow: sickly fluorescent lighting
      0.04, 0.35, 0.02,  // Green: basement concrete & soap
      0.00, 0.28, -0.04, // Aqua: dirty tile shadows
      -0.04, 0.18, -0.14,// Blue: cold midnight drizzle
      -0.02, -0.10, -0.06,// Purple: neutral
      -0.02, -0.15, -0.02,// Magenta: neutral
    ],
  ),

  // ──────────────────────────────────────────────────────────────
  // 29. La La Land — twilight Technicolor royal blues & electric magenta-violet
  MovieLook(
    name: 'La La Land',
    description:
        'Twilight Technicolor: royal blue shadows, vivid magenta/violet rim highlights, warm streetlamp glow, dreamy optical bloom',
    reference: 'La La Land (2016, Damien Chazelle / Linus Sandgren)',
    depthHint: 'dancers',
    focalPoint: 0.50,
    focalRange: 0.30,
    bokehShape: 5, // soap bubble (dreamy optical)
    blurAmount: 0.35,
    params: {
      'exposure': 0.08,
      'contrast': 0.18,
      'highlights': -0.04,
      'shadows': 0.10,
      'whites': 0.12,
      'blacks': -0.06,
      'clarity': 0.08,
      'texture': 0.14,
      'temperature': 0.04,
      'tint': 0.14, // magenta twilight bias
      'vibrance': 0.36,
      'saturation': 0.24,
      'gradeShadowHue': 0.64,
      'gradeShadowSat': 0.32,
      'gradeShadowLum': 0.02,
      'gradeHighlightHue': 0.86,
      'gradeHighlightSat': 0.30,
      'gradeHighlightLum': 0.08,
      'gradeMidHue': 0.14,
      'gradeMidSat': 0.22,
      'gradeMidLum': 0.04,
      'gradeBlending': 0.58,
      'gradeBalance': 0.02,
      'grain': 0.12,
      'grainSize': 0.16,
      'filmBloom': 0.24,
      'filmHalation': 0.16,
    },
    hsl: [
      0.02, 0.40, 0.12,  // Red: classic dress pop
      0.04, 0.38, 0.10,  // Orange: sunset horizon
      -0.04, 0.55, 0.20, // Yellow: iconic tap-dance dress
      0.04, 0.25, 0.06,  // Green: Griffith Park foliage
      0.02, 0.30, 0.08,  // Aqua: twilight sky transition
      -0.02, 0.45, 0.04, // Blue: magic hour twilight deep sky
      0.06, 0.48, 0.12,  // Purple: planetarium dreamscape
      0.08, 0.44, 0.14,  // Magenta: streetlamp rim glow
    ],
  ),

  // ──────────────────────────────────────────────────────────────
  // 30. Blade Runner (1982) — Jordan Cronenweth neo-noir & anamorphic cat's eye
  MovieLook(
    name: 'Blade Runner (1982)',
    description:
        'Jordan Cronenweth neo-noir: midnight blue shadows, smoking amber neon rims, anamorphic cat’s eye bokeh, high contrast',
    reference: 'Blade Runner (1982, Ridley Scott / Jordan Cronenweth)',
    depthHint: 'detective',
    focalPoint: 0.45,
    focalRange: 0.22,
    bokehShape: 4, // cat's eye (anamorphic lens)
    blurAmount: 0.38,
    params: {
      'exposure': -0.06,
      'contrast': 0.32,
      'highlights': 0.08,
      'shadows': -0.14,
      'whites': 0.16,
      'blacks': -0.20,
      'clarity': 0.24,
      'texture': 0.26,
      'dehaze': 0.16,
      'temperature': -0.08,
      'tint': 0.08,
      'vibrance': 0.18,
      'saturation': 0.10,
      'gradeShadowHue': 0.62,
      'gradeShadowSat': 0.38,
      'gradeShadowLum': -0.08,
      'gradeHighlightHue': 0.12,
      'gradeHighlightSat': 0.38,
      'gradeHighlightLum': 0.10,
      'gradeMidHue': 0.58,
      'gradeMidSat': 0.18,
      'gradeMidLum': -0.04,
      'gradeBlending': 0.68,
      'gradeBalance': -0.12,
      'grain': 0.30,
      'grainSize': 0.26,
      'filmBloom': 0.26,
      'filmHalation': 0.24,
      'filmScratches': 0.04,
    },
    hsl: [
      0.00, 0.40, 0.06,  // Red: spinner taillights
      0.04, 0.48, 0.14,  // Orange: Tyrell pyramid incandescent sodium
      0.00, 0.35, 0.12,  // Yellow: Chinatown street food smoke
      -0.02, 0.25, -0.04,// Green: glowing umbrella stems
      0.02, 0.32, 0.02,  // Aqua: neon billboards
      -0.02, 0.44, -0.12,// Blue: rain-soaked LA night
      0.04, 0.30, -0.02, // Purple: smoky back-alleys
      0.06, 0.36, 0.08,  // Magenta: neon reflections
    ],
  ),

  // ──────────────────────────────────────────────────────────────
  // 31. The Revenant — Chivo natural freezing light & crisp glacial textures
  MovieLook(
    name: 'The Revenant',
    description:
        'Chivo Lubezki natural freezing light: cold blue shadows, desaturated glacial tones, hyper-crisp edge texture',
    reference: 'The Revenant (2015, Alejandro G. Iñárritu / Emmanuel Lubezki)',
    depthHint: 'wilderness subject',
    focalPoint: 0.48,
    focalRange: 0.35,
    bokehShape: 0, // circle
    blurAmount: 0.18,
    params: {
      'exposure': 0.02,
      'contrast': 0.22,
      'highlights': -0.18,
      'shadows': 0.06,
      'whites': 0.14,
      'blacks': -0.10,
      'clarity': 0.34,
      'texture': 0.36,
      'dehaze': 0.18,
      'temperature': -0.18, // freezing cold natural light
      'tint': -0.04,
      'vibrance': -0.20,
      'saturation': -0.16,
      'gradeShadowHue': 0.58,
      'gradeShadowSat': 0.24,
      'gradeShadowLum': -0.04,
      'gradeHighlightHue': 0.52,
      'gradeHighlightSat': 0.16,
      'gradeHighlightLum': 0.06,
      'gradeMidHue': 0.56,
      'gradeMidSat': 0.12,
      'gradeMidLum': 0.00,
      'gradeBlending': 0.55,
      'gradeBalance': -0.14,
      'grain': 0.14,
      'grainSize': 0.16,
    },
    hsl: [
      -0.04, 0.10, -0.08,// Red: raw survival blood
      -0.02, -0.15, -0.02,// Orange: cold weather-beaten skin
      -0.04, -0.22, 0.04, // Yellow: muted winter sunlight
      -0.06, -0.30, -0.10,// Green: frozen boreal pine
      0.02, 0.22, 0.06,  // Aqua: glacial mountain melt
      0.00, 0.26, -0.06, // Blue: arctic sky & frost
      -0.02, -0.18, -0.06,// Purple: neutral
      0.00, -0.20, 0.00,  // Magenta: neutral
    ],
  ),

  // ──────────────────────────────────────────────────────────────
  // 32. Drive — synthwave neon: electric hot pink highlights & midnight cyan
  MovieLook(
    name: 'Drive',
    description:
        '80s synthwave neon: electric hot magenta highlights, deep midnight cyan shadows, slick asphalt night reflections',
    reference: 'Drive (2011, Nicolas Winding Refn / Newton Thomas Sigel)',
    depthHint: 'driver',
    focalPoint: 0.42,
    focalRange: 0.20,
    bokehShape: 4, // cat's eye
    blurAmount: 0.32,
    params: {
      'exposure': 0.00,
      'contrast': 0.28,
      'highlights': 0.10,
      'shadows': -0.12,
      'whites': 0.14,
      'blacks': -0.16,
      'clarity': 0.22,
      'texture': 0.20,
      'dehaze': 0.10,
      'temperature': -0.06,
      'tint': 0.12,
      'vibrance': 0.32,
      'saturation': 0.16,
      'gradeShadowHue': 0.52,
      'gradeShadowSat': 0.36,
      'gradeShadowLum': -0.08,
      'gradeHighlightHue': 0.88, // hot magenta/pink
      'gradeHighlightSat': 0.42,
      'gradeHighlightLum': 0.12,
      'gradeMidHue': 0.60,
      'gradeMidSat': 0.20,
      'gradeMidLum': -0.02,
      'gradeBlending': 0.62,
      'gradeBalance': -0.06,
      'grain': 0.16,
      'grainSize': 0.18,
      'filmBloom': 0.20,
    },
    hsl: [
      0.04, 0.35, 0.06,  // Red: scorpion jacket embroidery
      0.02, 0.28, 0.08,  // Orange: sodium streetlamp glow
      0.00, 0.20, 0.10,  // Yellow: diner counter warmth
      -0.02, 0.12, -0.04,// Green: traffic lights
      0.04, 0.40, 0.04,  // Aqua: wet asphalt reflections
      -0.02, 0.38, -0.12,// Blue: Los Angeles midnight sky
      0.08, 0.46, 0.10,  // Purple: synthwave neon haze
      0.10, 0.56, 0.16,  // Magenta: electric pink opening title credit
    ],
  ),

  // ──────────────────────────────────────────────────────────────
  // 33. Anime: Spirited Away — Ghibli hand-painted gouache & lantern amber
  MovieLook(
    name: 'Anime: Spirited Away',
    description:
        'Studio Ghibli hand-painted gouache: emerald bathhouse moss, lantern warm amber, soft twilight cyan, nostalgic harmony',
    reference: 'Spirited Away (2001, Hayao Miyazaki / Studio Ghibli)',
    depthHint: 'spirit world subject',
    focalPoint: 0.45,
    focalRange: 0.25,
    bokehShape: 0, // circle
    blurAmount: 0.25,
    params: {
      'exposure': 0.08,
      'contrast': 0.12,
      'highlights': -0.06,
      'shadows': 0.12,
      'whites': 0.08,
      'blacks': -0.04,
      'clarity': 0.10,
      'texture': 0.18,
      'temperature': 0.08,
      'tint': 0.04,
      'vibrance': 0.32,
      'saturation': 0.20,
      'gradeShadowHue': 0.48, // soft teal shadow
      'gradeShadowSat': 0.18,
      'gradeShadowLum': 0.02,
      'gradeHighlightHue': 0.12, // warm golden lantern
      'gradeHighlightSat': 0.24,
      'gradeHighlightLum': 0.06,
      'gradeMidHue': 0.10,
      'gradeMidSat': 0.16,
      'gradeMidLum': 0.04,
      'gradeBlending': 0.54,
      'gradeBalance': 0.02,
      'grain': 0.12,
      'grainSize': 0.16,
      'filmBloom': 0.14,
    },
    hsl: [
      0.02, 0.38, 0.08,  // Red: red bridge railing & bathhouse banners
      0.04, 0.40, 0.10,  // Orange: paper lanterns at dusk
      0.02, 0.34, 0.14,  // Yellow: evening banquet feast
      0.06, 0.44, 0.12,  // Green: lush moss & spirit garden foliage
      0.02, 0.36, 0.08,  // Aqua: flooding train ocean water
      -0.02, 0.30, 0.02, // Blue: soft twilight sky
      0.04, 0.25, 0.06,  // Purple: spirit flowers
      0.04, 0.28, 0.08,  // Magenta: sunset horizon clouds
    ],
  ),

  // ──────────────────────────────────────────────────────────────
  // 34. Anime: Cyberpunk Edgerunners — fluorescent cyber-yellow & electric aqua
  MovieLook(
    name: 'Anime: Cyberpunk Edgerunners',
    description:
        'Trigger anime grade: blinding fluorescent cyber-yellow, electric aqua neon, deep jet-black contrast, hyper-energy punch',
    reference: 'Cyberpunk: Edgerunners (2022, Hiroyuki Imaishi / Studio Trigger)',
    depthHint: 'edgerunner',
    focalPoint: 0.40,
    focalRange: 0.18,
    bokehShape: 2, // hexagon
    blurAmount: 0.30,
    params: {
      'exposure': 0.04,
      'contrast': 0.32,
      'highlights': 0.16,
      'shadows': -0.16,
      'whites': 0.20,
      'blacks': -0.22,
      'clarity': 0.32,
      'texture': 0.26,
      'dehaze': 0.14,
      'temperature': 0.02,
      'tint': -0.06,
      'vibrance': 0.44,
      'saturation': 0.28,
      'gradeShadowHue': 0.52,
      'gradeShadowSat': 0.42,
      'gradeShadowLum': -0.10,
      'gradeHighlightHue': 0.16, // neon cyber yellow
      'gradeHighlightSat': 0.50,
      'gradeHighlightLum': 0.14,
      'gradeMidHue': 0.14,
      'gradeMidSat': 0.28,
      'gradeMidLum': 0.02,
      'gradeBlending': 0.65,
      'gradeBalance': 0.06,
      'grain': 0.18,
      'grainSize': 0.20,
      'filmBloom': 0.28,
      'filmHalation': 0.22,
    },
    hsl: [
      0.02, 0.55, 0.12,  // Red: Sandevistan trail speedlines
      0.04, 0.48, 0.14,  // Orange: heavy muzzle blast
      -0.02, 0.70, 0.22, // Yellow: iconic Martinez cyber jacket
      0.06, 0.50, 0.10,  // Green: digital cyberware HUD
      0.02, 0.62, 0.12,  // Aqua: Lucy neon hair highlights
      -0.02, 0.45, -0.10,// Blue: Night City megabuilding canyons
      0.06, 0.52, 0.14,  // Purple: holographic braindance
      0.08, 0.58, 0.16,  // Magenta: high-voltage electric discharge
    ],
  ),
];

/// Helper returning [movieLooks] as a flat list of [ToolDefinition] instances.
List<ToolDefinition> movieLookTools() =>
    movieLooks.map((l) => l.toToolDefinition()).toList();
