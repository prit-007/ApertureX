import 'package:aperturex/edit/adjustment_layer.dart';
import 'package:aperturex/edit/node_editor.dart';
import 'package:aperturex/edit/recipe_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('nodeEditorProvider', () {
    late ProviderContainer container;
    setUp(() => container = ProviderContainer());
    tearDown(() => container.dispose());

    NodeEditorState state() => container.read(nodeEditorProvider);
    NodeEditor notifier() => container.read(nodeEditorProvider.notifier);

    test('starts disabled with no selection', () {
      expect(state().enabled, isFalse);
      expect(state().selected, isNull);
    });

    test('enable/disable manage the mode and clear the selection', () {
      notifier().enable();
      expect(state().enabled, isTrue);
      notifier().select(2);
      expect(state().selected, 2);

      notifier().disable();
      expect(state().enabled, isFalse);
      expect(state().selected, isNull);
    });

    test('enable is idempotent and keeps the selection', () {
      notifier()
        ..enable()
        ..select(1)
        ..enable();
      expect(state().enabled, isTrue);
      expect(state().selected, 1);
    });

    test('toggle flips the mode', () {
      notifier().toggle();
      expect(state().enabled, isTrue);
      notifier().toggle();
      expect(state().enabled, isFalse);
    });

    test('select keeps the mode and null deselects', () {
      notifier().enable();
      notifier().select(0);
      expect(state(), const NodeEditorState(enabled: true, selected: 0));
      notifier().select(null);
      expect(state(), const NodeEditorState(enabled: true));
    });
  });

  group('RecipeController.updateLayerAt', () {
    late ProviderContainer container;
    late RecipeController notifier;

    setUp(() {
      container = ProviderContainer();
      notifier = container.read(recipeControllerProvider.notifier);
      notifier
        ..addLayer(const AdjustmentLayer(exposure: 0.4))
        ..addLayer(
          const AdjustmentLayer(
            maskKind: MaskKind.linear,
            maskParams: [0, 0, 0, 1],
            exposure: 0.2,
          ),
        );
    });
    tearDown(() => container.dispose());

    List<AdjustmentLayer> layers() =>
        container.read(recipeControllerProvider).recipe.layers;

    test('replaces the layer in place and leaves the rest untouched', () {
      final before = layers();
      notifier.updateLayerAt(0, before[0].copyWith(exposure: 1.2));
      final after = layers();
      expect(after, hasLength(2));
      expect(after[0].exposure, 1.2);
      expect(after[0].maskKind, MaskKind.radial);
      expect(after[1], before[1]);
    });

    test('out-of-range indices are ignored', () {
      final before = layers();
      notifier
        ..updateLayerAt(-1, const AdjustmentLayer(exposure: 9))
        ..updateLayerAt(5, const AdjustmentLayer(exposure: 9));
      expect(layers(), before);
    });
  });
}
