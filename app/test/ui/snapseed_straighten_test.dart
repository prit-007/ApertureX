import 'package:aperturex/edit/recipe_controller.dart';
import 'package:aperturex/gesture/gesture_interpreter.dart';
import 'package:aperturex/ui/snapseed/snapseed_shell.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  late ProviderContainer container;
  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  Widget harness() => UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: Scaffold(
        body: SnapseedShell(
          tool: GradeTool.exposure,
          category: ToolCategory.light,
          tools: gestureCategories[ToolCategory.light]!,
          onCycleCategory: () {},
          onPickTool: (_) {},
        ),
      ),
    ),
  );

  testWidgets('SnapseedShell offers straighten button that opens rotation dial', (
    tester,
  ) async {
    await tester.pumpWidget(harness());

    final straightenToggle = find.byKey(const Key('snapseed-straighten-toggle'));
    expect(straightenToggle, findsOneWidget);

    // Tap to open straighten dial
    await tester.tap(straightenToggle);
    await tester.pump();

    expect(find.byKey(const Key('snapseed-straighten-panel')), findsOneWidget);
    expect(find.byKey(const Key('rotation-dial-ruler')), findsOneWidget);

    // Drag on dial ruler
    await tester.drag(
      find.byKey(const Key('rotation-dial-ruler')),
      const Offset(-60, 0),
    );
    await tester.pump();

    final straighten = container.read(recipeControllerProvider).recipe.straighten;
    expect(straighten, isNonZero);

    // Close dial
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const Key('snapseed-straighten-panel')), findsNothing);
  });
}
