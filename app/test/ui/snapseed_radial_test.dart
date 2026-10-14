import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:aperturex/gesture/gesture_interpreter.dart';
import 'package:aperturex/ui/snapseed/snapseed_shell.dart';

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

  testWidgets('shows the active category, tool and no radial by default', (
    tester,
  ) async {
    await tester.pumpWidget(harness());

    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Exposure'), findsOneWidget);
    expect(find.byKey(const Key('radial-exposure')), findsNothing);
  });

  testWidgets('the Tools button opens the radial menu for the category', (
    tester,
  ) async {
    await tester.pumpWidget(harness());

    await tester.tap(find.byTooltip('Tools'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('radial-exposure')), findsOneWidget);
    expect(find.byKey(const Key('radial-contrast')), findsOneWidget);
  });

  testWidgets('a tap 8px outside a ring item still hits the item (issue #46)', (
    tester,
  ) async {
    final picked = <GradeTool>[];
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: SnapseedShell(
              tool: GradeTool.exposure,
              category: ToolCategory.light,
              tools: gestureCategories[ToolCategory.light]!,
              onCycleCategory: () {},
              onPickTool: picked.add,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Tools'));
    await tester.pumpAndSettle();

    final item = find.byKey(const Key('radial-contrast'));
    expect(item, findsOneWidget);
    // The hit box (88×100) is centered on the ring point; the 56px circle
    // sits at its top. Tap 32px right of the box center — 4px outside the
    // circle, inside the hit box.
    final center = tester.getCenter(item);
    await tester.tapAt(center + const Offset(32, -18));
    await tester.pump();

    expect(picked, contains(GradeTool.contrast));
    // Picking closes the menu (by design) — the assertion above already
    // proves the inflated hit box claimed the tap instead of the backdrop.

    // A tap far from every item still hits the backdrop and dismisses
    // without picking.
    await tester.tap(find.byTooltip('Tools'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(8, 8));
    await tester.pump();
    expect(picked, hasLength(1)); // no second pick from the backdrop
    expect(find.byKey(const Key('radial-exposure')), findsNothing);
  });
}
