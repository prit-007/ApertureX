import 'package:aperturex/color/camera_calibration_editor.dart';
import 'package:aperturex/edit/recipe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Camera Calibration in EditRecipe', () {
    test('Recipe serialization with calibration values', () {
      const recipe = EditRecipe(
        calibrationShadowTint: 15.0,
        calibrationRedHue: -20.0,
        calibrationRedSat: 30.0,
        calibrationGreenHue: 10.0,
        calibrationGreenSat: -5.0,
        calibrationBlueHue: -15.0,
        calibrationBlueSat: 25.0,
      );

      final json = recipe.toJson();
      expect(json['calibrationShadowTint'], 15.0);
      expect(json['calibrationRedHue'], -20.0);
      expect(json['calibrationBlueSat'], 25.0);

      final roundTrip = EditRecipe.fromJson(json);
      expect(roundTrip.calibrationShadowTint, 15.0);
      expect(roundTrip.calibrationRedHue, -20.0);
      expect(roundTrip.calibrationBlueSat, 25.0);
    });

    test('Recipe clamps calibration to [-100, 100]', () {
      final recipe = const EditRecipe().copyWith(
        calibrationRedHue: 150.0,
        calibrationShadowTint: -120.0,
      ).clamped();

      expect(recipe.calibrationRedHue, 100.0);
      expect(recipe.calibrationShadowTint, -100.0);
    });
  });

  group('CameraCalibrationEditor widget', () {
    testWidgets('renders all sliders and reset button', (tester) async {
      double shadow = 10;
      double redH = 5;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return CameraCalibrationEditor(
                  shadowTint: shadow,
                  redHue: redH,
                  redSat: 0,
                  greenHue: 0,
                  greenSat: 0,
                  blueHue: 0,
                  blueSat: 0,
                  onChanged: ({
                    shadowTint,
                    redHue,
                    redSat,
                    greenHue,
                    greenSat,
                    blueHue,
                    blueSat,
                  }) {
                    setState(() {
                      if (shadowTint != null) shadow = shadowTint;
                      if (redHue != null) redH = redHue;
                    });
                  },
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Camera Calibration'), findsOneWidget);
      expect(find.text('Shadows'), findsOneWidget);
      expect(find.text('Red Primary'), findsOneWidget);
      expect(find.text('Green Primary'), findsOneWidget);
      expect(find.text('Blue Primary'), findsOneWidget);
      expect(find.byKey(const Key('reset-calibration-btn')), findsOneWidget);

      await tester.tap(find.byKey(const Key('reset-calibration-btn')));
      await tester.pumpAndSettle();

      expect(shadow, 0.0);
      expect(redH, 0.0);
    });
  });
}
