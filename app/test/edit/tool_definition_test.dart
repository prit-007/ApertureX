import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/edit/recipe.dart';
import 'package:aperturex/edit/tool_definition.dart';

void main() {
  test('applyTo sets the known parameters', () {
    const tool = ToolDefinition(
      name: 'x',
      params: {'contrast': 0.5, 'exposure': 1.0},
    );
    final recipe = tool.applyTo(EditRecipe.neutral);
    expect(recipe.contrast, 0.5);
    expect(recipe.exposure, 1.0);
  });

  test('unknown parameters are ignored and reported', () {
    const tool = ToolDefinition(name: 'x', params: {'nope': 1, 'contrast': 0.2});
    expect(tool.unknownParams(), ['nope']);
    expect(tool.applyTo(EditRecipe.neutral).contrast, 0.2);
  });

  test('encode/decode round-trips the look', () {
    const tool = ToolDefinition(
      name: 'Punch',
      description: 'pop',
      params: {'contrast': 0.3, 'vibrance': 0.3},
    );
    final decoded = ToolDefinition.decode(tool.encode());
    expect(decoded.name, 'Punch');
    expect(decoded.description, 'pop');
    expect(decoded.params, tool.params);
  });

  test('decode rejects non-object JSON', () {
    expect(
      () => ToolDefinition.decode('[1,2,3]'),
      throwsA(isA<FormatException>()),
    );
  });

  test('every built-in look applies with no unknown parameters', () {
    for (final tool in ToolLibrary.builtins) {
      expect(tool.unknownParams(), isEmpty, reason: tool.name);
      // Must not throw and must produce a valid recipe.
      final recipe = tool.applyTo(EditRecipe.neutral);
      expect(recipe.schemaVersion, EditRecipe.currentSchemaVersion);
    }
  });

  group('Preset strength amount semantics (Issue #169)', () {
    const tool = ToolDefinition(
      name: 'Moody Warmth',
      params: {
        'exposure': 1.0,
        'contrast': 0.4,
        'temperature': 0.6,
      },
      hsl: [0.2, 0.4, -0.6],
    );

    test('amount 0.0 (0%) keeps recipe at neutral baseline', () {
      final recipe = tool.applyTo(EditRecipe.neutral, amount: 0.0);
      expect(recipe.exposure, closeTo(0.0, 1e-4));
      expect(recipe.contrast, closeTo(0.0, 1e-4));
      expect(recipe.temperature, closeTo(0.0, 1e-4));
      expect(recipe.hsl, [0.0, 0.0, -0.0]);
    });

    test('amount 0.5 (50%) applies half-strength adjustments', () {
      final recipe = tool.applyTo(EditRecipe.neutral, amount: 0.5);
      expect(recipe.exposure, closeTo(0.5, 1e-4));
      expect(recipe.contrast, closeTo(0.2, 1e-4));
      expect(recipe.temperature, closeTo(0.3, 1e-4));
      expect(recipe.hsl[0], closeTo(0.1, 1e-4));
      expect(recipe.hsl[1], closeTo(0.2, 1e-4));
      expect(recipe.hsl[2], closeTo(-0.3, 1e-4));
    });

    test('amount 1.0 (100%) applies exact target parameters', () {
      final recipe = tool.applyTo(EditRecipe.neutral, amount: 1.0);
      expect(recipe.exposure, closeTo(1.0, 1e-4));
      expect(recipe.contrast, closeTo(0.4, 1e-4));
      expect(recipe.temperature, closeTo(0.6, 1e-4));
      expect(recipe.hsl, [0.2, 0.4, -0.6]);
    });

    test('amount 2.0 (200%) doubles parameters with proper clamping', () {
      final recipe = tool.applyTo(EditRecipe.neutral, amount: 2.0);
      expect(recipe.exposure, closeTo(2.0, 1e-4));
      expect(recipe.contrast, closeTo(0.8, 1e-4));
      // Temperature max clamp is 1.0
      expect(recipe.temperature, closeTo(1.0, 1e-4));
      expect(recipe.hsl[0], closeTo(0.4, 1e-4));
      expect(recipe.hsl[1], closeTo(0.8, 1e-4));
      expect(recipe.hsl[2], closeTo(-1.0, 1e-4)); // Clamped to -1.0
    });
  });
}
