import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:aperturex/edit/adjustment_layer.dart';
import 'package:aperturex/edit/node_editor.dart';
import 'package:aperturex/edit/recipe_controller.dart';
import 'package:aperturex/ui/common/brush_toolbar.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  Future<void> pumpToolbar(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Positioned(
                  top: 50,
                  left: 20,
                  right: 20,
                  child: BrushToolbar(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('BrushToolbar is hidden when no brush layer is selected', (
    tester,
  ) async {
    await pumpToolbar(tester);
    expect(find.byKey(const Key('brush-toolbar')), findsNothing);
  });

  testWidgets('BrushToolbar renders when brush layer is selected', (
    tester,
  ) async {
    final controller = container.read(recipeControllerProvider.notifier);
    controller.addLayer(
      const AdjustmentLayer(
        maskKind: MaskKind.brush,
        maskParams: [0.08, 0.35, 2, 0.2, 0.2, 1.0, 0.25, 0.25, 1.0],
        exposure: 0.5,
      ),
    );
    container.read(nodeEditorProvider.notifier).enable();
    container.read(nodeEditorProvider.notifier).select(0);

    await pumpToolbar(tester);

    expect(find.byKey(const Key('brush-toolbar')), findsOneWidget);
    expect(find.byKey(const Key('brush-toolbar-paint')), findsOneWidget);
    expect(find.byKey(const Key('brush-toolbar-erase')), findsOneWidget);
    expect(find.byKey(const Key('brush-toolbar-size-slider')), findsOneWidget);
    expect(find.byKey(const Key('brush-toolbar-clear')), findsOneWidget);
    expect(find.byKey(const Key('brush-toolbar-done')), findsOneWidget);
  });

  testWidgets('BrushToolbar toggles between Paint and Erase modes', (
    tester,
  ) async {
    final controller = container.read(recipeControllerProvider.notifier);
    controller.addLayer(
      const AdjustmentLayer(
        maskKind: MaskKind.brush,
        maskParams: [0.08, 0.35, 2, 0.2, 0.2, 1.0, 0.25, 0.25, 1.0],
        exposure: 0.5,
      ),
    );
    container.read(nodeEditorProvider.notifier).enable();
    container.read(nodeEditorProvider.notifier).select(0);

    await pumpToolbar(tester);

    // Initial state: Paint mode
    expect(container.read(nodeEditorProvider).eraserMode, isFalse);

    // Switch to Erase
    await tester.tap(find.byKey(const Key('brush-toolbar-erase')));
    await tester.pump();
    expect(container.read(nodeEditorProvider).eraserMode, isTrue);

    // Switch back to Paint
    await tester.tap(find.byKey(const Key('brush-toolbar-paint')));
    await tester.pump();
    expect(container.read(nodeEditorProvider).eraserMode, isFalse);
  });

  testWidgets('BrushToolbar adjusts brush size and clears strokes', (
    tester,
  ) async {
    final controller = container.read(recipeControllerProvider.notifier);
    controller.addLayer(
      const AdjustmentLayer(
        maskKind: MaskKind.brush,
        maskParams: [0.08, 0.35, 2, 0.2, 0.2, 1.0, 0.25, 0.25, 1.0],
        exposure: 0.5,
      ),
    );
    container.read(nodeEditorProvider.notifier).enable();
    container.read(nodeEditorProvider.notifier).select(0);

    await pumpToolbar(tester);

    // Adjust size slider
    await tester.drag(
      find.byKey(const Key('brush-toolbar-size-slider')),
      const Offset(60, 0),
    );
    await tester.pump();

    var layer = container.read(recipeControllerProvider).recipe.layers.first;
    expect(layer.brushRadius, greaterThan(0.08));

    // Clear strokes
    await tester.tap(find.byKey(const Key('brush-toolbar-clear')));
    await tester.pump();

    layer = container.read(recipeControllerProvider).recipe.layers.first;
    expect(layer.brushPointCount, 0);

    // Done exits node mode
    await tester.tap(find.byKey(const Key('brush-toolbar-done')));
    await tester.pump();
    expect(container.read(nodeEditorProvider).enabled, isFalse);
  });
}
