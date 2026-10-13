import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tessera/gesture/gesture_interpreter.dart';
import 'package:tessera/ui/snapseed/snapseed_shell.dart';

void main() {
  late ProviderContainer container;
  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  testWidgets('shows the active tool and no radial menu by default', (
    tester,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: SnapseedShell(
              tool: GradeTool.exposure,
              onPickTool: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Exposure'), findsOneWidget);
    expect(find.byKey(const Key('radial-exposure')), findsNothing);
  });

  testWidgets('the Tools button opens the radial menu', (tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: SnapseedShell(
              tool: GradeTool.exposure,
              onPickTool: (_) {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Tools'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('radial-exposure')), findsOneWidget);
    expect(find.byKey(const Key('radial-contrast')), findsOneWidget);
  });
}
