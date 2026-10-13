import 'package:flutter_test/flutter_test.dart';
import 'package:tessera/edit/parameter.dart';
import 'package:tessera/edit/recipe_mapping.dart';
import 'package:tessera/gesture/gesture_interpreter.dart' show GradeTool;

void main() {
  group('snapseedToolParameters', () {
    test('maps each carousel tool to exactly its parameter', () {
      expect(snapseedToolParameters[GradeTool.exposure], [Parameter.exposure]);
      expect(snapseedToolParameters[GradeTool.contrast], [Parameter.contrast]);
      expect(
        snapseedToolParameters[GradeTool.saturation],
        [Parameter.saturation],
      );
    });
  });

  group('parametersIn (Lightroom categories)', () {
    test('Light contains the tone-range controls, nothing from Color', () {
      final light = parametersIn(RecipeSection.light);
      expect(light, containsAll([
        Parameter.exposure,
        Parameter.contrast,
        Parameter.highlights,
        Parameter.shadows,
        Parameter.whites,
        Parameter.blacks,
      ]));
      expect(light, isNot(contains(Parameter.temperature)));
      expect(light, isNot(contains(Parameter.saturation)));
    });

    test('Color contains temperature/tint/vibrance/saturation, not Light', () {
      final color = parametersIn(RecipeSection.color);
      expect(color, containsAll([
        Parameter.temperature,
        Parameter.tint,
        Parameter.vibrance,
        Parameter.saturation,
      ]));
      expect(color, isNot(contains(Parameter.exposure)));
    });

    test('parameters partition exactly across sections', () {
      final all = <Parameter>{
        for (final section in RecipeSection.values) ...parametersIn(section),
      };
      expect(all.length, Parameter.values.length);
    });
  });

  group('snapseedCarousel', () {
    test('flattens the tool carousel in tool order', () {
      expect(snapseedCarousel, [
        Parameter.exposure,
        Parameter.contrast,
        Parameter.highlights,
        Parameter.shadows,
        Parameter.whites,
        Parameter.blacks,
        Parameter.temperature,
        Parameter.tint,
        Parameter.vibrance,
        Parameter.saturation,
        Parameter.clarity,
        Parameter.dehaze,
        Parameter.sharpen,
      ]);
    });
  });
}