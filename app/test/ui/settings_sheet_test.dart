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

  testWidgets('the sheet and About dialog state the offline claim (#76)', (
    tester,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: SettingsSheet())),
      ),
    );

    // The footer lives below the fold in AppSheet's lazy ListView.
    await tester.scrollUntilVisible(
      find.byKey(const Key('offline-claim')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    // Visible in the sheet footer without opening anything.
    expect(find.byKey(const Key('offline-claim')), findsOneWidget);
    expect(find.text(kOfflineClaim), findsOneWidget);

    await tester.tap(find.text('About ApertureX'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AboutDialog),
        matching: find.text(kOfflineClaim),
      ),
      findsOneWidget,
    );
  });

  testWidgets('AI consent toggle updates aiConsentProvider', (tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: SettingsSheet())),
      ),
    );

    final switchFinder = find.byKey(const Key('settings-ai-consent-toggle'));
    await tester.scrollUntilVisible(
      switchFinder,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(switchFinder, findsOneWidget);
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    // Switched to true
    final switchWidget = tester.widget<SwitchListTile>(switchFinder);
    expect(switchWidget.value, isTrue);
  });
}
