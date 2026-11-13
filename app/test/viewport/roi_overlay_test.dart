import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/viewport/roi_overlay.dart';

void main() {
  // Image being edited: 4000x3000, proxy capped at 1440, width-fit world
  // size 1000x750, viewport 500x500.
  const imageW = 4000;
  const imageH = 3000;
  const proxyW = 1440;
  const fitted = Size(1000, 750);
  const viewport = Size(500, 500);

  group('planRoiOverlay activation', () {
    test('returns null while the proxy is still displayed at native density',
        () {
      // scale * fitted.width = 1.3 * 1000 = 1300 < 1440 → proxy not yet
      // magnified, no sharpness to gain from a full-res band.
      expect(
        planRoiOverlay(
          imageW: imageW,
          imageH: imageH,
          proxyW: proxyW,
          fitted: fitted,
          scale: 1.3,
          offset: Offset.zero,
          viewport: viewport,
        ),
        isNull,
      );
    });

    test('activates exactly when the proxy would start upscaling', () {
      // scale * fitted.width = 1440 == proxyW.
      final plan = planRoiOverlay(
        imageW: imageW,
        imageH: imageH,
        proxyW: proxyW,
        fitted: fitted,
        scale: 1.44,
        offset: Offset.zero,
        viewport: viewport,
      );
      expect(plan, isNotNull);
    });

    test('returns null when geometry edits are active', () {
      expect(
        planRoiOverlay(
          imageW: imageW,
          imageH: imageH,
          proxyW: proxyW,
          fitted: fitted,
          scale: 4,
          offset: Offset.zero,
          viewport: viewport,
          geometryActive: true,
        ),
        isNull,
      );
    });

    test('returns null when the source has no ROI decoder (RAW)', () {
      expect(
        planRoiOverlay(
          imageW: imageW,
          imageH: imageH,
          proxyW: proxyW,
          fitted: fitted,
          scale: 4,
          offset: Offset.zero,
          viewport: viewport,
          roiSupported: false,
        ),
        isNull,
      );
    });

    test('returns null when the viewport does not intersect the image', () {
      // Fully panned above the content: visible world y = -500.
      expect(
        planRoiOverlay(
          imageW: imageW,
          imageH: imageH,
          proxyW: proxyW,
          fitted: fitted,
          scale: 2,
          offset: const Offset(0, 1000),
          viewport: viewport,
        ),
        isNull,
      );
    });
  });

  group('planRoiOverlay geometry', () {
    test('maps the visible world rect to a full-width image band', () {
      // Inverse transform: world = (screen - offset) / scale.
      //   x = (0 - (-100)) / 2 = 50, y = (0 - (-50)) / 2 = 25
      //   size = 500/2 x 500/2 = 250 x 250
      final plan = planRoiOverlay(
        imageW: imageW,
        imageH: imageH,
        proxyW: proxyW,
        fitted: fitted,
        scale: 2,
        offset: const Offset(-100, -50),
        viewport: viewport,
      );
      expect(plan, isNotNull);
      // Image-space band rows: y 25..275 of a 750-tall world → x4000/1000,
      // x3000/750.
      expect(plan!.bandTop, 100);
      expect(plan.bandBottom, 1100);
      expect(plan.decodeW, imageW);
      expect(plan.decodeH, 1000);
      expect(plan.dstRect, const Rect.fromLTWH(50, 25, 250, 250));
    });

    test('clamps the band to the image when panned off the top', () {
      // offset.dy = 200 pushes the image down; visible world y starts at -50.
      final plan = planRoiOverlay(
        imageW: imageW,
        imageH: imageH,
        proxyW: proxyW,
        fitted: fitted,
        scale: 4,
        offset: const Offset(0, 200),
        viewport: viewport,
      );
      expect(plan, isNotNull);
      expect(plan!.bandTop, 0);
      expect(plan.dstRect.top, 0);
      // Visible world rect: (0, 0, 125, 75) after clamping → band bottom
      // = 75 / 750 * 3000 = 300.
      expect(plan.bandBottom, 300);
      expect(plan.dstRect, const Rect.fromLTWH(0, 0, 125, 75));
    });

    test('caps the band height to the memory budget', () {
      // 16000-wide source: budget 32 MiB → 33554432/(4*16000) = 524 rows
      // max, even though the visible band needs 2000 rows.
      final plan = planRoiOverlay(
        imageW: 16000,
        imageH: 6000,
        proxyW: proxyW,
        fitted: fitted,
        scale: 2,
        offset: Offset.zero,
        viewport: viewport,
      );
      expect(plan, isNotNull);
      expect(plan!.bandTop, 0);
      expect(plan.decodeH, 524);
      expect(plan.bandBottom, 524);
    });

    test('decodes at most one source pixel per pixel (never upscales)', () {
      // Extreme zoom: visible band is 20 image rows, plenty within budget —
      // the band stays at source resolution (decode size == source rows).
      final plan = planRoiOverlay(
        imageW: imageW,
        imageH: imageH,
        proxyW: proxyW,
        fitted: fitted,
        scale: 40,
        offset: Offset.zero,
        viewport: viewport,
      );
      expect(plan, isNotNull);
      expect(plan!.decodeW, imageW);
      // Visible world height 500/40 = 12.5 → 12.5/750*3000 = 50 rows.
      expect(plan.decodeH, 50);
    });
  });

  group('planRoiOverlay mobile & high-DPI scaling', () {
    test('activates detail tiles on mobile viewport when zoomed in past native threshold', () {
      const mobileFitted = Size(390, 292.5);
      const mobileViewport = Size(390, 600);
      const dpr = 3.0; // 3x retina mobile display

      // At 1.0x fit view, no detail tiles
      final fit = planRoiOverlay(
        imageW: 4000,
        imageH: 3000,
        proxyW: 1440,
        fitted: mobileFitted,
        scale: 1.0,
        offset: Offset.zero,
        viewport: mobileViewport,
        devicePixelRatio: dpr,
      );
      expect(fit, isNull);

      // On 1024px proxy (common preview dim) or ultra-high DPR (3.5x, 4.0x),
      // zoomed-out contain-fit view (scale <= 1.0) must NEVER plan ROI tiles
      final fit1024 = planRoiOverlay(
        imageW: 6000,
        imageH: 4000,
        proxyW: 1024,
        fitted: const Size(400, 267),
        scale: 1.0,
        offset: Offset.zero,
        viewport: const Size(400, 800),
        devicePixelRatio: 3.0,
      );
      expect(fit1024, isNull);

      final zoomedOut = planRoiOverlay(
        imageW: 6000,
        imageH: 4000,
        proxyW: 1024,
        fitted: const Size(400, 267),
        scale: 0.85,
        offset: Offset.zero,
        viewport: const Size(400, 800),
        devicePixelRatio: 3.5,
      );
      expect(zoomedOut, isNull);

      // At 1.3x zoom, detail tiles activate to render tack-sharp 1:1 master pixels
      final zoomed = planRoiOverlay(
        imageW: 4000,
        imageH: 3000,
        proxyW: 1440,
        fitted: mobileFitted,
        scale: 1.3,
        offset: Offset.zero,
        viewport: mobileViewport,
        devicePixelRatio: dpr,
      );
      expect(zoomed, isNotNull);
      expect(zoomed!.decodeW, 4000);
    });
  });
}
