import 'package:aperturex/edit/recipe.dart';
import 'package:aperturex/ui/common/double_exposure_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DoubleExposureLayer', () {
    test('JSON serialization round-trip', () {
      const layer = DoubleExposureLayer(
        imagePath: '/path/to/img.jpg',
        blendModeIndex: 2, // Multiply
        opacity: 0.8,
        scale: 1.5,
        offsetX: 10.0,
        offsetY: -5.0,
      );

      final json = layer.toJson();
      final roundTrip = DoubleExposureLayer.fromJson(json);

      expect(roundTrip, equals(layer));
      expect(roundTrip.blendModeIndex, 2);
      expect(roundTrip.opacity, 0.8);
      expect(roundTrip.scale, 1.5);
    });

    test('Recipe serialization with double exposure layer', () {
      const recipe = EditRecipe(
        doubleExposure: DoubleExposureLayer(
          imagePath: '/test/overlay.png',
          opacity: 0.75,
        ),
      );

      final json = recipe.toJson();
      expect(json['doubleExposure'], isNotNull);

      final roundTrip = EditRecipe.fromJson(json);
      expect(roundTrip.doubleExposure?.imagePath, '/test/overlay.png');
      expect(roundTrip.doubleExposure?.opacity, 0.75);
    });
  });

  group('DoubleExposureSheet widget', () {
    testWidgets('renders empty state and pick button', (tester) async {
      DoubleExposureLayer? layer;
      var pickCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return DoubleExposureSheet(
                  layer: layer,
                  onChanged: (updated) => setState(() => layer = updated),
                  onPickImage: () => pickCalled = true,
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Double Exposure'), findsOneWidget);
      expect(find.byKey(const Key('choose-double-exposure-btn')), findsOneWidget);

      await tester.tap(find.byKey(const Key('choose-double-exposure-btn')));
      await tester.pumpAndSettle();

      expect(pickCalled, isTrue);
      expect(layer, isNotNull);
      expect(find.text('Blend Mode'), findsOneWidget);
      expect(find.text('Screen'), findsOneWidget);
    });
  });
}
