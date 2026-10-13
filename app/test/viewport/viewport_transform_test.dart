import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:tessera/viewport/viewport_transform.dart';

void main() {
  group('ViewportTransform', () {
    test('worldToScreen and screenToWorld are inverse', () {
      const t = ViewportTransform(scale: 2.0, offset: Offset(10, -5));
      const world = Offset(100, 200);
      final screen = t.worldToScreen(world);
      expect(screen, const Offset(210, 395));
      expect(t.screenToWorld(screen), world);
    });

    test('fitScale fits the limiting axis', () {
      expect(
        ViewportTransform.fitScale(const Size(2000, 1000), const Size(500, 500)),
        closeTo(0.25, 1e-9),
      );
      expect(
        ViewportTransform.fitScale(const Size(1000, 2000), const Size(500, 500)),
        closeTo(0.25, 1e-9),
      );
    });

    test('zoomed keeps the focal world point fixed', () {
      const t = ViewportTransform(scale: 1.0, offset: Offset.zero);
      const focal = Offset(250, 250);
      final before = t.screenToWorld(focal);
      final zoomed = t.zoomed(
        newScale: 4.0,
        focalScreen: focal,
        minScale: 0.1,
        maxScale: 16,
      );
      final after = zoomed.screenToWorld(focal);
      expect(after.dx, closeTo(before.dx, 1e-9));
      expect(after.dy, closeTo(before.dy, 1e-9));
      expect(zoomed.scale, 4.0);
    });

    test('zoomed clamps scale to the allowed range', () {
      const t = ViewportTransform(scale: 1.0, offset: Offset.zero);
      final tooBig = t.zoomed(
        newScale: 100,
        focalScreen: Offset.zero,
        minScale: 0.5,
        maxScale: 8,
      );
      expect(tooBig.scale, 8);
      final tooSmall = t.zoomed(
        newScale: 0.01,
        focalScreen: Offset.zero,
        minScale: 0.5,
        maxScale: 8,
      );
      expect(tooSmall.scale, 0.5);
    });

    test('panned shifts the offset', () {
      const t = ViewportTransform(scale: 1.0, offset: Offset(10, 10));
      final panned = t.panned(const Offset(5, -3));
      expect(panned.offset, const Offset(15, 7));
      expect(panned.scale, 1.0);
    });

    test('visibleWorld maps the viewport rect into world space', () {
      const t = ViewportTransform(scale: 2.0, offset: Offset(-100, -100));
      final world = t.visibleWorld(const Size(400, 300));
      expect(world.topLeft, const Offset(50, 50));
      expect(world.bottomRight, const Offset(250, 200));
    });

    test('clampToImage centres an image smaller than the viewport', () {
      const t = ViewportTransform(scale: 1.0, offset: Offset(0, 0));
      final clamped = t.clampToImage(const Size(100, 100), const Size(400, 300));
      expect(clamped.offset.dx, closeTo(150, 1e-9));
      expect(clamped.offset.dy, closeTo(100, 1e-9));
    });

    test('clampToImage keeps a larger image covering the viewport', () {
      final t = ViewportTransform(scale: 1.0, offset: const Offset(-1000, 500));
      final clamped = t.clampToImage(const Size(1000, 1000), const Size(400, 300));
      expect(clamped.offset.dx, -600);
      expect(clamped.offset.dy, 0);
    });

    test('clampToImage does not change scale', () {
      const t = ViewportTransform(scale: 3.0, offset: Offset(9, 9));
      final clamped = t.clampToImage(const Size(100, 100), const Size(50, 50));
      expect(clamped.scale, 3.0);
    });
  });
}
