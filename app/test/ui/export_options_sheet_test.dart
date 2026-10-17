import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:aperturex/features/editor/export_options_sheet.dart';

void main() {
  testWidgets('ExportOptionsSheet hides DNG option for non-raw image', (
    tester,
  ) async {
    ExportAction? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                selected = await ExportOptionsSheet.show(context, isRaw: false);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Export & Save'), findsOneWidget);
    expect(find.text('Save to ApertureX'), findsOneWidget);
    expect(find.text('Save to Photos'), findsOneWidget);
    expect(find.text('Share…'), findsOneWidget);
    expect(find.text('Export DNG (Lossless + Edits)'), findsNothing);

    await tester.tap(find.text('Save to Photos'));
    await tester.pumpAndSettle();

    expect(selected, ExportAction.saveToPhotos);
  });

  testWidgets('ExportOptionsSheet shows DNG option for raw image and selects it', (
    tester,
  ) async {
    ExportAction? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                selected = await ExportOptionsSheet.show(context, isRaw: true);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Export DNG (Lossless + Edits)'), findsOneWidget);
    expect(
      find.text('Original raw CFA sensor data with injected XMP recipe'),
      findsOneWidget,
    );

    await tester.tap(find.text('Export DNG (Lossless + Edits)'));
    await tester.pumpAndSettle();

    expect(selected, ExportAction.saveDngWithXmp);
  });

  testWidgets('ExportOptionsSheet shows and selects Export as Preset Card (QR)', (
    tester,
  ) async {
    ExportAction? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                selected = await ExportOptionsSheet.show(context, isRaw: false);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Export as Preset Card (QR)'), findsOneWidget);
    await tester.tap(find.text('Export as Preset Card (QR)'));
    await tester.pumpAndSettle();

    expect(selected, ExportAction.sharePresetCard);
  });

  testWidgets('ExportOptionsSheet interacts with branding accordion and C2PA toggle', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => ExportOptionsSheet.show(context, isRaw: false),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Verify Branding & Watermark section header exists
    expect(find.text('Branding & Watermark'), findsOneWidget);
    expect(find.byKey(const Key('c2pa_switch')), findsOneWidget);

    // Expand Branding section
    await tester.ensureVisible(find.text('Branding & Watermark'));
    await tester.tap(find.text('Branding & Watermark'));
    await tester.pumpAndSettle();

    // Museum frame switch is now visible
    expect(find.byKey(const Key('museum_frame_switch')), findsOneWidget);
    expect(find.byKey(const Key('signature_switch')), findsOneWidget);
    expect(find.byKey(const Key('foss_badge_switch')), findsOneWidget);

    // Toggle Museum Frame switch
    await tester.ensureVisible(find.byKey(const Key('museum_frame_switch')));
    await tester.tap(find.byKey(const Key('museum_frame_switch')));
    await tester.pumpAndSettle();

    // Verify themes appear
    expect(find.text('Studio White'), findsOneWidget);
    expect(find.text('Matte Dark'), findsOneWidget);
    expect(find.text('Warm Gallery'), findsOneWidget);

    // Select Matte Dark
    await tester.ensureVisible(find.text('Matte Dark'));
    await tester.tap(find.text('Matte Dark'));
    await tester.pumpAndSettle();

    // Toggle Signature switch
    await tester.ensureVisible(find.byKey(const Key('signature_switch')));
    await tester.tap(find.byKey(const Key('signature_switch')));
    await tester.pumpAndSettle();

    // Verify signature text field appears
    expect(find.byKey(const Key('signature_text_field')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('signature_text_field')));
    await tester.enterText(find.byKey(const Key('signature_text_field')), '© 2026 Test Photographer');
    await tester.pumpAndSettle();

    // Toggle FOSS badge
    await tester.ensureVisible(find.byKey(const Key('foss_badge_switch')));
    await tester.tap(find.byKey(const Key('foss_badge_switch')));
    await tester.pumpAndSettle();

    // Toggle C2PA switch
    await tester.ensureVisible(find.byKey(const Key('c2pa_switch')));
    await tester.tap(find.byKey(const Key('c2pa_switch')));
    await tester.pumpAndSettle();
  });
}

