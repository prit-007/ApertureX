import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:aperturex/ui/app_shell.dart';
import 'package:aperturex/ui/lightroom/lightroom_shell.dart';
import 'package:aperturex/viewport/image_canvas.dart';

void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  Future<void> pumpPortrait(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: AppShell())),
      ),
    );
    await tester.pump();
  }

  final body = find.byKey(const Key('lightroom-sheet-body'));
  double bodyHeight(WidgetTester tester) => tester.getSize(body).height;

  testWidgets('the photo fills the screen in Lightroom mode (issue #32)', (
    tester,
  ) async {
    await pumpPortrait(tester);

    // Edge-to-edge: the canvas is no longer squeezed by a reserved panel.
    expect(tester.getSize(find.byType(ImageCanvas)).height, 844);
  });

  testWidgets('the sheet starts at half and drags between snap points', (
    tester,
  ) async {
    await pumpPortrait(tester);
    expect(bodyHeight(tester), closeTo(844 * 0.5, 1));

    // Pull up toward the full snap point.
    await tester.drag(find.text('Hide tools'), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(bodyHeight(tester), closeTo(844 * 0.9, 1));

    // Push down toward the peek snap point.
    await tester.drag(find.text('Hide tools'), const Offset(0, 600));
    await tester.pumpAndSettle();
    expect(bodyHeight(tester), closeTo(844 * 0.22, 1));
  });

  testWidgets('the grab bar collapses the sheet for a clean canvas', (
    tester,
  ) async {
    await pumpPortrait(tester);
    expect(find.byType(LightroomShell), findsOneWidget);

    await tester.tap(find.text('Hide tools'));
    await tester.pumpAndSettle();
    expect(bodyHeight(tester), 0);
    expect(find.byType(LightroomShell), findsNothing);
    // The photo is still edge-to-edge behind the collapsed sheet.
    expect(tester.getSize(find.byType(ImageCanvas)).height, 844);

    await tester.tap(find.text('Show tools'));
    await tester.pumpAndSettle();
    expect(bodyHeight(tester), closeTo(844 * 0.5, 1));
    expect(find.byType(LightroomShell), findsOneWidget);
  });
}
