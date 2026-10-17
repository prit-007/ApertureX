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
}
