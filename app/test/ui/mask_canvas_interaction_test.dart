import 'package:aperturex/edit/adjustment_layer.dart';
import 'package:aperturex/edit/node_editor.dart';
import 'package:aperturex/edit/recipe_controller.dart';
import 'package:aperturex/ui/common/node_overlay.dart';
import 'package:aperturex/viewport/canvas_transform.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Canvas is 400×400 fitted at offset (0, 0), scale 1.
  // Normalized (0.5, 0.5) is at screen (200, 200).
  const transform = CanvasTransform(
    fitted: Size(400, 400),
    offset: Offset(0, 0),
    scale: 1,
  );

  late ProviderContainer container;
  setUp(() {
    container = ProviderContainer();
    container.read(canvasTransformProvider.notifier).set(transform);
    container.read(nodeEditorProvider.notifier).enable();
  });
  tearDown(() => container.dispose());

  Future<void> pumpOverlay(WidgetTester tester) => tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: NodeOverlay())),
        ),
      );

  List<AdjustmentLayer> layers() =>
      container.read(recipeControllerProvider).recipe.layers;

  testWidgets('dragging linear gradient start handle adjusts start point', (
    tester,
  ) async {
    // Start at (0.25, 0.5) -> screen (100, 200)
    // End at (0.75, 0.5) -> screen (300, 200)
    container.read(recipeControllerProvider.notifier).addLayer(
          const AdjustmentLayer(
            maskKind: MaskKind.linear,
            maskParams: [0.25, 0.5, 0.75, 0.5],
          ),
        );
    container.read(nodeEditorProvider.notifier).select(0);

    await pumpOverlay(tester);

    // Drag start handle from (100, 200) up-left by (-40, -40)
    final gesture = await tester.startGesture(const Offset(100, 200));
    await tester.pump();
    await gesture.moveBy(const Offset(-40, -40));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    final l = layers().first;
    expect(l.linearStart.dx, closeTo(0.15, 0.02));
    expect(l.linearStart.dy, closeTo(0.40, 0.02));
    // End point remains unchanged
    expect(l.linearEnd.dx, closeTo(0.75, 0.01));
    expect(l.linearEnd.dy, closeTo(0.50, 0.01));
  });

  testWidgets('dragging linear gradient end handle adjusts end point', (
    tester,
  ) async {
    // Start at (0.25, 0.5) -> screen (100, 200)
    // End at (0.75, 0.5) -> screen (300, 200)
    container.read(recipeControllerProvider.notifier).addLayer(
          const AdjustmentLayer(
            maskKind: MaskKind.linear,
            maskParams: [0.25, 0.5, 0.75, 0.5],
          ),
        );
    container.read(nodeEditorProvider.notifier).select(0);

    await pumpOverlay(tester);

    // Drag end handle from (300, 200) down-right by (40, 40)
    final gesture = await tester.startGesture(const Offset(300, 200));
    await tester.pump();
    await gesture.moveBy(const Offset(40, 40));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    final l = layers().first;
    // Start point remains unchanged
    expect(l.linearStart.dx, closeTo(0.25, 0.01));
    expect(l.linearStart.dy, closeTo(0.50, 0.01));
    // End point moved
    expect(l.linearEnd.dx, closeTo(0.85, 0.02));
    expect(l.linearEnd.dy, closeTo(0.60, 0.02));
  });

  testWidgets('dragging linear gradient midpoint translates both handles', (
    tester,
  ) async {
    // Midpoint is at (0.5, 0.5) -> screen (200, 200)
    container.read(recipeControllerProvider.notifier).addLayer(
          const AdjustmentLayer(
            maskKind: MaskKind.linear,
            maskParams: [0.3, 0.5, 0.7, 0.5],
          ),
        );
    container.read(nodeEditorProvider.notifier).select(0);

    await pumpOverlay(tester);

    // Drag midpoint from (200, 200) by (40, 40)
    final gesture = await tester.startGesture(const Offset(200, 200));
    await tester.pump();
    await gesture.moveBy(const Offset(40, 40));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    final l = layers().first;
    expect(l.linearStart.dx, closeTo(0.40, 0.02));
    expect(l.linearStart.dy, closeTo(0.60, 0.02));
    expect(l.linearEnd.dx, closeTo(0.80, 0.02));
    expect(l.linearEnd.dy, closeTo(0.60, 0.02));
  });

  testWidgets('dragging subject mask center moves the subject center', (
    tester,
  ) async {
    // Subject center at (0.5, 0.5) -> screen (200, 200)
    container.read(recipeControllerProvider.notifier).addLayer(
          const AdjustmentLayer(
            maskKind: MaskKind.subject,
            maskParams: [0.5, 0.5, 0.25, 0.35, 0.3],
          ),
        );
    container.read(nodeEditorProvider.notifier).select(0);

    await pumpOverlay(tester);

    // Drag center from (200, 200) to (240, 240)
    final gesture = await tester.startGesture(const Offset(200, 200));
    await tester.pump();
    await gesture.moveBy(const Offset(40, 40));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    final l = layers().first;
    expect(l.subjectCenter.dx, closeTo(0.60, 0.02));
    expect(l.subjectCenter.dy, closeTo(0.60, 0.02));
  });

  testWidgets('dragging sky mask horizon moves horizon y position', (
    tester,
  ) async {
    // Horizon at y=0.5 -> screen y=200
    container.read(recipeControllerProvider.notifier).addLayer(
          const AdjustmentLayer(
            maskKind: MaskKind.sky,
            maskParams: [0.5, 0.15, 0.6],
          ),
        );
    container.read(nodeEditorProvider.notifier).select(0);

    await pumpOverlay(tester);

    // Drag horizon line at (200, 200) downwards by 40px
    final gesture = await tester.startGesture(const Offset(200, 200));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 40));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    final l = layers().first;
    expect(l.skyHorizon, closeTo(0.60, 0.02));
  });

  testWidgets('dragging brush mask origin pin translates all stroke points', (
    tester,
  ) async {
    // Brush with radius 0.06, feather 0.25, 2 points at (0.25, 0.25) and (0.35, 0.35)
    container.read(recipeControllerProvider.notifier).addLayer(
          const AdjustmentLayer(
            maskKind: MaskKind.brush,
            maskParams: [0.06, 0.25, 2, 0.25, 0.25, 1.0, 0.35, 0.35, 1.0],
          ),
        );
    container.read(nodeEditorProvider.notifier).select(0);

    await pumpOverlay(tester);

    // Origin is at (0.25, 0.25) -> screen (100, 100)
    final gesture = await tester.startGesture(const Offset(100, 100));
    await tester.pump();
    await gesture.moveBy(const Offset(40, 40));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    final l = layers().first;
    final pts = l.maskParams;
    expect(pts[3], closeTo(0.35, 0.02));
    expect(pts[4], closeTo(0.35, 0.02));
    expect(pts[6], closeTo(0.45, 0.02));
    expect(pts[7], closeTo(0.45, 0.02));
  });

  testWidgets('tapping canvas when luminance mask is selected samples pixel luminance', (
    tester,
  ) async {
    container.read(recipeControllerProvider.notifier).addLayer(
          const AdjustmentLayer(
            maskKind: MaskKind.luminance,
            maskParams: [0.0, 0.4],
          ),
        );
    container.read(nodeEditorProvider.notifier).select(0);

    // Register a pixel luminance sampler that returns 0.70 at (0.5, 0.5)
    container.read(pixelSamplerProvider.notifier).setSampler((u, v) {
      if ((u - 0.5).abs() < 0.1 && (v - 0.5).abs() < 0.1) {
        return 0.70;
      }
      return 0.20;
    });

    await pumpOverlay(tester);

    // Tap at screen center (200, 200) -> normalized (0.5, 0.5)
    await tester.tapAt(const Offset(200, 200));
    await tester.pumpAndSettle();

    final l = layers().first;
    expect(l.maskKind, MaskKind.luminance);
    expect(l.lumaMin, closeTo(0.62, 0.02));
    expect(l.lumaMax, closeTo(0.78, 0.02));
    expect(l.lumaZone, 7);
  });
}
