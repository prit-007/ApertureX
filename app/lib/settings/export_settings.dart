import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/log/activity_log.dart';
import '../core/log/log_providers.dart';

/// Pro Image Sizing mode aligned with Lightroom Classic and Photoshop.
enum ExportResizeMode {
  original('Original', 'Preserve 100% sensor resolution'),
  longEdge('Long Edge', 'Constrain longest edge in pixels'),
  shortEdge('Short Edge', 'Constrain shortest edge in pixels'),
  fit('Fit Width × Height', 'Fit within bounding box'),
  percentage('Percentage', 'Scale by percentage of original');

  const ExportResizeMode(this.label, this.description);
  final String label;
  final String description;
}

/// Metadata and privacy options for export.
enum ExportMetadataMode {
  all('All Metadata', 'Retain all camera EXIF, lens, exposure & GPS data'),
  copyrightOnly('Copyright Only', 'Strip GPS location and camera serial numbers'),
  none('None (Anonymized)', 'Remove all metadata for maximum web privacy');

  const ExportMetadataMode(this.label, this.description);
  final String label;
  final String description;
}

/// Named export preset for quick 1-tap configuration (Phase 1 Pro export presets).
enum ExportPresetKind {
  fullRes('Full Res Master', 'Original size, JPEG 95%, sRGB, all metadata'),
  webSocial('Web & Social (2048px)', 'Max 2048px, JPEG 85%, screen sharpen, copyright only'),
  printLossless('Print / Lossless', 'Full resolution, Lossless PNG or 16-bit TIFF'),
  clientProof('Client Proof', 'Max 1600px, JPEG 75%, proof watermark'),
  proDisplay('Pro HDR (P3)', 'Display-P3 with Ultra HDR gain map');

  const ExportPresetKind(this.title, this.description);
  final String title;
  final String description;
}

/// Export preferences, persisted on-device.
class ExportSettings {
  const ExportSettings({
    this.quality = 90,
    this.maxDim = 0,
    this.colorSpace = 0,
    this.ultraHdr = false,
    this.hdrHeadroom = 2.0,
    this.filenamePattern = '{original}_{date}',
    this.resizeMode = ExportResizeMode.original,
    this.resizeDimension = 2048,
    this.resizeWidth = 1920,
    this.resizeHeight = 1080,
    this.resizePercentage = 100,
    this.dontEnlarge = true,
    this.outputSharpenMedia = 0, // 0 = None, 1 = Screen, 2 = Matte, 3 = Glossy
    this.outputSharpen = 0.0,
    this.metadataMode = ExportMetadataMode.all,
  });

  /// JPEG quality `60..100`.
  final int quality;

  /// Longest-side cap in pixels; `0` = original resolution.
  final int maxDim;

  /// Color space: `0` = sRGB, `1` = Display-P3 (Wide Color Gamut).
  final int colorSpace;

  /// Enable Ultra HDR (ISO 21496-1) gain map embedding.
  final bool ultraHdr;

  /// HDR peak headroom in EV stops (1.0..4.0, default 2.0 = 400% SDR brightness).
  final double hdrHeadroom;

  /// Filename template pattern with tokens: {original}, {date}, {preset}, {counter}.
  final String filenamePattern;

  /// Pro Image Sizing mode.
  final ExportResizeMode resizeMode;

  /// Target pixel length for Long Edge or Short Edge modes.
  final int resizeDimension;

  /// Target bounding width.
  final int resizeWidth;

  /// Target bounding height.
  final int resizeHeight;

  /// Percentage scale (10..100).
  final int resizePercentage;

  /// Guard to prevent upscaling smaller images.
  final bool dontEnlarge;

  /// Output sharpening media: 0 = Off, 1 = Screen, 2 = Matte Paper, 3 = Glossy Paper.
  final int outputSharpenMedia;

  /// Output sharpening amount (0.0 = low/off, 0.5 = standard, 1.0 = high).
  final double outputSharpen;

  /// Privacy and metadata preservation mode.
  final ExportMetadataMode metadataMode;

  /// Computes target output resolution `(targetW, targetH)` from input dimensions.
  ({int width, int height}) computeDimensions(int sourceW, int sourceH) {
    if (sourceW <= 0 || sourceH <= 0) return (width: 0, height: 0);

    switch (resizeMode) {
      case ExportResizeMode.original:
        if (maxDim > 0) {
          final longest = math.max(sourceW, sourceH);
          if (dontEnlarge && longest <= maxDim) {
            return (width: sourceW, height: sourceH);
          }
          final scale = maxDim / longest;
          return (
            width: math.max(1, (sourceW * scale).round()),
            height: math.max(1, (sourceH * scale).round()),
          );
        }
        return (width: sourceW, height: sourceH);

      case ExportResizeMode.longEdge:
        final longest = math.max(sourceW, sourceH);
        if (dontEnlarge && longest <= resizeDimension) {
          return (width: sourceW, height: sourceH);
        }
        final scale = resizeDimension / longest;
        return (
          width: math.max(1, (sourceW * scale).round()),
          height: math.max(1, (sourceH * scale).round()),
        );

      case ExportResizeMode.shortEdge:
        final shortest = math.min(sourceW, sourceH);
        if (dontEnlarge && shortest <= resizeDimension) {
          return (width: sourceW, height: sourceH);
        }
        final scale = resizeDimension / shortest;
        return (
          width: math.max(1, (sourceW * scale).round()),
          height: math.max(1, (sourceH * scale).round()),
        );

      case ExportResizeMode.fit:
        final scaleW = resizeWidth / sourceW;
        final scaleH = resizeHeight / sourceH;
        var scale = math.min(scaleW, scaleH);
        if (dontEnlarge && scale > 1.0) scale = 1.0;
        return (
          width: math.max(1, (sourceW * scale).round()),
          height: math.max(1, (sourceH * scale).round()),
        );

      case ExportResizeMode.percentage:
        final scale = (resizePercentage.clamp(5, 200)) / 100.0;
        return (
          width: math.max(1, (sourceW * scale).round()),
          height: math.max(1, (sourceH * scale).round()),
        );
    }
  }

  /// Calculates effective maxDim for engine calls.
  int get effectiveMaxDim {
    switch (resizeMode) {
      case ExportResizeMode.original:
        return maxDim;
      case ExportResizeMode.longEdge:
        return resizeDimension;
      case ExportResizeMode.shortEdge:
      case ExportResizeMode.fit:
      case ExportResizeMode.percentage:
        return 0; // handled via explicit dimensions
    }
  }

  /// Estimates file size string based on dimensions, format, and quality.
  String estimateFileSize({
    required int width,
    required int height,
    String format = 'jpeg',
  }) {
    if (width <= 0 || height <= 0) return '0 KB';
    final pixels = width * height;
    double bytes;
    switch (format.toLowerCase()) {
      case 'png':
        bytes = pixels * 4.0 * 0.45; // ~45% compression of RGBA
        break;
      case 'heic':
        // HEVC intra ~ 50% of JPEG size at equivalent quality
        final qFactor = (0.08 + (quality / 100.0) * 0.22) * 0.5;
        bytes = pixels * qFactor;
        break;
      case 'avif':
        // AV1 intra ~ 45% of JPEG size at equivalent quality
        final qFactor = (0.08 + (quality / 100.0) * 0.22) * 0.45;
        bytes = pixels * qFactor;
        break;
      case 'tiff':
      case 'tiff16':
        bytes = pixels * 8.0; // 16-bit uncompressed RGBA
        break;
      case 'dng':
        bytes = pixels * 2.0; // 14-bit packed Bayer
        break;
      case 'jpeg':
      default:
        // Empirical JPEG estimate: q90 ~ 0.25 bytes/pixel, q80 ~ 0.16 bytes/pixel
        final qFactor = 0.08 + (quality / 100.0) * 0.22;
        bytes = pixels * qFactor;
        if (ultraHdr) bytes *= 1.25; // Gain map adds ~25%
        break;
    }

    if (bytes >= 1024 * 1024) {
      return '~${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '~${(bytes / 1024).round()} KB';
    }
  }

  /// Formats output filename by replacing supported tokens.
  String formatFilename({
    String original = 'photo',
    String preset = 'edit',
    int counter = 1,
    DateTime? date,
    int? outWidth,
    int? outHeight,
  }) {
    final now = date ?? DateTime.now();
    final dateStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    final counterStr = counter.toString().padLeft(3, '0');
    final cleanOriginal = original.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');

    var result = filenamePattern;
    if (result.isEmpty) result = '{original}_{date}';
    result = result.replaceAll('{original}', cleanOriginal);
    result = result.replaceAll('{date}', dateStr);
    result = result.replaceAll('{year}', now.year.toString());
    result = result.replaceAll('{preset}', preset);
    result = result.replaceAll('{counter}', counterStr);
    result = result.replaceAll('{quality}', 'q$quality');
    if (outWidth != null && outHeight != null) {
      result = result.replaceAll('{dimensions}', '${outWidth}x$outHeight');
    } else {
      result = result.replaceAll('{dimensions}', '');
    }
    return result.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }

  ExportSettings copyWith({
    int? quality,
    int? maxDim,
    int? colorSpace,
    bool? ultraHdr,
    double? hdrHeadroom,
    String? filenamePattern,
    ExportResizeMode? resizeMode,
    int? resizeDimension,
    int? resizeWidth,
    int? resizeHeight,
    int? resizePercentage,
    bool? dontEnlarge,
    int? outputSharpenMedia,
    double? outputSharpen,
    ExportMetadataMode? metadataMode,
  }) => ExportSettings(
    quality: quality ?? this.quality,
    maxDim: maxDim ?? this.maxDim,
    colorSpace: colorSpace ?? this.colorSpace,
    ultraHdr: ultraHdr ?? this.ultraHdr,
    hdrHeadroom: hdrHeadroom ?? this.hdrHeadroom,
    filenamePattern: filenamePattern ?? this.filenamePattern,
    resizeMode: resizeMode ?? this.resizeMode,
    resizeDimension: resizeDimension ?? this.resizeDimension,
    resizeWidth: resizeWidth ?? this.resizeWidth,
    resizeHeight: resizeHeight ?? this.resizeHeight,
    resizePercentage: resizePercentage ?? this.resizePercentage,
    dontEnlarge: dontEnlarge ?? this.dontEnlarge,
    outputSharpenMedia: outputSharpenMedia ?? this.outputSharpenMedia,
    outputSharpen: outputSharpen ?? this.outputSharpen,
    metadataMode: metadataMode ?? this.metadataMode,
  );
}

class ExportSettingsNotifier extends Notifier<ExportSettings> {
  static const _qualityKey = 'export_quality';
  static const _maxDimKey = 'export_max_dim';
  static const _colorSpaceKey = 'export_color_space';
  static const _ultraHdrKey = 'export_ultra_hdr';
  static const _hdrHeadroomKey = 'export_hdr_headroom';
  static const _filenamePatternKey = 'export_filename_pattern';
  static const _resizeModeKey = 'export_resize_mode';
  static const _resizeDimensionKey = 'export_resize_dimension';
  static const _dontEnlargeKey = 'export_dont_enlarge';
  static const _sharpenMediaKey = 'export_sharpen_media';
  static const _sharpenAmountKey = 'export_sharpen_amount';
  static const _metadataModeKey = 'export_metadata_mode';
  bool _userSet = false;

  @override
  ExportSettings build() {
    _restore();
    return const ExportSettings();
  }

  void setQuality(int quality) {
    _userSet = true;
    final clamped = quality.clamp(60, 100);
    state = state.copyWith(quality: clamped);
    _persist();
    axLog(LogDomain.export, 'Export quality set to $clamped');
  }

  void setMaxDim(int maxDim) {
    _userSet = true;
    final clamped = maxDim.clamp(0, 100000);
    state = state.copyWith(maxDim: clamped);
    _persist();
    axLog(
      LogDomain.export,
      'Export max dimension set to ${clamped == 0 ? 'Original' : '$clamped px'}',
    );
  }

  void setColorSpace(int colorSpace) {
    _userSet = true;
    state = state.copyWith(colorSpace: colorSpace);
    _persist();
    axLog(
      LogDomain.export,
      'Export color space set to ${colorSpace == 1 ? 'Display-P3 (Wide Gamut)' : 'sRGB'}',
    );
  }

  void setUltraHdr(bool enabled) {
    _userSet = true;
    state = state.copyWith(ultraHdr: enabled);
    _persist();
    axLog(LogDomain.export, 'Export Ultra HDR set to $enabled');
  }

  void setHdrHeadroom(double headroom) {
    _userSet = true;
    final clamped = headroom.clamp(1.0, 4.0);
    state = state.copyWith(hdrHeadroom: clamped);
    _persist();
    axLog(LogDomain.export, 'Export HDR headroom set to +${clamped.toStringAsFixed(1)} EV');
  }

  void setFilenamePattern(String pattern) {
    _userSet = true;
    state = state.copyWith(filenamePattern: pattern.trim());
    _persist();
    axLog(LogDomain.export, 'Export filename pattern set to "$pattern"');
  }

  void setResizeMode(ExportResizeMode mode, {int? dimension, int? width, int? height, int? percentage}) {
    _userSet = true;
    state = state.copyWith(
      resizeMode: mode,
      resizeDimension: dimension ?? state.resizeDimension,
      resizeWidth: width ?? state.resizeWidth,
      resizeHeight: height ?? state.resizeHeight,
      resizePercentage: percentage ?? state.resizePercentage,
    );
    _persist();
  }

  void setDontEnlarge(bool dontEnlarge) {
    _userSet = true;
    state = state.copyWith(dontEnlarge: dontEnlarge);
    _persist();
  }

  void setOutputSharpen({int? media, double? amount}) {
    _userSet = true;
    state = state.copyWith(
      outputSharpenMedia: media ?? state.outputSharpenMedia,
      outputSharpen: amount ?? state.outputSharpen,
    );
    _persist();
  }

  void setMetadataMode(ExportMetadataMode mode) {
    _userSet = true;
    state = state.copyWith(metadataMode: mode);
    _persist();
  }

  void applyPreset(ExportPresetKind preset) {
    _userSet = true;
    switch (preset) {
      case ExportPresetKind.fullRes:
        state = state.copyWith(
          quality: 95,
          maxDim: 0,
          resizeMode: ExportResizeMode.original,
          colorSpace: 0,
          ultraHdr: false,
          outputSharpenMedia: 0,
          metadataMode: ExportMetadataMode.all,
        );
        break;
      case ExportPresetKind.webSocial:
        state = state.copyWith(
          quality: 85,
          maxDim: 2048,
          resizeMode: ExportResizeMode.longEdge,
          resizeDimension: 2048,
          colorSpace: 0,
          ultraHdr: false,
          outputSharpenMedia: 1, // Screen
          outputSharpen: 0.5,
          metadataMode: ExportMetadataMode.copyrightOnly,
        );
        break;
      case ExportPresetKind.printLossless:
        state = state.copyWith(
          quality: 100,
          maxDim: 0,
          resizeMode: ExportResizeMode.original,
          colorSpace: 0,
          ultraHdr: false,
          outputSharpenMedia: 2, // Matte paper
          outputSharpen: 0.6,
          metadataMode: ExportMetadataMode.all,
        );
        break;
      case ExportPresetKind.clientProof:
        state = state.copyWith(
          quality: 75,
          maxDim: 1600,
          resizeMode: ExportResizeMode.longEdge,
          resizeDimension: 1600,
          colorSpace: 0,
          ultraHdr: false,
          outputSharpenMedia: 1,
          outputSharpen: 0.3,
          metadataMode: ExportMetadataMode.none,
        );
        break;
      case ExportPresetKind.proDisplay:
        state = state.copyWith(
          quality: 95,
          maxDim: 0,
          resizeMode: ExportResizeMode.original,
          colorSpace: 1,
          ultraHdr: true,
          hdrHeadroom: 2.0,
          outputSharpenMedia: 0,
          metadataMode: ExportMetadataMode.all,
        );
        break;
    }
    _persist();
    axLog(LogDomain.export, 'Applied export preset "${preset.title}"');
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_userSet) return;
      final modeIndex = prefs.getInt(_resizeModeKey);
      final metaIndex = prefs.getInt(_metadataModeKey);
      state = ExportSettings(
        quality: prefs.getInt(_qualityKey) ?? 90,
        maxDim: prefs.getInt(_maxDimKey) ?? 0,
        colorSpace: prefs.getInt(_colorSpaceKey) ?? 0,
        ultraHdr: prefs.getBool(_ultraHdrKey) ?? false,
        hdrHeadroom: prefs.getDouble(_hdrHeadroomKey) ?? 2.0,
        filenamePattern:
            prefs.getString(_filenamePatternKey) ?? '{original}_{date}',
        resizeMode: modeIndex != null && modeIndex < ExportResizeMode.values.length
            ? ExportResizeMode.values[modeIndex]
            : ExportResizeMode.original,
        resizeDimension: prefs.getInt(_resizeDimensionKey) ?? 2048,
        dontEnlarge: prefs.getBool(_dontEnlargeKey) ?? true,
        outputSharpenMedia: prefs.getInt(_sharpenMediaKey) ?? 0,
        outputSharpen: prefs.getDouble(_sharpenAmountKey) ?? 0.0,
        metadataMode: metaIndex != null && metaIndex < ExportMetadataMode.values.length
            ? ExportMetadataMode.values[metaIndex]
            : ExportMetadataMode.all,
      );
    } catch (_) {
      // No storage available (e.g. tests) — keep defaults.
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_qualityKey, state.quality);
      await prefs.setInt(_maxDimKey, state.maxDim);
      await prefs.setInt(_colorSpaceKey, state.colorSpace);
      await prefs.setBool(_ultraHdrKey, state.ultraHdr);
      await prefs.setDouble(_hdrHeadroomKey, state.hdrHeadroom);
      await prefs.setString(_filenamePatternKey, state.filenamePattern);
      await prefs.setInt(_resizeModeKey, state.resizeMode.index);
      await prefs.setInt(_resizeDimensionKey, state.resizeDimension);
      await prefs.setBool(_dontEnlargeKey, state.dontEnlarge);
      await prefs.setInt(_sharpenMediaKey, state.outputSharpenMedia);
      await prefs.setDouble(_sharpenAmountKey, state.outputSharpen);
      await prefs.setInt(_metadataModeKey, state.metadataMode.index);
    } catch (_) {
      // best effort
    }
  }
}

final exportSettingsProvider =
    NotifierProvider<ExportSettingsNotifier, ExportSettings>(
      ExportSettingsNotifier.new,
    );
