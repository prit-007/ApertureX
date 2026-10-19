import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:aperturex/edit/parameter.dart';
import 'package:aperturex/edit/recipe_controller.dart';
import 'package:aperturex/ui/common/parameter_control.dart';
import 'package:aperturex/ui/common/parameter_panel.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  Future<void> pumpParameterPanel(
    WidgetTester tester, {
    required RecipeSection section,
  }) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: ParameterPanel(section: section),
          ),
        ),
      ),
    );
  }

  testWidgets('ParameterPanel renders all parameters in section', (
    tester,
  ) async {
    await pumpParameterPanel(tester, section: RecipeSection.light);

    // Light section has exposure, contrast, highlights, shadows, whites, blacks
    expect(
      find.byWidgetPredicate(
        (widget) {
          if (widget is ParameterControl) {
            return widget.parameter == Parameter.exposure;
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
            return widget.parameter == Parameter.contrast;
          }
          return false;
        },
      ),
      findsOneWidget,
    );
  });

  testWidgets('ParameterPanel uses tight 2px vertical padding', (
    tester,
  ) async {
    await pumpParameterPanel(tester, section: RecipeSection.light);

    final listView = tester.widget<ListView>(find.byType(ListView));
    expect(listView.padding, const EdgeInsets.symmetric(vertical: 2));
  });

  testWidgets('ParameterPanel exposes recipe state for parameter values', (
    tester,
  ) async {
    await pumpParameterPanel(tester, section: RecipeSection.light);

    final recipe = container.read(recipeControllerProvider).recipe;
    expect(recipe.exposure, 0);
    expect(recipe.contrast, 0);
  });
}
