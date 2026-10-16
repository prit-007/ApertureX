import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aperturex/edit/parameter.dart';
import 'package:aperturex/edit/recipe_controller.dart';
import 'package:aperturex/settings/shell_preference.dart';
import 'package:aperturex/ui/app_shell.dart';
import 'package:aperturex/ui/snapseed/edit_hud.dart';
import 'package:aperturex/ui/snapseed/ghost_hint.dart';
import 'package:aperturex/ui/snapseed/snapseed_shell.dart';
import 'package:aperturex/viewport/image_canvas.dart';

// 1x1 transparent PNG bytes.
final Uint8List _png = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Ghost shell edge-to-edge & safe-area HUD (#41)', () {
    testWidgets('ImageCanvas is full-bleed with no SafeArea parent in ghost shell', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(shellPreferenceProvider.notifier).select(AppShellKind.snapseed);

      // Simulate a notched device (e.g. 48dp top status/camera cutout, 34dp bottom nav)
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 2.0;
      tester.view.padding = const FakeViewPadding(top: 96, bottom: 68);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: AppShell(imageBytes: _png),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final canvasFinder = find.byType(ImageCanvas);
      expect(canvasFinder, findsOneWidget);

      // Canvas extends to the full bounds of the parent Stack (0, 0 to 400, 800)
      final canvasRect = tester.getRect(canvasFinder);
      expect(canvasRect.top, 0.0);
      expect(canvasRect.left, 0.0);
      expect(canvasRect.width, 400.0);
      expect(canvasRect.height, 800.0);

      // Ensure no SafeArea ancestor sits directly between Stack and ImageCanvas
      // to avoid letterboxing black bars on edge-to-edge.
      final directSafeAreaParent = find.ancestor(
        of: canvasFinder,
        matching: find.byType(SafeArea),
      );
      expect(directSafeAreaParent, findsNothing);
    });

    testWidgets('GhostHint respects SafeArea insets', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(shellPreferenceProvider.notifier).select(AppShellKind.snapseed);

      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 2.0;
      tester.view.padding = const FakeViewPadding(top: 96, bottom: 68);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: AppShell(imageBytes: _png),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // GhostHint is rendered and contained within a SafeArea
      final hintFinder = find.byType(GhostHint);
      expect(hintFinder, findsOneWidget);

      final safeAreaInsideHint = find.descendant(
        of: hintFinder,
        matching: find.byType(SafeArea),
      );
      expect(safeAreaInsideHint, findsOneWidget);
    });

    testWidgets('EditHud and bottom dock respect safe-area insets', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'seen_gesture_hint': true});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(shellPreferenceProvider.notifier).select(AppShellKind.snapseed);

      // Set a non-neutral parameter to make EditHud active
      container.read(recipeControllerProvider.notifier).applyDelta(Parameter.exposure, 0.5);

      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 2.0;
      tester.view.padding = const FakeViewPadding(top: 96, bottom: 68, left: 24, right: 24);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: AppShell(imageBytes: _png),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // EditHud has a SafeArea protecting its content from notches
      final editHudFinder = find.byType(EditHud);
      expect(editHudFinder, findsOneWidget);
      final hudSafeArea = find.descendant(
        of: editHudFinder,
        matching: find.byType(SafeArea),
      );
      expect(hudSafeArea, findsOneWidget);

      // Bottom dock in SnapseedShell is wrapped in SafeArea
      final snapseedShellFinder = find.byType(SnapseedShell);
      expect(snapseedShellFinder, findsOneWidget);
      final dockSafeArea = find.descendant(
        of: snapseedShellFinder,
        matching: find.byType(SafeArea),
      );
      expect(dockSafeArea, findsWidgets);
    });
  });
}
