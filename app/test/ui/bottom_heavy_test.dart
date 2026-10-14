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
