import 'package:aperturex/edit/node_editor.dart';
import 'package:aperturex/edit/recipe_controller.dart';
import 'package:aperturex/settings/onboarding.dart';
import 'package:aperturex/settings/shell_preference.dart';
import 'package:aperturex/ui/app_shell.dart';
import 'package:aperturex/ui/common/node_overlay.dart';
import 'package:aperturex/ui/lightroom/lightroom_shell.dart';
import 'package:aperturex/ui/snapseed/snapseed_shell.dart';
import 'package:aperturex/viewport/canvas_transform.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  SharedPreferences.setMockInitialValues({});
  // The unit-test canvas can't decode (no Rust engine), so the view transform
  // is seeded exactly as the loaded canvas would publish it: 400×300 fitted,
  // letterboxed 50px down the 800×600 test surface.
  const transform = CanvasTransform(
    fitted: Size(400, 300),
    offset: Offset(0, 50),
    scale: 1,
  );

  late ProviderContainer container;
  setUp(() {
    container = ProviderContainer();
    container.read(canvasTransformProvider.notifier).set(transform);
    container.read(gestureHintSeenProvider.notifier).markGestureHintSeen();
  });
  tearDown(() => container.dispose());

  Future<void> pumpShell(
    WidgetTester tester, {
    AppShellKind kind = AppShellKind.snapseed,
  }) async {
    container.read(shellPreferenceProvider.notifier).select(kind);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: AppShell())),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  List<double> params() =>
      container.read(recipeControllerProvider).recipe.layers.single.maskParams;

  group('gesture shell', () {
    testWidgets('Selective toggles node mode and swaps the bottom chrome', (
      tester,
    ) async {
      await pumpShell(tester);
      expect(find.byType(SnapseedShell), findsOneWidget);
      expect(find.byType(NodeOverlay), findsNothing);

      await tester.tap(find.byKey(const Key('selective-toggle')));
      await tester.pump();

      expect(container.read(nodeEditorProvider).enabled, isTrue);
      expect(find.byType(NodeOverlay), findsOneWidget);
      expect(find.byKey(const Key('node-controls')), findsOneWidget);
      // The tool pill and the bottom-corner hints step aside.
      expect(find.byKey(const Key('selective-toggle')), findsNothing);
      expect(find.text('Hold to compare'), findsNothing);
    });

    testWidgets('tap places a node; the bar edits, deletes and exits', (
      tester,
    ) async {
      await pumpShell(tester);
      await tester.tap(find.byKey(const Key('selective-toggle')));
      await tester.pump();

      await tester.tapAt(const Offset(200, 150));
      await tester.pump();

      expect(
        container.read(recipeControllerProvider).recipe.layers,
        hasLength(1),
      );
      expect(find.text('Node 1'), findsOneWidget);
      expect(params()[0], closeTo(0.5, 1e-9)); // (200)/400
      expect(params()[1], closeTo(100 / 300, 1e-9)); // (150-50)/300

      // Exposure: drag far right of centre so the result clears the default.
      await tester.drag(
        find.byKey(const Key('node-exposure-slider')),
        const Offset(200, 0),
      );
      await tester.pump();
      final exposure = container
          .read(recipeControllerProvider)
          .recipe
          .layers
          .single
          .exposure;
      expect(exposure, greaterThan(0.5));

      // Radius stays circular for the 4:3 image.
      await tester.drag(
        find.byKey(const Key('node-radius-slider')),
        const Offset(60, 0),
      );
      await tester.pump();
      final p = params();
      expect(p[2], greaterThan(0.18));
      expect(p[3] / p[2], closeTo(4 / 3, 1e-6));

      await tester.tap(find.byKey(const Key('node-delete')));
      await tester.pump();
      expect(container.read(recipeControllerProvider).recipe.layers, isEmpty);
      expect(find.byKey(const Key('node-controls')), findsOneWidget);
      expect(find.text('Selective'), findsOneWidget); // back to the hint

      await tester.tap(find.byKey(const Key('node-done')));
      await tester.pump();
      expect(container.read(nodeEditorProvider).enabled, isFalse);
      expect(find.byType(NodeOverlay), findsNothing);
      expect(find.byKey(const Key('node-controls')), findsNothing);
      expect(find.byKey(const Key('selective-toggle')), findsOneWidget);
      expect(find.text('Hold to compare'), findsOneWidget); // chrome back
    });
  });

  group('Lightroom shell', () {
    testWidgets('renders the node layer and adjust bar over the photo', (
      tester,
    ) async {
      await pumpShell(tester, kind: AppShellKind.lightroom);
      expect(find.byType(LightroomShell), findsOneWidget);
      expect(find.byType(NodeOverlay), findsNothing);

      container.read(nodeEditorProvider.notifier).enable();
      await tester.pump();

      expect(find.byType(NodeOverlay), findsOneWidget);
      expect(find.byKey(const Key('node-controls')), findsOneWidget);
      expect(find.text('Hold to compare'), findsNothing);
    });

    testWidgets('the Mask tab button toggles node mode', (tester) async {
      await pumpShell(tester, kind: AppShellKind.lightroom);
      await tester.scrollUntilVisible(
        find.text('Masks'),
        80,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Masks'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Masks'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('edit-on-canvas')), findsOneWidget);

      await tester.tap(find.byKey(const Key('edit-on-canvas')));
      await tester.pump();
      expect(container.read(nodeEditorProvider).enabled, isTrue);
      expect(find.byType(NodeOverlay), findsOneWidget);

      await tester.tap(find.byKey(const Key('edit-on-canvas')));
      await tester.pump();
      expect(container.read(nodeEditorProvider).enabled, isFalse);
      expect(find.byType(NodeOverlay), findsNothing);
    });
  });
}
