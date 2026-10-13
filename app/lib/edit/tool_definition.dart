import 'dart:convert';

import 'parameter.dart';
import 'recipe.dart';

/// A shareable **look**: a named patch of recipe parameters. Because it is just
/// JSON, looks can be imported/exported/shared (file, QR) — community "tools"
/// without arbitrary shader execution (#14; Flutter can't compile GLSL at
/// runtime, so a parameterized look format is the honest realization).
class ToolDefinition {
  const ToolDefinition({
    required this.name,
    this.description = '',
    required this.params,
  });

  final String name;
  final String description;

  /// `Parameter.name → value`.
  final Map<String, double> params;

  /// Applies this look onto [base] (unknown parameter names are ignored).
  EditRecipe applyTo(EditRecipe base) {
    var recipe = base;
    for (final entry in params.entries) {
      final parameter = _parameterByName(entry.key);
      if (parameter != null) {
        recipe = withValue(recipe, parameter, entry.value);
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
  };

  factory ToolDefinition.fromJson(Map<String, Object?> json) => ToolDefinition(
    name: (json['name'] as String?) ?? 'Untitled',
    description: (json['description'] as String?) ?? '',
    params: {
      for (final e in (json['params'] as Map? ?? {}).entries)
        e.key.toString(): (e.value as num).toDouble(),
    },
  );

  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());

  static ToolDefinition decode(String json) {
    final decoded = jsonDecode(json);
    if (decoded is! Map) {
      throw const FormatException('look is not a JSON object');
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
      },
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
      },
    ),
    ToolDefinition(
      name: 'Teal & Orange',
      description: 'Cinematic split tone',
      params: {
        'gradeShadowHue': 0.50,
        'gradeShadowSat': 0.40,
        'gradeHighlightHue': 0.08,
        'gradeHighlightSat': 0.30,
        'vibrance': 0.20,
      },
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
      },
    ),
    ToolDefinition(
      name: 'Mono',
      description: 'Black & white',
      params: {'saturation': -1.0, 'contrast': 0.15},
    ),
  ];

  static List<ToolDefinition> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return builtins;
    return [
      for (final t in builtins)
        if (t.name.toLowerCase().contains(q) ||
            t.description.toLowerCase().contains(q))
          t,
    ];
  }
}
