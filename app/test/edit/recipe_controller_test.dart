import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/edit/adjustment_layer.dart';
import 'package:aperturex/edit/parameter.dart';
import 'package:aperturex/edit/recipe.dart';
import 'package:aperturex/edit/recipe_controller.dart';
import 'package:aperturex/edit/recipe_state.dart';

void main() {
  late ProviderContainer container;
  late RecipeController notifier;

  setUp(() {
    container = ProviderContainer();
    notifier = container.read(recipeControllerProvider.notifier);
  });

  tearDown(() => container.dispose());

  RecipeState state() => container.read(recipeControllerProvider);

  group('lifecycle', () {
    test('starts neutral with an Original history node', () {
      expect(state().recipe, EditRecipe.neutral);
      expect(state().history.length, 1);
      expect(state().history.single.label, 'Original');
      expect(state().index, 0);
      expect(state().isDirty, isFalse);
      expect(state().activeParameter, isNull);
    });
  });

  group('update / applyDelta / reset', () {
    test('update sets the value, clamps, and selects the parameter', () {
      notifier.update(Parameter.exposure, 99);
      expect(state().recipe.exposure, 4.0);
      expect(state().activeParameter, Parameter.exposure);
    });

    test('applyDelta scales by the parameter sensitivity', () {
      notifier.applyDelta(Parameter.exposure, 1.0);
      expect(state().recipe.exposure, closeTo(2.0, 1e-9));
    });

    test('reset returns the parameter to neutral', () {
      notifier.update(Parameter.tint, -0.4);
      notifier.reset(Parameter.tint);
      expect(state().recipe.tint, 0);
    });

    test('isDirty tracks live edits vs committed', () {
      expect(state().isDirty, isFalse);
      notifier.update(Parameter.saturation, 0.2);
      expect(state().isDirty, isTrue);
      notifier.cancel();
      expect(state().isDirty, isFalse);
    });
  });

  group('commit / cancel', () {
    test('commit appends a node and moves the index', () {
      notifier.update(Parameter.exposure, 1.0);
      notifier.commit(label: 'Exposure +1');

      expect(state().history.length, 2);
      expect(state().index, 1);
      expect(state().history.last.label, 'Exposure +1');
      expect(state().committed.exposure, 1.0);
      expect(state().isDirty, isFalse);
    });

    test('commit is a no-op when nothing changed', () {
      notifier.commit();
      expect(state().history.length, 1);
    });

    test('cancel discards live edits back to the committed node', () {
      notifier.update(Parameter.exposure, 1.0);
      notifier.commit();
      notifier.update(Parameter.exposure, 2.0);
      notifier.cancel();
      expect(state().recipe.exposure, 1.0);
    });
  });

  group('undo / redo / jump', () {
    void buildTwoCommits() {
      notifier.update(Parameter.exposure, 1.0);
      notifier.commit(label: 'a');
      notifier.update(Parameter.exposure, 2.0);
      notifier.commit(label: 'b');
    }

    test('walks the history', () {
      buildTwoCommits();
      expect(state().history.length, 3);

      notifier.undo();
      expect(state().recipe.exposure, 1.0);
      expect(state().index, 1);

      notifier.undo();
      expect(state().recipe, EditRecipe.neutral);
      expect(state().index, 0);

      notifier.redo();
      expect(state().recipe.exposure, 1.0);
      expect(state().index, 1);
    });

    test('undo at the start / redo at the end are no-ops', () {
      notifier.undo();
      expect(state().index, 0);
      buildTwoCommits();
      for (var i = 0; i < 5; i++) {
        notifier.redo();
      }
      expect(state().index, state().history.length - 1);
    });

    test('committing after an undo branches (truncates the redo tail)', () {
      buildTwoCommits();
      notifier.undo(); // back to node 1
      notifier.update(Parameter.contrast, 0.5);
      notifier.commit(label: 'branch');

      expect(state().history.length, 3); // Original, a, branch — 'b' dropped
      expect(state().history.last.label, 'branch');
      expect(state().history.any((e) => e.label == 'b'), isFalse);
    });

    test('jumpTo views a node; a later commit branches from it', () {
      buildTwoCommits();
      notifier.jumpTo(0);
      expect(state().index, 0);
      expect(state().recipe, EditRecipe.neutral);

      notifier.update(Parameter.tint, 0.3);
      notifier.commit(label: 'from-original');
      expect(state().history.length, 2);
      expect(state().history.last.label, 'from-original');
    });
  });

  group('history model', () {
    test('loadRecipe replaces the session and resets history', () {
      notifier.update(Parameter.exposure, 1.0);
      notifier.commit();
      notifier.loadRecipe(EditRecipe.neutral.copyWith(contrast: 0.5));

      expect(state().recipe.contrast, 0.5);
      expect(state().recipe.exposure, 0);
      expect(state().history.length, 1);
      expect(state().history.single.label, 'Loaded');
    });
  });

  group('layers', () {
    test('add / remove / clear', () {
      const layer = AdjustmentLayer(exposure: 1);
      notifier.addLayer(layer);
      expect(state().recipe.layers.length, 1);

      notifier.removeLayerAt(0);
      expect(state().recipe.layers, isEmpty);

      notifier.addLayer(layer);
      notifier.clearLayers();
      expect(state().recipe.layers, isEmpty);
    });
  });

  group('geometry', () {
    test('rotate wraps around the four quarter turns', () {
      notifier.rotate(-1);
      expect(state().recipe.rotation, 3);
      notifier.rotate(1);
      expect(state().recipe.rotation, 0);
    });

    test('flips toggle', () {
      notifier.toggleFlipH();
      expect(state().recipe.flipH, isTrue);
      notifier.toggleFlipV();
      expect(state().recipe.flipV, isTrue);
    });

    test('straighten clamps to +/-45', () {
      notifier.setStraighten(90);
      expect(state().recipe.straighten, 45);
    });
  });

  group('setHsl', () {
    test('updates a band component and clamps', () {
      notifier.setHsl(0, hue: 2.0, saturation: -0.5);
      expect(state().recipe.hsl[0], 1.0); // clamped
      expect(state().recipe.hsl[1], -0.5);
      expect(state().recipe.hsl[2], 0.0);
    });
  });

  group('selectParameter', () {
    test('selects and clears the active parameter', () {
      notifier.selectParameter(Parameter.whites);
      expect(state().activeParameter, Parameter.whites);
      notifier.selectParameter(null);
      expect(state().activeParameter, isNull);
    });
  });
}
