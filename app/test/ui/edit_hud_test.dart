import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:aperturex/edit/parameter.dart';
import 'package:aperturex/edit/recipe_controller.dart';
import 'package:aperturex/ui/snapseed/edit_hud.dart';

void main() {
  late ProviderContainer container;
  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: EditHud())),
    ),
  );

  testWidgets('shows only the parameters that were changed', (tester) async {
    await pump(tester);
    expect(find.textContaining('EXP'), findsNothing); // neutral -> empty

    container
        .read(recipeControllerProvider.notifier)
        .update(Parameter.exposure, 0.5);
    container
        .read(recipeControllerProvider.notifier)
        .update(Parameter.contrast, -0.2);
    await tester.pump();

    expect(find.textContaining('EXP'), findsOneWidget);
    expect(find.textContaining('CON'), findsOneWidget);
    expect(find.textContaining('SAT'), findsNothing);
  });

  testWidgets('float noise at neutral does not stick a badge in the HUD', (
    tester,
  ) async {
    // Issue #42: fractional drags land on 1e-11 instead of 0.0 — with strict
    // equality the "reset" tool stays in the HUD forever showing +0.00.
    await pump(tester);
    container
        .read(recipeControllerProvider.notifier)
        .update(Parameter.exposure, 1e-11);
    await tester.pump();

    expect(find.textContaining('EXP'), findsNothing);

    // A real change still shows.
    container
        .read(recipeControllerProvider.notifier)
        .update(Parameter.exposure, 0.01);
    await tester.pump();
    expect(find.textContaining('EXP'), findsOneWidget);
  });

  testWidgets('caps visible badges at 4 with overflow chip on small viewports', (
    tester,
  ) async {
    await pump(tester);

    final notifier = container.read(recipeControllerProvider.notifier);
    // Set 6 parameters to non-neutral
    notifier.update(Parameter.exposure, 0.5);
    notifier.update(Parameter.contrast, -0.2);
    notifier.update(Parameter.highlights, 0.3);
    notifier.update(Parameter.shadows, -0.1);
    notifier.update(Parameter.whites, 0.2);
    notifier.update(Parameter.blacks, -0.3);
    await tester.pump();

    // First 4 badges visible (parameter.values order: exposure, contrast,
    // highlights, shadows, whites, blacks, ...)
    expect(find.textContaining('EXP'), findsOneWidget);
    expect(find.textContaining('CON'), findsOneWidget);
    expect(find.textContaining('HIL'), findsOneWidget);
    expect(find.textContaining('SHA'), findsOneWidget);

    // Remaining 2 not shown individually
    expect(find.textContaining('WHI'), findsNothing);
    expect(find.textContaining('BLA'), findsNothing);

    // Overflow chip visible
    expect(find.textContaining('+2 more'), findsOneWidget);
  });
}
