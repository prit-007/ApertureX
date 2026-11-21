import 'package:aperturex/color/point_color_editor.dart';
import 'package:aperturex/edit/recipe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PointColorDef', () {
    test('JSON round-trip preserves all fields', () {
      const original = PointColorDef(
        targetHue: 0.15,
        targetSat: 0.75,
        targetLum: 0.45,
        rangeHue: 0.08,
        rangeSat: 0.25,
        rangeLum: 0.35,
        falloff: 0.6,
        hueShift: 0.2,
        satShift: -0.3,
        lumShift: 0.1,
      );

      final json = original.toJson();
      final decoded = PointColorDef.fromJson(json);

      expect(decoded, equals(original));
      expect(decoded.targetHue, 0.15);
      expect(decoded.hueShift, 0.2);
    });

    test('Recipe serialization with point colors', () {
      const recipe = EditRecipe(
        pointColors: [
          PointColorDef(targetHue: 0.2, hueShift: 0.5),
        ],
      );

      final json = recipe.toJson();
      expect(json['pointColors'], isNotNull);

      final roundTrip = EditRecipe.fromJson(json);
      expect(roundTrip.pointColors.length, 1);
      expect(roundTrip.pointColors.first.targetHue, 0.2);
      expect(roundTrip.pointColors.first.hueShift, 0.5);
    });
  });

  group('PointColorEditor widget', () {
    testWidgets('renders empty state and adds a target', (tester) async {
      List<PointColorDef> points = [];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return PointColorEditor(
                  pointColors: points,
                  onChanged: (updated) => setState(() => points = updated),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('No Point Color Targets'), findsOneWidget);
      expect(find.byKey(const Key('add-point-color-btn')), findsOneWidget);

      await tester.tap(find.byKey(const Key('add-point-color-btn')));
      await tester.pumpAndSettle();

      expect(points.length, 1);
      expect(find.text('Color Targets'), findsOneWidget);
    });

    testWidgets('modifies hue shift slider', (tester) async {
      List<PointColorDef> points = [
        const PointColorDef(targetHue: 0.1, targetSat: 0.5, targetLum: 0.5),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return PointColorEditor(
                  pointColors: points,
                  onChanged: (updated) => setState(() => points = updated),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Hue Shift'), findsOneWidget);
      expect(find.byType(Slider), findsWidgets);
    });
  });
}
