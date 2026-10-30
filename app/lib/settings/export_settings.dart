import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/log/activity_log.dart';
import '../core/log/log_providers.dart';

/// Named export preset for quick 1-tap configuration (Phase 1 Pro export presets).
enum ExportPresetKind {
  fullRes('Full Res JPEG', 'Original size, JPEG 92%, sRGB'),
  webSocial('Web & Social', 'Max 2048px, JPEG 85%, sRGB'),
  printLossless('Print / Lossless', 'Full resolution, Lossless PNG or 16-bit TIFF'),
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

  /// Formats output filename by replacing supported tokens.
  String formatFilename({
    String original = 'photo',
    String preset = 'edit',
    int counter = 1,
    DateTime? date,
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
    result = result.replaceAll('{preset}', preset);
    result = result.replaceAll('{counter}', counterStr);
    return result.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }

  ExportSettings copyWith({
    int? quality,
    int? maxDim,
    int? colorSpace,
    bool? ultraHdr,
    double? hdrHeadroom,
    String? filenamePattern,
  }) => ExportSettings(
    quality: quality ?? this.quality,
    maxDim: maxDim ?? this.maxDim,
    colorSpace: colorSpace ?? this.colorSpace,
    ultraHdr: ultraHdr ?? this.ultraHdr,
    hdrHeadroom: hdrHeadroom ?? this.hdrHeadroom,
    filenamePattern: filenamePattern ?? this.filenamePattern,
  );
}

class ExportSettingsNotifier extends Notifier<ExportSettings> {
  static const _qualityKey = 'export_quality';
  static const _maxDimKey = 'export_max_dim';
  static const _colorSpaceKey = 'export_color_space';
  static const _ultraHdrKey = 'export_ultra_hdr';
  static const _hdrHeadroomKey = 'export_hdr_headroom';
  static const _filenamePatternKey = 'export_filename_pattern';
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

  void applyPreset(ExportPresetKind preset) {
    _userSet = true;
    switch (preset) {
      case ExportPresetKind.fullRes:
        state = state.copyWith(
          quality: 92,
          maxDim: 0,
          colorSpace: 0,
          ultraHdr: false,
        );
        break;
      case ExportPresetKind.webSocial:
        state = state.copyWith(
          quality: 85,
          maxDim: 2048,
          colorSpace: 0,
          ultraHdr: false,
        );
        break;
      case ExportPresetKind.printLossless:
        state = state.copyWith(
          quality: 100,
          maxDim: 0,
          colorSpace: 0,
          ultraHdr: false,
        );
        break;
      case ExportPresetKind.proDisplay:
        state = state.copyWith(
          quality: 95,
          maxDim: 0,
          colorSpace: 1,
          ultraHdr: true,
          hdrHeadroom: 2.0,
        );
        break;
    }
    _persist();
    axLog(LogDomain.export, 'Applied export preset "${preset.title}"');
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_userSet) return; // never clobber a choice made during startup
      state = ExportSettings(
        quality: prefs.getInt(_qualityKey) ?? 90,
        maxDim: prefs.getInt(_maxDimKey) ?? 0,
        colorSpace: prefs.getInt(_colorSpaceKey) ?? 0,
        ultraHdr: prefs.getBool(_ultraHdrKey) ?? false,
        hdrHeadroom: prefs.getDouble(_hdrHeadroomKey) ?? 2.0,
        filenamePattern:
            prefs.getString(_filenamePatternKey) ?? '{original}_{date}',
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
    } catch (_) {
      // best effort
    }
  }
}

final exportSettingsProvider =
    NotifierProvider<ExportSettingsNotifier, ExportSettings>(
      ExportSettingsNotifier.new,
    );
