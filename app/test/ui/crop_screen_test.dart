import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:aperturex/features/crop/crop_screen.dart';

final Uint8List _png = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CropScreen', () {
    test('kCropAspects covers standard ratios', () {
      expect(kCropAspects.any((a) => a.$1 == 'Free'), isTrue);
      expect(kCropAspects.any((a) => a.$1 == '1:1' && a.$2 == 1.0), isTrue);
      expect(kCropAspects.any((a) => a.$1 == '16:9'), isTrue);
    });

    testWidgets('renders CropScreen without crashing', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: CropScreen(imageBytes: _png),
          ),
        ),
      );

      // Loading state or scaffold is visible
      expect(find.byType(CropScreen), findsOneWidget);
    });
  });
}
