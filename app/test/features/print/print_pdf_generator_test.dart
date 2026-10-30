import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/features/print/print_model.dart';
import 'package:aperturex/features/print/print_pdf_generator.dart';

// Minimal 1x1 valid JPEG bytes for testing
final Uint8List _sampleJpeg = Uint8List.fromList([
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
  0x00, 0x7F, 0x00, 0xFF, 0xD9,
]);

void main() {
  group('PrintPdfGenerator', () {
    test('generates valid PDF header and structure for single photo layout', () {
      const config = PrintJobConfig(
        paperSize: PaperSize.a4,
        orientation: PrintOrientation.portrait,
        layoutMode: PrintLayoutMode.single,
      );

      final photo = PrintPhotoItem(
        id: 'photo-1',
        title: 'Alpine Peak',
        filename: 'DSC04921.ARW',
        exifSummary: '1/500s · f/4.0 · ISO 100',
        imageBytes: _sampleJpeg,
      );

      final pdfBytes = PrintPdfGenerator.generate(
        config: config,
        items: [photo],
      );

      expect(pdfBytes, isNotEmpty);
      final pdfString = ascii.decode(pdfBytes, allowInvalid: true);

      // PDF specification requirements
      expect(pdfString.startsWith('%PDF-1.4'), isTrue);
      expect(pdfString.contains('/Type /Catalog'), isTrue);
      expect(pdfString.contains('/Type /Pages'), isTrue);
      expect(pdfString.contains('/Type /Page'), isTrue);
      expect(pdfString.contains('/MediaBox [0 0 595.28 841.89]'), isTrue);
      expect(pdfString.contains('xref'), isTrue);
      expect(pdfString.contains('trailer'), isTrue);
      expect(pdfString.contains('startxref'), isTrue);
      expect(pdfString.trimRight().endsWith('%%EOF'), isTrue);
    });

    test('generates multi-item contact sheet with metadata captions and cell grid', () {
      const config = PrintJobConfig(
        paperSize: PaperSize.letter,
        orientation: PrintOrientation.landscape,
        layoutMode: PrintLayoutMode.contactSheet,
        contactSheetGrid: ContactSheetGrid(
          rows: 2,
          columns: 2,
          showFilename: true,
          showExif: true,
        ),
      );

      final photos = List.generate(
        4,
        (i) => PrintPhotoItem(
          id: 'photo-$i',
          title: 'Frame $i',
          filename: 'IMG_${1000 + i}.JPG',
          exifSummary: '24mm · 1/250s · f/2.8',
          imageBytes: _sampleJpeg,
        ),
      );

      final pdfBytes = PrintPdfGenerator.generate(
        config: config,
        items: photos,
      );

      final pdfString = ascii.decode(pdfBytes, allowInvalid: true);
      expect(pdfString.startsWith('%PDF-1.4'), isTrue);
      // Landscape letter = 792.0 x 612.0
      expect(pdfString.contains('/MediaBox [0 0 792.00 612.00]'), isTrue);
      // Verify caption filenames are present
      expect(pdfString.contains('IMG_1000.JPG'), isTrue);
      expect(pdfString.contains('IMG_1003.JPG'), isTrue);
    });

    test('spans multiple pages when contact sheet exceeds items per page', () {
      const config = PrintJobConfig(
        paperSize: PaperSize.a4,
        layoutMode: PrintLayoutMode.contactSheet,
        contactSheetGrid: ContactSheetGrid(rows: 2, columns: 2), // 4 per page
      );

      // 6 photos on a 4-item-per-page grid -> must create 2 pages
      final photos = List.generate(
        6,
        (i) => PrintPhotoItem(
          id: 'p-$i',
          filename: 'SHOT_$i.JPG',
          imageBytes: _sampleJpeg,
        ),
      );

      final pdfBytes = PrintPdfGenerator.generate(
        config: config,
        items: photos,
      );

      final pdfString = ascii.decode(pdfBytes, allowInvalid: true);
      expect(pdfString.contains('/Count 2'), isTrue); // 2 pages in Pages tree
    });
  });
}
