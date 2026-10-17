import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/features/editor/image_info_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('ImageInfoSheet renders C2PA provenance status section', (tester) async {
    final fakeBytes = Uint8List.fromList(const [
      0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
      0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0xFF, 0xD9,
    ]);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ImageInfoSheet(imageBytes: fakeBytes),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify C2PA provenance card is present
    expect(find.text('Content Credentials (C2PA)'), findsOneWidget);
  });
}
