import 'dart:math' as math;
import 'dart:typed_data';

/// Reads the EXIF orientation tag (1..8) from [bytes] without decoding pixels.
/// Returns 1 (normal / identity) when no EXIF orientation tag is present or
/// when the input is not a JPEG.
int readExifOrientation(Uint8List bytes) {
  if (bytes.length < 4 || bytes[0] != 0xFF || bytes[1] != 0xD8) return 1;
  var i = 2;
  while (i + 4 <= bytes.length) {
    if (bytes[i] != 0xFF) break;
    final marker = bytes[i + 1];
    if (marker == 0xDA || marker == 0xD9) break; // SOS or EOI
    if (marker == 0xD8 || marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7)) {
      i += 2;
      continue;
    }
    final len = (bytes[i + 2] << 8) | bytes[i + 3];
    final segEnd = i + 2 + len;
    if (segEnd > bytes.length || len < 2) break;
    if (marker == 0xE1 && len >= 14) {
      // APP1 Exif segment
      if (bytes[i + 4] == 0x45 && // 'E'
          bytes[i + 5] == 0x78 && // 'x'
          bytes[i + 6] == 0x69 && // 'i'
          bytes[i + 7] == 0x66 && // 'f'
          bytes[i + 8] == 0x00 &&
          bytes[i + 9] == 0x00) {
        final tiff = i + 10;
        if (tiff + 8 <= segEnd) {
          final isLE = bytes[tiff] == 0x49 && bytes[tiff + 1] == 0x49; // 'II'
          final isBE = bytes[tiff] == 0x4D && bytes[tiff + 1] == 0x4D; // 'MM'
          if (isLE || isBE) {
            int readU16(int offset) {
              return isLE
                  ? bytes[offset] | (bytes[offset + 1] << 8)
                  : (bytes[offset] << 8) | bytes[offset + 1];
            }

            int readU32(int offset) {
              return isLE
                  ? bytes[offset] |
                      (bytes[offset + 1] << 8) |
                      (bytes[offset + 2] << 16) |
                      (bytes[offset + 3] << 24)
                  : (bytes[offset] << 24) |
                      (bytes[offset + 1] << 16) |
                      (bytes[offset + 2] << 8) |
                      bytes[offset + 3];
            }

            if (readU16(tiff + 2) == 42) {
              final ifd0Offset = readU32(tiff + 4);
              var ifd = tiff + ifd0Offset;
              if (ifd + 2 <= segEnd) {
                final tagCount = readU16(ifd);
                ifd += 2;
                for (var t = 0; t < tagCount && ifd + 12 <= segEnd; t++, ifd += 12) {
                  final tagId = readU16(ifd);
                  if (tagId == 0x0112) {
                    // Tag 0x0112 = Orientation
                    final val = readU16(ifd + 8);
                    return val >= 1 && val <= 8 ? val : 1;
                  }
                }
              }
            }
          }
        }
      }
    }
    i = segEnd;
  }
  return 1;
}

/// Whether the EXIF orientation swaps width and height in display coordinates.
/// Orientations 5 (transpose), 6 (rotate 90 CW), 7 (transverse), and 8 (rotate 270 CW)
/// swap horizontal and vertical axes.
bool exifSwapsDimensions(int orientation) =>
    orientation == 5 || orientation == 6 || orientation == 7 || orientation == 8;

/// Computes display dimensions (width, height) from the raw file header dimensions
/// and EXIF orientation tag.
({int width, int height}) computeDisplayDimensions({
  required int rawWidth,
  required int rawHeight,
  required int orientation,
}) {
  if (exifSwapsDimensions(orientation)) {
    return (width: rawHeight, height: rawWidth);
  }
  return (width: rawWidth, height: rawHeight);
}

/// Sizing targets for [instantiateImageCodecFromBuffer].
class DecodeTarget {
  const DecodeTarget({this.targetWidth, this.targetHeight});
  final int? targetWidth;
  final int? targetHeight;
}

/// Calculates [targetWidth] or [targetHeight] to pass to Flutter's codec, ensuring:
/// 1. The longest dimension in display orientation does not exceed [maxDim].
/// 2. Only ONE target dimension is set, allowing Flutter to scale the other dimension
///    proportionally without distorting or squeezing the aspect ratio.
DecodeTarget computeDecodeTarget({
  required int rawWidth,
  required int rawHeight,
  required int orientation,
  int? maxDim,
}) {
  if (maxDim == null) return const DecodeTarget();
  final display = computeDisplayDimensions(
    rawWidth: rawWidth,
    rawHeight: rawHeight,
    orientation: orientation,
  );
  final longest = math.max(display.width, display.height);
  if (longest <= maxDim) return const DecodeTarget();

  if (display.width >= display.height) {
    return DecodeTarget(targetWidth: maxDim);
  } else {
    return DecodeTarget(targetHeight: maxDim);
  }
}
