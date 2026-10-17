import 'package:aperturex/edit/adjustment_layer.dart';
import 'package:aperturex/edit/node_editor.dart';
import 'package:aperturex/edit/recipe_controller.dart';
import 'package:aperturex/ui/common/node_overlay.dart';
import 'package:aperturex/viewport/canvas_transform.dart';
import 'package:aperturex/viewport/mask_peek.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Image is 400×300 width-fitted, letterboxed 50px down a 800×600 surface.
  const transform = CanvasTransform(
    fitted: Size(400, 300),
    offset: Offset(0, 50),
    scale: 1,
  );

  late ProviderContainer container;
  setUp(() {
    container = ProviderContainer();
    container.read(canvasTransformProvider.notifier).set(transform);
    container.read(nodeEditorProvider.notifier).enable();
  });
  tearDown(() => container.dispose());

  Future<void> pumpOverlay(WidgetTester tester) => tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: NodeOverlay())),
    ),
  );

  List<AdjustmentLayer> layers() =>
      container.read(recipeControllerProvider).recipe.layers;

  testWidgets('tap on the photo places a radial node at that point', (
    tester,
  ) async {
    await pumpOverlay(tester);
    await tester.tapAt(const Offset(100, 200));
    await tester.pump();

    expect(layers(), hasLength(1));
    final layer = layers().single;
    expect(layer.maskKind, MaskKind.radial);
    final p = layer.maskParams;
    expect(p[0], closeTo(0.25, 1e-9)); // (100 - 0) / 400
    expect(p[1], closeTo(0.5, 1e-9)); // (200 - 50) / 300
    expect(p[2], closeTo(0.18, 1e-9)); // default radius
    expect(p[3], closeTo(0.24, 1e-9)); // radius × aspect (4:3) → circular
    expect(p[4], closeTo(0.3, 1e-9)); // feather
    expect(layer.exposure, 0.5); // visibly active from the start
    expect(container.read(nodeEditorProvider).selected, 0);
  });

  testWidgets('a second tap places and selects another node', (tester) async {
    await pumpOverlay(tester);
    await tester.tapAt(const Offset(100, 200));
    await tester.pump();
    await tester.tapAt(const Offset(300, 400));
    await tester.pump();

    expect(layers(), hasLength(2));
    expect(container.read(nodeEditorProvider).selected, 1);
  });

  testWidgets('tapping an existing node selects it without duplicating', (
    tester,
  ) async {
    await pumpOverlay(tester);
    await tester.tapAt(const Offset(100, 200));
    await tester.pump();
    await tester.tapAt(const Offset(100, 200));
    await tester.pump();

    expect(layers(), hasLength(1));
    expect(container.read(nodeEditorProvider).selected, 0);
  });

  testWidgets('dragging the centre handle moves the node', (tester) async {
    await pumpOverlay(tester);
    await tester.tapAt(const Offset(100, 200));
    await tester.pump();

    await tester.dragFrom(const Offset(100, 200), const Offset(40, 20));
    await tester.pump();

    final p = layers().single.maskParams;
    expect(p[0], closeTo(140 / 400, 1e-6)); // (140 - 0) / 400
    expect(p[1], closeTo((220 - 50) / 300, 1e-6)); // (220 - 50) / 300
    expect(p[2], closeTo(0.18, 1e-9)); // radius untouched
  });

  testWidgets('dragging the ring resizes the radius around the centre', (
    tester,
  ) async {
    await pumpOverlay(tester);
    await tester.tapAt(const Offset(100, 200));
    await tester.pump();

    // Ring's right edge: radius 0.18 × 400 = 72px right of centre (100, 200).
    await tester.dragFrom(const Offset(172, 200), const Offset(40, 0));
    await tester.pump();

    final p = layers().single.maskParams;
    // Pointer lands at x=212 → d = 112/72 → rx scales to 0.18 × d = 0.28.
    expect(p[2], closeTo(0.28, 1e-9));
    expect(p[3], closeTo(0.28 * 4 / 3, 1e-9)); // keeps the circular shape
    expect(p[0], closeTo(0.25, 1e-9)); // centre unchanged
  });

  testWidgets('taps fall through while node mode is off', (tester) async {
    container.read(nodeEditorProvider.notifier).disable();
    await pumpOverlay(tester);
    await tester.tapAt(const Offset(100, 200));
    await tester.pump();

    expect(layers(), isEmpty);
  });

  testWidgets('taps fall through before an image transform exists', (
    tester,
  ) async {
    container.read(canvasTransformProvider.notifier).set(null);
    await pumpOverlay(tester);
    await tester.tapAt(const Offset(100, 200));
    await tester.pump();

    expect(layers(), isEmpty);
  });

  group('palm rejection (issue #35)', () {
    testWidgets('stylus-only mode ignores touch pointers', (tester) async {
      container.read(stylusOnlyModeProvider.notifier).set(true);
      await pumpOverlay(tester);
      await tester.tapAt(const Offset(100, 200));
      await tester.pump();

      expect(layers(), isEmpty);
    });

    testWidgets('stylus-only mode still places with a stylus', (tester) async {
      container.read(stylusOnlyModeProvider.notifier).set(true);
      await pumpOverlay(tester);
      final gesture = await tester.startGesture(
        const Offset(100, 200),
        kind: PointerDeviceKind.stylus,
      );
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(layers(), hasLength(1));
      expect(layers().single.maskKind, MaskKind.radial);
    });

    testWidgets('stylus-only mode ignores concurrent palm touch during stylus interaction', (
      tester,
    ) async {
      container.read(stylusOnlyModeProvider.notifier).set(true);
      await pumpOverlay(tester);
      final palmGesture = await tester.startGesture(
        const Offset(50, 50),
        kind: PointerDeviceKind.touch,
      );
      await tester.pump();

      final stylusGesture = await tester.startGesture(
        const Offset(100, 200),
        kind: PointerDeviceKind.stylus,
      );
      await tester.pump();
      await stylusGesture.up();
      await tester.pump();

      await palmGesture.up();
      await tester.pump();

      expect(layers(), hasLength(1));
      expect(layers().single.maskKind, MaskKind.radial);
    });

    testWidgets('touch mode places with touch as before', (tester) async {
      container.read(stylusOnlyModeProvider.notifier).set(false);
      await pumpOverlay(tester);
      await tester.tapAt(const Offset(100, 200));
      await tester.pump();

      expect(layers(), hasLength(1));
    });

    testWidgets('bitmap mask paints ruby overlay when selected with peek enabled', (
      tester,
    ) async {
      final bitmapLayer = AdjustmentLayer.bitmap(
        width: 2,
        height: 2,
        alphas: [1.0, 0.0, 0.5, 0.8],
      );
      container.read(recipeControllerProvider.notifier).addLayer(bitmapLayer);
      container.read(nodeEditorProvider.notifier).select(0);
      container.read(maskPeekProvider.notifier).set(true);

      await pumpOverlay(tester);
      await tester.pump();

      // CustomPaint is present and rendered without error
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('multi-touch (2 fingers) dispatches canvas gesture and does not add node', (
      tester,
    ) async {
      await pumpOverlay(tester);

      CanvasGestureEvent? capturedEvent;
      container.listen(canvasGestureProvider, (_, next) {
        if (next != null) capturedEvent = next;
      });

      final g1 = await tester.createGesture(pointer: 1);
      final g2 = await tester.createGesture(pointer: 2);

      await g1.down(const Offset(100, 150));
      await g2.down(const Offset(200, 150));
      await tester.pump();

      await g1.moveTo(const Offset(80, 150));
      await g2.moveTo(const Offset(220, 150));
      await tester.pump();

      await g1.up();
      await g2.up();
      await tester.pumpAndSettle();

      expect(capturedEvent, isNotNull);
      expect(layers(), isEmpty);
    });
  });
}
