import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aperturex/features/editor/export_options_sheet.dart';
import 'package:aperturex/features/editor/export_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestableExportScreen({
    ExportAction? Function(ExportAction?)? onPopped,
    bool isRaw = false,
  }) {
    // Generate a minimal 2x2 mock PNG/JPEG preview buffer
    final dummyBytes = Uint8List.fromList([
      0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
      0x01, 0x01, 0x00, 0x48, 0x00, 0x48, 0x00, 0x00, 0xFF, 0xDB, 0x00, 0x43,
      0x00, 0x08, 0x06, 0x06, 0x07, 0x06, 0x05, 0x08, 0x07, 0x07, 0x07, 0x09,
      0x09, 0x08, 0x0A, 0x0C, 0x14, 0x0D, 0x0C, 0x0B, 0x0B, 0x0C, 0x19, 0x12,
      0x13, 0x0F, 0x14, 0x1D, 0x1A, 0x1F, 0x1E, 0x1D, 0x1A, 0x1C, 0x1C, 0x20,
      0x24, 0x2E, 0x27, 0x20, 0x22, 0x2C, 0x23, 0x1C, 0x1C, 0x28, 0x37, 0x29,
      0x2C, 0x30, 0x31, 0x34, 0x34, 0x34, 0x1F, 0x27, 0x39, 0x3D, 0x38, 0x32,
      0x3C, 0x2E, 0x33, 0x34, 0x32, 0xFF, 0xC0, 0x00, 0x0B, 0x08, 0x00, 0x02,
      0x00, 0x02, 0x01, 0x01, 0x11, 0x00, 0xFF, 0xDA, 0x00, 0x08, 0x01, 0x01,
      0x00, 0x00, 0x3F, 0x00, 0xBF, 0x00, 0xFF, 0xD9,
    ]);

    return ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                final action = await ExportScreen.open(
                  context,
                  previewBytes: dummyBytes,
                  isRaw: isRaw,
                  sourceWidth: 4000,
                  sourceHeight: 3000,
                );
                onPopped?.call(action);
              },
              child: const Text('Open Export Studio'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('ExportScreen renders all core sections and live HUD', (tester) async {
    await tester.pumpWidget(buildTestableExportScreen());

    await tester.tap(find.text('Open Export Studio'));
    await tester.pumpAndSettle();

    // Verify AppBar
    expect(find.text('Export Studio'), findsOneWidget);

    // Verify Quick Profiles
    expect(find.text('QUICK PROFILES'), findsOneWidget);
    expect(find.text('Full Res Master'), findsOneWidget);
    expect(find.text('Web & Social (2048px)'), findsOneWidget);

    // Verify File Format & Quality Panel
    expect(find.text('File Settings & Format'), findsOneWidget);
    expect(find.text('JPEG'), findsOneWidget);
    expect(find.text('PNG'), findsOneWidget);
    expect(find.text('TIFF 16-bit'), findsOneWidget);
    expect(find.text('sRGB (Web)'), findsOneWidget);
    expect(find.text('Display-P3 (WCG)'), findsOneWidget);

    // Verify Image Sizing card
    expect(find.text('Image Sizing'), findsOneWidget);

    // Verify Watermarking & Branding Studio card
    expect(find.text('Watermarking & Branding Studio'), findsOneWidget);
    expect(find.text('Watermark Styles:'), findsOneWidget);
    expect(find.text('Minimal Clean (White)'), findsOneWidget);
    expect(find.text('Gold Fine Art'), findsOneWidget);
    expect(find.text('Client Proof (Tiled)'), findsOneWidget);

    // Verify Primary CTA Button
    expect(find.byKey(const Key('export_studio_primary_btn')), findsOneWidget);
  });

  testWidgets('ExportScreen toggles watermark presets and updates text signature', (tester) async {
    await tester.pumpWidget(buildTestableExportScreen());
    await tester.tap(find.text('Open Export Studio'));
    await tester.pumpAndSettle();

    // Tap Gold Fine Art watermark preset
    final goldPreset = find.text('Gold Fine Art');
    await tester.ensureVisible(goldPreset);
    await tester.tap(goldPreset);
    await tester.pumpAndSettle();

    // Verify Signature switch is on
    expect(find.text('Photographer Text Signature'), findsOneWidget);

    // Enter signature text
    final sigField = find.byKey(const Key('watermark_signature_field'));
    await tester.ensureVisible(sigField);
    expect(sigField, findsOneWidget);
    await tester.enterText(sigField, '© 2026 Prit Vasani');
    await tester.pumpAndSettle();

    // Verify dynamic metadata quick-inserter chip
    expect(find.text('© {year}'), findsOneWidget);
  });

  testWidgets('ExportScreen selects PNG format and exports via primary button', (tester) async {
    ExportAction? result;
    await tester.pumpWidget(buildTestableExportScreen(
      onPopped: (action) => result = action,
    ));

    await tester.tap(find.text('Open Export Studio'));
    await tester.pumpAndSettle();

    // Select PNG format segment
    await tester.tap(find.text('PNG'));
    await tester.pumpAndSettle();

    // Tap Primary Export Button
    await tester.tap(find.byKey(const Key('export_studio_primary_btn')));
    await tester.pumpAndSettle();

    expect(result, ExportAction.savePng);
  });

  testWidgets('ExportScreen selects TIFF 16-bit format and exports via primary button', (tester) async {
    ExportAction? result;
    await tester.pumpWidget(buildTestableExportScreen(
      onPopped: (action) => result = action,
    ));

    await tester.tap(find.text('Open Export Studio'));
    await tester.pumpAndSettle();

    // Select TIFF 16-bit format segment
    await tester.tap(find.text('TIFF 16-bit'));
    await tester.pumpAndSettle();

    // Tap Primary Export Button
    await tester.tap(find.byKey(const Key('export_studio_primary_btn')));
    await tester.pumpAndSettle();

    expect(result, ExportAction.saveTiff16);
  });

  testWidgets('ExportScreen shows RAW DNG option only when isRaw is true', (tester) async {
    await tester.pumpWidget(buildTestableExportScreen(isRaw: true));
    await tester.tap(find.text('Open Export Studio'));
    await tester.pumpAndSettle();

    expect(find.text('RAW DNG'), findsOneWidget);
  });

  testWidgets('ExportScreen shows in-app library export icon and triggers saveToApertureX', (tester) async {
    ExportAction? result;
    await tester.pumpWidget(buildTestableExportScreen(
      onPopped: (action) => result = action,
    ));

    await tester.tap(find.text('Open Export Studio'));
    await tester.pumpAndSettle();

    // Tap In-App Edits icon
    await tester.tap(find.byIcon(Icons.auto_fix_high_outlined));
    await tester.pumpAndSettle();

    expect(result, ExportAction.saveToApertureX);
  });
}
