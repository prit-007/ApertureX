import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:aperturex/edit/parameter.dart';
import 'package:aperturex/edit/recipe_controller.dart';
import 'package:aperturex/settings/shell_preference.dart';
import 'package:aperturex/ui/app_shell.dart';
import 'package:aperturex/ui/lightroom/lightroom_shell.dart';
import 'package:aperturex/ui/snapseed/snapseed_shell.dart';
import 'package:aperturex/viewport/image_canvas.dart';

void main() {
  late ProviderContainer container;
  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  Future<void> pumpShell(WidgetTester tester) => tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: AppShell())),
    ),
  );

  testWidgets('defaults to the Lightroom shell over the shared canvas', (
    tester,
  ) async {
    await pumpShell(tester);

    expect(find.byType(LightroomShell), findsOneWidget);
    expect(find.byType(SnapseedShell), findsNothing);
    expect(find.byType(ImageCanvas), findsOneWidget);
  });

  testWidgets('switching shells keeps the recipe and canvas identical', (
    tester,
  ) async {
    await pumpShell(tester);

    // Edit through the shared controller, as the Lightroom shell would.
    container
        .read(recipeControllerProvider.notifier)
        .update(Parameter.exposure, 1.5);
    await tester.pump();
    final before = container.read(recipeControllerProvider).recipe;

    // Switch shells via the preference (no longer a chrome toggle).
    container
        .read(shellPreferenceProvider.notifier)
        .select(AppShellKind.snapseed);
    // The first-run ghost hint loops forever, so don't pumpAndSettle here.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(SnapseedShell), findsOneWidget);
    expect(find.byType(LightroomShell), findsNothing);
    expect(find.byType(ImageCanvas), findsOneWidget); // canvas is shared
    expect(container.read(recipeControllerProvider).recipe, before);
    expect(before.exposure, 1.5);
  });

  testWidgets('the editor shell exposes no debug floating buttons', (
    tester,
  ) async {
    await pumpShell(tester);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('the Lightroom panel can collapse for a full-screen image', (
    tester,
  ) async {
    await pumpShell(tester);
    expect(find.byType(LightroomShell), findsOneWidget);

    await tester.tap(find.text('Hide tools'));
    await tester.pumpAndSettle();
    expect(find.byType(LightroomShell), findsNothing);

    await tester.tap(find.text('Show tools'));
    await tester.pumpAndSettle();
    expect(find.byType(LightroomShell), findsOneWidget);
  });
}
