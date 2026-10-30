import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:aperturex/edit/recipe_controller.dart';
import 'package:aperturex/ui/common/geometry_controls.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  testWidgets('GeometryControls renders Auto button and rotation controls', (tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: GeometryControls(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final autoBtn = find.byKey(const Key('geometry-auto-straighten'));
    expect(autoBtn, findsOneWidget);

    expect(find.text('Left'), findsOneWidget);
    expect(find.text('Right'), findsOneWidget);
    expect(find.text('Flip H'), findsOneWidget);
    expect(find.text('Flip V'), findsOneWidget);

    // Tap rotate Right
    await tester.tap(find.text('Right'));
    await tester.pumpAndSettle();

    expect(container.read(recipeControllerProvider).recipe.rotation, 1);

    // Tap Auto with no photo loaded shows snackbar
    await tester.tap(autoBtn);
    await tester.pumpAndSettle();

    expect(find.text('No photo loaded for auto-straighten'), findsOneWidget);

    // Wait for first snackbar to dismiss before tapping the second button
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    final autoFrameBtn = find.byKey(const Key('geometry-auto-frame'));
    expect(autoFrameBtn, findsOneWidget);

    await tester.tap(autoFrameBtn);
    await tester.pumpAndSettle();

    expect(find.text('No photo loaded for auto-frame'), findsOneWidget);
  });
}
