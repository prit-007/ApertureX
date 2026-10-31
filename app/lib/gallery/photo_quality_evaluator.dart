import 'dart:math' as math;
import 'dart:typed_data';

/// Quality metrics evaluated for an image asset (used in photo culling).
class QualityScore {
  const QualityScore({
    required this.sharpnessScore,
    required this.isBlurry,
    this.hasFace = false,
    this.faceConfidence = 0.0,
    this.eyesOpenConfidence = 1.0,
    this.hasClosedEyes = false,
  });

  /// Laplacian variance sharpness score (typically 0..1000+).
  final double sharpnessScore;

  /// True when sharpness falls below the blur threshold.
  final bool isBlurry;

  /// Whether a human face was detected in the frame.
  final bool hasFace;

  /// Confidence of the detected face (0..1).
  final double faceConfidence;

  /// Estimated eye openness score (0..1, where < 0.2 indicates closed eyes).
  final double eyesOpenConfidence;

  /// True when a detected subject likely has their eyes closed.
  final bool hasClosedEyes;

  /// Quality culling badge recommendations:
  /// - 'sharp': high detail / in focus
  /// - 'blurry': out of focus
  /// - 'closed_eyes': subject blinking
  String? get cullingBadge {
    if (hasClosedEyes) return 'closed_eyes';
    if (isBlurry) return 'blurry';
    if (sharpnessScore > 150.0) return 'sharp';
    return null;
  }
}

/// Evaluates photo sharpness (Laplacian variance) and facial quality for culling.
class PhotoQualityEvaluator {
  const PhotoQualityEvaluator();

  /// Default Laplacian variance threshold below which an image is flagged blurry.
  static const double kDefaultBlurThreshold = 45.0;

  /// Computes the Laplacian variance of [rgba] pixels to evaluate optical sharpness.
  ///
  /// Convolves a standard discrete 3×3 Laplacian filter:
  /// ```
  /// [ 0,  1,  0 ]
  /// [ 1, -4,  1 ]
  /// [ 0,  1,  0 ]
  /// ```
  /// Over the image luminance plane and calculates statistical variance.
  /// Sharp images with high edge contrast have large Laplacian variance,
  /// while blurred or out-of-focus images have low variance.
  static double computeLaplacianVariance(Uint8List rgba, int width, int height) {
    if (width < 3 || height < 3 || rgba.length < width * height * 4) {
      return 0.0;
    }

    // 1. Convert to normalized grayscale luminance
    final gray = Float32List(width * height);
    for (var i = 0; i < width * height; i++) {
      final idx = i * 4;
      final r = rgba[idx];
      final g = rgba[idx + 1];
      final b = rgba[idx + 2];
      gray[i] = 0.299 * r + 0.587 * g + 0.114 * b;
    }

    // 2. Convolve with discrete Laplacian kernel
    var sum = 0.0;
    var sumSq = 0.0;
    var count = 0;

    for (var y = 1; y < height - 1; y++) {
      final rowOffset = y * width;
      for (var x = 1; x < width - 1; x++) {
        final c = gray[rowOffset + x];
        final up = gray[(y - 1) * width + x];
        final down = gray[(y + 1) * width + x];
        final left = gray[rowOffset + (x - 1)];
        final right = gray[rowOffset + (x + 1)];

        final lap = up + down + left + right - 4.0 * c;
        sum += lap;
        sumSq += lap * lap;
        count++;
      }
    }

    if (count == 0) return 0.0;
    final mean = sum / count;
    final variance = (sumSq / count) - (mean * mean);
    return math.max(0.0, variance);
  }

  /// Evaluates overall quality for culling from pixel data and optional face landmarks.
  static QualityScore evaluateQuality(
    Uint8List rgba,
    int width,
    int height, {
    double blurThreshold = kDefaultBlurThreshold,
    bool hasFace = false,
    double faceConfidence = 0.0,
    double eyesOpenScore = 1.0,
  }) {
    final sharpness = computeLaplacianVariance(rgba, width, height);
    final isBlurry = sharpness < blurThreshold;
    final hasClosedEyes = hasFace && eyesOpenScore < 0.25;

    return QualityScore(
      sharpnessScore: sharpness,
      isBlurry: isBlurry,
      hasFace: hasFace,
      faceConfidence: faceConfidence,
      eyesOpenConfidence: eyesOpenScore,
      hasClosedEyes: hasClosedEyes,
    );
  }
}
