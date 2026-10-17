import 'dart:typed_data';

/// Encoded image container families the app may be handed.
enum ImageFormat {
  jpeg,
  png,
  webp,
  gif,
  bmp,
  heic,
  avif,
  /// A raw camera format (DNG/CR2/NEF/ARW/ORF/RW2/CR3/RAF…). Flutter's image
  /// codec cannot decode these, so they are routed through the Rust engine.
  raw,
  unknown,
}

/// Sniffs the container from the first bytes — no full decode, no I/O.
///
/// TIFF-based raw formats (DNG, CR2, NEF, ARW, ORF, RW2, PEF, SRW) share the
/// little/big-endian TIFF magic; CR3 is ISO-BMFF (`ftypcrx`); RAF is `FUJIFILM`.
/// Plain TIFF is reported as [ImageFormat.raw] too, since Flutter cannot render
/// it and the Rust path is the only chance of opening it.
ImageFormat detectImageFormat(Uint8List bytes) {
  if (_startsWith(bytes, const [0xFF, 0xD8, 0xFF])) return ImageFormat.jpeg;
  if (_startsWith(bytes, const [0x89, 0x50, 0x4E, 0x47])) return ImageFormat.png;
  if (_startsWith(bytes, const [0x47, 0x49, 0x46, 0x38])) return ImageFormat.gif;
  if (_startsWith(bytes, const [0x42, 0x4D])) return ImageFormat.bmp;
  if (bytes.length >= 12 &&
      _asciiAt(bytes, 0, 'RIFF') &&
      _asciiAt(bytes, 8, 'WEBP')) {
    return ImageFormat.webp;
  }
  if (_isTiff(bytes)) return ImageFormat.raw;
  if (bytes.length >= 12 && _asciiAt(bytes, 4, 'ftypcrx')) return ImageFormat.raw;
  if (bytes.length >= 12 && _asciiAt(bytes, 4, 'ftyp')) {
    if (_asciiAt(bytes, 8, 'heic') ||
        _asciiAt(bytes, 8, 'heix') ||
        _asciiAt(bytes, 8, 'heim') ||
        _asciiAt(bytes, 8, 'heis') ||
        _asciiAt(bytes, 8, 'mif1') ||
        _asciiAt(bytes, 8, 'msf1')) {
      return ImageFormat.heic;
    }
    if (_asciiAt(bytes, 8, 'avif') || _asciiAt(bytes, 8, 'avis')) {
      return ImageFormat.avif;
    }
  }
  if (_asciiAt(bytes, 0, 'FUJIFILM')) return ImageFormat.raw;
  return ImageFormat.unknown;
}

/// Whether [bytes] should go through the Rust RAW decoder rather than the
/// Flutter image codec.
bool isRawImage(Uint8List bytes) => detectImageFormat(bytes) == ImageFormat.raw;

bool _isTiff(Uint8List b) {
  if (b.length < 4) return false;
  final little = b[0] == 0x49 && b[1] == 0x49 && b[2] == 0x2A && b[3] == 0x00;
  final big = b[0] == 0x4D && b[1] == 0x4D && b[2] == 0x00 && b[3] == 0x2A;
  return little || big;
}

bool _startsWith(Uint8List bytes, List<int> prefix) {
  if (bytes.length < prefix.length) return false;
  for (var i = 0; i < prefix.length; i++) {
    if (bytes[i] != prefix[i]) return false;
  }
  return true;
}

bool _asciiAt(Uint8List bytes, int offset, String text) {
  if (bytes.length < offset + text.length) return false;
  for (var i = 0; i < text.length; i++) {
    if (bytes[offset + i] != text.codeUnitAt(i)) return false;
  }
  return true;
}
