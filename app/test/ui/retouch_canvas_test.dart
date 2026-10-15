import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:aperturex/edit/recipe_controller.dart';
import 'package:aperturex/ui/common/retouch_canvas_overlay.dart';

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
}
