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
}
