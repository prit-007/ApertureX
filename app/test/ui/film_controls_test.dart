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

  testWidgets('FilmControls uses ExpansionTile accordion groups', (
    tester,
  ) async {
    await pumpFilmControls(tester);

    // Three ExpansionTiles: Halation, Optical Bloom, Film Emulsion
    expect(find.byType(ExpansionTile), findsNWidgets(3));
  });

  testWidgets('FilmControls ExpansionTiles start expanded', (
    tester,
  ) async {
    await pumpFilmControls(tester);

    for (final tile in tester.widgetList<ExpansionTile>(
      find.byType(ExpansionTile),
    )) {
      expect(tile.initiallyExpanded, isTrue);
    }
  });

  testWidgets('FilmControls sections contain correct parameter controls', (
    tester,
  ) async {
    await pumpFilmControls(tester);

    // Halation section
    expect(
      find.byWidgetPredicate(
        (widget) {
          if (widget is ParameterControl) {
            return widget.parameter == Parameter.filmHalation;
          }
          return false;
        },
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) {
          if (widget is ParameterControl) {
            return widget.parameter == Parameter.filmHalationRadius;
          }
          return false;
        },
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) {
          if (widget is ParameterControl) {
            return widget.parameter == Parameter.filmHalationThreshold;
          }
          return false;
        },
      ),
      findsOneWidget,
    );

    // Optical Bloom section
    expect(
      find.byWidgetPredicate(
        (widget) {
          if (widget is ParameterControl) {
            return widget.parameter == Parameter.filmBloom;
          }
          return false;
        },
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) {
          if (widget is ParameterControl) {
            return widget.parameter == Parameter.filmBloomRadius;
          }
          return false;
        },
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) {
          if (widget is ParameterControl) {
            return widget.parameter == Parameter.filmBloomThreshold;
          }
          return false;
        },
      ),
      findsOneWidget,
    );

    // Film Emulsion section
    expect(
      find.byWidgetPredicate(
        (widget) {
          if (widget is ParameterControl) {
            return widget.parameter == Parameter.filmDust;
          }
          return false;
        },
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) {
          if (widget is ParameterControl) {
            return widget.parameter == Parameter.filmScratches;
          }
          return false;
        },
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
