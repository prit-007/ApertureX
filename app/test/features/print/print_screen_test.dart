import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aperturex/features/print/print_model.dart';
import 'package:aperturex/features/print/print_screen.dart';

void main() {
  // Minimal valid 1x1 JPEG for widget tests
  final sampleJpeg = Uint8List.fromList([
    0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
    0x01, 0x01, 0x00, 0x48, 0x00, 0x48, 0x00, 0x00, 0xFF, 0xDB, 0x00, 0x43,
    0x00, 0x08, 0x06, 0x06, 0x07, 0x06, 0x05, 0x08, 0x07, 0x07, 0x07, 0x09,
    0x09, 0x08, 0x0A, 0x0C, 0x14, 0x0D, 0x0C, 0x0B, 0x0B, 0x0C, 0x19, 0x12,
    0x13, 0x0F, 0x14, 0x1D, 0x1A, 0x1F, 0x1E, 0x1D, 0x1A, 0x1C, 0x1C, 0x20,
    0x24, 0x2E, 0x27, 0x20, 0x22, 0x2C, 0x23, 0x1C, 0x1C, 0x28, 0x37, 0x29,
    0x2C, 0x30, 0x31, 0x34, 0x34, 0x34, 0x1F, 0x27, 0x39, 0x3D, 0x38, 0x32,
    0x3C, 0x2E, 0x33, 0x34, 0x32, 0xFF, 0xC0, 0x00, 0x0B, 0x08, 0x00, 0x01,
    0x00, 0x01, 0x01, 0x01, 0x11, 0x00, 0xFF, 0xC4, 0x00, 0x1F, 0x00, 0x00,
    0x01, 0x05, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
    0x09, 0x0A, 0x0B, 0xFF, 0xDA, 0x00, 0x08, 0x01, 0x01, 0x00, 0x00, 0x3F,
    0x00, 0xBF, 0x00, 0xFF, 0xD9,
  ]);

  final testItems = [
    PrintPhotoItem(
      id: 'p1',
      filename: 'DSC_0001.JPG',
      imageBytes: sampleJpeg,
      exifSummary: '1/250s · f/2.8 · ISO 100',
    ),
    PrintPhotoItem(
      id: 'p2',
      filename: 'DSC_0002.JPG',
      imageBytes: sampleJpeg,
      exifSummary: '1/500s · f/4.0 · ISO 200',
    ),
  ];

  Widget buildSubject({List<PrintPhotoItem>? items}) {
    return ProviderScope(
      child: MaterialApp(
        home: PrintScreen(
          items: items ?? testItems,
        ),
      ),
    );
  }

  testWidgets('renders Print & Contact Sheet Studio title and controls', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Print & Contact Sheet Studio'), findsOneWidget);
    expect(find.text('Paper'), findsOneWidget);
    expect(find.text('Layout'), findsOneWidget);
    expect(find.text('Color / Proof'), findsOneWidget);
    expect(find.text('Captions'), findsOneWidget);
    expect(find.byKey(const Key('generate-pdf-btn')), findsOneWidget);
    expect(find.byKey(const Key('soft-proof-quick-toggle')), findsOneWidget);
  });

  testWidgets('navigates pages in single photo layout', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Page 1 of 2'), findsOneWidget);
    expect(find.byKey(const Key('next-page-btn')), findsOneWidget);

    await tester.tap(find.byKey(const Key('next-page-btn')));
    await tester.pumpAndSettle();

    expect(find.text('Page 2 of 2'), findsOneWidget);

    await tester.tap(find.byKey(const Key('prev-page-btn')));
    await tester.pumpAndSettle();

    expect(find.text('Page 1 of 2'), findsOneWidget);
  });

  testWidgets('switches to contact sheet mode and changes layout', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    // Tap Layout tab
    await tester.tap(find.text('Layout'));
    await tester.pumpAndSettle();

    // Switch to Contact Sheet
    await tester.tap(find.text('Contact Sheet'));
    await tester.pumpAndSettle();

    // In contact sheet mode with 2 items and 3x3 default grid, all fit on 1 page
    expect(find.text('Page 1 of 1'), findsOneWidget);
    expect(find.text('Grid Dimensions'), findsOneWidget);
  });

  testWidgets('toggles soft proofing and displays indicator', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    // Tap Color / Proof tab
    await tester.tap(find.text('Color / Proof'));
    await tester.pumpAndSettle();

    // Scroll until Gamut Warning is visible
    final gamutTile = find.widgetWithText(SwitchListTile, 'Gamut Warning');
    await tester.ensureVisible(gamutTile);
    await tester.pumpAndSettle();

    // Tap Gamut Warning switch
    await tester.tap(gamutTile);
    await tester.pumpAndSettle();

    expect(find.text('GAMUT WARNING'), findsOneWidget);
  });

  testWidgets('generates PDF and shows success notification', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    final exportBtn = find.byKey(const Key('generate-pdf-btn'));
    expect(exportBtn, findsOneWidget);

    await tester.tap(exportBtn);
    await tester.pumpAndSettle();

    expect(find.textContaining('PDF Generated successfully'), findsOneWidget);
  });
}
