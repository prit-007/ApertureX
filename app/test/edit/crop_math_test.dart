import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:tessera/edit/crop_math.dart';

void main() {
  group('fitAspectWithin', () {
    const image = Size(400, 800); // portrait 1:2

    test('a square aspect on a 2:1-tall image is full-width, half-height', () {
      final r = fitAspectWithin(const Rect.fromLTWH(0, 0, 1, 1), 1.0, image);
      // A pixel square is 400x400 => full width, half the (800px) height.
      expect(r.width, closeTo(1.0, 1e-9));
      expect(r.height, closeTo(0.5, 1e-9));
      expect(r.center.dx, closeTo(0.5, 1e-9));
      expect(r.center.dy, closeTo(0.5, 1e-9));
    });

    test('an aspect wider than the frame is width-bound', () {
      final r = fitAspectWithin(const Rect.fromLTWH(0, 0, 1, 1), 16 / 9, image);
      expect(r.width, closeTo(1.0, 1e-9));
      expect(r.height, lessThan(1.0));
    });

    test('free aspect returns the input', () {
      const within = Rect.fromLTWH(0.1, 0.2, 0.5, 0.5);
      expect(fitAspectWithin(within, 0, image), within);
    });
  });

  group('clampNormalized', () {
    test('keeps a valid rect', () {
      expect(clampNormalized(const Rect.fromLTRB(0.1, 0.1, 0.9, 0.9)),
          const Rect.fromLTRB(0.1, 0.1, 0.9, 0.9));
    });

    test('enforces a minimum size', () {
      final r = clampNormalized(const Rect.fromLTRB(0.5, 0.5, 0.5, 0.5));
      expect(r.width, greaterThanOrEqualTo(0.05));
      expect(r.height, greaterThanOrEqualTo(0.05));
    });

    test('keeps the rect inside the unit square', () {
      final r = clampNormalized(const Rect.fromLTRB(-0.2, -0.2, 1.5, 1.5));
      expect(r.left, 0);
      expect(r.top, 0);
      expect(r.right, 1);
      expect(r.bottom, 1);
    });
  });

  test('rect <-> list round-trips', () {
    const r = Rect.fromLTRB(0.1, 0.2, 0.8, 0.9);
    expect(listToRect(rectToList(r)), r);
  });

  test('isFullCrop', () {
    expect(isFullCrop([0, 0, 1, 1]), isTrue);
    expect(isFullCrop([0, 0, 1, 0.9]), isFalse);
  });
}
