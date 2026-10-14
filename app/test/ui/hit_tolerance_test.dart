import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/ui/common/node_overlay.dart';
import 'package:aperturex/ui/common/tone_curve_editor.dart';

void main() {
  group('hit tolerance scales with DPR (issue #50)', () {
    test('the ring drag tolerance grows with devicePixelRatio, bounded', () {
      final t1 = NodeOverlay.scaleTolerance(18, 1.0);
      final t2 = NodeOverlay.scaleTolerance(18, 2.0);
      final t3 = NodeOverlay.scaleTolerance(18, 3.0);
      expect(t2, greaterThan(t1));
      expect(t3, greaterThanOrEqualTo(t2)); // equal at the 36px ceiling
      expect(t1, greaterThanOrEqualTo(12)); // sane floor
      expect(t3, lessThanOrEqualTo(36)); // sane ceiling
    });
  });

  group('tone curve select/remove share one tolerance (issue #50)', () {
    test('toleranceFor returns the same normalized distance for any size', () {
      // Values are in normalized [0,1] space, so the hit distance is a
      // fraction of the editor — one shared constant, not two literals.
      final t1 = ToneCurveEditor.toleranceFor(const Size(200, 200));
      final t2 = ToneCurveEditor.toleranceFor(const Size(400, 400));
      expect(t1, t2, reason: 'shared function, not size-duplicated literals');
      expect(t1, greaterThan(0));
      expect(t1, lessThan(0.5), reason: 'sane fraction of the editor');
    });
  });
}
