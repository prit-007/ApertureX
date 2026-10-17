import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:aperturex/edit/recipe_controller.dart';
import 'package:aperturex/ui/common/retouch_canvas_overlay.dart';
import 'package:aperturex/ui/common/retouch_controls.dart';

void main() {
  testWidgets('RetouchCanvasOverlay tap creates a patch', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                height: 400,
                child: RetouchCanvasOverlay(),
              ),
            ),
          ),
        ),
      ),
    );

    expect(container.read(recipeControllerProvider).recipe.retouchPatches, isEmpty);

    // Tap in center (200, 200 in 400x400 box => normalized 0.5, 0.5)
    await tester.tap(find.byType(RetouchCanvasOverlay));
    await tester.pumpAndSettle();

    final patches = container.read(recipeControllerProvider).recipe.retouchPatches;
    expect(patches.length, 1);
    expect(patches.first.targetX, closeTo(0.5, 0.05));
    expect(patches.first.targetY, closeTo(0.5, 0.05));
  });

  testWidgets('Stylus pressure creates pressure-scaled patch', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                height: 400,
                child: RetouchCanvasOverlay(),
              ),
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.createGesture(
      kind: PointerDeviceKind.stylus,
      pointer: 1,
    );
    await gesture.downWithCustomEvent(
      const Offset(200, 200),
      const PointerDownEvent(
        position: Offset(200, 200),
        kind: PointerDeviceKind.stylus,
        pressure: 0.8,
      ),
    );
    await gesture.up();
    await tester.pumpAndSettle();

    final patches = container.read(recipeControllerProvider).recipe.retouchPatches;
    expect(patches.length, 1);
    // Pressure 0.8 should scale radius: 0.05 * (0.5 + 0.5 * 0.8) = 0.045
    expect(patches.first.radius, greaterThan(0.01));
  });

  testWidgets('Dragging target pin moves target and translates source', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                height: 400,
                child: RetouchCanvasOverlay(),
              ),
            ),
          ),
        ),
      ),
    );

    // Tap to create patch at center
    await tester.tap(find.byType(RetouchCanvasOverlay));
    await tester.pumpAndSettle();

    final initial = container.read(recipeControllerProvider).recipe.retouchPatches.first;
    expect(initial.targetX, closeTo(0.5, 0.02));

    final origin = tester.getTopLeft(find.byType(RetouchCanvasOverlay));
    final targetPos = origin + Offset(initial.targetX * 400, initial.targetY * 400);

    // Drag from target pin to (+40, +20)
    final gesture = await tester.startGesture(targetPos);
    await tester.pump();
    await gesture.moveTo(targetPos + const Offset(40, 20));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    final updated = container.read(recipeControllerProvider).recipe.retouchPatches.first;
    expect(updated.targetX, closeTo(0.60, 0.02));
    expect(updated.targetY, closeTo(0.55, 0.02));
    expect(updated.sourceX - initial.sourceX, closeTo(0.10, 0.02));
  });

  testWidgets('Dragging source pin moves source independently', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                height: 400,
                child: RetouchCanvasOverlay(),
              ),
            ),
          ),
        ),
      ),
    );

    // Tap to create patch
    await tester.tap(find.byType(RetouchCanvasOverlay));
    await tester.pumpAndSettle();

    final patch = container.read(recipeControllerProvider).recipe.retouchPatches.first;
    final origin = tester.getTopLeft(find.byType(RetouchCanvasOverlay));
    final sourcePos = origin + Offset(patch.sourceX * 400, patch.sourceY * 400);

    // Drag source pin by (+20, -20)
    final gesture = await tester.startGesture(sourcePos);
    await tester.pump();
    await gesture.moveTo(sourcePos + const Offset(20, -20));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    final updated = container.read(recipeControllerProvider).recipe.retouchPatches.first;
    // Target remained unchanged
    expect(updated.targetX, closeTo(patch.targetX, 0.01));
    expect(updated.targetY, closeTo(patch.targetY, 0.01));
    // Source moved
    expect(updated.sourceX, closeTo(patch.sourceX + 20 / 400, 0.02));
    expect(updated.sourceY, closeTo(patch.sourceY - 20 / 400, 0.02));
  });

  testWidgets('Dragging radius handle on selected patch resizes radius', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                height: 400,
                child: RetouchCanvasOverlay(),
              ),
            ),
          ),
        ),
      ),
    );

    // Tap center to create and select patch
    await tester.tap(find.byType(RetouchCanvasOverlay));
    await tester.pumpAndSettle();

    final patch = container.read(recipeControllerProvider).recipe.retouchPatches.first;
    expect(patch.radius, closeTo(0.05, 0.01));

    final origin = tester.getTopLeft(find.byType(RetouchCanvasOverlay));
    final rScreen = patch.radius * 400; // 20px
    final handlePos = origin + Offset(patch.targetX * 400 + rScreen, patch.targetY * 400);

    // Drag radius handle outward by +20px
    final gesture = await tester.startGesture(handlePos);
    await tester.pump();
    await gesture.moveTo(handlePos + const Offset(20, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    final updated = container.read(recipeControllerProvider).recipe.retouchPatches.first;
    // Radius resized from 0.05 to ~0.10
    expect(updated.radius, closeTo(0.10, 0.02));
    // Position stayed same
    expect(updated.targetX, closeTo(patch.targetX, 0.01));
    expect(updated.targetY, closeTo(patch.targetY, 0.01));
  });

  testWidgets('Multi-touch (2 fingers) does not place patch and forwards gesture', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                height: 400,
                child: RetouchCanvasOverlay(),
              ),
            ),
          ),
        ),
      ),
    );

    expect(container.read(recipeControllerProvider).recipe.retouchPatches, isEmpty);

    final center = tester.getCenter(find.byType(RetouchCanvasOverlay));
    final g1 = await tester.createGesture(pointer: 1);
    final g2 = await tester.createGesture(pointer: 2);

    await g1.down(center - const Offset(40, 0));
    await g2.down(center + const Offset(40, 0));
    await tester.pump();

    await g1.moveTo(center - const Offset(50, 0));
    await g2.moveTo(center + const Offset(50, 0));
    await tester.pump();

    await g1.up();
    await g2.up();
    await tester.pumpAndSettle();

    // Multi-touch should not create any patches
    expect(container.read(recipeControllerProvider).recipe.retouchPatches, isEmpty);
  });

  testWidgets('Tapping on-canvas delete badge removes selected patch', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                height: 400,
                child: RetouchCanvasOverlay(),
              ),
            ),
          ),
        ),
      ),
    );

    // Tap to create patch
    await tester.tap(find.byType(RetouchCanvasOverlay));
    await tester.pumpAndSettle();

    final patches = container.read(recipeControllerProvider).recipe.retouchPatches;
    expect(patches.length, 1);
    final patch = patches.first;

    // Delete badge position: (tp.dx + r + 14, tp.dy - 14)
    final origin = tester.getTopLeft(find.byType(RetouchCanvasOverlay));
    final rScreen = patch.radius * 400;
    final delPos = origin + Offset(patch.targetX * 400 + rScreen + 14, patch.targetY * 400 - 14);

    await tester.tapAt(delPos);
    await tester.pumpAndSettle();

    expect(container.read(recipeControllerProvider).recipe.retouchPatches, isEmpty);
    expect(container.read(selectedRetouchPatchIndexProvider), isNull);
  });
}

