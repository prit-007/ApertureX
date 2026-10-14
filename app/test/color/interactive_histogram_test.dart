import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:aperturex/color/histogram_view.dart';
import 'package:aperturex/color/interactive_histogram.dart';
import 'package:aperturex/edit/recipe_controller.dart';
import 'package:aperturex/engine/engine.dart';

Histogram _histogram() => Histogram(
  r: Uint32List(256)..[200] = 10,
  g: Uint32List(256)..[128] = 20,
  b: Uint32List(256)..[40] = 7,
  luma: Uint32List(256)..[100] = 15,
);

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    container.read(histogramProvider.notifier).publish(_histogram());
  });
  tearDown(() => container.dispose());

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: EdgeInsets.all(20),
            child: InteractiveHistogram(),
          ),
        ),
      ),
    ),
  );

  testWidgets('dragging the left third adjusts Blacks', (tester) async {
    await pump(tester);
    final rect = tester.getRect(find.byType(InteractiveHistogram));
    await tester.dragFrom(
      Offset(rect.left + rect.width * 0.15, rect.center.dy),
      const Offset(40, 0),
    );
    await tester.pumpAndSettle();

    final recipe = container.read(recipeControllerProvider).recipe;
    expect(recipe.blacks, greaterThan(0));
    expect(recipe.exposure, 0);
    expect(recipe.whites, 0);
  });

  testWidgets('dragging the middle adjusts Exposure', (tester) async {
    await pump(tester);
    final rect = tester.getRect(find.byType(InteractiveHistogram));
    await tester.dragFrom(rect.center, const Offset(40, 0));
    await tester.pumpAndSettle();

    final recipe = container.read(recipeControllerProvider).recipe;
    expect(recipe.exposure, greaterThan(0));
    expect(recipe.blacks, 0);
  });

  testWidgets('dragging the right third adjusts Whites', (tester) async {
    await pump(tester);
    final rect = tester.getRect(find.byType(InteractiveHistogram));
    await tester.dragFrom(
      Offset(rect.left + rect.width * 0.85, rect.center.dy),
      const Offset(40, 0),
    );
    await tester.pumpAndSettle();

    expect(
      container.read(recipeControllerProvider).recipe.whites,
      greaterThan(0),
    );
  });
}
