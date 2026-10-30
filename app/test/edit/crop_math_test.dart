import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/edit/crop_math.dart';

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

  group('calculateAutoFrameCrop', () {
    test('frames centered portrait subject nicely within unit square', () {
      final crop = calculateAutoFrameCrop(
        cx: 0.5,
        cy: 0.5,
        rx: 0.18,
        ry: 0.28,
      );
      expect(crop.length, 4);
      expect(crop[0], greaterThanOrEqualTo(0.0));
      expect(crop[1], greaterThanOrEqualTo(0.0));
      expect(crop[2], lessThanOrEqualTo(1.0));
      expect(crop[3], lessThanOrEqualTo(1.0));
      expect(crop[2], greaterThan(crop[0]));
      expect(crop[3], greaterThan(crop[1]));
      // The subject (0.5 - 0.18 = 0.32, 0.5 + 0.18 = 0.68) is contained
      expect(crop[0], lessThanOrEqualTo(0.32));
      expect(crop[2], greaterThanOrEqualTo(0.68));
    });

    test('aligns left-weighted subject towards Rule of Thirds power line', () {
      final crop = calculateAutoFrameCrop(
        cx: 0.30,
        cy: 0.40,
        rx: 0.12,
        ry: 0.18,
      );
      expect(crop[0], closeTo(0.0, 0.1));
      expect(crop[2], greaterThan(0.42)); // Provides look room to the right
    });

    test('respects targetAspect ratio when provided', () {
      final crop = calculateAutoFrameCrop(
        cx: 0.5,
        cy: 0.5,
        rx: 0.15,
        ry: 0.20,
        targetAspect: 1.0,
      );
      final w = crop[2] - crop[0];
      final h = crop[3] - crop[1];
      expect(w / h, closeTo(1.0, 0.05));
    });
  });
}
