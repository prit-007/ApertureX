import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aperturex/edit/parameter.dart';
import 'package:aperturex/edit/recipe_controller.dart';
import 'package:aperturex/edit/settings_clipboard.dart';
import 'package:aperturex/settings/shell_preference.dart';
import 'package:aperturex/ui/app_shell.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer();
    container
        .read(shellPreferenceProvider.notifier)
        .select(AppShellKind.snapseed);
  });

  tearDown(() => container.dispose());

  Future<void> pumpShell(
    WidgetTester tester, {
    VoidCallback? onNext,
    VoidCallback? onPrevious,
  }) =>
      tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: AppShell(
                onNextPhoto: onNext,
                onPreviousPhoto: onPrevious,
              ),
            ),
          ),
        ),
      );

  testWidgets('3-finger swipe UP copies recipe and shows HUD', (tester) async {
    await pumpShell(tester);
    await tester.pump(const Duration(milliseconds: 300));

    // Make an edit
    container
        .read(recipeControllerProvider.notifier)
        .update(Parameter.exposure, 1.8);
    await tester.pump();

    expect(find.text('Recipe Copied'), findsNothing);

    // 3 fingers down
    final g1 = await tester.startGesture(const Offset(100, 300), pointer: 1);
    final g2 = await tester.startGesture(const Offset(150, 300), pointer: 2);
    final g3 = await tester.startGesture(const Offset(200, 300), pointer: 3);

    // Swipe UP
    await g1.moveTo(const Offset(100, 200));
    await g2.moveTo(const Offset(150, 200));
    await g3.moveTo(const Offset(200, 200));
    await tester.pump();

    // Verify HUD toast appears
    expect(find.text('Recipe Copied'), findsOneWidget);

    // Verify clipboard received the recipe
    final copied = container.read(settingsClipboardProvider);
    expect(copied, isNotNull);
    expect(copied!.exposure, 1.8);

    await g1.up();
    await g2.up();
    await g3.up();
    await tester.pump(const Duration(milliseconds: 1500));
  });

  testWidgets('3-finger swipe DOWN pastes recipe and shows HUD', (tester) async {
    await pumpShell(tester);
    await tester.pump(const Duration(milliseconds: 300));

    // Populate clipboard
    container
        .read(recipeControllerProvider.notifier)
        .update(Parameter.contrast, 0.75);
    final recipe = container.read(recipeControllerProvider).recipe;
    container.read(settingsClipboardProvider.notifier).copy(recipe);

    // Reset recipe to neutral
    container.read(recipeControllerProvider.notifier).resetAll();
    expect(container.read(recipeControllerProvider).recipe.contrast, 0.0);

    // 3 fingers down
    final g1 = await tester.startGesture(const Offset(100, 200), pointer: 1);
    final g2 = await tester.startGesture(const Offset(150, 200), pointer: 2);
    final g3 = await tester.startGesture(const Offset(200, 200), pointer: 3);

    // Swipe DOWN
    await g1.moveTo(const Offset(100, 300));
    await g2.moveTo(const Offset(150, 300));
    await g3.moveTo(const Offset(200, 300));
    await tester.pump();

    // Verify HUD toast and recipe pasted
    expect(find.text('Recipe Pasted'), findsOneWidget);
    expect(container.read(recipeControllerProvider).recipe.contrast, 0.75);

    await g1.up();
    await g2.up();
    await g3.up();
    await tester.pump(const Duration(milliseconds: 1500));
  });

  testWidgets('3-finger swipe LEFT triggers onNextPhoto', (tester) async {
    var nextCalled = false;
    await pumpShell(tester, onNext: () => nextCalled = true);
    await tester.pump(const Duration(milliseconds: 300));

    final g1 = await tester.startGesture(const Offset(250, 200), pointer: 1);
    final g2 = await tester.startGesture(const Offset(300, 200), pointer: 2);
    final g3 = await tester.startGesture(const Offset(350, 200), pointer: 3);

    // Swipe LEFT past -80px
    await g1.moveTo(const Offset(140, 200));
    await g2.moveTo(const Offset(190, 200));
    await g3.moveTo(const Offset(240, 200));
    await tester.pump();

    expect(nextCalled, isTrue);
    expect(find.text('Next Photo'), findsOneWidget);

    await g1.up();
    await g2.up();
    await g3.up();
    await tester.pump(const Duration(milliseconds: 1500));
  });

  testWidgets('3-finger swipe RIGHT triggers onPreviousPhoto', (tester) async {
    var prevCalled = false;
    await pumpShell(tester, onPrevious: () => prevCalled = true);
    await tester.pump(const Duration(milliseconds: 300));

    final g1 = await tester.startGesture(const Offset(100, 200), pointer: 1);
    final g2 = await tester.startGesture(const Offset(150, 200), pointer: 2);
    final g3 = await tester.startGesture(const Offset(200, 200), pointer: 3);

    // Swipe RIGHT past +80px
    await g1.moveTo(const Offset(210, 200));
    await g2.moveTo(const Offset(260, 200));
    await g3.moveTo(const Offset(310, 200));
    await tester.pump();

    expect(prevCalled, isTrue);
    expect(find.text('Previous Photo'), findsOneWidget);

    await g1.up();
    await g2.up();
    await g3.up();
    await tester.pump(const Duration(milliseconds: 1500));
  });
}
