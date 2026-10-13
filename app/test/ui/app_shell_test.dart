import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tessera/edit/parameter.dart';
import 'package:tessera/edit/recipe_controller.dart';
import 'package:tessera/settings/shell_preference.dart';
import 'package:tessera/ui/app_shell.dart';
import 'package:tessera/ui/lightroom/lightroom_shell.dart';
import 'package:tessera/ui/snapseed/snapseed_shell.dart';
import 'package:tessera/viewport/image_canvas.dart';

void main() {
  late ProviderContainer container;
  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  Future<void> pumpShell(WidgetTester tester) => tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: AppShell()),
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

    // Switch shells.
    container
        .read(shellPreferenceProvider.notifier)
        .select(AppShellKind.snapseed);
    await tester.pumpAndSettle();

    expect(find.byType(SnapseedShell), findsOneWidget);
    expect(find.byType(LightroomShell), findsNothing);
    expect(find.byType(ImageCanvas), findsOneWidget); // canvas is shared
    expect(container.read(recipeControllerProvider).recipe, before);
    expect(before.exposure, 1.5);
  });

  testWidgets('the shell toggle switches between shells', (tester) async {
    await pumpShell(tester);

    await tester.tap(find.text('Snapseed'));
    await tester.pumpAndSettle();
    expect(find.byType(SnapseedShell), findsOneWidget);

    await tester.tap(find.text('Lightroom'));
    await tester.pumpAndSettle();
    expect(find.byType(LightroomShell), findsOneWidget);
  });
}
