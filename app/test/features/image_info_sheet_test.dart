import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:aperturex/edit/recipe.dart';
import 'package:aperturex/features/editor/image_info_sheet.dart';

void main() {
  testWidgets('ImageInfoSheet renders title, quick stat badges and sections', (
    tester,
  ) async {
    final fakeBytes = Uint8List.fromList(const [
      0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
      0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0xFF, 0xD9,
    ]);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ImageInfoSheet(
              imageBytes: fakeBytes,
              recipe: EditRecipe.neutral.copyWith(exposure: 0.5),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Image Information'), findsOneWidget);
    expect(find.text('SHUTTER'), findsOneWidget);
    expect(find.text('APERTURE'), findsOneWidget);
    expect(find.text('ISO'), findsOneWidget);
    expect(find.text('FOCAL'), findsOneWidget);
    expect(find.text('File & Sensor'), findsOneWidget);
    expect(find.text('Non-Destructive Session'), findsOneWidget);
    expect(find.byTooltip('Copy info'), findsOneWidget);
  });
}
