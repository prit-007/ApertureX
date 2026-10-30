import 'dart:typed_data';
import 'dart:ui' show Color, Rect, Size;

import '../../viewport/soft_proofing.dart';

const double kPointsPerInch = 72.0;
const double kMmPerInch = 25.4;
const double kPointsPerMm = kPointsPerInch / kMmPerInch;

/// Standard paper sizes supported by professional photographic printers.
enum PaperSize {
  a4('A4', 210.0, 297.0),
  a3('A3', 297.0, 420.0),
  letter('US Letter', 215.9, 279.4),
  legal('US Legal', 215.9, 355.6),
  photo4x6('4 × 6 in (Postcard)', 101.6, 152.4),
  photo5x7('5 × 7 in', 127.0, 177.8),
  photo8x10('8 × 10 in', 203.2, 254.0),
  photo11x14('11 × 14 in', 279.4, 355.6),
  superB13x19('13 × 19 in (Super B)', 330.2, 482.6);

  const PaperSize(this.label, this.widthMm, this.heightMm);

  final String label;
  final double widthMm;
  final double heightMm;

  String get displayName => label;
  double get widthPt => widthMm * kPointsPerMm;
  double get heightPt => heightMm * kPointsPerMm;

  Size dimensions(PrintOrientation orientation) {
    if (orientation == PrintOrientation.portrait) {
      return Size(widthPt, heightPt);
    } else {
      return Size(heightPt, widthPt);
    }
  }
}

/// Paper printing orientation.
enum PrintOrientation {
  portrait('Portrait'),
  landscape('Landscape');

  const PrintOrientation(this.label);
  final String label;
}

/// Print composition style.
enum PrintLayoutMode {
  single('Single Image'),
  contactSheet('Contact Sheet'),
  picturePackage('Picture Package');

  const PrintLayoutMode(this.label);
  final String label;
}

/// Page margins specified in millimeters.
class PrintMargins {
  const PrintMargins({
    this.topMm = 12.0,
    this.bottomMm = 12.0,
    this.leftMm = 12.0,
    this.rightMm = 12.0,
  });

  const PrintMargins.uniform(double mm)
      : topMm = mm,
        bottomMm = mm,
        leftMm = mm,
        rightMm = mm;

  final double topMm;
  final double bottomMm;
  final double leftMm;
  final double rightMm;

  double get topPt => topMm * kPointsPerMm;
  double get bottomPt => bottomMm * kPointsPerMm;
  double get leftPt => leftMm * kPointsPerMm;
  double get rightPt => rightMm * kPointsPerMm;

  double get horizontalPt => leftPt + rightPt;
  double get verticalPt => topPt + bottomPt;

  Rect printableArea(Size paperDimensions) {
    return Rect.fromLTWH(
      leftPt,
      topPt,
      (paperDimensions.width - horizontalPt).clamp(0.0, double.infinity),
      (paperDimensions.height - verticalPt).clamp(0.0, double.infinity),
    );
  }

  PrintMargins copyWith({
    double? topMm,
    double? bottomMm,
    double? leftMm,
    double? rightMm,
  }) {
    return PrintMargins(
      topMm: topMm ?? this.topMm,
      bottomMm: bottomMm ?? this.bottomMm,
      leftMm: leftMm ?? this.leftMm,
      rightMm: rightMm ?? this.rightMm,
    );
  }
}

/// Grid geometry and metadata options for contact sheet layouts.
class ContactSheetGrid {
  const ContactSheetGrid({
    this.rows = 4,
    this.columns = 3,
    this.cellSpacingMm = 4.0,
    this.showFilename = true,
    this.showExif = true,
    this.showDate = false,
    this.captionFontSize = 8.0,
    this.strokeBorder = false,
  });

  final int rows;
  final int columns;
  final double cellSpacingMm;
  final bool showFilename;
  final bool showExif;
  final bool showDate;
  final double captionFontSize;
  final bool strokeBorder;

  double get spacingPt => cellSpacingMm * kPointsPerMm;
  double get spacingPoints => spacingPt;
  int get itemsPerPage => rows * columns;

  int pageCountFor(int totalItems) {
    if (totalItems <= 0) return 1;
    return (totalItems + itemsPerPage - 1) ~/ itemsPerPage;
  }

  Size computeCellSize(Rect printableArea) {
    final availableWidth = printableArea.width - (columns - 1) * spacingPt;
    final availableHeight = printableArea.height - (rows - 1) * spacingPt;
    final cellW = (availableWidth / columns).clamp(1.0, double.infinity);
    final cellH = (availableHeight / rows).clamp(1.0, double.infinity);
    return Size(cellW, cellH);
  }

  Rect cellRectAt(int indexOnPage, Rect printableArea) {
    final col = indexOnPage % columns;
    final row = (indexOnPage ~/ columns) % rows;
    final cellSize = computeCellSize(printableArea);

    final x = printableArea.left + col * (cellSize.width + spacingPt);
    final y = printableArea.top + row * (cellSize.height + spacingPt);

    return Rect.fromLTWH(x, y, cellSize.width, cellSize.height);
  }

  ContactSheetGrid copyWith({
    int? rows,
    int? columns,
    double? cellSpacingMm,
    bool? showFilename,
    bool? showExif,
    bool? showDate,
    double? captionFontSize,
    bool? strokeBorder,
  }) {
    return ContactSheetGrid(
      rows: rows ?? this.rows,
      columns: columns ?? this.columns,
      cellSpacingMm: cellSpacingMm ?? this.cellSpacingMm,
      showFilename: showFilename ?? this.showFilename,
      showExif: showExif ?? this.showExif,
      showDate: showDate ?? this.showDate,
      captionFontSize: captionFontSize ?? this.captionFontSize,
      strokeBorder: strokeBorder ?? this.strokeBorder,
    );
  }
}

/// Color management configuration integrating with the soft proofing engine.
class PrintColorManagement {
  const PrintColorManagement({
    this.enabled = true,
    this.profile = ProofProfile.cmykSwop,
    this.intent = ProofIntent.relativeColorimetric,
    this.simulatePaperWhite = true,
    this.simulateInkBlack = true,
    this.showGamutWarning = false,
    this.warningColor = const Color(0xFF00E5FF),
  });

  final bool enabled;
  final ProofProfile profile;
  final ProofIntent intent;
  final bool simulatePaperWhite;
  final bool simulateInkBlack;
  final bool showGamutWarning;
  final Color warningColor;

  bool get simulatePaperAndInk => simulatePaperWhite && simulateInkBlack;
  bool get gamutWarning => showGamutWarning;

  PrintColorManagement copyWith({
    bool? enabled,
    ProofProfile? profile,
    ProofIntent? intent,
    bool? simulatePaperWhite,
    bool? simulateInkBlack,
    bool? simulatePaperAndInk,
    bool? showGamutWarning,
    bool? gamutWarning,
    Color? warningColor,
  }) {
    final paperInk = simulatePaperAndInk ?? (simulatePaperWhite ?? this.simulatePaperWhite);
    return PrintColorManagement(
      enabled: enabled ?? this.enabled,
      profile: profile ?? this.profile,
      intent: intent ?? this.intent,
      simulatePaperWhite: paperInk,
      simulateInkBlack: paperInk,
      showGamutWarning: gamutWarning ?? showGamutWarning ?? this.showGamutWarning,
      warningColor: warningColor ?? this.warningColor,
    );
  }
}

/// Master configuration for a print job or PDF contact sheet export.
class PrintJobConfig {
  const PrintJobConfig({
    this.paperSize = PaperSize.a4,
    this.orientation = PrintOrientation.portrait,
    this.layoutMode = PrintLayoutMode.single,
    this.margins = const PrintMargins(),
    this.contactSheetGrid = const ContactSheetGrid(),
    this.colorManagement = const PrintColorManagement(),
    this.dpi = 300,
    this.copies = 1,
    this.renderCutMarks = false,
    this.renderPageNumbers = true,
    this.renderCaptions = true,
  });

  final PaperSize paperSize;
  final PrintOrientation orientation;
  final PrintLayoutMode layoutMode;
  final PrintMargins margins;
  final ContactSheetGrid contactSheetGrid;
  final PrintColorManagement colorManagement;
  final int dpi;
  final int copies;
  final bool renderCutMarks;
  final bool renderPageNumbers;
  final bool renderCaptions;

  Size get paperDimensions => paperSize.dimensions(orientation);
  Rect get printableArea => margins.printableArea(paperDimensions);

  PrintJobConfig copyWith({
    PaperSize? paperSize,
    PrintOrientation? orientation,
    PrintLayoutMode? layoutMode,
    PrintMargins? margins,
    ContactSheetGrid? contactSheetGrid,
    PrintColorManagement? colorManagement,
    int? dpi,
    int? copies,
    bool? renderCutMarks,
    bool? renderPageNumbers,
    bool? renderCaptions,
  }) {
    return PrintJobConfig(
      paperSize: paperSize ?? this.paperSize,
      orientation: orientation ?? this.orientation,
      layoutMode: layoutMode ?? this.layoutMode,
      margins: margins ?? this.margins,
      contactSheetGrid: contactSheetGrid ?? this.contactSheetGrid,
      colorManagement: colorManagement ?? this.colorManagement,
      dpi: dpi ?? this.dpi,
      copies: copies ?? this.copies,
      renderCutMarks: renderCutMarks ?? this.renderCutMarks,
      renderPageNumbers: renderPageNumbers ?? this.renderPageNumbers,
      renderCaptions: renderCaptions ?? this.renderCaptions,
    );
  }
}

/// Represents a photo queued for printing or contact sheet generation.
class PrintPhotoItem {
  const PrintPhotoItem({
    required this.id,
    this.filePath,
    this.imageBytes,
    this.title = '',
    this.filename = '',
    this.exifSummary = '',
    this.captureDate = '',
    this.aspectRatio = 1.0,
  });

  final String id;
  final String? filePath;
  final Uint8List? imageBytes;
  final String title;
  final String filename;
  final String exifSummary;
  final String captureDate;
  final double aspectRatio;
}
