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
}
