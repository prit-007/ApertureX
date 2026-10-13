import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tessera/edit/parameter.dart';
import 'package:tessera/edit/recipe.dart';
import 'package:tessera/edit/recipe_controller.dart';
import 'package:tessera/edit/recipe_state.dart';

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
    test('starts neutral and clean', () {
      expect(state().recipe, EditRecipe.neutral);
      expect(state().committed, EditRecipe.neutral);
      expect(state().isDirty, isFalse);
      expect(state().undoStack, isEmpty);
      expect(state().redoStack, isEmpty);
      expect(state().activeParameter, isNull);
    });
  });

  group('update / applyDelta / reset', () {
    test('update sets the value, clamps, and selects the parameter', () {
      notifier.update(Parameter.exposure, 99);
      expect(state().recipe.exposure, 4.0); // clamped
      expect(state().activeParameter, Parameter.exposure);
    });

    test('applyDelta scales by the parameter sensitivity (exposure is EV x2)', () {
      notifier.applyDelta(Parameter.exposure, 1.0); // full swipe
      expect(state().recipe.exposure, closeTo(2.0, 1e-9));

      notifier.applyDelta(Parameter.contrast, 0.5);
      expect(state().recipe.contrast, closeTo(0.5, 1e-9));
    });

    test('applyDelta accumulates and clamps', () {
      for (var i = 0; i < 10; i++) {
        notifier.applyDelta(Parameter.exposure, 1.0);
      }
      expect(state().recipe.exposure, 4.0); // clamped at the range edge
    });

    test('reset returns the parameter to neutral', () {
      notifier.update(Parameter.tint, -0.4);
      notifier.reset(Parameter.tint);
      expect(state().recipe.tint, 0);
      expect(state().recipe.temperature, 0); // untouched
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
    test('commit moves the live recipe to committed and pushes history', () {
      notifier.update(Parameter.exposure, 1.0);
      notifier.commit();

      expect(state().committed.exposure, 1.0);
      expect(state().undoStack.single, EditRecipe.neutral); // previous node
      expect(state().isDirty, isFalse);
      expect(state().redoStack, isEmpty);
    });

    test('commit is a no-op when nothing changed', () {
      notifier.commit();
      expect(state().undoStack, isEmpty);
    });

    test('cancel discards live edits back to the last commit', () {
      notifier.update(Parameter.exposure, 1.0);
      notifier.commit();
      notifier.update(Parameter.exposure, 2.0);
      notifier.update(Parameter.contrast, 0.3);

      notifier.cancel();

      expect(state().recipe.exposure, 1.0);
      expect(state().recipe.contrast, 0);
      expect(state().undoStack.length, 1);
    });
  });

  group('undo / redo history walk', () {
    test('walks the committed stack and re-applies', () {
      // N -> +1 -> commit -> +2 -> commit
      notifier.update(Parameter.exposure, 1.0);
      notifier.commit();
      notifier.update(Parameter.exposure, 2.0);
      notifier.commit();
      expect(state().undoStack.length, 2);

      notifier.undo();
      expect(state().recipe.exposure, 1.0); // back one
      expect(state().undoStack.length, 1);
      expect(state().redoStack.length, 1);

      notifier.undo();
      expect(state().recipe, EditRecipe.neutral);
      expect(state().undoStack, isEmpty);
      expect(state().redoStack.length, 2);

      notifier.redo();
      expect(state().recipe.exposure, 1.0);
      expect(state().undoStack.length, 1);

      notifier.redo();
      expect(state().recipe.exposure, 2.0);
      expect(state().undoStack.length, 2);
      expect(state().redoStack, isEmpty);
    });

    test('undo on an empty stack is a no-op', () {
      notifier.undo();
      expect(state().recipe, EditRecipe.neutral);
      expect(state().redoStack, isEmpty);
    });

    test('redo on an empty stack is a no-op', () {
      notifier.redo();
      expect(state().recipe, EditRecipe.neutral);
    });

    test('undo replaces live edits, not just the committed value', () {
      notifier.update(Parameter.exposure, 1.0);
      notifier.commit();
      notifier.update(Parameter.exposure, 3.0); // live, uncommitted
      notifier.update(Parameter.tint, 0.5);

      notifier.undo(); // discard live + step back

      expect(state().recipe, EditRecipe.neutral);
      expect(state().recipe.tint, 0);
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