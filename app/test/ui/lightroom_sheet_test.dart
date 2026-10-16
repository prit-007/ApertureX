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

  testWidgets('the photo occupies the unobstructed viewport in Lightroom mode (issue #32)', (
    tester,
  ) async {
    await pumpPortrait(tester);

    // Unobstructed viewport: canvas occupies ~75% of portrait height above the docked instrument tray
    expect(tester.getSize(find.byType(ImageCanvas)).height, closeTo(844 * 0.73, 40));
  });

  testWidgets('the sheet starts docked and drags between snap points', (
    tester,
  ) async {
    await pumpPortrait(tester);
    expect(bodyHeight(tester), closeTo(844 * 0.24, 2));

    // Pull up toward the full snap point.
    await tester.drag(find.text('Hide tools'), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(bodyHeight(tester), closeTo(844 * 0.38, 2));

    // Push down toward the docked snap point.
    await tester.drag(find.text('Hide tools'), const Offset(0, 150));
    await tester.pumpAndSettle();
    expect(bodyHeight(tester), closeTo(844 * 0.24, 2));

    // Push down toward the peek snap point.
    await tester.drag(find.text('Hide tools'), const Offset(0, 50));
    await tester.pumpAndSettle();
    expect(bodyHeight(tester), closeTo(844 * 0.20, 2));
  });

  testWidgets('the grab bar collapses the sheet for a clean canvas', (
    tester,
  ) async {
    await pumpPortrait(tester);
    expect(find.byType(LightroomShell), findsOneWidget);

    await tester.tap(find.text('Hide tools'));
    // Pump intermediate frames where height sweeps through 0..88px
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(bodyHeight(tester), 0);
    expect(find.byType(LightroomShell), findsNothing);
    // The photo expands to full screen in immersive preview.
    expect(tester.getSize(find.byType(ImageCanvas)).height, closeTo(844, 35));

    await tester.tap(find.text('Show tools'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(bodyHeight(tester), closeTo(844 * 0.24, 2));
    expect(find.byType(LightroomShell), findsOneWidget);
  });

  testWidgets('double tapping the grab bar toggles maximize', (tester) async {
    await pumpPortrait(tester);
    expect(bodyHeight(tester), closeTo(844 * 0.24, 2));

    // Double tap to maximize
    await tester.tap(find.text('Hide tools'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Hide tools'));
    await tester.pumpAndSettle();
    expect(bodyHeight(tester), closeTo(844 * 0.38, 2));

    // Double tap again to restore docked
    await tester.tap(find.text('Hide tools'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Hide tools'));
    await tester.pumpAndSettle();
    expect(bodyHeight(tester), closeTo(844 * 0.24, 2));
  });

  testWidgets('the tool panel within the sheet scrolls properly within bounds', (
    tester,
  ) async {
    await pumpPortrait(tester);
    expect(bodyHeight(tester), closeTo(844 * 0.24, 2));

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


