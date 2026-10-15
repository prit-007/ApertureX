import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:aperturex/color/blur_spec.dart';
import 'package:aperturex/edit/recipe_controller.dart';
import 'package:aperturex/ui/common/blur_controls.dart';
import 'package:aperturex/ui/common/parameter_control.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  Future<void> pumpBlurControls(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: BlurControls(),
          ),
        ),
      ),
    );
  }

  testWidgets('BlurControls toggle enables and disables lens blur controls', (
    tester,
  ) async {
    await pumpBlurControls(tester);

    // Initially disabled, so parameter controls for blur should not be rendered
    expect(find.byType(SwitchListTile), findsOneWidget);
    expect(find.byType(ParameterControl), findsNothing);
    expect(container.read(recipeControllerProvider).recipe.blurEnabled, isFalse);

    // Toggle switch on
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(container.read(recipeControllerProvider).recipe.blurEnabled, isTrue);
    expect(find.byType(ParameterControl), findsNWidgets(4));

    // Verify all BokehShape chips are present
    for (final shape in BokehShape.values) {
      expect(find.text(shape.label), findsOneWidget);
    }

    // Tap Hexagon shape chip
    await tester.tap(find.text('6 Blade'));
    await tester.pumpAndSettle();

    expect(
      container.read(recipeControllerProvider).recipe.blurBokehShape,
      BokehShape.hexagon.index,
    );
  });
}
