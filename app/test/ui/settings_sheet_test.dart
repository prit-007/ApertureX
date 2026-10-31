import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:aperturex/edit/parameter.dart';
import 'package:aperturex/edit/recipe.dart';
import 'package:aperturex/edit/recipe_controller.dart';
import 'package:aperturex/settings/app_settings.dart';
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

    final copyBtn = find.text('Copy settings');
    await tester.scrollUntilVisible(
      copyBtn,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(copyBtn);
    await tester.pumpAndSettle();

    notifier.resetAll();
    expect(container.read(recipeControllerProvider).recipe.contrast, 0);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: SettingsSheet())),
      ),
    );
    final pasteBtn = find.text('Paste settings');
    await tester.scrollUntilVisible(
      pasteBtn,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(pasteBtn);
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

  testWidgets('Glassmorphic UI toggle updates glassmorphicUiProvider', (tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: SettingsSheet())),
      ),
    );

    final switchFinder = find.byKey(const Key('settings-glassmorphic-toggle'));
    await tester.scrollUntilVisible(
      switchFinder,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(switchFinder, findsOneWidget);
    expect(container.read(glassmorphicUiProvider), isFalse);

    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    expect(container.read(glassmorphicUiProvider), isTrue);
  });

  testWidgets('Exposure Assist segmented button switches between Off, Zebras, and False Color', (tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: SettingsSheet())),
      ),
    );

    final zebrasBtn = find.text('Zebras');
    await tester.scrollUntilVisible(
      zebrasBtn,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(zebrasBtn, findsOneWidget);
    await tester.tap(zebrasBtn);
    await tester.pumpAndSettle();

    // Mode is now Zebras
    expect(find.text('Highlight Clipping Zebras'), findsOneWidget);
    expect(find.text('Shadow Crush Zebras'), findsOneWidget);

    final falseColorBtn = find.text('False Color');
    await tester.tap(falseColorBtn);
    await tester.pumpAndSettle();

    expect(find.textContaining('ARRI 16-Zone IRE Heatmap'), findsOneWidget);

    final offBtn = find.text('Off');
    await tester.tap(offBtn);
    await tester.pumpAndSettle();
  });

  testWidgets('Settings sheet displays Editor Guide and Image Info quick action tiles', (tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: SettingsSheet())),
      ),
    );

    expect(find.text('Editor Guide'), findsOneWidget);
    expect(find.text('Image Info & EXIF'), findsOneWidget);
  });

  testWidgets('settings sheet version is dynamic, not hardcoded', (tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: SettingsSheet())),
      ),
    );

    await tester.scrollUntilVisible(
      find.textContaining('· P2'),
      500,
      scrollable: find.byType(Scrollable).first,
    );

    // Before the dynamic-version fix, this was hardcoded to '0.3.5 · P2'.
    expect(find.text('ApertureX 0.3.5 · P2'), findsNothing);
  });
}
