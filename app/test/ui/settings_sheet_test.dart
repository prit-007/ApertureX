import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:aperturex/edit/parameter.dart';
import 'package:aperturex/edit/recipe.dart';
import 'package:aperturex/edit/recipe_controller.dart';
import 'package:aperturex/ui/common/settings_sheet.dart';

void main() {
  late ProviderContainer container;
  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  test('resetAll returns the recipe to neutral', () {
    final notifier = container.read(recipeControllerProvider.notifier);
    notifier.update(Parameter.exposure, 2.0);
    notifier.resetAll();
    expect(container.read(recipeControllerProvider).recipe, EditRecipe.neutral);
  });

  testWidgets('copy then paste round-trips the settings', (tester) async {
    final notifier = container.read(recipeControllerProvider.notifier);
    notifier.update(Parameter.contrast, 0.4);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: SettingsSheet())),
      ),
    );

    await tester.tap(find.text('Copy settings'));
    await tester.pumpAndSettle();

    notifier.resetAll();
    expect(container.read(recipeControllerProvider).recipe.contrast, 0);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: SettingsSheet())),
      ),
    );
    await tester.tap(find.text('Paste settings'));
    await tester.pumpAndSettle();

    expect(container.read(recipeControllerProvider).recipe.contrast, 0.4);
  });
}
