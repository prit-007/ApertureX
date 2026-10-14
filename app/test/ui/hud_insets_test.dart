import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aperturex/color/histogram_view.dart';
import 'package:aperturex/color/interactive_histogram.dart';
import 'package:aperturex/edit/node_editor.dart';
import 'package:aperturex/edit/parameter.dart';
import 'package:aperturex/edit/recipe_controller.dart';
import 'package:aperturex/settings/onboarding.dart';
import 'package:aperturex/settings/shell_preference.dart';
import 'package:aperturex/src/rust/api/histogram.dart';
import 'package:aperturex/ui/app_shell.dart';
import 'package:aperturex/ui/snapseed/edit_hud.dart';
import 'package:aperturex/ui/snapseed/snapseed_shell.dart';
import 'package:aperturex/gesture/gesture_interpreter.dart';

/// Floating HUDs must clear system insets (issue #47): side notches in
/// landscape, status bar / curved corners in portrait, gesture-nav bar at the
/// bottom. Each test injects a MediaQuery padding and asserts the HUD's rect
/// stays inside the safe region.
void main() {
  late ProviderContainer container;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer();
  });
  tearDown(() => container.dispose());

  /// Overrides the ambient padding (display cutout / nav bar) for [child].
  Widget withInsets(EdgeInsets padding, Widget child) {
    return Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(padding: padding),
        child: child,
      ),
    );
  }

  Widget snapseed({EdgeInsets padding = EdgeInsets.zero}) => MaterialApp(
    home: Scaffold(
      body: withInsets(
        padding,
        UncontrolledProviderScope(
          container: container,
          child: SnapseedShell(
            tool: GradeTool.exposure,
            category: ToolCategory.light,
            tools: gestureCategories[ToolCategory.light]!,
            onCycleCategory: () {},
            onPickTool: (_) {},
          ),
        ),
      ),
    ),
  );

  testWidgets('EditHud clears the right-edge notch (issue #47)', (tester) async {
    // Punch-hole on the right edge (landscape).
    await tester.pumpWidget(
      snapseed(padding: const EdgeInsets.only(right: 48)),
    );
    container
        .read(recipeControllerProvider.notifier)
        .update(Parameter.exposure, 0.5);
    await tester.pump();

    final rect = tester.getRect(find.byType(EditHud));
    expect(rect.right, lessThanOrEqualTo(tester.getSize(find.byType(SnapseedShell)).width - 48 + 0.5),
        reason: 'EditHud must not sit under the right-edge cutout');
  });

  testWidgets('EditHud clears the status bar in portrait (issue #47)', (tester) async {
    await tester.pumpWidget(
      snapseed(padding: const EdgeInsets.only(top: 24)),
    );
    container
        .read(recipeControllerProvider.notifier)
        .update(Parameter.exposure, 0.5);
    await tester.pump();

    final rect = tester.getRect(find.byType(EditHud));
    expect(rect.top, greaterThanOrEqualTo(24 - 0.5),
        reason: 'EditHud must not sit under the status bar');
  });

  testWidgets('radial ring items clear the side and nav-bar insets (issue #47)', (tester) async {
    // Landscape phone: a left-edge cutout and the gesture-nav bar. The ring is
    // 280px tall, so without insets its bottom items fall under the nav bar.
    tester.view.physicalSize = const Size(2400, 1080); // 800x360 logical
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      snapseed(padding: const EdgeInsets.only(left: 48, bottom: 48)),
    );
    await tester.tap(find.byTooltip('Tools'));
    await tester.pumpAndSettle();

    final items = find.byWidgetPredicate(
      (w) => w.key != null && w.key.toString().contains('radial-'),
    );
    expect(items, findsWidgets);
    final height = tester.getSize(find.byType(SnapseedShell)).height;
    for (final element in items.evaluate()) {
      final rect = tester.getRect(find.byWidget(element.widget));
      expect(rect.left, greaterThanOrEqualTo(48 - 0.5),
          reason: 'ring item ${element.widget.key} clipped by the leading cutout');
      expect(rect.bottom, lessThanOrEqualTo(height - 48 + 0.5),
          reason: 'ring item ${element.widget.key} under the gesture-nav bar');
    }
  });

  testWidgets('wide-layout NodeControls clears side notches (issue #47)', (tester) async {
    // Landscape surface → AppShell's split layout.
    tester.view.physicalSize = const Size(2400, 1080);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    container.read(shellPreferenceProvider.notifier).select(AppShellKind.lightroom);
    container.read(nodeEditorProvider.notifier).enable();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: withInsets(
            const EdgeInsets.only(left: 48, right: 48, bottom: 24),
            UncontrolledProviderScope(
              container: container,
              child: const AppShell(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final controls = find.byKey(const Key('node-controls'));
    expect(controls, findsOneWidget);
    final rect = tester.getRect(controls);
    expect(rect.left, greaterThanOrEqualTo(48 - 0.5),
        reason: 'NodeControls under the left-edge cutout in landscape');
    expect(rect.right, lessThanOrEqualTo(800 - 48 + 0.5),
        reason: 'NodeControls under the right-edge cutout in landscape');
  });

  testWidgets('histogram overlay clears the status bar (issue #47)', (tester) async {
    container.read(shellPreferenceProvider.notifier).select(AppShellKind.snapseed);
    container.read(gestureHintSeenProvider.notifier).markGestureHintSeen();
    final bins = Uint32List(256);
    bins[10] = 3;
    container.read(histogramProvider.notifier).publish(
      Histogram(r: bins, g: bins, b: bins, luma: bins),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: withInsets(
            const EdgeInsets.only(top: 24, left: 48, right: 48),
            UncontrolledProviderScope(
              container: container,
              child: const AppShell(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Show histogram'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final histogram = find.byType(InteractiveHistogram);
    expect(histogram, findsOneWidget);
    final rect = tester.getRect(histogram);
    expect(rect.top, greaterThanOrEqualTo(24 - 0.5),
        reason: 'histogram under the status bar');
    expect(rect.left, greaterThanOrEqualTo(48 - 0.5),
        reason: 'histogram under the left-edge cutout');
  });

  testWidgets('bottom affordances clear the gesture-nav bar (issue #47)', (tester) async {
    container.read(shellPreferenceProvider.notifier).select(AppShellKind.snapseed);
    container.read(gestureHintSeenProvider.notifier).markGestureHintSeen();
    final bins = Uint32List(256);
    container.read(histogramProvider.notifier).publish(
      Histogram(r: bins, g: bins, b: bins, luma: bins),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: withInsets(
            const EdgeInsets.only(bottom: 24),
            UncontrolledProviderScope(
              container: container,
              child: const AppShell(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final toggle = find.byTooltip('Show histogram');
    expect(toggle, findsOneWidget);
    final rect = tester.getRect(toggle);
    final height = tester.getSize(find.byType(AppShell)).height;
    expect(rect.bottom, lessThanOrEqualTo(height - 24 + 0.5),
        reason: 'histogram toggle under the gesture-nav bar');
  });
}
