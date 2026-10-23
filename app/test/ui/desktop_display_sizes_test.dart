import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:aperturex/ui/app_shell.dart';
import 'package:aperturex/ui/lightroom/lightroom_shell.dart';
import 'package:aperturex/viewport/image_canvas.dart';

/// Desktop display-size matrix (issue #102).
///
/// Why: the adaptive layout (#34) was only ever proven at 390x844 and
/// 1280x800. Desktops span 1024x640 netbooks to 2560x1440 monitors, and the
/// installer smoke (#101/#105) can't catch RenderFlex overflow or a sidebar
/// width that drifts from the spec: sidebar = 30% of width, clamped to
/// 240–480dp, then capped at 40% of the window; wide = landscape OR
/// width >= 600. The expected numbers below duplicate that spec on purpose —
/// a refactored formula must fail here, not ship a silently different shell.
void main() {
  late ProviderContainer container;
  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  Future<void> pumpShell(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: AppShell())),
      ),
    );
    // One extra frame lets layout/paint exceptions (overflow) surface.
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// Spec copy of the sidebar width formula (app_shell.dart).
  double sidebarSpec(double width) {
    var w = width * 0.30;
    if (w < 240) w = 240;
    if (w > 480) w = 480;
    final cap = width * 0.40;
    if (w > cap) w = cap;
    return w;
  }

  Finder sidebarFinder(double expectedWidth) => find.descendant(
    of: find.byType(AppShell),
    matching: find.byWidgetPredicate(
      (w) =>
          w is SizedBox &&
          w.width != null &&
          (w.width! - expectedWidth).abs() < 0.01,
      description: 'sidebar SizedBox(width: $expectedWidth)',
    ),
  );

  group('wide sizes split into canvas + spec-width sidebar', () {
    // name: [width, height]
    const sizes = <String, (double, double)>{
      'laptop 1440x900': (1440, 900),
      'full-HD 1920x1080': (1920, 1080),
      'small laptop 1024x640': (1024, 640),
      'portrait tablet 800x1280 (width >= 600)': (800, 1280),
      'QHD 2560x1440': (2560, 1440),
      'wide-breakpoint boundary 600x960': (600, 960),
    };

    for (final entry in sizes.entries) {
      final name = entry.key;
      final size = entry.value;
      testWidgets('$name shows the sidebar hosting the Lightroom panel', (
        tester,
      ) async {
        tester.view.physicalSize = Size(size.$1, size.$2);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await pumpShell(tester);

        expect(find.byType(LightroomShell), findsOneWidget);
        expect(find.byType(ImageCanvas), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'no layout overflow');

        final expected = sidebarSpec(size.$1);
        final sidebar = sidebarFinder(expected);
        expect(
          sidebar,
          findsWidgets,
          reason:
              'sidebar must be ${expected}dp wide at ${size.$1}px '
              '(30%, clamp 240-480, cap 40%)',
        );
        expect(
          find.descendant(
            of: sidebar.first,
            matching: find.byType(LightroomShell),
          ),
          findsOneWidget,
          reason: 'the spec-width sidebar hosts the Lightroom panel',
        );
      });
    }
  });

  group('narrow sizes stay stacked', () {
    const sizes = <String, (double, double)>{
      'phone portrait 390x844': (390, 844),
      'just below breakpoint 599x800': (599, 800),
    };

    for (final entry in sizes.entries) {
      final name = entry.key;
      final size = entry.value;
      testWidgets('$name has no sidebar column', (tester) async {
        tester.view.physicalSize = Size(size.$1, size.$2);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await pumpShell(tester);

        expect(find.byType(LightroomShell), findsOneWidget);
        expect(find.byType(ImageCanvas), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'no layout overflow');

        // At 599px the layout is stacked, so the (clamped) spec width must
        // not appear as a sidebar; below 600 * 0.3 the raw 30% width is
        // below the 240dp floor, so neither value may show up as a column.
        expect(sidebarFinder(size.$1 * 0.30), findsNothing);
        expect(sidebarFinder(sidebarSpec(size.$1)), findsNothing);
      });
    }
  });

  testWidgets('rotating a desktop window swaps split <-> stacked', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpShell(tester);
    expect(sidebarFinder(sidebarSpec(1440)), findsWidgets);

    // Rotate to portrait tablet: still >= 600 wide, so the sidebar remains
    // but follows the new (shorter) width in the formula.
    tester.view.physicalSize = const Size(900, 1440);
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);
    expect(sidebarFinder(sidebarSpec(900)), findsWidgets);

    // Collapse below the breakpoint on both axes → stacked.
    tester.view.physicalSize = const Size(480, 800);
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);
    expect(sidebarFinder(sidebarSpec(480)), findsNothing);
    expect(find.byType(LightroomShell), findsOneWidget);
  });
}
