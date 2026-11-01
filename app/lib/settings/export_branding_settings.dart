import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../src/rust/api/export.dart';

/// Predefined watermark presets for quick 1-tap professional styling.
enum WatermarkPreset {
  minimalWhite('Minimal Clean (White)', 'Subtle signature in bottom right corner'),
  goldStudio('Gold Fine Art', 'Warm metallic gold signature with anti-halation shadow'),
  matteDark('Matte Dark Corner', 'Charcoal text for bright high-key photography'),
  clientProof('Client Proof (Tiled)', 'Repetitive diagonal watermark across frame'),
  museumMat('Exhibition Museum Mat', 'Gallery border with camera & exposure typography');

  const WatermarkPreset(this.title, this.description);
  final String title;
  final String description;
}

/// Immutable model representing watermark, signature, museum frame, tiled proof, and C2PA export options.
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
    this.signatureInsetPct = 3.0,
    this.signatureColor = 0, // 0 = White, 1 = Black, 2 = Ivory, 3 = Gold
    this.signatureDropShadow = true,
    this.enableLogo = false,
    this.logoBytes,
    this.logoPath,
    this.logoAnchorIndex = 8,
    this.logoOpacity = 0.8,
    this.logoScalePct = 10.0,
    this.logoInsetPct = 3.0,
    this.enableTiledWatermark = false,
    this.tiledText = 'PROOF - DO NOT COPY',
    this.tiledOpacity = 0.25,
    this.tiledSizePct = 3.0,
    this.tiledSpacingPct = 30.0,
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
  final double signatureInsetPct;
  final int signatureColor;
  final bool signatureDropShadow;

  final bool enableLogo;
  final Uint8List? logoBytes;
  final String? logoPath;
  final int logoAnchorIndex;
  final double logoOpacity;
  final double logoScalePct;
  final double logoInsetPct;

  final bool enableTiledWatermark;
  final String tiledText;
  final double tiledOpacity;
  final double tiledSizePct;
  final double tiledSpacingPct;

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
    double? signatureInsetPct,
    int? signatureColor,
    bool? signatureDropShadow,
    bool? enableLogo,
    Uint8List? logoBytes,
    String? logoPath,
    int? logoAnchorIndex,
    double? logoOpacity,
    double? logoScalePct,
    double? logoInsetPct,
    bool? enableTiledWatermark,
    String? tiledText,
    double? tiledOpacity,
    double? tiledSizePct,
    double? tiledSpacingPct,
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
      signatureInsetPct: signatureInsetPct ?? this.signatureInsetPct,
      signatureColor: signatureColor ?? this.signatureColor,
      signatureDropShadow: signatureDropShadow ?? this.signatureDropShadow,
      enableLogo: enableLogo ?? this.enableLogo,
      logoBytes: logoBytes ?? this.logoBytes,
      logoPath: logoPath ?? this.logoPath,
      logoAnchorIndex: logoAnchorIndex ?? this.logoAnchorIndex,
      logoOpacity: logoOpacity ?? this.logoOpacity,
      logoScalePct: logoScalePct ?? this.logoScalePct,
      logoInsetPct: logoInsetPct ?? this.logoInsetPct,
      enableTiledWatermark: enableTiledWatermark ?? this.enableTiledWatermark,
      tiledText: tiledText ?? this.tiledText,
      tiledOpacity: tiledOpacity ?? this.tiledOpacity,
      tiledSizePct: tiledSizePct ?? this.tiledSizePct,
      tiledSpacingPct: tiledSpacingPct ?? this.tiledSpacingPct,
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
      signatureInsetPct: signatureInsetPct,
      signatureColor: signatureColor,
      signatureDropShadow: signatureDropShadow,
      enableLogo: enableLogo,
      logoBytes: logoBytes ?? Uint8List(0),
      logoAnchor: logoAnchorIndex,
      logoOpacity: logoOpacity,
      logoScalePct: logoScalePct,
      logoInsetPct: logoInsetPct,
      enableTiledWatermark: enableTiledWatermark,
      tiledText: tiledText,
      tiledOpacity: tiledOpacity,
      tiledSizePct: tiledSizePct,
      tiledSpacingPct: tiledSpacingPct,
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
        signatureInsetPct: prefs.getDouble('branding_signature_inset') ?? 3.0,
        signatureColor: prefs.getInt('branding_signature_color') ?? 0,
        signatureDropShadow: prefs.getBool('branding_signature_shadow') ?? true,
        enableLogo: prefs.getBool('branding_logo_enabled') ?? false,
        logoOpacity: prefs.getDouble('branding_logo_opacity') ?? 0.8,
        logoScalePct: prefs.getDouble('branding_logo_scale') ?? 10.0,
        logoAnchorIndex: prefs.getInt('branding_logo_anchor') ?? 8,
        logoInsetPct: prefs.getDouble('branding_logo_inset') ?? 3.0,
        logoPath: prefs.getString('branding_logo_path'),
        enableTiledWatermark: prefs.getBool('branding_tiled_enabled') ?? false,
        tiledText: prefs.getString('branding_tiled_text') ?? 'PROOF - DO NOT COPY',
        tiledOpacity: prefs.getDouble('branding_tiled_opacity') ?? 0.25,
        enableFossBadge: prefs.getBool('branding_foss_badge') ?? false,
        enableC2pa: prefs.getBool('branding_c2pa_enabled') ?? true,
        quality: prefs.getInt('export_quality') ?? 92,
      );

      final savedLogoPath = prefs.getString('branding_logo_path');
      if (savedLogoPath != null && savedLogoPath.isNotEmpty) {
        final file = File(savedLogoPath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          state = state.copyWith(logoBytes: bytes);
        }
      }
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
      frameThemeIndex: themeIndex ?? state.frameThemeIndex,
      exifLine1: line1 ?? state.exifLine1,
      exifLine2: line2 ?? state.exifLine2,
    );
    _persist();
  }

  void setSignature({
    required bool enabled,
    String? text,
    int? anchorIndex,
    double? opacity,
    double? sizePct,
    double? insetPct,
    int? color,
    bool? dropShadow,
  }) {
    state = state.copyWith(
      enableSignature: enabled,
      signatureText: text ?? state.signatureText,
      signatureAnchorIndex: anchorIndex ?? state.signatureAnchorIndex,
      signatureOpacity: opacity ?? state.signatureOpacity,
      signatureSizePct: sizePct ?? state.signatureSizePct,
      signatureInsetPct: insetPct ?? state.signatureInsetPct,
      signatureColor: color ?? state.signatureColor,
      signatureDropShadow: dropShadow ?? state.signatureDropShadow,
    );
    _persist();
  }

  void setLogo({
    required bool enabled,
    Uint8List? bytes,
    String? path,
    int? anchorIndex,
    double? opacity,
    double? scalePct,
    double? insetPct,
  }) {
    state = state.copyWith(
      enableLogo: enabled,
      logoBytes: bytes ?? state.logoBytes,
      logoPath: path ?? state.logoPath,
      logoAnchorIndex: anchorIndex ?? state.logoAnchorIndex,
      logoOpacity: opacity ?? state.logoOpacity,
      logoScalePct: scalePct ?? state.logoScalePct,
      logoInsetPct: insetPct ?? state.logoInsetPct,
    );
    _persist();
  }

  void clearLogo() {
    state = state.copyWith(
      enableLogo: false,
      logoBytes: Uint8List(0),
      logoPath: '',
    );
    _persist();
  }

  void setTiledWatermark({
    required bool enabled,
    String? text,
    double? opacity,
    double? sizePct,
    double? spacingPct,
  }) {
    state = state.copyWith(
      enableTiledWatermark: enabled,
      tiledText: text ?? state.tiledText,
      tiledOpacity: opacity ?? state.tiledOpacity,
      tiledSizePct: sizePct ?? state.tiledSizePct,
      tiledSpacingPct: spacingPct ?? state.tiledSpacingPct,
    );
    _persist();
  }

  void applyWatermarkPreset(WatermarkPreset preset) {
    switch (preset) {
      case WatermarkPreset.minimalWhite:
        state = state.copyWith(
          enableSignature: true,
          enableMuseumFrame: false,
          enableTiledWatermark: false,
          signatureColor: 0,
          signatureAnchorIndex: 8,
          signatureOpacity: 0.8,
          signatureSizePct: 2.5,
          signatureInsetPct: 3.0,
          signatureDropShadow: true,
        );
        break;
      case WatermarkPreset.goldStudio:
        state = state.copyWith(
          enableSignature: true,
          enableMuseumFrame: false,
          enableTiledWatermark: false,
          signatureColor: 3, // Gold
          signatureAnchorIndex: 8,
          signatureOpacity: 0.9,
          signatureSizePct: 3.0,
          signatureInsetPct: 3.5,
          signatureDropShadow: true,
        );
        break;
      case WatermarkPreset.matteDark:
        state = state.copyWith(
          enableSignature: true,
          enableMuseumFrame: false,
          enableTiledWatermark: false,
          signatureColor: 1, // Black
          signatureAnchorIndex: 8,
          signatureOpacity: 0.75,
          signatureSizePct: 2.5,
          signatureInsetPct: 3.0,
          signatureDropShadow: false,
        );
        break;
      case WatermarkPreset.clientProof:
        state = state.copyWith(
          enableTiledWatermark: true,
          enableSignature: false,
          enableMuseumFrame: false,
          tiledText: 'PROOF - DO NOT COPY',
          tiledOpacity: 0.25,
          tiledSpacingPct: 28.0,
        );
        break;
      case WatermarkPreset.museumMat:
        state = state.copyWith(
          enableMuseumFrame: true,
          enableSignature: false,
          enableTiledWatermark: false,
          frameThemeIndex: 0,
        );
        break;
    }
    _persist();
  }

  void setFossBadge(bool enabled) {
    state = state.copyWith(enableFossBadge: enabled);
    _persist();
  }

  void setC2pa(bool enabled) {
    state = state.copyWith(enableC2pa: enabled);
    _persist();
  }

  void setFormat(String format) {
    state = state.copyWith(format: format);
    _persist();
  }

  void setQuality(int quality) {
    state = state.copyWith(quality: quality);
    _persist();
  }

  void setMaxDim(int maxDim) {
    state = state.copyWith(maxDim: maxDim);
    _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('branding_museum_frame', state.enableMuseumFrame);
      await prefs.setInt('branding_frame_theme', state.frameThemeIndex);
      await prefs.setBool('branding_signature_enabled', state.enableSignature);
      await prefs.setString('branding_signature_text', state.signatureText);
      await prefs.setDouble('branding_signature_opacity', state.signatureOpacity);
      await prefs.setInt('branding_signature_anchor', state.signatureAnchorIndex);
      await prefs.setDouble('branding_signature_inset', state.signatureInsetPct);
      await prefs.setInt('branding_signature_color', state.signatureColor);
      await prefs.setBool('branding_signature_shadow', state.signatureDropShadow);
      await prefs.setBool('branding_logo_enabled', state.enableLogo);
      await prefs.setDouble('branding_logo_opacity', state.logoOpacity);
      await prefs.setDouble('branding_logo_scale', state.logoScalePct);
      await prefs.setInt('branding_logo_anchor', state.logoAnchorIndex);
      await prefs.setDouble('branding_logo_inset', state.logoInsetPct);
      if (state.logoPath != null) {
        await prefs.setString('branding_logo_path', state.logoPath!);
      }
      await prefs.setBool('branding_tiled_enabled', state.enableTiledWatermark);
      await prefs.setString('branding_tiled_text', state.tiledText);
      await prefs.setDouble('branding_tiled_opacity', state.tiledOpacity);
      await prefs.setBool('branding_foss_badge', state.enableFossBadge);
      await prefs.setBool('branding_c2pa_enabled', state.enableC2pa);
      await prefs.setInt('export_quality', state.quality);
    } catch (_) {}
  }
}

/// Global provider for export branding and watermark settings.
final exportBrandingProvider =
    NotifierProvider<ExportBrandingNotifier, ExportBrandingSettings>(
  ExportBrandingNotifier.new,
);
