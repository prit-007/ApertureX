// Movie-reference grading presets that acknowledge subjects and depth.
//
// These presets ship as [ToolDefinition] entries so they can be applied from
// the Looks Sheet like any built-in look. Each preset carries optional depth /
// lens-blur parameters (`blurEnabled`, `blurAmount`, `blurFocalPoint`,
// `blurFocalRange`, `blurBokehShape`, `blurBokehBoost`, `blurBackgroundBlur`)
// which, when applied, route through the Depth Anything V2 monocular depth
// model (bundled ONNX, ~14 MB INT8) via `estimateDepthMapWithModel` and
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
    this.depthHint,
    this.focalPoint = 0.5,
    this.focalRange = 0.25,
    this.bokehShape = 1,
    this.blurAmount = 0.0,
  });

  final String name;
  final String description;
  final String reference; // movie title + year
  final Map<String, double> params;
  final String? depthHint; // e.g. 'eyes', 'face', 'subject center'
  final double focalPoint;   // 0..1 depth plane in focus
  final double focalRange;   // 0..1 DOF range
  final int bokehShape;      // 0 circle .. 5 soap bubble
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
    );
  }
}

/// Movie-reference grading presets with subject-aware depth fall-off.
const List<MovieLook> movieLooks = [
  // ──────────────────────────────────────────────────────────────
  // 1. Blade Runner 2049 — neon-noir, orange shadows, teal highlights,
  //    shallow depth on the subject's face.
  MovieLook(
    name: 'Blade Runner 2049',
    description:
        'Neon-noir: crushed teal shadows, smoky orange highlights, shallow depth on face',
    reference: 'Blade Runner 2049 (2017)',
    depthHint: 'eyes',
    focalPoint: 0.45,
    focalRange: 0.20,
    bokehShape: 1, // pentagon
    blurAmount: 0.35,
    params: {
      'contrast': 0.20,
      'highlights': -0.25,
      'shadows': 0.15,
      'whites': 0.08,
      'blacks': -0.12,
      'temperature': -0.08,
      'tint': 0.05,
      'vibrance': 0.22,
      'saturation': 0.10,
      'gradeShadowHue': 0.55,
      'gradeShadowSat': 0.42,
      'gradeShadowLum': -0.08,
      'gradeHighlightHue': 0.12,
      'gradeHighlightSat': 0.35,
      'gradeMidHue': 0.30,
      'gradeMidSat': 0.20,
      'gradeBlending': 0.55,
      'grain': 0.18,
      'grainSize': 0.22,
      'filmHalation': 0.12,
      'filmBloom': 0.08,
    },
  ),

  // ──────────────────────────────────────────────────────────────
  // 2. The Grand Budapest Hotel — pastel pink/purple, symmetrical,
  //    deep focus, almost everything sharp.
  MovieLook(
    name: 'Grand Budapest',
    description:
        'Wes Anderson pastel: pink-magenta shadows, cream highlights, deep focus',
    reference: 'The Grand Budapest Hotel (2014)',
    depthHint: 'full frame',
    focalPoint: 0.55,
    focalRange: 0.60,
    bokehShape: 0, // circle
    blurAmount: 0.05,
    params: {
      'contrast': -0.10,
      'highlights': -0.10,
      'shadows': 0.05,
      'temperature': 0.05,
      'tint': 0.12,
      'vibrance': 0.28,
      'saturation': 0.25,
      'gradeShadowHue': 0.62,
      'gradeShadowSat': 0.30,
      'gradeHighlightHue': 0.05,
      'gradeHighlightSat': 0.10,
      'gradeMidHue': 0.25,
      'gradeMidSat': 0.15,
      'gradeBlending': 0.50,
      'vignette': -0.10,
      'grain': 0.08,
    },
  ),

  // ──────────────────────────────────────────────────────────────
  // 3. Inception — cold blue-grey shadows, warm gold highlights,
  //    medium depth with falling-off background.
  MovieLook(
    name: 'Inception',
    description:
        'Hans Zimmer cold: blue-grey shadows, gold highlights, falling-off background',
    reference: 'Inception (2010)',
    depthHint: 'subject',
    focalPoint: 0.50,
    focalRange: 0.30,
    bokehShape: 2, // hexagon
    blurAmount: 0.30,
    params: {
      'contrast': 0.18,
      'highlights': -0.18,
      'shadows': 0.10,
      'temperature': -0.12,
      'tint': -0.02,
      'vibrance': 0.16,
      'saturation': -0.05,
      'gradeShadowHue': 0.48,
      'gradeShadowSat': 0.38,
      'gradeHighlightHue': 0.10,
      'gradeHighlightSat': 0.28,
      'gradeMidHue': 0.20,
      'gradeMidSat': 0.15,
      'gradeBlending': 0.60,
      'grain': 0.14,
      'filmBloom': 0.10,
      'filmHalation': 0.08,
    },
  ),

  // ──────────────────────────────────────────────────────────────
  // 4. Amélie — green/yellow split, high saturation, shallow depth,
  //    portrait subject sharp, background creamy.
  MovieLook(
    name: 'Amélie',
    description:
        'Jean-Pierre Jeunet: green shadows, yellow highlights, saturated, shallow depth',
    reference: 'Amélie (2001)',
    depthHint: 'face',
    focalPoint: 0.40,
    focalRange: 0.18,
    bokehShape: 5, // soap bubble
    blurAmount: 0.45,
    params: {
      'contrast': 0.08,
      'highlights': -0.12,
      'shadows': 0.08,
      'temperature': 0.02,
      'tint': -0.02,
      'vibrance': 0.32,
      'saturation': 0.22,
      'gradeShadowHue': 0.40,
      'gradeShadowSat': 0.45,
      'gradeHighlightHue': 0.02,
      'gradeHighlightSat': 0.38,
      'gradeMidHue': 0.35,
      'gradeMidSat': 0.25,
      'gradeBlending': 0.50,
      'grain': 0.10,
      'filmBloom': 0.12,
    },
  ),

  // ──────────────────────────────────────────────────────────────
  // 5. The Godfather — deep amber shadows, warm highlights,
  //    medium depth, subject-centered.
  MovieLook(
    name: 'The Godfather',
    description:
        'Coppola: deep amber shadows, warm honey highlights, classic portrait depth',
    reference: 'The Godfather (1972)',
    depthHint: 'subject center',
    focalPoint: 0.50,
    focalRange: 0.28,
    bokehShape: 1, // pentagon
    blurAmount: 0.28,
    params: {
      'contrast': 0.25,
      'highlights': -0.15,
      'shadows': 0.10,
      'temperature': 0.10,
      'tint': 0.02,
      'vibrance': 0.10,
      'saturation': -0.08,
      'gradeShadowHue': 0.12,
      'gradeShadowSat': 0.35,
      'gradeHighlightHue': 0.05,
      'gradeHighlightSat': 0.18,
      'gradeMidHue': 0.15,
      'gradeMidSat': 0.12,
      'gradeBlending': 0.55,
      'blacks': -0.10,
      'grain': 0.20,
    },
  ),

  // ──────────────────────────────────────────────────────────────
  // 6. Dunkirk — cold desaturated, blue-grey, deep focus,
  //    everything sharp for IMAX scale.
  MovieLook(
    name: 'Dunkirk',
    description:
        'Christopher Nolan: cold desaturated blue-grey, deep IMAX focus',
    reference: 'Dunkirk (2017)',
    depthHint: 'full frame',
    focalPoint: 0.60,
    focalRange: 0.70,
    bokehShape: 0, // circle
    blurAmount: 0.0,
    params: {
      'contrast': 0.15,
      'highlights': -0.20,
      'shadows': 0.05,
      'temperature': -0.18,
      'tint': -0.04,
      'vibrance': -0.10,
      'saturation': -0.20,
      'gradeShadowHue': 0.45,
      'gradeShadowSat': 0.20,
      'gradeHighlightHue': 0.40,
      'gradeHighlightSat': 0.15,
      'gradeMidHue': 0.40,
      'gradeMidSat': 0.05,
      'gradeBlending': 0.45,
      'clarity': 0.20,
      'grain': 0.12,
    },
  ),

  // ──────────────────────────────────────────────────────────────
  // 7. Moonlight — purple/blue shadows, pink highlights,
  //    very shallow depth, subject isolated.
  MovieLook(
    name: 'Moonlight',
    description:
        'Barry Jenkins: purple-blue shadows, pink highlights, very shallow depth',
    reference: 'Moonlight (2016)',
    depthHint: 'face',
    focalPoint: 0.35,
    focalRange: 0.15,
    bokehShape: 5, // soap bubble
    blurAmount: 0.55,
    params: {
      'contrast': 0.10,
      'highlights': -0.10,
      'shadows': 0.12,
      'temperature': -0.02,
      'tint': 0.08,
      'vibrance': 0.28,
      'saturation': 0.15,
      'gradeShadowHue': 0.52,
      'gradeShadowSat': 0.50,
      'gradeHighlightHue': 0.02,
      'gradeHighlightSat': 0.45,
      'gradeMidHue': 0.30,
      'gradeMidSat': 0.25,
      'gradeBlending': 0.50,
      'grain': 0.15,
      'filmBloom': 0.10,
    },
  ),

  // ──────────────────────────────────────────────────────────────
  // 8. Mad Max: Fury Road — orange dust, high contrast,
  //    medium depth, sharp subject, blown-out background.
  MovieLook(
    name: 'Mad Max Fury Road',
    description:
        'George Miller: orange dust, high contrast, blown-out background',
    reference: 'Mad Max: Fury Road (2015)',
    depthHint: 'subject',
    focalPoint: 0.45,
    focalRange: 0.35,
    bokehShape: 3, // septagon
    blurAmount: 0.32,
    params: {
      'contrast': 0.32,
      'highlights': -0.35,
      'shadows': 0.05,
      'temperature': 0.15,
      'tint': 0.02,
      'vibrance': 0.25,
      'saturation': 0.10,
      'gradeShadowHue': 0.15,
      'gradeShadowSat': 0.45,
      'gradeHighlightHue': 0.08,
      'gradeHighlightSat': 0.35,
      'gradeMidHue': 0.20,
      'gradeMidSat': 0.20,
      'gradeBlending': 0.60,
      'blacks': -0.15,
      'grain': 0.22,
      'filmHalation': 0.15,
    },
  ),

  // ──────────────────────────────────────────────────────────────
  // 9. Her — soft orange/pink, warm glow, shallow depth,
  //    intimate subject focus.
  MovieLook(
    name: 'Her',
    description:
        'Spike Jonze: soft orange-pink glow, warm, intimate shallow depth',
    reference: 'Her (2013)',
    depthHint: 'face',
    focalPoint: 0.42,
    focalRange: 0.22,
    bokehShape: 5, // soap bubble
    blurAmount: 0.40,
    params: {
      'contrast': -0.05,
      'highlights': -0.08,
      'shadows': 0.05,
      'temperature': 0.12,
      'tint': 0.06,
      'vibrance': 0.15,
      'saturation': 0.08,
      'gradeShadowHue': 0.10,
      'gradeShadowSat': 0.25,
      'gradeHighlightHue': 0.02,
      'gradeHighlightSat': 0.20,
      'gradeMidHue': 0.10,
      'gradeMidSat': 0.15,
      'gradeBlending': 0.50,
      'grain': 0.08,
      'filmBloom': 0.15,
      'filmHalation': 0.10,
    },
  ),

  // ──────────────────────────────────────────────────────────────
  // 10. The Matrix — green tint, high contrast, deep focus,
  //     digital world feel.
  MovieLook(
    name: 'The Matrix',
    description:
        'The Wachowskis: green tint, high contrast, deep digital focus',
    reference: 'The Matrix (1999)',
    depthHint: 'full frame',
    focalPoint: 0.55,
    focalRange: 0.65,
    bokehShape: 0, // circle
    blurAmount: 0.0,
    params: {
      'contrast': 0.30,
      'highlights': -0.20,
      'shadows': 0.08,
      'temperature': -0.05,
      'tint': 0.15,
      'vibrance': 0.10,
      'saturation': -0.10,
      'gradeShadowHue': 0.42,
      'gradeShadowSat': 0.30,
      'gradeHighlightHue': 0.40,
      'gradeHighlightSat': 0.15,
      'gradeMidHue': 0.42,
      'gradeMidSat': 0.10,
      'gradeBlending': 0.40,
      'clarity': 0.25,
      'blacks': -0.10,
    },
  ),
];

/// Convert all [movieLooks] to [ToolDefinition] entries.
List<ToolDefinition> movieLookTools() =>
    movieLooks.map((l) => l.toToolDefinition()).toList();
