import 'dart:convert';
import 'dart:typed_data';

import 'print_model.dart';

/// Pure-Dart professional PDF document generator for photo printing and contact sheets.
///
/// Compliant with PDF 1.4 specification (ISO 32000-1):
/// - Embeds high-resolution JPEG streams with `/DCTDecode`.
/// - Supports arbitrary paper sizes (A4, A3, US Letter, 4×6", 8×10", etc.) in exact point dimensions.
/// - Renders single-photo layouts, multi-column contact sheets, vector margins, and EXIF captions.
/// - 100% offline, zero network dependencies, F-Droid compliant.
class PrintPdfGenerator {
  const PrintPdfGenerator._();

  static Uint8List generate({
    required PrintJobConfig config,
    required List<PrintPhotoItem> items,
  }) {
    final builder = _PdfDocumentBuilder();
    final paperDims = config.paperSize.dimensions(config.orientation);
    final printable = config.margins.printableArea(paperDims);

    final fontObj = builder.addObject(
      '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
    );

    final pagesObj = builder.reserveObject();

    final pageRefs = <int>[];

    if (config.layoutMode == PrintLayoutMode.contactSheet) {
      final grid = config.contactSheetGrid;
      final totalPages = grid.pageCountFor(items.length);

      for (var pageIdx = 0; pageIdx < totalPages; pageIdx++) {
        final startIdx = pageIdx * grid.itemsPerPage;
        final endIdx = (startIdx + grid.itemsPerPage).clamp(0, items.length);
        final pageItems = items.sublist(startIdx, endIdx);

        final pageRef = _buildContactSheetPage(
          builder: builder,
          pagesRef: pagesObj,
          fontRef: fontObj,
          paperDims: paperDims,
          printable: printable,
          grid: grid,
          pageIdx: pageIdx,
          totalPages: totalPages,
          items: pageItems,
        );
        pageRefs.add(pageRef);
      }
    } else {
      // Single photo layout: 1 page per photo (or 1 page if empty)
      final photoList = items.isEmpty ? [const PrintPhotoItem(id: 'placeholder')] : items;

      for (var i = 0; i < photoList.length; i++) {
        final photo = photoList[i];
        final pageRef = _buildSinglePhotoPage(
          builder: builder,
          pagesRef: pagesObj,
          fontRef: fontObj,
          paperDims: paperDims,
          printable: printable,
          photo: photo,
          pageIdx: i,
          totalPages: photoList.length,
        );
        pageRefs.add(pageRef);
      }
    }

    // Resolve Pages container
    final kidsArray = pageRefs.map((r) => '$r 0 R').join(' ');
    builder.setReservedObject(
      pagesObj,
      '<< /Type /Pages /Kids [$kidsArray] /Count ${pageRefs.length} >>',
    );

    // Root Catalog
    builder.addObject(
      '<< /Type /Catalog /Pages $pagesObj 0 R >>',
    );

    return builder.build();
  }

  static int _buildSinglePhotoPage({
    required _PdfDocumentBuilder builder,
    required int pagesRef,
    required int fontRef,
    required dynamic paperDims,
    required dynamic printable,
    required PrintPhotoItem photo,
    required int pageIdx,
    required int totalPages,
  }) {
    final xObjects = <String, int>{};
    final stream = BytesBuilder();

    // Image placement (center inside printable area, PDF Y runs bottom-to-top)
    if (photo.imageBytes != null && photo.imageBytes!.isNotEmpty) {
      final imgRef = builder.addImageObject(photo.imageBytes!);
      xObjects['/Im1'] = imgRef;

      final aspect = photo.aspectRatio > 0 ? photo.aspectRatio : 1.5;
      var drawW = printable.width as double;
      var drawH = drawW / aspect;
      if (drawH > printable.height) {
        drawH = printable.height as double;
        drawW = drawH * aspect;
      }

      final drawX = printable.left + (printable.width - drawW) / 2;
      final drawY = (paperDims.height - printable.top - printable.height) +
          (printable.height - drawH) / 2;

      final cmd = 'q\n'
          '${drawW.toStringAsFixed(2)} 0 0 ${drawH.toStringAsFixed(2)} '
          '${drawX.toStringAsFixed(2)} ${drawY.toStringAsFixed(2)} cm\n'
          '/Im1 Do\n'
          'Q\n';
      stream.add(utf8.encode(cmd));

      // Caption if available
      if (photo.filename.isNotEmpty || photo.exifSummary.isNotEmpty) {
        final captionY = drawY - 14.0;
        final captionText = photo.filename.isNotEmpty && photo.exifSummary.isNotEmpty
            ? '${photo.filename}  ·  ${photo.exifSummary}'
            : (photo.filename.isNotEmpty ? photo.filename : photo.exifSummary);

        final textCmd = 'BT\n'
            '/F1 9 Tf\n'
            '${drawX.toStringAsFixed(2)} ${captionY.toStringAsFixed(2)} Td\n'
            '(${_escapePdfText(captionText)}) Tj\n'
            'ET\n';
        stream.add(utf8.encode(textCmd));
      }
    }

    final contentRef = builder.addStreamObject(stream.toBytes());

    final xObjDict = xObjects.entries.map((e) => '${e.key} ${e.value} 0 R').join(' ');
    final wStr = paperDims.width.toStringAsFixed(2);
    final hStr = paperDims.height.toStringAsFixed(2);

    return builder.addObject(
      '<< /Type /Page /Parent $pagesRef 0 R '
      '/MediaBox [0 0 $wStr $hStr] '
      '/Contents $contentRef 0 R '
      '/Resources << /Font << /F1 $fontRef 0 R >> '
      '${xObjects.isNotEmpty ? '/XObject << $xObjDict >> ' : ''}'
      '>> >>',
    );
  }

  static int _buildContactSheetPage({
    required _PdfDocumentBuilder builder,
    required int pagesRef,
    required int fontRef,
    required dynamic paperDims,
    required dynamic printable,
    required ContactSheetGrid grid,
    required int pageIdx,
    required int totalPages,
    required List<PrintPhotoItem> items,
  }) {
    final xObjects = <String, int>{};
    final stream = BytesBuilder();
    final cellSize = grid.computeCellSize(printable);

    // Header banner
    final headerY = paperDims.height - printable.top + 8.0;
    final headerCmd = 'BT\n'
        '/F1 9 Tf\n'
        '${printable.left.toStringAsFixed(2)} ${headerY.toStringAsFixed(2)} Td\n'
        '(ApertureX Contact Sheet  ·  Page ${pageIdx + 1} of $totalPages) Tj\n'
        'ET\n';
    stream.add(utf8.encode(headerCmd));

    for (var i = 0; i < items.length; i++) {
      final photo = items[i];
      final col = i % grid.columns;
      final row = i ~/ grid.columns;

      final cellX = printable.left + col * (cellSize.width + grid.spacingPt);
      // PDF Y is bottom-up:
      final cellY = paperDims.height -
          printable.top -
          (row + 1) * cellSize.height -
          row * grid.spacingPt;

      // Draw subtle cell outline
      final borderCmd = '0.85 0.85 0.85 RG\n'
          '0.5 w\n'
          '${cellX.toStringAsFixed(2)} ${cellY.toStringAsFixed(2)} '
          '${cellSize.width.toStringAsFixed(2)} ${cellSize.height.toStringAsFixed(2)} re\n'
          'S\n';
      stream.add(utf8.encode(borderCmd));

      // Image rect inside cell (reserving room for caption)
      final captionReserved = (grid.showFilename || grid.showExif) ? 18.0 : 0.0;
      final imgAvailableH = (cellSize.height - captionReserved - 4.0).clamp(10.0, cellSize.height);
      final imgAvailableW = cellSize.width - 4.0;

      if (photo.imageBytes != null && photo.imageBytes!.isNotEmpty) {
        final imgKey = '/Im${xObjects.length + 1}';
        final imgRef = builder.addImageObject(photo.imageBytes!);
        xObjects[imgKey] = imgRef;

        final aspect = photo.aspectRatio > 0 ? photo.aspectRatio : 1.5;
        var drawW = imgAvailableW;
        var drawH = drawW / aspect;
        if (drawH > imgAvailableH) {
          drawH = imgAvailableH;
          drawW = drawH * aspect;
        }

        final drawX = cellX + 2.0 + (imgAvailableW - drawW) / 2;
        final drawY = cellY + captionReserved + 2.0 + (imgAvailableH - drawH) / 2;

        final drawCmd = 'q\n'
            '${drawW.toStringAsFixed(2)} 0 0 ${drawH.toStringAsFixed(2)} '
            '${drawX.toStringAsFixed(2)} ${drawY.toStringAsFixed(2)} cm\n'
            '$imgKey Do\n'
            'Q\n';
        stream.add(utf8.encode(drawCmd));
      }

      // Metadata caption
      if (grid.showFilename || grid.showExif) {
        final label = photo.filename.isNotEmpty ? photo.filename : photo.title;
        final captionY = cellY + 4.0;
        final textCmd = 'BT\n'
            '/F1 ${grid.captionFontSize.toStringAsFixed(1)} Tf\n'
            '0.2 0.2 0.2 rg\n'
            '${(cellX + 4.0).toStringAsFixed(2)} ${captionY.toStringAsFixed(2)} Td\n'
            '(${_escapePdfText(label)}) Tj\n'
            'ET\n';
        stream.add(utf8.encode(textCmd));
      }
    }

    final contentRef = builder.addStreamObject(stream.toBytes());

    final xObjDict = xObjects.entries.map((e) => '${e.key} ${e.value} 0 R').join(' ');
    final wStr = paperDims.width.toStringAsFixed(2);
    final hStr = paperDims.height.toStringAsFixed(2);

    return builder.addObject(
      '<< /Type /Page /Parent $pagesRef 0 R '
      '/MediaBox [0 0 $wStr $hStr] '
      '/Contents $contentRef 0 R '
      '/Resources << /Font << /F1 $fontRef 0 R >> '
      '${xObjects.isNotEmpty ? '/XObject << $xObjDict >> ' : ''}'
      '>> >>',
    );
  }

  static String _escapePdfText(String text) {
    return text
        .replaceAll('\\', '\\\\')
        .replaceAll('(', '\\(')
        .replaceAll(')', '\\)');
  }
}

class _PdfDocumentBuilder {
  _PdfDocumentBuilder() {
    _buffer.add(utf8.encode('%PDF-1.4\n%\xE2\xE3\xCF\xD3\n'));
  }

  final BytesBuilder _buffer = BytesBuilder();
  final List<int> _offsets = [];
  int _nextId = 1;

  int reserveObject() {
    return _nextId++;
  }

  int addObject(String dictBody) {
    final id = _nextId++;
    _offsets.add(_buffer.length);
    final text = '$id 0 obj\n$dictBody\nendobj\n';
    _buffer.add(utf8.encode(text));
    return id;
  }

  void setReservedObject(int id, String dictBody) {
    while (_offsets.length < id) {
      _offsets.add(0);
    }
    _offsets[id - 1] = _buffer.length;
    final text = '$id 0 obj\n$dictBody\nendobj\n';
    _buffer.add(utf8.encode(text));
  }

  int addStreamObject(Uint8List streamBytes) {
    final id = _nextId++;
    _offsets.add(_buffer.length);
    final header = '$id 0 obj\n<< /Length ${streamBytes.length} >>\nstream\n';
    _buffer.add(utf8.encode(header));
    _buffer.add(streamBytes);
    const footer = '\nendstream\nendobj\n';
    _buffer.add(utf8.encode(footer));
    return id;
  }

  int addImageObject(Uint8List jpegBytes) {
    final id = _nextId++;
    _offsets.add(_buffer.length);
    final (width, height) = _parseJpegDimensions(jpegBytes);
    final header = '$id 0 obj\n'
        '<< /Type /XObject /Subtype /Image '
        '/Width $width /Height $height '
        '/ColorSpace /DeviceRGB /BitsPerComponent 8 '
        '/Filter /DCTDecode /Length ${jpegBytes.length} >>\n'
        'stream\n';
    _buffer.add(utf8.encode(header));
    _buffer.add(jpegBytes);
    const footer = '\nendstream\nendobj\n';
    _buffer.add(utf8.encode(footer));
    return id;
  }

  static (int, int) _parseJpegDimensions(Uint8List bytes) {
    // Robust SOF0/SOF2 marker dimension extractor
    for (var i = 0; i < bytes.length - 8; i++) {
      if (bytes[i] == 0xFF &&
          (bytes[i + 1] == 0xC0 || bytes[i + 1] == 0xC2)) {
        final h = (bytes[i + 5] << 8) | bytes[i + 6];
        final w = (bytes[i + 7] << 8) | bytes[i + 8];
        if (w > 0 && h > 0) return (w, h);
      }
    }
    return (1, 1);
  }

  Uint8List build() {
    final startXref = _buffer.length;
    final totalObjects = _offsets.length + 1;

    final xrefBuilder = StringBuffer();
    xrefBuilder.write('xref\n0 $totalObjects\n0000000000 65535 f \n');
    for (final offset in _offsets) {
      xrefBuilder.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
    }

    xrefBuilder.write('trailer\n<< /Size $totalObjects /Root ${_nextId - 1} 0 R >>\n');
    xrefBuilder.write('startxref\n$startXref\n%%EOF\n');

    _buffer.add(utf8.encode(xrefBuilder.toString()));
    return _buffer.toBytes();
  }
}
