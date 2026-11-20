import 'dart:convert';
import 'package:universal_io/io.dart';
import 'dart:typed_data';

/// The origin source of an estimated or embedded depth field.
enum DepthSourceType {
  embeddedGDepth,
  neural,
  approximate,
  none;

  static DepthSourceType fromU8(int val) {
    switch (val) {
      case 0:
        return DepthSourceType.embeddedGDepth;
      case 1:
        return DepthSourceType.neural;
      case 2:
        return DepthSourceType.approximate;
      default:
        return DepthSourceType.none;
    }
  }

  int toU8() {
    switch (this) {
      case DepthSourceType.embeddedGDepth:
        return 0;
      case DepthSourceType.neural:
        return 1;
      case DepthSourceType.approximate:
        return 2;
      case DepthSourceType.none:
        return 3;
    }
  }
}

/// In-memory representation of an ApertureX depth field sidecar payload.
class DepthSidecarData {
  const DepthSidecarData({
    required this.width,
    required this.height,
    required this.confidence,
    required this.source,
    required this.contentHash,
    required this.plane,
  });

  factory DepthSidecarData.fromJson(Map<String, Object?> json) {
    final planeRaw = json['plane'];
    Float32List planeList;
    if (planeRaw is String) {
      final bytes = base64Decode(planeRaw);
      planeList = Float32List.sublistView(bytes);
    } else if (planeRaw is List) {
      planeList = Float32List.fromList(
        planeRaw.cast<num>().map((e) => e.toDouble()).toList(),
      );
    } else {
      planeList = Float32List(0);
    }

    return DepthSidecarData(
      width: (json['width'] as num?)?.toInt() ?? 0,
      height: (json['height'] as num?)?.toInt() ?? 0,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      source: DepthSourceType.fromU8((json['source'] as num?)?.toInt() ?? 3),
      contentHash: (json['contentHash'] as num?)?.toInt() ?? 0,
      plane: planeList,
    );
  }

  final int width;
  final int height;
  final double confidence;
  final DepthSourceType source;
  final int contentHash;
  final Float32List plane;

  Map<String, Object?> toJson() => <String, Object?>{
        'width': width,
        'height': height,
        'confidence': confidence,
        'source': source.toU8(),
        'contentHash': contentHash,
        'plane': base64Encode(Uint8List.sublistView(plane)),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DepthSidecarData &&
          width == other.width &&
          height == other.height &&
          (confidence - other.confidence).abs() < 1e-4 &&
          source == other.source &&
          contentHash == other.contentHash &&
          plane.length == other.plane.length;

  @override
  int get hashCode => Object.hash(width, height, source, contentHash, plane.length);
}

/// Binary sidecar storage for cached neural and embedded depth maps.
/// File extension: `.axdf` (ApertureX Depth Field).
///
/// Binary format:
/// - 0..4: Magic ASCII `AXDF` (0x41, 0x58, 0x44, 0x46)
/// - 4..6: Format version (uint16 little-endian, currently 1)
/// - 6..10: Width (uint32 little-endian)
/// - 10..14: Height (uint32 little-endian)
/// - 14..18: Confidence score [0.0, 1.0] (float32 little-endian)
/// - 18: DepthSourceType (uint8)
/// - 19..27: Content hash (uint64 little-endian)
/// - 27..: Float32 planar depth buffer (width * height * 4 bytes)
class DepthSidecar {
  const DepthSidecar._();

  static const String extension = '.axdf';
  static const int headerLength = 27;

  /// Returns the canonical sidecar file name for an image.
  static String fileNameFor(String imageName) {
    final dot = imageName.lastIndexOf('.');
    final base = dot <= 0 ? imageName : imageName.substring(0, dot);
    return '$base$extension';
  }

  /// Serializes [data] into binary AXDF format.
  static Uint8List encode(DepthSidecarData data) {
    final totalBytes = headerLength + data.plane.lengthInBytes;
    final bytes = Uint8List(totalBytes);
    final byteData = ByteData.sublistView(bytes);

    // Magic: "AXDF"
    bytes[0] = 0x41;
    bytes[1] = 0x58;
    bytes[2] = 0x44;
    bytes[3] = 0x46;

    byteData.setUint16(4, 1, Endian.little);
    byteData.setUint32(6, data.width, Endian.little);
    byteData.setUint32(10, data.height, Endian.little);
    byteData.setFloat32(14, data.confidence, Endian.little);
    bytes[18] = data.source.toU8();
    byteData.setUint64(19, data.contentHash, Endian.little);

    final planeBytes = Uint8List.sublistView(data.plane);
    bytes.setRange(headerLength, totalBytes, planeBytes);

    return bytes;
  }

  /// Deserializes [bytes] into a [DepthSidecarData] instance.
  static DepthSidecarData decode(Uint8List bytes) {
    if (bytes.length < headerLength) {
      throw const FormatException('Depth sidecar payload too short (< 27 bytes)');
    }
    if (bytes[0] != 0x41 || bytes[1] != 0x58 || bytes[2] != 0x44 || bytes[3] != 0x46) {
      throw const FormatException('Invalid depth sidecar magic header');
    }

    final byteData = ByteData.sublistView(bytes);
    final version = byteData.getUint16(4, Endian.little);
    if (version != 1) {
      throw FormatException('Unsupported depth sidecar version $version');
    }

    final width = byteData.getUint32(6, Endian.little);
    final height = byteData.getUint32(10, Endian.little);
    final confidence = byteData.getFloat32(14, Endian.little);
    final source = DepthSourceType.fromU8(bytes[18]);
    final contentHash = byteData.getUint64(19, Endian.little);

    final expectedFloats = width * height;
    final expectedTotalBytes = headerLength + expectedFloats * 4;
    if (bytes.length < expectedTotalBytes) {
      throw FormatException(
        'Depth sidecar plane buffer truncated: expected $expectedTotalBytes, got ${bytes.length}',
      );
    }

    final planeBytes = bytes.sublist(headerLength, expectedTotalBytes);
    final plane = Float32List.sublistView(Uint8List.fromList(planeBytes));

    return DepthSidecarData(
      width: width,
      height: height,
      confidence: confidence,
      source: source,
      contentHash: contentHash,
      plane: plane,
    );
  }

  /// Reads and deserializes a sidecar file if it exists.
  static Future<DepthSidecarData?> load(File file) async {
    if (!await file.exists()) return null;
    final bytes = await file.readAsBytes();
    return decode(bytes);
  }

  /// Encodes and writes [data] to [file].
  static Future<void> save(File file, DepthSidecarData data) async {
    final bytes = encode(data);
    await file.writeAsBytes(bytes, flush: true);
  }
}

/// Abstract destination sink for depth sidecar persistence.
abstract class DepthSidecarSink {
  Future<void> write(String imageName, DepthSidecarData data);
  Future<DepthSidecarData?> read(String imageName);
}

/// Directory-based depth sidecar sink for local file persistence.
class DirectoryDepthSidecarSink implements DepthSidecarSink {
  const DirectoryDepthSidecarSink(this.resolveDir);

  final Future<Directory> Function() resolveDir;

  @override
  Future<void> write(String imageName, DepthSidecarData data) async {
    final dir = await resolveDir();
    await dir.create(recursive: true);
    final file = File('${dir.path}/${DepthSidecar.fileNameFor(imageName)}');
    await file.writeAsBytes(DepthSidecar.encode(data), flush: true);
  }

  @override
  Future<DepthSidecarData?> read(String imageName) async {
    final dir = await resolveDir();
    final file = File('${dir.path}/${DepthSidecar.fileNameFor(imageName)}');
    if (!await file.exists()) {
      return null;
    }
    final bytes = await file.readAsBytes();
    return DepthSidecar.decode(bytes);
  }
}
