import 'package:aperturex/viewport/canvas_transform.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const t = CanvasTransform(
    fitted: Size(400, 300),
    offset: Offset(0, 50),
    scale: 1,
  );

  test('maps normalised image points to screen and back', () {
    final screen = t.toScreen(const Offset(0.25, 0.5));
    expect(screen, const Offset(100, 200));
    expect(t.toNormalized(screen), const Offset(0.25, 0.5));
  });

  test('accounts for zoom and pan', () {
    const zoomed = CanvasTransform(
      fitted: Size(400, 300),
      offset: Offset(-100, -50),
      scale: 2,
    );
    final screen = zoomed.toScreen(Offset.zero);
    expect(screen, const Offset(-100, -50));
    expect(zoomed.toNormalized(screen), Offset.zero);
    expect(zoomed.radiusOf(0.25), 200); // 0.25 * 400 * 2
  });

  test('aspect matches the width-fitted image', () {
    expect(t.aspect, closeTo(4 / 3, 1e-9));
  });

  test('degenerate transforms refuse to map', () {
    const empty = CanvasTransform(
      fitted: Size.zero,
      offset: Offset.zero,
      scale: 1,
    );
    expect(empty.toNormalized(Offset.zero), isNull);
    const unscaled = CanvasTransform(
      fitted: Size(10, 10),
      offset: Offset.zero,
      scale: 0,
    );
    expect(unscaled.toNormalized(Offset.zero), isNull);
  });

  test('equality is by value (drives publish dedup)', () {
    const a = CanvasTransform(
      fitted: Size(10, 10),
      offset: Offset.zero,
      scale: 1,
    );
    const b = CanvasTransform(
      fitted: Size(10, 10),
      offset: Offset.zero,
      scale: 1,
    );
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(
      a,
      isNot(
        const CanvasTransform(
          fitted: Size(10, 10),
          offset: Offset.zero,
          scale: 2,
        ),
      ),
    );
  });
}
