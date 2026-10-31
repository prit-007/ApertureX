import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/features/print/print_model.dart';
import 'package:aperturex/viewport/soft_proofing.dart';

void main() {
  group('PaperSize', () {
    test('standard paper sizes have accurate millimeter and point dimensions', () {
      expect(PaperSize.a4.widthMm, 210.0);
      expect(PaperSize.a4.heightMm, 297.0);
      expect(PaperSize.a4.widthPt, closeTo(595.28, 0.1));
      expect(PaperSize.a4.heightPt, closeTo(841.89, 0.1));

      expect(PaperSize.letter.widthMm, closeTo(215.9, 0.1));
      expect(PaperSize.letter.heightMm, closeTo(279.4, 0.1));
      expect(PaperSize.letter.widthPt, closeTo(612.0, 0.1));
      expect(PaperSize.letter.heightPt, closeTo(792.0, 0.1));

      expect(PaperSize.photo4x6.widthPt, closeTo(288.0, 0.1));
      expect(PaperSize.photo4x6.heightPt, closeTo(432.0, 0.1));

      expect(PaperSize.photo8x10.widthPt, closeTo(576.0, 0.1));
      expect(PaperSize.photo8x10.heightPt, closeTo(720.0, 0.1));
    });

    test('orientation adjusts dimensions correctly', () {
      final portraitA4 = PaperSize.a4.dimensions(PrintOrientation.portrait);
      expect(portraitA4.width, closeTo(595.28, 0.1));
      expect(portraitA4.height, closeTo(841.89, 0.1));

      final landscapeA4 = PaperSize.a4.dimensions(PrintOrientation.landscape);
      expect(landscapeA4.width, closeTo(841.89, 0.1));
      expect(landscapeA4.height, closeTo(595.28, 0.1));
    });
  });

  group('PrintMargins', () {
    test('computes printable area from paper dimensions', () {
      const margins = PrintMargins(
        topMm: 10.0,
        bottomMm: 10.0,
        leftMm: 15.0,
        rightMm: 15.0,
      );
      final paperDims = PaperSize.a4.dimensions(PrintOrientation.portrait);
      final printable = margins.printableArea(paperDims);

      expect(printable.left, closeTo(margins.leftPt, 0.1));
      expect(printable.top, closeTo(margins.topPt, 0.1));
      expect(printable.width, closeTo(paperDims.width - margins.horizontalPt, 0.1));
      expect(printable.height, closeTo(paperDims.height - margins.verticalPt, 0.1));
    });
  });

  group('ContactSheetGrid', () {
    test('computes uniform cell dimensions given printable area and spacing', () {
      const grid = ContactSheetGrid(
        rows: 3,
        columns: 2,
        cellSpacingMm: 5.0,
        showFilename: true,
        showExif: true,
      );

      final paperDims = PaperSize.a4.dimensions(PrintOrientation.portrait);
      const margins = PrintMargins.uniform(10.0);
      final printable = margins.printableArea(paperDims);

      final cell = grid.computeCellSize(printable);
      expect(cell.width, greaterThan(0));
      expect(cell.height, greaterThan(0));

      final totalWidth = 2 * cell.width + grid.spacingPt;
      expect(totalWidth, closeTo(printable.width, 0.2));

      final totalHeight = 3 * cell.height + 2 * grid.spacingPt;
      expect(totalHeight, closeTo(printable.height, 0.2));
    });

    test('computes correct page count for number of items', () {
      const grid = ContactSheetGrid(rows: 4, columns: 3); // 12 per page
      expect(grid.pageCountFor(1), 1);
      expect(grid.pageCountFor(12), 1);
      expect(grid.pageCountFor(13), 2);
      expect(grid.pageCountFor(24), 2);
      expect(grid.pageCountFor(25), 3);
    });
  });

  group('PrintJobConfig', () {
    test('defaults are sensible for professional photo printing', () {
      const config = PrintJobConfig();
      expect(config.paperSize, PaperSize.a4);
      expect(config.orientation, PrintOrientation.portrait);
      expect(config.layoutMode, PrintLayoutMode.single);
      expect(config.dpi, 300);
      expect(config.colorManagement.profile, ProofProfile.cmykSwop);
      expect(config.colorManagement.intent, ProofIntent.relativeColorimetric);
    });

    test('copyWith updates fields immutably', () {
      const config = PrintJobConfig();
      final updated = config.copyWith(
        paperSize: PaperSize.photo8x10,
        orientation: PrintOrientation.landscape,
        dpi: 600,
      );

      expect(updated.paperSize, PaperSize.photo8x10);
      expect(updated.orientation, PrintOrientation.landscape);
      expect(updated.dpi, 600);
      expect(config.paperSize, PaperSize.a4);
    });
  });
}
