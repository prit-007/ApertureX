import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:aperturex/edit/parameter.dart';
import 'package:aperturex/edit/recipe_controller.dart';
import 'package:aperturex/ui/common/lab_controls.dart';
import 'package:aperturex/ui/common/parameter_control.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  Future<void> pumpLabControls(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: LabControls(),
          ),
        ),
      ),
    );
  }

  testWidgets('renders presets and selecting VHS Retro updates recipe state', (
    tester,
  ) async {
    await pumpLabControls(tester);

    expect(find.text('COMMUNITY SHADERS & GLITCHES'), findsOneWidget);
    expect(find.text('None'), findsOneWidget);
    expect(find.text('VHS Retro'), findsOneWidget);
    expect(find.text('Prism Dispersion'), findsOneWidget);
    expect(find.text('CRT Scanlines'), findsOneWidget);
    expect(find.text('Pixelate'), findsOneWidget);

    // Tap VHS Retro
    await tester.tap(find.text('VHS Retro'));
    await tester.pumpAndSettle();

    final recipe = container.read(recipeControllerProvider).recipe;
    expect(recipe.shaderLabPreset, 1);

    // When VHS is selected, shader parameters 1..3 controls appear
    expect(
      find.byWidgetPredicate(
        (w) => w is ParameterControl && w.parameter == Parameter.shaderParam1,
      ),
      findsOneWidget,
    );
  });

  testWidgets('selecting Pixelate updates recipe state to preset 4', (
    tester,
  ) async {
    await pumpLabControls(tester);

    // Tap Pixelate
    await tester.tap(find.text('Pixelate'));
    await tester.pumpAndSettle();

    final recipe = container.read(recipeControllerProvider).recipe;
    expect(recipe.shaderLabPreset, 4);

    // When Pixelate is selected, shader parameters controls appear
    expect(
      find.byWidgetPredicate(
        (w) => w is ParameterControl && w.parameter == Parameter.shaderParam1,
      ),
      findsOneWidget,
    );
  });
}
