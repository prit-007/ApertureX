import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:aperturex/color/histogram_view.dart';
import 'package:aperturex/color/interactive_histogram.dart';
import 'package:aperturex/engine/engine.dart';
import 'package:aperturex/ui/app_shell.dart';
import 'package:aperturex/viewport/compare_hold.dart';

Histogram _histogram() => Histogram(
  r: Uint32List(256)..[200] = 10,
  g: Uint32List(256)..[128] = 20,
  b: Uint32List(256)..[40] = 7,
  luma: Uint32List(256)..[100] = 15,
);

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    container.read(histogramProvider.notifier).publish(_histogram());
  });
  tearDown(() => container.dispose);

  Future<void> pumpShell(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: AppShell())),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  final handle = find.byKey(const Key('histogram-drawer-handle'));

  testWidgets('the histogram drawer starts collapsed and taps open', (
    tester,
  ) async {
    await pumpShell(tester);

    expect(handle, findsOneWidget);
    expect(find.byType(InteractiveHistogram), findsNothing);

    await tester.tap(handle);
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveHistogram), findsOneWidget);

    await tester.tap(handle);
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveHistogram), findsNothing);
  });

  testWidgets('the drawer responds to a swipe up and a swipe down', (
    tester,
  ) async {
    await pumpShell(tester);
    expect(find.byType(InteractiveHistogram), findsNothing);

    // Swipe the handle upward to pull it up.
    await tester.drag(handle, const Offset(0, -48));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveHistogram), findsOneWidget);

    // Swipe it back down to hide it.
    await tester.drag(handle, const Offset(0, 48));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveHistogram), findsNothing);
  });

  testWidgets('a short flick opens/closes on velocity (issue #45)', (
    tester,
  ) async {
    await pumpShell(tester);
    expect(find.byType(InteractiveHistogram), findsNothing);

    // 30px of travel in 2ms steps, then lift: net displacement after
    // kTouchSlop is ~12px — below the 24px open threshold — so only the
    // release velocity (~1500px/s) can open the drawer.
    var t = Duration.zero;
    final up = await tester.createGesture();
    await up.down(tester.getCenter(handle));
    await tester.pump();
    for (var i = 1; i <= 10; i++) {
      t += const Duration(microseconds: 2000);
      await up.moveBy(const Offset(0, -3), timeStamp: t);
    }
    await up.up(timeStamp: t + const Duration(microseconds: 1000));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveHistogram), findsOneWidget);

    // Same flick downward closes it.
    t = Duration.zero;
    final down = await tester.createGesture();
    await down.down(tester.getCenter(handle));
    await tester.pump();
    for (var i = 1; i <= 10; i++) {
      t += const Duration(microseconds: 2000);
      await down.moveBy(const Offset(0, 3), timeStamp: t);
    }
    await down.up(timeStamp: t + const Duration(microseconds: 1000));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveHistogram), findsNothing);
  });

  testWidgets('a slow drift below the threshold snaps back (issue #45)', (
    tester,
  ) async {
    await pumpShell(tester);
    expect(find.byType(InteractiveHistogram), findsNothing);

    // 20px up over a long time, released with no velocity: an accepted drag
    // (past kTouchSlop) but below the displacement threshold and no flick —
    // the drawer must not open.
    final drift = await tester.startGesture(tester.getCenter(handle));
    await tester.pump();
    await drift.moveBy(const Offset(0, -10));
    await tester.pump(const Duration(milliseconds: 80));
    await drift.moveBy(const Offset(0, -10));
    await tester.pump(const Duration(milliseconds: 80));
    await drift.up();
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveHistogram), findsNothing);
  });

  testWidgets('the panel holds the compare button', (tester) async {
    await pumpShell(tester);

    final compare = find.byTooltip('Hold to compare');
    expect(compare, findsOneWidget);
    expect(container.read(compareHoldProvider), isFalse);

    final gesture = await tester.startGesture(tester.getCenter(compare));
    await tester.pump();
    expect(container.read(compareHoldProvider), isTrue);

    await gesture.up();
    await tester.pump();
    expect(container.read(compareHoldProvider), isFalse);
    await tester.pump(const Duration(milliseconds: 400));
  });
}
