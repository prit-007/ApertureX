import 'dart:convert';

import 'look_qr_codec.dart';
import 'parameter.dart';
import 'recipe.dart';

import '../features/presets/cultural_travel_presets.dart';
import '../features/presets/movie_presets.dart';
import '../features/presets/nature_presets.dart';

/// A shareable **look**: a named patch of recipe parameters. Because it is just
/// JSON, looks can be imported/exported/shared (file, QR) — community "tools"
/// without arbitrary shader execution (#14; Flutter can't compile GLSL at
/// runtime, so a parameterized look format is the honest realization).
class ToolDefinition {
  const ToolDefinition({
    required this.name,
    this.description = '',
    required this.params,
    this.hsl,
  });

  factory ToolDefinition.fromJson(Map<String, Object?> json) => ToolDefinition(
    name: (json['name'] as String?) ?? 'Untitled',
    description: (json['description'] as String?) ?? '',
    params: {
      for (final e in (json['params'] as Map? ?? {}).entries)
        e.key.toString(): (e.value as num).toDouble(),
    },
    hsl: (json['hsl'] as List?)?.map((e) => (e as num).toDouble()).toList(),
  );

  final String name;
  final String description;

  /// `Parameter.name → value`.
  final Map<String, double> params;

  /// Optional HSL 8-band color mix `[r_h, r_s, r_l, ...]`.
  final List<double>? hsl;

  /// Applies this look onto [base] with optional [amount] scaling (0.0 to 2.0, default 1.0).
  ///
  /// At 1.0 (100%), full preset parameters are applied.
  /// At 0.0 (0%), parameters remain at neutral.
  /// Between 1.0 and 2.0 (100%-200%), parameters are boosted proportionally.
  EditRecipe applyTo(EditRecipe base, {double amount = 1.0}) {
    var recipe = base;
    for (final entry in params.entries) {
      final parameter = _parameterByName(entry.key);
      if (parameter != null) {
        if ((amount - 1.0).abs() < 0.001) {
          recipe = withValue(recipe, parameter, entry.value);
        } else {
          final spec = specOf(parameter);
          final baseVal = spec.neutral;
          final targetVal = entry.value;
          final effectiveVal = clampParameter(parameter, baseVal + (targetVal - baseVal) * amount);
          recipe = withValue(recipe, parameter, effectiveVal);
        }
      }
    }
    if (hsl != null && hsl!.isNotEmpty) {
      if ((amount - 1.0).abs() < 0.001) {
        recipe = recipe.copyWith(hsl: List<double>.from(hsl!));
      } else {
        final scaled = hsl!.map((v) => (v * amount).clamp(-1.0, 1.0)).toList();
        recipe = recipe.copyWith(hsl: scaled);
      }
    }
    return recipe;
  }

  /// Reports the parameter names this look references that we don't know.
  List<String> unknownParams() =>
      [for (final k in params.keys) if (_parameterByName(k) == null) k];

  Map<String, Object?> toJson() => {
    'name': name,
    'description': description,
    'params': params,
    if (hsl != null) 'hsl': hsl,
  };

  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());

  static ToolDefinition decode(String json) {
    final trimmed = json.trim();
    if (trimmed.startsWith('apx://')) {
      return LookQrCodec.decode(trimmed).toToolDefinition();
    }
    final decoded = jsonDecode(trimmed);
    if (decoded is! Map) {
      throw const FormatException('look is not a JSON object');
    }
    if (decoded.containsKey('p') || decoded.containsKey('params')) {
      return LookQrCodec.decode(trimmed).toToolDefinition();
    }
    return ToolDefinition.fromJson(decoded.cast<String, Object?>());
  }
}

Parameter? _parameterByName(String name) {
  for (final p in Parameter.values) {
    if (p.name == name) return p;
  }
  return null;
}

/// Helper to construct 8-band HSL list from individual band offsets.
/// Bands: 0:Red, 1:Orange, 2:Yellow, 3:Green, 4:Aqua, 5:Blue, 6:Purple, 7:Magenta.
/// Each band has hue, saturation, luminance in [-1.0, 1.0].
List<double> createHslBands({
  double redHue = 0, double redSat = 0, double redLum = 0,
  double orangeHue = 0, double orangeSat = 0, double orangeLum = 0,
  double yellowHue = 0, double yellowSat = 0, double yellowLum = 0,
  double greenHue = 0, double greenSat = 0, double greenLum = 0,
  double aquaHue = 0, double aquaSat = 0, double aquaLum = 0,
  double blueHue = 0, double blueSat = 0, double blueLum = 0,
  double purpleHue = 0, double purpleSat = 0, double purpleLum = 0,
  double magentaHue = 0, double magentaSat = 0, double magentaLum = 0,
}) {
  return [
    redHue, redSat, redLum,
    orangeHue, orangeSat, orangeLum,
    yellowHue, yellowSat, yellowLum,
    greenHue, greenSat, greenLum,
    aquaHue, aquaSat, aquaLum,
    blueHue, blueSat, blueLum,
    purpleHue, purpleSat, purpleLum,
    magentaHue, magentaSat, magentaLum,
  ];
}

/// Built-in looks (the "tool gallery").
class ToolLibrary {
  const ToolLibrary._();

  static const List<ToolDefinition> builtins = [
    ToolDefinition(
      name: 'Punch',
      description: 'Contrast + clarity pop',
      params: {
        'contrast': 0.30,
        'clarity': 0.30,
        'vibrance': 0.30,
        'whites': 0.10,
        'blacks': -0.15,
        'gradeShadowHue': 0.0,
        'gradeShadowSat': 0.0,
        'gradeShadowLum': -0.05,
        'gradeMidHue': 0.0,
        'gradeMidSat': 0.0,
        'gradeMidLum': 0.05,
        'gradeHighlightHue': 0.0,
        'gradeHighlightSat': 0.0,
        'gradeHighlightLum': 0.08,
        'gradeBlending': 0.50,
        'gradeBalance': 0.0,
        'blurFocalPoint': 0.50,
        'blurFocalRange': 0.25,
        'blurBokehShape': 0.0,
        'blurAmount': 0.0,
      },
      hsl: [
        0.0, 0.10, 0.0, // Red
        0.0, 0.05, 0.0, // Orange
        0.0, 0.05, 0.0, // Yellow
        0.0, 0.08, 0.0, // Green
        0.0, 0.05, 0.0, // Aqua
        0.0, 0.08, 0.0, // Blue
        0.0, 0.0, 0.0,  // Purple
        0.0, 0.0, 0.0,  // Magenta
      ],
    ),
    ToolDefinition(
      name: 'Soft Portrait',
      description: 'Gentle skin-friendly tone',
      params: {
        'contrast': -0.10,
        'highlights': -0.20,
        'shadows': 0.15,
        'clarity': -0.20,
        'vibrance': 0.15,
        'saturation': -0.05,
        'sharpen': 0.15,
        'gradeShadowHue': 0.08,
        'gradeShadowSat': 0.05,
        'gradeShadowLum': 0.05,
        'gradeMidHue': 0.08,
        'gradeMidSat': 0.08,
        'gradeMidLum': 0.02,
        'gradeHighlightHue': 0.12,
        'gradeHighlightSat': 0.10,
        'gradeHighlightLum': 0.0,
        'gradeBlending': 0.50,
        'gradeBalance': 0.05,
        'blurFocalPoint': 0.50,
        'blurFocalRange': 0.20,
        'blurBokehShape': 0.0,
        'blurAmount': 0.10,
      },
      hsl: [
        0.01, 0.02, 0.02, // Red
        0.02, 0.05, 0.04, // Orange
        0.0, 0.0, 0.0,    // Yellow
        0.0, 0.0, 0.0,    // Green
        0.0, 0.0, 0.0,    // Aqua
        0.0, 0.0, 0.0,    // Blue
        0.0, 0.0, 0.0,    // Purple
        0.0, 0.0, 0.0,    // Magenta
      ],
    ),
    ToolDefinition(
      name: 'Kodak Portra 160',
      description: 'Pat David analog profile: soft highlights, natural skin warmth',
      params: {
        'contrast': -0.08,
        'highlights': -0.18,
        'shadows': 0.12,
        'temperature': 0.08,
        'vibrance': 0.14,
        'grain': 0.12,
        'grainSize': 0.20,
        'grainRoughness': 0.40,
        'gradeShadowHue': 0.08,
        'gradeShadowSat': 0.08,
        'gradeShadowLum': 0.02,
        'gradeMidHue': 0.09,
        'gradeMidSat': 0.10,
        'gradeMidLum': 0.0,
        'gradeHighlightHue': 0.10,
        'gradeHighlightSat': 0.15,
        'gradeHighlightLum': -0.02,
        'gradeBlending': 0.55,
        'gradeBalance': 0.05,
        'blurFocalPoint': 0.50,
        'blurFocalRange': 0.25,
        'blurBokehShape': 0.0,
        'blurAmount': 0.08,
      },
      hsl: [
        0.0, 0.04, 0.0,   // Red
        0.03, 0.06, 0.05, // Orange
        -0.02, 0.0, 0.0,  // Yellow
        0.0, 0.0, 0.0,    // Green
        0.0, 0.0, 0.0,    // Aqua
        0.0, 0.0, 0.0,    // Blue
        0.0, 0.0, 0.0,    // Purple
        0.0, 0.0, 0.0,    // Magenta
      ],
    ),
    ToolDefinition(
      name: 'Kodak Portra 400',
      description: 'Pat David analog profile: golden warmth, fine organic grain',
      params: {
        'contrast': 0.05,
        'highlights': -0.22,
        'shadows': 0.16,
        'whites': 0.05,
        'temperature': 0.12,
        'vibrance': 0.18,
        'grain': 0.22,
        'grainSize': 0.28,
        'grainRoughness': 0.50,
        'gradeShadowHue': 0.12,
        'gradeShadowSat': 0.14,
        'gradeShadowLum': 0.02,
        'gradeMidHue': 0.10,
        'gradeMidSat': 0.12,
        'gradeMidLum': 0.0,
        'gradeHighlightHue': 0.11,
        'gradeHighlightSat': 0.16,
        'gradeHighlightLum': -0.04,
        'gradeBlending': 0.55,
        'gradeBalance': 0.08,
        'blurFocalPoint': 0.50,
        'blurFocalRange': 0.25,
        'blurBokehShape': 1.0,
        'blurAmount': 0.12,
      },
      hsl: [
        0.0, 0.04, 0.0,    // Red
        0.04, 0.08, 0.06,  // Orange
        -0.03, 0.0, 0.0,   // Yellow
        0.0, -0.05, 0.0,   // Green
        0.0, 0.0, 0.0,     // Aqua
        0.0, 0.0, 0.0,     // Blue
        0.0, 0.0, 0.0,     // Purple
        0.0, 0.0, 0.0,     // Magenta
      ],
    ),
    ToolDefinition(
      name: 'Fuji Pro 400H',
      description: 'Pat David analog profile: cool pastel tones, emerald shadow tint',
      params: {
        'contrast': -0.05,
        'highlights': -0.15,
        'shadows': 0.18,
        'temperature': -0.06,
        'tint': -0.04,
        'vibrance': 0.12,
        'saturation': -0.04,
        'grain': 0.18,
        'gradeShadowHue': 0.42,
        'gradeShadowSat': 0.18,
        'gradeShadowLum': 0.04,
        'gradeMidHue': 0.38,
        'gradeMidSat': 0.08,
        'gradeMidLum': 0.0,
        'gradeHighlightHue': 0.12,
        'gradeHighlightSat': 0.10,
        'gradeHighlightLum': -0.02,
        'gradeBlending': 0.50,
        'gradeBalance': -0.05,
        'blurFocalPoint': 0.50,
        'blurFocalRange': 0.30,
        'blurBokehShape': 0.0,
        'blurAmount': 0.10,
      },
      hsl: [
        0.0, 0.0, 0.0,    // Red
        0.0, 0.0, 0.0,    // Orange
        0.0, 0.0, 0.0,    // Yellow
        0.04, 0.06, 0.04, // Green
        0.05, 0.10, 0.0,  // Aqua
        0.0, 0.0, 0.0,    // Blue
        0.0, 0.0, 0.0,    // Purple
        0.0, 0.0, 0.0,    // Magenta
      ],
    ),
    ToolDefinition(
      name: 'Ilford HP5 Plus',
      description: 'Pat David analog profile: classic silver-halide B&W street contrast',
      params: {
        'saturation': -1.0,
        'contrast': 0.28,
        'highlights': -0.10,
        'shadows': 0.08,
        'clarity': 0.22,
        'grain': 0.35,
        'grainSize': 0.35,
        'grainRoughness': 0.65,
        'gradeShadowHue': 0.0,
        'gradeShadowSat': 0.0,
        'gradeShadowLum': -0.08,
        'gradeMidHue': 0.0,
        'gradeMidSat': 0.0,
        'gradeMidLum': 0.0,
        'gradeHighlightHue': 0.0,
        'gradeHighlightSat': 0.0,
        'gradeHighlightLum': 0.06,
        'gradeBlending': 0.50,
        'gradeBalance': 0.0,
        'blurFocalPoint': 0.50,
        'blurFocalRange': 0.25,
        'blurBokehShape': 2.0,
        'blurAmount': 0.0,
      },
      hsl: [
        0.0, -1.0, 0.0, // Red
        0.0, -1.0, 0.0, // Orange
        0.0, -1.0, 0.0, // Yellow
        0.0, -1.0, 0.0, // Green
        0.0, -1.0, 0.0, // Aqua
        0.0, -1.0, 0.0, // Blue
        0.0, -1.0, 0.0, // Purple
        0.0, -1.0, 0.0, // Magenta
      ],
    ),
    ToolDefinition(
      name: 'CineStill 800T',
      description: 'Tungsten balance, cool shadows, red halation bloom',
      params: {
        'temperature': -0.16,
        'contrast': 0.14,
        'highlights': -0.25,
        'shadows': 0.12,
        'vibrance': 0.20,
        'filmHalation': 0.35,
        'filmBloom': 0.25,
        'grain': 0.26,
        'gradeShadowHue': 0.54,
        'gradeShadowSat': 0.28,
        'gradeShadowLum': -0.04,
        'gradeMidHue': 0.52,
        'gradeMidSat': 0.12,
        'gradeMidLum': 0.0,
        'gradeHighlightHue': 0.05,
        'gradeHighlightSat': 0.22,
        'gradeHighlightLum': 0.04,
        'gradeBlending': 0.60,
        'gradeBalance': -0.10,
        'blurFocalPoint': 0.50,
        'blurFocalRange': 0.25,
        'blurBokehShape': 0.0,
        'blurAmount': 0.15,
      },
      hsl: [
        0.02, 0.20, 0.05, // Red
        0.0, 0.0, 0.0,    // Orange
        0.0, 0.0, 0.0,    // Yellow
        0.0, 0.0, 0.0,    // Green
        0.0, 0.0, 0.0,    // Aqua
        -0.04, 0.15, 0.0, // Blue
        0.0, 0.0, 0.0,    // Purple
        0.0, 0.0, 0.0,    // Magenta
      ],
    ),
    ToolDefinition(
      name: 'Teal & Orange',
      description: 'Cinematic split tone',
      params: {
        'gradeShadowHue': 0.50,
        'gradeShadowSat': 0.40,
        'gradeShadowLum': -0.06,
        'gradeMidHue': 0.30,
        'gradeMidSat': 0.10,
        'gradeMidLum': 0.0,
        'gradeHighlightHue': 0.08,
        'gradeHighlightSat': 0.30,
        'gradeHighlightLum': 0.05,
        'gradeBlending': 0.55,
        'gradeBalance': 0.05,
        'vibrance': 0.20,
        'blurFocalPoint': 0.50,
        'blurFocalRange': 0.25,
        'blurBokehShape': 1.0,
        'blurAmount': 0.10,
      },
      hsl: [
        0.0, 0.0, 0.0,    // Red
        0.05, 0.25, 0.0,  // Orange
        0.0, 0.0, 0.0,    // Yellow
        0.0, 0.0, 0.0,    // Green
        -0.05, 0.30, 0.0, // Aqua
        0.0, 0.20, 0.0,   // Blue
        0.0, 0.0, 0.0,    // Purple
        0.0, 0.0, 0.0,    // Magenta
      ],
    ),
    ToolDefinition(
      name: 'Moody Dark',
      description: 'Deep crushed blacks, muted cinematic tones',
      params: {
        'exposure': -0.15,
        'contrast': 0.22,
        'highlights': -0.30,
        'shadows': -0.12,
        'blacks': -0.20,
        'saturation': -0.15,
        'vignette': -0.35,
        'clarity': 0.15,
        'gradeShadowHue': 0.60,
        'gradeShadowSat': 0.18,
        'gradeShadowLum': -0.12,
        'gradeMidHue': 0.58,
        'gradeMidSat': 0.08,
        'gradeMidLum': -0.05,
        'gradeHighlightHue': 0.10,
        'gradeHighlightSat': 0.12,
        'gradeHighlightLum': -0.05,
        'gradeBlending': 0.50,
        'gradeBalance': -0.15,
        'blurFocalPoint': 0.50,
        'blurFocalRange': 0.25,
        'blurBokehShape': 2.0,
        'blurAmount': 0.08,
      },
      hsl: [
        0.0, 0.0, 0.0,     // Red
        0.0, -0.10, 0.0,   // Orange
        0.0, 0.0, 0.0,     // Yellow
        0.0, 0.0, -0.15,   // Green
        0.0, 0.0, 0.0,     // Aqua
        0.0, 0.0, -0.10,   // Blue
        0.0, 0.0, 0.0,     // Purple
        0.0, 0.0, 0.0,     // Magenta
      ],
    ),
    ToolDefinition(
      name: 'Kodak Ektar 100',
      description: 'Pat David analog profile: ultra-vivid saturation, micro-contrast, fine grain',
      params: {
        'saturation': 0.25,
        'contrast': 0.15,
        'vibrance': 0.18,
        'grain': 0.12,
        'highlights': -0.10,
        'shadows': 0.08,
        'gradeShadowHue': 0.62,
        'gradeShadowSat': 0.12,
        'gradeShadowLum': -0.04,
        'gradeMidHue': 0.10,
        'gradeMidSat': 0.10,
        'gradeMidLum': 0.02,
        'gradeHighlightHue': 0.12,
        'gradeHighlightSat': 0.14,
        'gradeHighlightLum': 0.02,
        'gradeBlending': 0.50,
        'gradeBalance': 0.02,
        'blurFocalPoint': 0.50,
        'blurFocalRange': 0.25,
        'blurBokehShape': 0.0,
        'blurAmount': 0.0,
      },
      hsl: [
        0.0, 0.20, 0.0, // Red
        0.0, 0.15, 0.0, // Orange
        0.0, 0.15, 0.0, // Yellow
        0.0, 0.15, 0.0, // Green
        0.0, 0.15, 0.0, // Aqua
        0.0, 0.20, 0.0, // Blue
        0.0, 0.10, 0.0, // Purple
        0.0, 0.10, 0.0, // Magenta
      ],
    ),
    ToolDefinition(
      name: 'Fuji Velvia 50',
      description: 'Pat David analog profile: iconic slide film, punchy greens and deep blues',
      params: {
        'saturation': 0.32,
        'contrast': 0.22,
        'clarity': 0.18,
        'vibrance': 0.20,
        'shadows': -0.08,
        'gradeShadowHue': 0.65,
        'gradeShadowSat': 0.16,
        'gradeShadowLum': -0.06,
        'gradeMidHue': 0.35,
        'gradeMidSat': 0.12,
        'gradeMidLum': 0.0,
        'gradeHighlightHue': 0.15,
        'gradeHighlightSat': 0.18,
        'gradeHighlightLum': 0.04,
        'gradeBlending': 0.52,
        'gradeBalance': 0.0,
        'blurFocalPoint': 0.50,
        'blurFocalRange': 0.25,
        'blurBokehShape': 1.0,
        'blurAmount': 0.0,
      },
      hsl: [
        0.0, 0.25, 0.0,   // Red
        0.0, 0.15, 0.0,   // Orange
        0.0, 0.15, 0.0,   // Yellow
        0.08, 0.30, 0.0,  // Green
        0.0, 0.20, 0.0,   // Aqua
        -0.05, 0.28, 0.0, // Blue
        0.0, 0.10, 0.0,   // Purple
        0.0, 0.10, 0.0,   // Magenta
      ],
    ),
    ToolDefinition(
      name: 'Agfa Vista 200',
      description: 'Pat David analog profile: warm consumer negative, poppy reds, golden midtones',
      params: {
        'temperature': 0.14,
        'tint': 0.06,
        'contrast': 0.12,
        'vibrance': 0.16,
        'grain': 0.22,
        'shadows': 0.10,
        'gradeShadowHue': 0.05,
        'gradeShadowSat': 0.14,
        'gradeShadowLum': 0.02,
        'gradeMidHue': 0.08,
        'gradeMidSat': 0.12,
        'gradeMidLum': 0.02,
        'gradeHighlightHue': 0.12,
        'gradeHighlightSat': 0.15,
        'gradeHighlightLum': 0.0,
        'gradeBlending': 0.55,
        'gradeBalance': 0.06,
        'blurFocalPoint': 0.50,
        'blurFocalRange': 0.25,
        'blurBokehShape': 0.0,
        'blurAmount': 0.08,
      },
      hsl: [
        -0.02, 0.18, 0.0, // Red
        0.0, 0.14, 0.0,   // Orange
        0.0, 0.10, 0.0,   // Yellow
        0.0, 0.0, 0.0,    // Green
        0.0, 0.0, 0.0,    // Aqua
        0.0, 0.0, 0.0,    // Blue
        0.0, 0.0, 0.0,    // Purple
        0.0, 0.0, 0.0,    // Magenta
      ],
    ),
    ToolDefinition(
      name: 'Kodachrome 64',
      description: 'Pat David analog profile: legendary National Geographic warmth and color depth',
      params: {
        'temperature': 0.12,
        'contrast': 0.20,
        'highlights': -0.16,
        'shadows': -0.08,
        'vibrance': 0.15,
        'clarity': 0.12,
        'gradeShadowHue': 0.60,
        'gradeShadowSat': 0.12,
        'gradeShadowLum': -0.04,
        'gradeMidHue': 0.10,
        'gradeMidSat': 0.10,
        'gradeMidLum': 0.0,
        'gradeHighlightHue': 0.10,
        'gradeHighlightSat': 0.15,
        'gradeHighlightLum': 0.02,
        'gradeBlending': 0.52,
        'gradeBalance': 0.04,
        'blurFocalPoint': 0.50,
        'blurFocalRange': 0.25,
        'blurBokehShape': 1.0,
        'blurAmount': 0.05,
      },
      hsl: [
        0.0, 0.22, -0.05, // Red
        0.0, 0.15, 0.0,   // Orange
        -0.05, 0.10, 0.0, // Yellow
        0.0, 0.0, 0.0,    // Green
        0.0, 0.0, 0.0,    // Aqua
        0.0, 0.16, 0.0,   // Blue
        0.0, 0.0, 0.0,    // Purple
        0.0, 0.0, 0.0,    // Magenta
      ],
    ),
    ToolDefinition(
      name: 'Warm Film',
      description: 'Warm, soft contrast',
      params: {
        'temperature': 0.30,
        'contrast': 0.10,
        'vibrance': 0.15,
        'gradeShadowHue': 0.10,
        'gradeShadowSat': 0.20,
        'gradeShadowLum': 0.02,
        'gradeMidHue': 0.10,
        'gradeMidSat': 0.12,
        'gradeMidLum': 0.02,
        'gradeHighlightHue': 0.12,
        'gradeHighlightSat': 0.18,
        'gradeHighlightLum': 0.0,
        'gradeBlending': 0.55,
        'gradeBalance': 0.08,
        'blurFocalPoint': 0.50,
        'blurFocalRange': 0.25,
        'blurBokehShape': 0.0,
        'blurAmount': 0.10,
      },
      hsl: [
        0.0, 0.10, 0.0,   // Red
        0.0, 0.15, 0.05,  // Orange
        0.0, 0.12, 0.0,   // Yellow
        0.0, 0.0, 0.0,    // Green
        0.0, 0.0, 0.0,    // Aqua
        0.0, 0.0, 0.0,    // Blue
        0.0, 0.0, 0.0,    // Purple
        0.0, 0.0, 0.0,    // Magenta
      ],
    ),
    ToolDefinition(
      name: 'Mono',
      description: 'Black & white',
      params: {
        'saturation': -1.0,
        'contrast': 0.15,
        'gradeShadowHue': 0.0,
        'gradeShadowSat': 0.0,
        'gradeShadowLum': 0.0,
        'gradeMidHue': 0.0,
        'gradeMidSat': 0.0,
        'gradeMidLum': 0.0,
        'gradeHighlightHue': 0.0,
        'gradeHighlightSat': 0.0,
        'gradeHighlightLum': 0.0,
        'gradeBlending': 0.50,
        'gradeBalance': 0.0,
        'blurFocalPoint': 0.50,
        'blurFocalRange': 0.25,
        'blurBokehShape': 0.0,
        'blurAmount': 0.0,
      },
      hsl: [
        0.0, -1.0, 0.0, // Red
        0.0, -1.0, 0.0, // Orange
        0.0, -1.0, 0.0, // Yellow
        0.0, -1.0, 0.0, // Green
        0.0, -1.0, 0.0, // Aqua
        0.0, -1.0, 0.0, // Blue
        0.0, -1.0, 0.0, // Purple
        0.0, -1.0, 0.0, // Magenta
      ],
    ),
  ];

  /// All built-in looks including movie, anime, nature, Indian cultural, travel, and film presets.
  static List<ToolDefinition> get allBuiltins => [
        ...builtins,
        ...movieLookTools(),
        ...natureLookTools(),
        ...culturalTravelLookTools(),
      ];

  static List<ToolDefinition> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return allBuiltins;
    return [
      for (final t in allBuiltins)
        if (t.name.toLowerCase().contains(q) ||
            t.description.toLowerCase().contains(q))
        t,
    ];
  }
}
