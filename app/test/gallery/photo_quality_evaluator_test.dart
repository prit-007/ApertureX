import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/gallery/photo_quality_evaluator.dart';

void main() {
  group('PhotoQualityEvaluator Tests', () {
    test('flat or uniform image yields near zero Laplacian variance (blurry)', () {
      const w = 20;
      const h = 20;
      final flat = Uint8List(w * h * 4);
      for (var i = 0; i < flat.length; i += 4) {
        flat[i] = 128;
        flat[i + 1] = 128;
        flat[i + 2] = 128;
        flat[i + 3] = 255;
      }

      final score = PhotoQualityEvaluator.computeLaplacianVariance(flat, w, h);
      expect(score, closeTo(0.0, 0.001));

      final eval = PhotoQualityEvaluator.evaluateQuality(flat, w, h);
      expect(eval.isBlurry, isTrue);
      expect(eval.cullingBadge, 'blurry');
    });

    test('high contrast checkerboard edges yield high sharpness score', () {
      const w = 20;
      const h = 20;
      final sharp = Uint8List(w * h * 4);
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          final isWhite = (x + y) % 2 == 0;
          final luma = isWhite ? 255 : 0;
          final idx = (y * w + x) * 4;
          sharp[idx] = luma;
          sharp[idx + 1] = luma;
          sharp[idx + 2] = luma;
          sharp[idx + 3] = 255;
        }
      }

      final score = PhotoQualityEvaluator.computeLaplacianVariance(sharp, w, h);
      expect(score, greaterThan(100.0));

      final eval = PhotoQualityEvaluator.evaluateQuality(sharp, w, h);
      expect(eval.isBlurry, isFalse);
      expect(eval.cullingBadge, 'sharp');
    });

    test('flags closed eyes when face present and eyesOpenScore is low', () {
      final dummyImg = Uint8List(16 * 16 * 4);
      final eval = PhotoQualityEvaluator.evaluateQuality(
        dummyImg,
        16,
        16,
        hasFace: true,
        faceConfidence: 0.95,
        eyesOpenScore: 0.10, // closed eyes
      );

      expect(eval.hasClosedEyes, isTrue);
      expect(eval.cullingBadge, 'closed_eyes');
    });
  });
}
