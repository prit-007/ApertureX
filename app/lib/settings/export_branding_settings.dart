import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../src/rust/api/export.dart';

/// Immutable model representing watermark, signature, museum frame, and C2PA export options.
class ExportBrandingSettings {

  const ExportBrandingSettings({
    this.enableMuseumFrame = false,
    this.frameThemeIndex = 0,
    this.exifLine1 = '',
    this.exifLine2 = '',
    this.enableSignature = false,
    this.signatureText = '',
    this.signatureAnchorIndex = 8, // BottomRight
    this.signatureOpacity = 0.8,
    this.signatureSizePct = 2.5,
    this.enableLogo = false,
    this.logoBytes,
    this.logoAnchorIndex = 8,
    this.logoOpacity = 0.8,
    this.logoScalePct = 10.0,
    this.enableFossBadge = false,
    this.enableC2pa = true,
    this.format = 'jpeg',
    this.quality = 92,
    this.maxDim = 0,
  });
  final bool enableMuseumFrame;
  final int frameThemeIndex; // 0 = StudioWhite, 1 = MatteDark, 2 = WarmGallery
  final String exifLine1;
  final String exifLine2;

  final bool enableSignature;
  final String signatureText;
  final int signatureAnchorIndex; // 0..8
  final double signatureOpacity;
  final double signatureSizePct;

  final bool enableLogo;
  final Uint8List? logoBytes;
  final int logoAnchorIndex;
  final double logoOpacity;
  final double logoScalePct;

  final bool enableFossBadge;
  final bool enableC2pa;

  final String format; // 'jpeg', 'dng', 'png', 'tiff'
  final int quality;
  final int maxDim;

  ExportBrandingSettings copyWith({
    bool? enableMuseumFrame,
    int? frameThemeIndex,
    String? exifLine1,
    String? exifLine2,
    bool? enableSignature,
    String? signatureText,
    int? signatureAnchorIndex,
    double? signatureOpacity,
    double? signatureSizePct,
    bool? enableLogo,
    Uint8List? logoBytes,
    int? logoAnchorIndex,
    double? logoOpacity,
    double? logoScalePct,
    bool? enableFossBadge,
    bool? enableC2pa,
    String? format,
    int? quality,
    int? maxDim,
  }) {
    return ExportBrandingSettings(
      enableMuseumFrame: enableMuseumFrame ?? this.enableMuseumFrame,
      frameThemeIndex: frameThemeIndex ?? this.frameThemeIndex,
      exifLine1: exifLine1 ?? this.exifLine1,
      exifLine2: exifLine2 ?? this.exifLine2,
      enableSignature: enableSignature ?? this.enableSignature,
      signatureText: signatureText ?? this.signatureText,
      signatureAnchorIndex: signatureAnchorIndex ?? this.signatureAnchorIndex,
      signatureOpacity: signatureOpacity ?? this.signatureOpacity,
      signatureSizePct: signatureSizePct ?? this.signatureSizePct,
      enableLogo: enableLogo ?? this.enableLogo,
      logoBytes: logoBytes ?? this.logoBytes,
      logoAnchorIndex: logoAnchorIndex ?? this.logoAnchorIndex,
      logoOpacity: logoOpacity ?? this.logoOpacity,
      logoScalePct: logoScalePct ?? this.logoScalePct,
      enableFossBadge: enableFossBadge ?? this.enableFossBadge,
      enableC2pa: enableC2pa ?? this.enableC2pa,
      format: format ?? this.format,
      quality: quality ?? this.quality,
      maxDim: maxDim ?? this.maxDim,
    );
  }

  /// Converts this configuration to the Rust bridge spec.
  ExportBrandingSpec toRustBrandingSpec() {
    return ExportBrandingSpec(
      enableMuseumFrame: enableMuseumFrame,
      frameTheme: frameThemeIndex,
      exifLine1: exifLine1,
      exifLine2: exifLine2,
      enableSignature: enableSignature,
      signatureText: signatureText,
      signatureAnchor: signatureAnchorIndex,
      signatureOpacity: signatureOpacity,
      signatureSizePct: signatureSizePct,
      enableLogo: enableLogo,
      logoBytes: logoBytes ?? Uint8List(0),
      logoAnchor: logoAnchorIndex,
      logoOpacity: logoOpacity,
      logoScalePct: logoScalePct,
      enableFossBadge: enableFossBadge,
    );
  }
}

/// Notifier managing user export preferences and branding defaults.
class ExportBrandingNotifier extends Notifier<ExportBrandingSettings> {
  @override
  ExportBrandingSettings build() {
    _loadPreferences();
    return const ExportBrandingSettings();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = state.copyWith(
        enableMuseumFrame: prefs.getBool('branding_museum_frame') ?? false,
        frameThemeIndex: prefs.getInt('branding_frame_theme') ?? 0,
        enableSignature: prefs.getBool('branding_signature_enabled') ?? false,
        signatureText: prefs.getString('branding_signature_text') ?? '',
        signatureOpacity: prefs.getDouble('branding_signature_opacity') ?? 0.8,
        signatureAnchorIndex: prefs.getInt('branding_signature_anchor') ?? 8,
        enableFossBadge: prefs.getBool('branding_foss_badge') ?? false,
        enableC2pa: prefs.getBool('branding_c2pa_enabled') ?? true,
        quality: prefs.getInt('export_quality') ?? 92,
      );
    } catch (_) {}
  }

  void setMuseumFrame({
    required bool enabled,
    int? themeIndex,
    String? line1,
    String? line2,
  }) {
    state = state.copyWith(
      enableMuseumFrame: enabled,
      frameThemeIndex: themeIndex,
      exifLine1: line1,
      exifLine2: line2,
    );
    SharedPreferences.getInstance().then((p) {
      p.setBool('branding_museum_frame', enabled);
      if (themeIndex != null) p.setInt('branding_frame_theme', themeIndex);
    });
  }

  void setSignature({
    required bool enabled,
    String? text,
    int? anchorIndex,
    double? opacity,
    double? sizePct,
  }) {
    state = state.copyWith(
      enableSignature: enabled,
      signatureText: text,
      signatureAnchorIndex: anchorIndex,
      signatureOpacity: opacity,
      signatureSizePct: sizePct,
    );
    SharedPreferences.getInstance().then((p) {
      p.setBool('branding_signature_enabled', enabled);
      if (text != null) p.setString('branding_signature_text', text);
      if (opacity != null) p.setDouble('branding_signature_opacity', opacity);
      if (anchorIndex != null) p.setInt('branding_signature_anchor', anchorIndex);
    });
  }

  void setLogo({
    required bool enabled,
    Uint8List? bytes,
    int? anchorIndex,
    double? opacity,
    double? scalePct,
  }) {
    state = state.copyWith(
      enableLogo: enabled,
      logoBytes: bytes,
      logoAnchorIndex: anchorIndex,
      logoOpacity: opacity,
      logoScalePct: scalePct,
    );
  }

  void setFossBadge(bool enabled) {
    state = state.copyWith(enableFossBadge: enabled);
    SharedPreferences.getInstance().then((p) {
      p.setBool('branding_foss_badge', enabled);
    });
  }

  void setC2pa(bool enabled) {
    state = state.copyWith(enableC2pa: enabled);
    SharedPreferences.getInstance().then((p) {
      p.setBool('branding_c2pa_enabled', enabled);
    });
  }

  void setFormat(String format) {
    state = state.copyWith(format: format);
  }

  void setQuality(int quality) {
    state = state.copyWith(quality: quality);
    SharedPreferences.getInstance().then((p) {
      p.setInt('export_quality', quality);
    });
  }

  void setMaxDim(int maxDim) {
    state = state.copyWith(maxDim: maxDim);
  }
}

/// Global Riverpod provider for export branding settings.
final exportBrandingProvider =
    NotifierProvider<ExportBrandingNotifier, ExportBrandingSettings>(
  ExportBrandingNotifier.new,
);
