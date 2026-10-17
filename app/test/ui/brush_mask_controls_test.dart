import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:aperturex/edit/adjustment_layer.dart';
import 'package:aperturex/edit/node_editor.dart';
import 'package:aperturex/edit/recipe_controller.dart';
import 'package:aperturex/ui/common/mask_controls.dart';
import 'package:aperturex/ui/common/node_controls.dart';
import 'package:aperturex/ui/common/node_overlay.dart';
import 'package:aperturex/viewport/canvas_transform.dart';

void main() {
  const transform = CanvasTransform(
    fitted: Size(400, 400),
    offset: Offset(0, 0),
    scale: 1,
  );

  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    container.read(canvasTransformProvider.notifier).set(transform);
  });

  tearDown(() {
    container.dispose();
  });

  Future<void> pumpNodeControls(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Positioned.fill(child: NodeOverlay()),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: NodeControls(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'NodeControls shows Brush Size, Feather, and Paint/Erase toggle for brush layer',
    (tester) async {
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

      await pumpNodeControls(tester);

      expect(find.byKey(const Key('node-brush-paint')), findsOneWidget);
      expect(find.byKey(const Key('node-brush-erase')), findsOneWidget);
      expect(find.byKey(const Key('node-brush-size-slider')), findsOneWidget);
      expect(find.byKey(const Key('node-brush-feather-slider')), findsOneWidget);
      expect(find.byKey(const Key('node-brush-clear')), findsOneWidget);

      // Drag Brush Size
      await tester.drag(
        find.byKey(const Key('node-brush-size-slider')),
        const Offset(50, 0),
      );
      await tester.pump();

      var layer = container.read(recipeControllerProvider).recipe.layers.first;
      expect(layer.brushRadius, greaterThan(0.08));

      // Drag Brush Feather
      await tester.drag(
        find.byKey(const Key('node-brush-feather-slider')),
        const Offset(-120, 0),
      );
      await tester.pump();

      layer = container.read(recipeControllerProvider).recipe.layers.first;
      expect(layer.brushFeather, lessThan(0.35));

      // Tap Erase
      await tester.tap(find.byKey(const Key('node-brush-erase')));
      await tester.pump();
      expect(container.read(nodeEditorProvider).eraserMode, isTrue);

      // Tap Clear Strokes
      await tester.tap(find.byKey(const Key('node-brush-clear')));
      await tester.pump();

      layer = container.read(recipeControllerProvider).recipe.layers.first;
      expect(layer.brushPointCount, 0);
    },
  );

  testWidgets(
    'NodeControls provides full tonal adjustment sliders for masks',
    (tester) async {
      final controller = container.read(recipeControllerProvider.notifier);
      controller.addLayer(
        const AdjustmentLayer(
          maskKind: MaskKind.brush,
          maskParams: [0.06, 0.25, 0],
          exposure: 0.0,
        ),
      );
      container.read(nodeEditorProvider.notifier).enable();
      container.read(nodeEditorProvider.notifier).select(0);

      await pumpNodeControls(tester);

      // Exposure slider
      expect(find.byKey(const Key('node-exposure-slider')), findsOneWidget);
      // Contrast slider
      expect(find.byKey(const Key('node-contrast-slider')), findsOneWidget);
      // Saturation slider
      expect(find.byKey(const Key('node-saturation-slider')), findsOneWidget);
      // Temperature slider
      expect(find.byKey(const Key('node-temperature-slider')), findsOneWidget);

      // Drag Saturation slider
      await tester.drag(
        find.byKey(const Key('node-saturation-slider')),
        const Offset(60, 0),
      );
      await tester.pump();

      final layer = container.read(recipeControllerProvider).recipe.layers.first;
      expect(layer.saturation, greaterThan(0));
    },
  );

  testWidgets(
    'NodeOverlay in eraser mode removes brush points near drag gesture',
    (tester) async {
      final controller = container.read(recipeControllerProvider.notifier);
      controller.addLayer(
        const AdjustmentLayer(
          maskKind: MaskKind.brush,
          maskParams: [
            0.10, 0.25, 3,
            0.5, 0.5, 1.0, // at center (200, 200)
            0.52, 0.52, 1.0, // also near center
            0.9, 0.9, 1.0, // far away at (360, 360)
          ],
          exposure: 0.5,
        ),
      );
      container.read(nodeEditorProvider.notifier).enable();
      container.read(nodeEditorProvider.notifier).select(0);
      container.read(nodeEditorProvider.notifier).setEraserMode(true);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox.expand(child: NodeOverlay()),
            ),
          ),
        ),
      );
      await tester.pump();

      // Drag across center (200, 200) where points 0 and 1 are located
      final gesture = await tester.startGesture(
        const Offset(190, 190),
        kind: PointerDeviceKind.stylus,
      );
      await tester.pump();
      await gesture.moveTo(const Offset(210, 210));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      final layer = container.read(recipeControllerProvider).recipe.layers.first;
      // Points near (0.5, 0.5) were erased; point at (0.9, 0.9) remains
      expect(layer.brushPointCount, 1);
      expect(layer.maskParams[3], 0.9);
      expect(layer.maskParams[4], 0.9);
    },
  );

  testWidgets(
    'MaskControls inline card provides brush feather, clear, and tonal sliders',
    (tester) async {
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

      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 800,
                child: MaskControls(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check sliders and chips exist in MaskControls
      expect(find.byKey(const Key('mask-inline-brush-paint')), findsOneWidget);
      expect(find.byKey(const Key('mask-inline-brush-erase')), findsOneWidget);
      expect(find.byKey(const Key('mask-inline-brush-size-slider')), findsOneWidget);
      expect(find.byKey(const Key('mask-inline-brush-feather-slider')), findsOneWidget);
      expect(find.byKey(const Key('mask-inline-brush-clear')), findsOneWidget);
      expect(find.byKey(const Key('mask-inline-contrast-slider')), findsOneWidget);
      expect(find.byKey(const Key('mask-inline-saturation-slider')), findsOneWidget);

      // Tap Erase
      await tester.tap(find.byKey(const Key('mask-inline-brush-erase')));
      await tester.pump();
      expect(container.read(nodeEditorProvider).eraserMode, isTrue);

      // Drag feather
      final featherFinder = find.byKey(const Key('mask-inline-brush-feather-slider'));
      await tester.scrollUntilVisible(featherFinder, 100);
      await tester.pumpAndSettle();
      await tester.drag(
        featherFinder,
        const Offset(60, 0),
      );
      await tester.pumpAndSettle();
      expect(container.read(recipeControllerProvider).recipe.layers.first.brushFeather, greaterThan(0.35));

      // Tap clear
      final clearFinder = find.byKey(const Key('mask-inline-brush-clear'));
      await tester.scrollUntilVisible(clearFinder, -100);
      await tester.pumpAndSettle();
      await tester.tap(clearFinder);
      await tester.pumpAndSettle();
      expect(container.read(recipeControllerProvider).recipe.layers.first.brushPointCount, 0);
    },
  );
}

