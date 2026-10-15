import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:aperturex/edit/parameter.dart';
import 'package:aperturex/edit/recipe_controller.dart';
import 'package:aperturex/ui/common/film_controls.dart';
import 'package:aperturex/ui/common/parameter_control.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  Future<void> pumpFilmControls(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: FilmControls(),
          ),
        ),
      ),
    );
  }

  testWidgets('renders Halation, Bloom, and Emulsion headers and sliders', (
    tester,
  ) async {
    await pumpFilmControls(tester);

    expect(find.text('Halation'), findsWidgets);
    expect(find.text('OPTICAL BLOOM'), findsOneWidget);
    expect(find.text('FILM EMULSION'), findsOneWidget);

    // Verify parameter controls are present
    expect(
      find.byWidgetPredicate(
        (w) => w is ParameterControl && w.parameter == Parameter.filmHalation,
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (w) => w is ParameterControl && w.parameter == Parameter.filmBloom,
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (w) => w is ParameterControl && w.parameter == Parameter.filmDust,
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (w) => w is ParameterControl && w.parameter == Parameter.filmScratches,
      ),
      findsOneWidget,
    );
  });

  testWidgets('updating film parameters modifies recipe controller state', (
    tester,
  ) async {
    await pumpFilmControls(tester);

    final controller = container.read(recipeControllerProvider.notifier);
    controller.update(Parameter.filmHalation, 0.75);
    controller.update(Parameter.filmBloom, 0.5);
    controller.update(Parameter.filmDust, 0.3);

    final recipe = container.read(recipeControllerProvider).recipe;
    expect(recipe.filmHalation, 0.75);
    expect(recipe.filmBloom, 0.5);
    expect(recipe.filmDust, 0.3);
  });
}
