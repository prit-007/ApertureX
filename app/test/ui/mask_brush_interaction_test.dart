import 'dart:typed_data';

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:aperturex/edit/active_image.dart';
import 'package:aperturex/edit/adjustment_layer.dart';
import 'package:aperturex/edit/node_editor.dart';
import 'package:aperturex/edit/recipe_controller.dart';
import 'package:aperturex/engine/engine.dart';
import 'package:aperturex/ui/common/mask_controls.dart';
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

  Future<void> pumpMaskingApp(WidgetTester tester) async {
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
                  height: 300,
                  child: MaskControls(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('MaskControls offers Brush, Subject, Sky and Radial/Linear buttons', (
    tester,
  ) async {
    await pumpMaskingApp(tester);

    expect(find.text('Brush +'), findsOneWidget);
    expect(find.text('Linear +'), findsOneWidget);
    expect(find.text('Radial +'), findsOneWidget);
    expect(find.text('Subject +'), findsOneWidget);
    expect(find.text('Sky +'), findsOneWidget);
  });

  testWidgets('tapping Brush + creates a brush layer and selects it for painting', (
    tester,
  ) async {
    await pumpMaskingApp(tester);

    await tester.tap(find.text('Brush +'));
    await tester.pumpAndSettle();

    final layers = container.read(recipeControllerProvider).recipe.layers;
    expect(layers, hasLength(1));
    expect(layers.first.maskKind, MaskKind.brush);
    expect(container.read(nodeEditorProvider).enabled, isTrue);
    expect(container.read(nodeEditorProvider).selected, 0);

    // Paint a stroke across the photo with stylus
    final gesture = await tester.startGesture(
      const Offset(100, 100),
      kind: PointerDeviceKind.stylus,
    );
    await tester.pump();
    await gesture.moveTo(const Offset(200, 200));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    final updated = container.read(recipeControllerProvider).recipe.layers.first;
    expect(updated.maskParams.length, greaterThan(3));
    // Check that count of points is recorded
    expect(updated.maskParams[2], greaterThanOrEqualTo(2));
  });

  testWidgets('tapping Subject + creates an AI Subject adjustment layer', (
    tester,
  ) async {
    await pumpMaskingApp(tester);

    await tester.tap(find.text('Subject +'));
    await tester.pumpAndSettle();

    final layers = container.read(recipeControllerProvider).recipe.layers;
    expect(layers, hasLength(1));
    expect(layers.first.maskKind, MaskKind.subject);
  });

  testWidgets('tapping Sky + creates an AI Sky adjustment layer', (
    tester,
  ) async {
    await pumpMaskingApp(tester);

    await tester.tap(find.text('Sky +'));
    await tester.pumpAndSettle();

    final layers = container.read(recipeControllerProvider).recipe.layers;
    expect(layers, hasLength(1));
    expect(layers.first.maskKind, MaskKind.sky);
    expect(layers.first.maskParams, [0.5, 0.15, 0.6]);
  });

  testWidgets('Sky + with fake detector creates a layer with detected params', (
    tester,
  ) async {
    final detectorContainer = ProviderContainer(
      overrides: [
        skyDetectorProvider.overrideWithValue(
          (bytes) async => const DetectedSky(
            horizonY: 0.35,
            feather: 0.12,
            blueWeight: 0.78,
          ),
        ),
      ],
    );
    detectorContainer.read(activeImageBytesProvider.notifier).setBytes(
          Uint8List.fromList([1, 2, 3, 4]),
        );
    detectorContainer.read(canvasTransformProvider.notifier).set(transform);
    addTearDown(detectorContainer.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: detectorContainer,
        child: const MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Positioned.fill(child: NodeOverlay()),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 300,
                  child: MaskControls(),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Sky +'));
    await tester.pumpAndSettle();

    final layers = detectorContainer.read(recipeControllerProvider).recipe.layers;
    expect(layers, hasLength(1));
    expect(layers.first.maskKind, MaskKind.sky);
    expect(layers.first.skyHorizon, closeTo(0.35, 1e-4));
    expect(layers.first.skyFeather, closeTo(0.12, 1e-4));
    expect(layers.first.skyBlueWeight, closeTo(0.78, 1e-4));
  });

  testWidgets('selected layer in MaskControls displays inline editor for quick adjustments', (
    tester,
  ) async {
    final controller = container.read(recipeControllerProvider.notifier);
    controller.addLayer(
      const AdjustmentLayer(
        maskKind: MaskKind.brush,
        maskParams: [0.06, 0.25, 0],
        exposure: 0.5,
      ),
    );
    container.read(nodeEditorProvider.notifier).enable();
    container.read(nodeEditorProvider.notifier).select(0);

    await pumpMaskingApp(tester);

    expect(find.byKey(const Key('mask-inline-exposure-slider')), findsOneWidget);
    expect(find.byKey(const Key('mask-inline-brush-size-slider')), findsOneWidget);
    expect(find.byKey(const Key('mask-inline-invert')), findsOneWidget);

    // Scroll into view if needed
    await tester.ensureVisible(find.byKey(const Key('mask-inline-exposure-slider')));
    await tester.pumpAndSettle();

    // Adjust exposure slider
    await tester.drag(
      find.byKey(const Key('mask-inline-exposure-slider')),
      const Offset(120, 0),
    );
    await tester.pump();

    final layer = container.read(recipeControllerProvider).recipe.layers.first;
    expect(layer.exposure, greaterThan(0.5));
  });

  testWidgets('selected sky layer displays horizon, feather, and blue weight sliders', (
    tester,
  ) async {
    final controller = container.read(recipeControllerProvider.notifier);
    controller.addLayer(
      const AdjustmentLayer(
        maskKind: MaskKind.sky,
        maskParams: [0.5, 0.15, 0.6],
      ),
    );
    container.read(nodeEditorProvider.notifier).enable();
    container.read(nodeEditorProvider.notifier).select(0);

    await pumpMaskingApp(tester);

    expect(find.byKey(const Key('mask-inline-sky-horizon-slider')), findsOneWidget);
    expect(find.byKey(const Key('mask-inline-sky-feather-slider')), findsOneWidget);
    expect(find.byKey(const Key('mask-inline-sky-blue-weight-slider')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('mask-inline-sky-blue-weight-slider')));
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const Key('mask-inline-sky-blue-weight-slider')),
      const Offset(60, 0),
    );
    await tester.pumpAndSettle();

    final layer = container.read(recipeControllerProvider).recipe.layers.first;
    expect(layer.skyBlueWeight, greaterThan(0.6));
  });

  testWidgets('multiple brush strokes separate with break sentinel and do not connect', (
    tester,
  ) async {
    await pumpMaskingApp(tester);

    await tester.tap(find.text('Brush +'));
    await tester.pumpAndSettle();

    // First stroke: drag from (50, 50) to (80, 50)
    final g1 = await tester.startGesture(const Offset(50, 50));
    await tester.pump();
    await g1.moveTo(const Offset(80, 50));
    await tester.pump();
    await g1.up();
    await tester.pump();

    final layer1 = container.read(recipeControllerProvider).recipe.layers.first;
    final count1 = layer1.brushPointCount;
    expect(count1, greaterThanOrEqualTo(2));

    // Second stroke: drag from (200, 200) to (250, 200)
    final g2 = await tester.startGesture(const Offset(200, 200));
    await tester.pump();
    await g2.moveTo(const Offset(250, 200));
    await tester.pump();
    await g2.up();
    await tester.pump();

    final layer2 = container.read(recipeControllerProvider).recipe.layers.first;
    final params2 = layer2.maskParams;
    // Verify that sentinel [-1.0, -1.0, -1.0] exists separating stroke 1 and stroke 2
    final pts2 = params2.sublist(3);
    var foundSentinel = false;
    for (var i = 0; i < pts2.length - 2; i += 3) {
      if (pts2[i] == -1.0 && pts2[i + 1] == -1.0 && pts2[i + 2] == -1.0) {
        foundSentinel = true;
        break;
      }
    }
    expect(foundSentinel, isTrue, reason: 'Must have stroke-break sentinel separating strokes');
  });
}
