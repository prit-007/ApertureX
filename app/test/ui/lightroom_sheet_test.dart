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
    expect(bodyHeight(tester), closeTo(844 * 0.55, 1));

    // Pull up toward the full snap point.
    await tester.drag(find.text('Hide tools'), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(bodyHeight(tester), closeTo(844 * 0.92, 1));

    // Push down toward the peek snap point.
    await tester.drag(find.text('Hide tools'), const Offset(0, 600));
    await tester.pumpAndSettle();
    expect(bodyHeight(tester), closeTo(844 * 0.25, 1));
  });

  testWidgets('the grab bar collapses the sheet for a clean canvas', (
    tester,
  ) async {
    await pumpPortrait(tester);
    expect(find.byType(LightroomShell), findsOneWidget);

    await tester.tap(find.text('Hide tools'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(bodyHeight(tester), 0);
    expect(find.byType(LightroomShell), findsNothing);
    // The photo is still edge-to-edge behind the collapsed sheet.
    expect(tester.getSize(find.byType(ImageCanvas)).height, 844);

    await tester.tap(find.text('Show tools'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(bodyHeight(tester), closeTo(844 * 0.55, 1));
    expect(find.byType(LightroomShell), findsOneWidget);
  });

  testWidgets('double tapping the grab bar toggles maximize', (tester) async {
    await pumpPortrait(tester);
    expect(bodyHeight(tester), closeTo(844 * 0.55, 1));

    // Double tap to maximize
    await tester.tap(find.text('Hide tools'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Hide tools'));
    await tester.pumpAndSettle();
    expect(bodyHeight(tester), closeTo(844 * 0.92, 1));

    // Double tap again to restore half
    await tester.tap(find.text('Hide tools'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Hide tools'));
    await tester.pumpAndSettle();
    expect(bodyHeight(tester), closeTo(844 * 0.55, 1));
  });

  testWidgets('the tool panel within the sheet scrolls properly within bounds', (
    tester,
  ) async {
    await pumpPortrait(tester);
    expect(bodyHeight(tester), closeTo(844 * 0.55, 1));

    // In LightroomShell at half-height, the parameter list should be bounded to the sheet
    // and allow smooth vertical scrolling.
    final scrollable = find.byType(Scrollable).last;
    expect(scrollable, findsOneWidget);

    final scrollState = tester.state<ScrollableState>(scrollable);
    expect(scrollState.position.pixels, 0.0);

    // Drag up to scroll the parameters down
    await tester.drag(scrollable, const Offset(0, -150));
    await tester.pumpAndSettle();
    expect(scrollState.position.pixels, greaterThan(0.0));
  });

  testWidgets(
    'switching to blur, optics, and masking tabs renders without intermediate DecoratedBox ListTile error',
    (tester) async {
      await pumpPortrait(tester);

      final chipBar = find.byType(ListView).first;

      // Drag slightly to bring Blur on-screen
      await tester.drag(chipBar, const Offset(-60, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Blur'));
      await tester.pumpAndSettle();
      expect(find.byType(SwitchListTile), findsWidgets);

      // Drag further to bring Optics on-screen
      await tester.drag(chipBar, const Offset(-180, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Optics'));
      await tester.pumpAndSettle();
      expect(find.byType(SwitchListTile), findsWidgets);

      // Drag further to bring Masking on-screen
      await tester.drag(chipBar, const Offset(-180, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Masking'));
      await tester.pumpAndSettle();
    },
  );
}


