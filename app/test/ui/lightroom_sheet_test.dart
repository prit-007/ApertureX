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

    // Docked tray at the (raised) half snap: canvas keeps ~60% of portrait
    // height; collapsing the tray restores the full-height photo.
    expect(tester.getSize(find.byType(ImageCanvas)).height, closeTo(844 * 0.60, 40));
  });

  testWidgets('the sheet starts docked and drags between snap points', (
    tester,
  ) async {
    await pumpPortrait(tester);
    expect(bodyHeight(tester), closeTo(844 * 0.36, 2));

    // Pull up toward the full snap point.
    await tester.drag(find.text('Hide tools'), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(bodyHeight(tester), closeTo(844 * 0.62, 2));

    // Push down toward the docked snap point.
    await tester.drag(find.text('Hide tools'), const Offset(0, 150));
    await tester.pumpAndSettle();
    expect(bodyHeight(tester), closeTo(844 * 0.36, 2));

    // Push down toward the peek snap point. The gap half→peek is now wide
    // (raised snap fractions), so the drag must cross the midpoint, not just
    // nudge — test drags report zero velocity, so snapping is nearest-position.
    // Peek is floored at 236px (raised from 0.20; 844*0.28=236.32).
    await tester.drag(find.text('Hide tools'), const Offset(0, 110));
    await tester.pumpAndSettle();
    expect(bodyHeight(tester), closeTo(236, 2));
  });

  testWidgets('at peek the first parameter track is fully inside the sheet body', (
    tester,
  ) async {
    await pumpPortrait(tester);

    // Navigate to the peek snap: half -> peek.
    await tester.drag(find.text('Hide tools'), const Offset(0, 150));
    await tester.pumpAndSettle();
    await tester.drag(find.text('Hide tools'), const Offset(0, 110));
    await tester.pumpAndSettle();
    expect(bodyHeight(tester), closeTo(236, 2));

    final track = find.byKey(const Key('param-track-exposure'));
    expect(track, findsOneWidget);
    expect(track.hitTestable(), findsOneWidget);

    final bodyRect = tester.getRect(body);
    final trackRect = tester.getRect(track);
    expect(
      bodyRect.contains(trackRect.topLeft) &&
          bodyRect.contains(trackRect.bottomRight),
      isTrue,
      reason: 'exposure track $trackRect is not fully within peek body $bodyRect',
    );
  });

  testWidgets('short device (360x640) peek is floored so controls stay visible', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: AppShell())),
      ),
    );
    await tester.pump();

    // Docked at half; drag down toward peek. Before the 236px floor this
    // yielded 0.20*640=128px (zero content rows).
    expect(bodyHeight(tester), closeTo(640 * 0.36, 2));
    await tester.drag(find.text('Hide tools'), const Offset(0, 100));
    await tester.pumpAndSettle();
    expect(bodyHeight(tester), closeTo(236, 2));
    expect(tester.takeException(), isNull);

    final track = find.byKey(const Key('param-track-exposure'));
    expect(track, findsOneWidget);
    expect(track.hitTestable(), findsOneWidget);

    final bodyRect = tester.getRect(body);
    final trackRect = tester.getRect(track);
    expect(
      bodyRect.contains(trackRect.topLeft) &&
          bodyRect.contains(trackRect.bottomRight),
      isTrue,
      reason: 'exposure track $trackRect is not fully within peek body $bodyRect',
    );
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
    expect(bodyHeight(tester), closeTo(844 * 0.36, 2));
    expect(find.byType(LightroomShell), findsOneWidget);
  });

  testWidgets('double tapping the grab bar toggles maximize', (tester) async {
    await pumpPortrait(tester);
    expect(bodyHeight(tester), closeTo(844 * 0.36, 2));

    // Double tap to maximize
    await tester.tap(find.text('Hide tools'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Hide tools'));
    await tester.pumpAndSettle();
    expect(bodyHeight(tester), closeTo(844 * 0.62, 2));

    // Double tap again to restore docked
    await tester.tap(find.text('Hide tools'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Hide tools'));
    await tester.pumpAndSettle();
    expect(bodyHeight(tester), closeTo(844 * 0.36, 2));
  });

  testWidgets('the tool panel within the sheet scrolls properly within bounds', (
    tester,
  ) async {
    await pumpPortrait(tester);
    expect(bodyHeight(tester), closeTo(844 * 0.36, 2));

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

      final chipBar = find.byKey(const Key('lightroom-master-tabs-bar'));

      // Tap Effects & Detail -> Blur sub-tab
      await tester.tap(find.text('Effects & Detail'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Blur'));
      await tester.pumpAndSettle();
      expect(find.byType(SwitchListTile), findsWidgets);

      final chipBarScrollable = find.descendant(
        of: chipBar,
        matching: find.byType(Scrollable),
      );

      // Ensure Pro Tools is visible and tap it
      await tester.scrollUntilVisible(find.text('Pro Tools'), 50, scrollable: chipBarScrollable);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pro Tools'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Optics'));
      await tester.pumpAndSettle();
      expect(find.byType(SwitchListTile), findsWidgets);

      // Ensure Masks is visible and tap it
      await tester.scrollUntilVisible(find.text('Masks'), 50, scrollable: chipBarScrollable);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Masks'));
      await tester.pumpAndSettle();
    },
  );
}


