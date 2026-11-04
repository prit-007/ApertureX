import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:image/image.dart' as img;
import 'package:aperturex/edit/active_image.dart';
import 'package:aperturex/edit/parameter.dart';
import 'package:aperturex/edit/recipe_controller.dart';
import 'package:aperturex/ui/common/parameter_slider_row.dart';
import 'package:aperturex/ui/edit_activity.dart';
import 'package:aperturex/viewport/canvas_transform.dart';
import 'package:aperturex/viewport/compare_hold.dart';
import 'package:aperturex/viewport/preview_surface.dart';
import 'package:aperturex/viewport/roi_overlay.dart';
import 'package:aperturex/viewport/split_compare.dart';
import 'package:aperturex/viewport/wiper_compare.dart';

Uint8List createValidJpeg({int width = 32, int height = 32}) {
  final image = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      image.setPixelRgb(x, y, (x * 10) % 256, (y * 10) % 256, 128);
    }
  }
  return Uint8List.fromList(img.encodeJpg(image));
}

void main() {
  group('Pro Viewport Zoom & Scrubbing Precision Tests', () {
    test('planRoiOverlay plans detail overlay when zoomed in on mobile viewport', () {
      // Mobile screen: fitted width 390px, image 4000x3000, proxy 1440
      const imageW = 4000;
      const imageH = 3000;
      const proxyW = 1440;
      const fitted = Size(390, 292.5);
      const viewport = Size(390, 600);

      // At scale = 1.0 (fit mode), no ROI overlay needed
      final fitPlan = planRoiOverlay(
        imageW: imageW,
        imageH: imageH,
        proxyW: proxyW,
        fitted: fitted,
        scale: 1.0,
        offset: Offset.zero,
        viewport: viewport,
      );
      expect(fitPlan, isNull);

      // At zoom on mobile high-DPI (e.g. 1.3x zoom with DPR 3.0)
      final mobileZoomPlan = planRoiOverlay(
        imageW: imageW,
        imageH: imageH,
        proxyW: proxyW,
        fitted: fitted,
        scale: 1.3,
        offset: const Offset(-50, -30),
        viewport: viewport,
        devicePixelRatio: 3.0,
      );
      expect(mobileZoomPlan, isNotNull);
      expect(mobileZoomPlan!.decodeW, imageW);

      // At deep zoom (e.g. 4.0x where scale * fitted.width >= proxyW), ROI overlay plans correctly
      final deepPlan = planRoiOverlay(
        imageW: imageW,
        imageH: imageH,
        proxyW: proxyW,
        fitted: fitted,
        scale: 4.0,
        offset: const Offset(-200, -100),
        viewport: viewport,
      );
      expect(deepPlan, isNotNull);
      expect(deepPlan!.decodeW, imageW);
    });

    test('CanvasTransform correctly preserves zoom and pan during recipe modifications', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Initialize viewport transform to 2.5x zoom centered on an interest point
      const zoomed = CanvasTransform(
        fitted: Size(400, 300),
        offset: Offset(-200, -150),
        scale: 2.5,
      );
      container.read(canvasTransformProvider.notifier).set(zoomed);

      expect(container.read(canvasTransformProvider)!.scale, 2.5);
      expect(container.read(canvasTransformProvider)!.offset, const Offset(-200, -150));

      // Update recipe parameters (e.g. exposure and contrast)
      container.read(recipeControllerProvider.notifier).update(Parameter.exposure, 1.25);
      container.read(recipeControllerProvider.notifier).update(Parameter.contrast, 15.0);

      // Zoom transform state must remain rock solid
      final current = container.read(canvasTransformProvider);
      expect(current!.scale, 2.5);
      expect(current.offset, const Offset(-200, -150));
    });

    test('Compare hold can be activated and released without resetting zoom scale', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      const zoomed = CanvasTransform(
        fitted: Size(400, 300),
        offset: Offset(-100, -80),
        scale: 2.0,
      );
      container.read(canvasTransformProvider.notifier).set(zoomed);

      // User presses and holds compare while zoomed in
      container.read(compareHoldProvider.notifier).hold();
      expect(container.read(compareHoldProvider), isTrue);
      expect(container.read(canvasTransformProvider)!.scale, 2.0);

      // User releases compare
      container.read(compareHoldProvider.notifier).release();
      expect(container.read(compareHoldProvider), isFalse);
      expect(container.read(canvasTransformProvider)!.scale, 2.0);
    });

    test('Wiper compare works smoothly on zoomed viewport without resetting scale', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      const zoomed = CanvasTransform(
        fitted: Size(400, 300),
        offset: Offset(-150, -120),
        scale: 3.0,
      );
      container.read(canvasTransformProvider.notifier).set(zoomed);

      // Activate wiper compare
      container.read(wiperCompareProvider.notifier).toggle();
      expect(container.read(wiperCompareProvider).isActive, isTrue);
      expect(container.read(canvasTransformProvider)!.scale, 3.0);

      // Scrub wiper curtain across screen
      container.read(wiperCompareProvider.notifier).setPosition(0.70);
      expect(container.read(wiperCompareProvider).position, 0.70);
      expect(container.read(canvasTransformProvider)!.scale, 3.0);

      // Toggle wiper orientation
      container.read(wiperCompareProvider.notifier).toggleOrientation();
      expect(container.read(wiperCompareProvider).orientation, WiperOrientation.horizontal);
      expect(container.read(canvasTransformProvider)!.scale, 3.0);
    });

    test('Split compare side-by-side mode operates seamlessly while zoomed in', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      const zoomed = CanvasTransform(
        fitted: Size(400, 300),
        offset: Offset(-80, -60),
        scale: 2.2,
      );
      container.read(canvasTransformProvider.notifier).set(zoomed);

      // Activate split compare
      container.read(splitCompareProvider.notifier).toggle();
      expect(container.read(splitCompareProvider).isEnabled, isTrue);
      expect(container.read(canvasTransformProvider)!.scale, 2.2);

      // Switch to top/bottom split
      container.read(splitCompareProvider.notifier).setOrientation(SplitOrientation.topBottom);
      expect(container.read(splitCompareProvider).orientation, SplitOrientation.topBottom);
      expect(container.read(canvasTransformProvider)!.scale, 2.2);
    });

    test('Master image resolution upgrade updates activeImageBytesProvider seamlessly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final previewBytes = createValidJpeg(width: 100, height: 75);
      final masterBytes = createValidJpeg(width: 4000, height: 3000);

      // Set initial preview bytes
      container.read(activeImageBytesProvider.notifier).setBytes(previewBytes);
      expect(container.read(activeImageBytesProvider), previewBytes);

      // Background load delivers full master bytes
      container.read(activeImageBytesProvider.notifier).setBytes(masterBytes);
      expect(container.read(activeImageBytesProvider), masterBytes);
      expect(container.read(activeImageBytesProvider)!.length, greaterThan(previewBytes.length));
    });

    testWidgets('ParameterSliderRow supports onChangeStart and onChangeEnd for live edit activity signaling', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      double currentValue = 0.5;
      bool started = false;
      bool ended = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: ParameterSliderRow(
                  label: 'Exposure',
                  value: currentValue,
                  min: -2.0,
                  max: 2.0,
                  onChanged: (val) => currentValue = val,
                  onChangeStart: (_) {
                    started = true;
                    container.read(editActivityProvider.notifier).begin();
                  },
                  onChangeEnd: (_) {
                    ended = true;
                    container.read(editActivityProvider.notifier).end();
                  },
                ),
              ),
            ),
          ),
        ),
      );

      expect(container.read(editActivityProvider), isFalse);

      // Drag the slider
      final sliderFinder = find.byType(Slider);
      expect(sliderFinder, findsOneWidget);

      final center = tester.getCenter(sliderFinder);
      final gesture = await tester.startGesture(center);
      await tester.pump();

      expect(started, isTrue);
      expect(container.read(editActivityProvider), isTrue);

      await gesture.moveBy(const Offset(30, 0));
      await tester.pump();

      await gesture.up();
      await tester.pump();

      expect(ended, isTrue);
      expect(container.read(editActivityProvider), isFalse);
    });

    test('useTextureDelivery yields to shader/tile custom paint when roiActive is true', () {
      // Proves that when high-zoom detail tiles are active, zero-copy texture
      // yields so CustomPaint renders the sharp 1:1 master resolution tiles
      expect(
        useTextureDelivery(
          textureId: 42,
          hasImportedLut: false,
          gestureActive: false,
          roiActive: true,
          geometryActive: false,
        ),
        isFalse,
      );

      // Normal idle view without tiles retains zero-copy texture
      expect(
        useTextureDelivery(
          textureId: 42,
          hasImportedLut: false,
          gestureActive: false,
          roiActive: false,
          geometryActive: false,
        ),
        isTrue,
      );
    });

    testWidgets('PreviewSurface renders fallback when textureId is null (e.g. tiles active)', (tester) async {
      bool fallbackRendered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PreviewSurface(
              textureId: null, // As yielded when _tilesActive || tiles.isNotEmpty
              fallback: (context) {
                fallbackRendered = true;
                return const Text('Sharp Master Tiles Overlay');
              },
            ),
          ),
        ),
      );

      expect(fallbackRendered, isTrue);
      expect(find.text('Sharp Master Tiles Overlay'), findsOneWidget);
    });

    test('computeDoubleTapZoom toggles between 1:1 punch-in and fit view', () {
      const fitted = Size(1000, 750);
      const bounds = Size(1000, 1000);
      const initialOffset = Offset(0, 125);

      // 1. Initial fitted state at 1.0x -> double-tap at center
      final punchedIn = computeDoubleTapZoom(
        currentScale: 1.0,
        currentOffset: initialOffset,
        tapPosition: const Offset(500, 500),
        fitted: fitted,
        bounds: bounds,
        fullWidth: 3000, // 3000px image on 1000px display = 3.0x 1:1 sensor view
      );

      // Verify punch-in to 3.0x 1:1 sensor view
      expect(punchedIn.scale, 3.0);
      expect(punchedIn.fitted, fitted);

      // 2. Already zoomed in (> 1.05x) -> double-tap resets back to 1.0x fit view
      final resetToFit = computeDoubleTapZoom(
        currentScale: punchedIn.scale,
        currentOffset: punchedIn.offset,
        tapPosition: const Offset(500, 500),
        fitted: fitted,
        bounds: bounds,
        fullWidth: 3000,
      );

      expect(resetToFit.scale, 1.0);
      expect(resetToFit.offset, initialOffset);

      // 3. Off-center tap targets the tapped region precisely
      final cornerPunch = computeDoubleTapZoom(
        currentScale: 1.0,
        currentOffset: initialOffset,
        tapPosition: const Offset(800, 300),
        fitted: fitted,
        bounds: bounds,
        fullWidth: 2500,
      );
      expect(cornerPunch.scale, 2.5);
      // Offset is clamped within valid bounds
      expect(cornerPunch.offset.dx, lessThanOrEqualTo(0.0));
      expect(cornerPunch.offset.dx, greaterThanOrEqualTo(bounds.width - fitted.width * 2.5));
    });
  });
}
