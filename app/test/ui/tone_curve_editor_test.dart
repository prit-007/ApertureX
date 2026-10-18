import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:aperturex/edit/recipe_controller.dart';
import 'package:aperturex/ui/common/tone_curve_editor.dart';

import '../helpers/viewport_harness.dart';

void main() {
  late ProviderContainer container;
  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: ToneCurveEditor())),
    ),
  );

  int masterPoints() =>
      container.read(recipeControllerProvider).recipe.masterCurve.points.length;

  testWidgets('the master curve starts as identity (2 points)', (tester) async {
    await pump(tester);
    expect(masterPoints(), 4); // flat [0,0,1,1]
  });

  testWidgets('dragging adds a control point to the master curve', (
    tester,
  ) async {
    await pump(tester);
    await tester.dragFrom(
      tester.getCenter(find.byType(ToneCurveEditor)),
      const Offset(30, 0),
    );
    await tester.pumpAndSettle();

    expect(masterPoints(), greaterThan(4)); // an interior point was added
  });

  testWidgets('switching to RED edits the red channel curve', (tester) async {
    await pump(tester);
    await tester.tap(find.text('RED'));
    await tester.pumpAndSettle();

    await tester.dragFrom(
      tester.getCenter(find.byType(ToneCurveEditor)),
      const Offset(30, 0),
    );
    await tester.pumpAndSettle();

    final recipe = container.read(recipeControllerProvider).recipe;
    expect(recipe.redCurve.points.length, greaterThan(4));
    expect(recipe.masterCurve.points.length, 4); // untouched
  });

  testWidgets(
    'channel buttons fit a 240dp sidebar at phone viewports and text scales',
    (tester) async {
      for (final viewport in const [Size(360, 800), Size(320, 640)]) {
        for (final textScale in const [1.0, 1.3]) {
          setViewport(tester, viewport, textScale);
          // Fresh container each iteration so curve edits don't accumulate
          // near the drag point and mask a channel switch.
          final iterationContainer = ProviderContainer();
          addTearDown(iterationContainer.dispose);
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: iterationContainer,
              child: const MaterialApp(
                home: Scaffold(
                  body: SizedBox(
                    width: 240,
                    height: 400,
                    child: ToneCurveEditor(),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          await tester.tap(find.text('RED'));
          await tester.pumpAndSettle();
          await tester.dragFrom(
            tester.getCenter(find.byType(ToneCurveEditor)),
            const Offset(20, 0),
          );
          await tester.pumpAndSettle();

          final recipe =
              iterationContainer.read(recipeControllerProvider).recipe;
          expect(
            recipe.redCurve.points.length,
            greaterThan(4),
            reason: 'RED tap must still switch the curve at '
                '$viewport / textScale $textScale',
          );
          expect(recipe.masterCurve.points.length, 4);
        }
      }
    },
  );
}
