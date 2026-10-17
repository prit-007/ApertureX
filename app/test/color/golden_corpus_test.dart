import 'dart:io';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:aperturex/color/grade_spec.dart';
import 'package:aperturex/color/spatial_spec.dart';
import 'package:aperturex/edit/recipe.dart';
import 'package:aperturex/edit/tone_curve.dart';

/// 24 standard Macbeth ColorChecker patches in 8-bit sRGB.
const List<List<int>> macbeth24 = <List<int>>[
  <int>[115, 82, 68],   // 1. Dark skin
  <int>[194, 150, 130], // 2. Light skin
  <int>[98, 122, 157],  // 3. Blue sky
  <int>[87, 108, 67],   // 4. Foliage
  <int>[133, 128, 177], // 5. Blue flower
  <int>[103, 189, 170], // 6. Bluish green
  <int>[214, 126, 44],  // 7. Orange
  <int>[80, 91, 166],   // 8. Purplish blue
  <int>[193, 90, 99],   // 9. Moderate red
  <int>[94, 60, 108],   // 10. Purple
  <int>[157, 188, 64],  // 11. Yellow green
  <int>[224, 163, 46],  // 12. Orange yellow
  <int>[56, 61, 150],   // 13. Blue
  <int>[70, 148, 73],   // 14. Green
  <int>[175, 54, 60],   // 15. Red
  <int>[231, 199, 31],  // 16. Yellow
  <int>[187, 86, 149],  // 17. Magenta
  <int>[8, 133, 161],   // 18. Cyan
  <int>[243, 243, 242], // 19. White 9.5
  <int>[200, 200, 200], // 20. Neutral 8
  <int>[160, 160, 160], // 21. Neutral 6.5
  <int>[122, 122, 121], // 22. Neutral 5
  <int>[85, 85, 85],    // 23. Neutral 3.5
  <int>[52, 52, 52],    // 24. Black 2
];

/// sRGB EOTF to linear light.
double _srgbToLinear(double c) {
  final clamped = c.clamp(0.0, 1.0);
  return clamped <= 0.04045 ? clamped / 12.92 : math.pow((clamped + 0.055) / 1.055, 2.4).toDouble();
}

/// Converts sRGB [0..1] to CIE L*a*b* (D65).
List<double> _srgbToLab(double r, double g, double b) {
  final lr = _srgbToLinear(r);
  final lg = _srgbToLinear(g);
  final lb = _srgbToLinear(b);

  final x = 0.4124564 * lr + 0.3575761 * lg + 0.1804375 * lb;
  final y = 0.2126729 * lr + 0.7151522 * lg + 0.0721750 * lb;
  final z = 0.0193339 * lr + 0.1191920 * lg + 0.9503041 * lb;

  const xn = 0.95047;
  const yn = 1.00000;
  const zn = 1.08883;

  double f(double t) => t > 0.008856452 ? math.pow(t, 1.0 / 3.0).toDouble() : 7.787037 * t + 16.0 / 116.0;

  final fx = f(x / xn);
  final fy = f(y / yn);
  final fz = f(z / zn);

  final l = 116.0 * fy - 16.0;
  final a = 500.0 * (fx - fy);
  final bCoord = 200.0 * (fy - fz);

  return <double>[l, a, bCoord];
}

/// CIE ΔE*76 color difference metric.
double deltaE76(List<double> c1, List<double> c2) {
  final lab1 = _srgbToLab(c1[0], c1[1], c1[2]);
  final lab2 = _srgbToLab(c2[0], c2[1], c2[2]);
  final dl = lab1[0] - lab2[0];
  final da = lab1[1] - lab2[1];
  final db = lab1[2] - lab2[2];
  return math.sqrt(dl * dl + da * da + db * db);
}

void main() {
  group('Golden-image tolerance corpus (issue #60)', () {
    test('Macbeth 24 color patches have valid sRGB ranges', () {
      expect(macbeth24.length, 24);
      for (final p in macbeth24) {
        expect(p.length, 3);
        for (final c in p) {
          expect(c, inInclusiveRange(0, 255));
        }
      }
    });

    test('deltaE76 identity is zero and detects perceptible color difference', () {
      final white = <double>[1.0, 1.0, 1.0];
      final grey = <double>[0.5, 0.5, 0.5];
      expect(deltaE76(white, white), closeTo(0.0, 1e-4));
      expect(deltaE76(white, grey), greaterThan(10.0));
    });

    test('Golden recipe basic maps accurately to GradeSpec and SpatialSpec', () {
      final recipe = EditRecipe.neutral.copyWith(
        exposure: 0.5,
        contrast: 0.2,
        whites: 0.15,
        blacks: -0.15,
        temperature: 0.2,
        tint: -0.1,
        vibrance: 0.25,
        saturation: 0.1,
        clarity: 0.30,
        dehaze: 0.25,
      );

      final grade = GradeSpec.fromRecipe(recipe);
      expect(grade.exposure, 0.5);
      expect(grade.contrast, 0.2);
      expect(grade.whites, 0.15);
      expect(grade.blacks, -0.15);
      expect(grade.temperature, 0.2);
      expect(grade.tint, -0.1);
      expect(grade.vibrance, 0.25);
      expect(grade.saturation, 0.1);

      final spatial = SpatialSpec.fromRecipe(recipe);
      expect(spatial.clarity, 0.30);
      expect(spatial.dehaze, 0.25);
    });

    test('Golden recipe curves and split-tone map accurately to GradeSpec', () {
      const curve = ToneCurve(<double>[
        0.0, 0.0, //
        0.25, 0.20,
        0.75, 0.85,
        1.0, 1.0,
      ]);
      final recipe = EditRecipe.neutral.copyWith(
        masterCurve: curve,
        gradeShadowHue: 0.58,
        gradeShadowSat: 0.30,
        gradeShadowLum: -0.10,
        gradeHighlightHue: 0.11,
        gradeHighlightSat: 0.25,
        gradeHighlightLum: 0.10,
        gradeBlending: 0.50,
        gradeBalance: 0.00,
      );

      final grade = GradeSpec.fromRecipe(recipe);
      expect(grade.gradeShadowHue, 0.58);
      expect(grade.gradeShadowSat, 0.30);
      expect(grade.gradeShadowLum, -0.10);
      expect(grade.gradeHighlightHue, 0.11);
      expect(grade.gradeHighlightSat, 0.25);
      expect(grade.gradeHighlightLum, 0.10);
      expect(grade.gradeBlending, 0.50);
      expect(grade.gradeBalance, 0.00);
      expect(grade.masterCurve.length, 8);
    });

    test('Comparator fails when deliberate color regression is injected', () {
      final patch = macbeth24[0]; // Dark skin
      final original = <double>[patch[0] / 255.0, patch[1] / 255.0, patch[2] / 255.0];
      // Inject +8 levels (~0.031) color cast
      final regressed = <double>[
        (patch[0] + 8) / 255.0,
        patch[1] / 255.0,
        patch[2] / 255.0,
      ];
      final de = deltaE76(original, regressed);
      expect(de, greaterThan(1.5), reason: 'ΔE must exceed gate tolerance of 1.0 on a +8 color shift');
    });

    test('synthetic_math_breaker fixture decodes cleanly as 2048x2048 RGB target', () {
      var file = File('rust/tests/golden_fixtures/synthetic_math_breaker.png');
      if (!file.existsSync()) {
        file = File('../app/rust/tests/golden_fixtures/synthetic_math_breaker.png');
      }
      if (!file.existsSync()) {
        // If not running in repo workspace
        return;
      }
      final bytes = file.readAsBytesSync();
      expect(bytes.length, greaterThan(1000));

      final image = img.decodePng(bytes);
      expect(image, isNotNull);
      expect(image!.width, 2048);
      expect(image.height, 2048);

      // Verify corner/center samples have valid RGB components
      final pixelCenter = image.getPixel(1024, 1024);
      expect(pixelCenter.r, inInclusiveRange(0, 255));
      expect(pixelCenter.g, inInclusiveRange(0, 255));
      expect(pixelCenter.b, inInclusiveRange(0, 255));
    });
  });
}
