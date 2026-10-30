import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Supported target color spaces and printer profiles for soft proofing (#12).
enum ProofProfile {
  /// Standard sRGB (IEC 61966-2-1) web/mobile default.
  sRGB,

  /// Apple Display P3 / DCI-P3 wide-gamut profile.
  displayP3,

  /// Adobe RGB (1998) photography wide-gamut profile.
  adobeRgb,

  /// Commercial offset sheetfed press (US Web Coated SWOP v2) CMYK simulation.
  cmykSwop;

  String get displayName => switch (this) {
    ProofProfile.sRGB => 'sRGB (Web & Mobile)',
    ProofProfile.displayP3 => 'Display P3 (Wide Gamut)',
    ProofProfile.adobeRgb => 'Adobe RGB (1998)',
    ProofProfile.cmykSwop => 'US Web Coated SWOP (CMYK Print)',
  };
}

/// Rendering intent for gamut mapping.
enum ProofIntent {
  /// Compresses out-of-gamut colors smoothly, preserving proportional relationships.
  perceptual,

  /// Preserves in-gamut colors exactly and clips out-of-gamut colors to the border.
  relativeColorimetric;

  String get displayName => switch (this) {
    ProofIntent.perceptual => 'Perceptual',
    ProofIntent.relativeColorimetric => 'Relative Colorimetric',
  };
}

/// State controlling soft proofing preview and out-of-gamut warnings.
class SoftProofState {
  const SoftProofState({
    this.enabled = false,
    this.profile = ProofProfile.cmykSwop,
    this.intent = ProofIntent.relativeColorimetric,
    this.simulatePaperAndInk = true,
    this.gamutWarning = false,
    this.warningColor = const Color(0xFF00E5FF), // High-visibility bright cyan
  });

  /// Whether soft proofing is active on the image viewport.
  final bool enabled;

  /// The target output device/print profile being simulated.
  final ProofProfile profile;

  /// Rendering intent used for out-of-gamut mapping.
  final ProofIntent intent;

  /// Simulates matte/uncoated paper white point and ink DMax black point limitation.
  final bool simulatePaperAndInk;

  /// Whether out-of-gamut pixels are highlighted with [warningColor].
  final bool gamutWarning;

  /// False color used to highlight out-of-gamut regions when [gamutWarning] is true.
  final Color warningColor;

  SoftProofState copyWith({
    bool? enabled,
    ProofProfile? profile,
    ProofIntent? intent,
    bool? simulatePaperAndInk,
    bool? gamutWarning,
    Color? warningColor,
  }) {
    return SoftProofState(
      enabled: enabled ?? this.enabled,
      profile: profile ?? this.profile,
      intent: intent ?? this.intent,
      simulatePaperAndInk: simulatePaperAndInk ?? this.simulatePaperAndInk,
      gamutWarning: gamutWarning ?? this.gamutWarning,
      warningColor: warningColor ?? this.warningColor,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SoftProofState &&
          runtimeType == other.runtimeType &&
          enabled == other.enabled &&
          profile == other.profile &&
          intent == other.intent &&
          simulatePaperAndInk == other.simulatePaperAndInk &&
          gamutWarning == other.gamutWarning &&
          warningColor == other.warningColor;

  @override
  int get hashCode => Object.hash(
        enabled,
        profile,
        intent,
        simulatePaperAndInk,
        gamutWarning,
        warningColor,
      );
}

/// Riverpod notifier for Soft Proofing configuration.
class SoftProofingNotifier extends Notifier<SoftProofState> {
  @override
  SoftProofState build() => const SoftProofState();

  void toggleEnabled() {
    state = state.copyWith(enabled: !state.enabled);
  }

  void setEnabled(bool enabled) {
    state = state.copyWith(enabled: enabled);
  }

  void setProfile(ProofProfile profile) {
    state = state.copyWith(profile: profile);
  }

  void setIntent(ProofIntent intent) {
    state = state.copyWith(intent: intent);
  }

  void togglePaperAndInk() {
    state = state.copyWith(simulatePaperAndInk: !state.simulatePaperAndInk);
  }

  void toggleGamutWarning() {
    state = state.copyWith(gamutWarning: !state.gamutWarning);
  }
}

final softProofingProvider =
    NotifierProvider<SoftProofingNotifier, SoftProofState>(
  SoftProofingNotifier.new,
);

/// Color science math for proof profile gamut verification and simulation.
class SoftProofMath {
  /// Checks whether a normalized sRGB triple (0.0..1.0) exceeds the gamut of [profile].
  static bool isOutOfGamut(
    double r,
    double g,
    double b,
    ProofProfile profile,
  ) {
    switch (profile) {
      case ProofProfile.displayP3:
      case ProofProfile.adobeRgb:
        // Any standard sRGB pixel is within Display P3 and Adobe RGB
        return false;
      case ProofProfile.sRGB:
        // Check for boundary clipping
        return r < 0.0 || r > 1.0 || g < 0.0 || g > 1.0 || b < 0.0 || b > 1.0;
      case ProofProfile.cmykSwop:
        // CMYK SWOP has a significantly smaller gamut than sRGB in vibrant cyans,
        // saturated greens (500-530nm), and deep blues.
        final c = 1.0 - r;
        final m = 1.0 - g;
        final y = 1.0 - b;
        final k = math.min(c, math.min(m, y));

        // Total Ink Limit (TAC) for SWOP is ~300%
        final double cyan = k == 1.0 ? 0.0 : (c - k) / (1.0 - k);
        final double magenta = k == 1.0 ? 0.0 : (m - k) / (1.0 - k);
        final double yellow = k == 1.0 ? 0.0 : (y - k) / (1.0 - k);
        final totalAreaCoverage = (cyan + magenta + yellow + k) * 100.0;

        // Vivid greens and saturated electric cyans/blues cannot be printed on CMYK SWOP
        final isVividGreen = g > 0.85 && (r < 0.35 || b < 0.35);
        final isVividCyan = (b > 0.85 && g > 0.80) && r < 0.25;
        final isDeepSaturatedBlue = b > 0.80 && r < 0.20 && g < 0.20;

        return totalAreaCoverage > 300.0 || isVividGreen || isVividCyan || isDeepSaturatedBlue;
    }
  }

  /// Transforms an sRGB color (0.0..1.0) to simulated proof color output.
  static ({double r, double g, double b}) simulateProof(
    double r,
    double g,
    double b,
    SoftProofState proof,
  ) {
    if (!proof.enabled) {
      return (r: r, g: g, b: b);
    }

    double pr = r;
    double pg = g;
    double pb = b;

    if (proof.profile == ProofProfile.cmykSwop) {
      // CMYK Gamut compression
      if (proof.intent == ProofIntent.perceptual) {
        // Soft-knee compression of saturated chroma
        final maxC = math.max(pr, math.max(pg, pb));
        if (maxC > 0.85) {
          final factor = 0.85 + (maxC - 0.85) * 0.6;
          pr = (pr / maxC) * factor;
          pg = (pg / maxC) * factor;
          pb = (pb / maxC) * factor;
        }
      } else {
        // Relative Colorimetric: clip to printable boundaries
        if (pr > 0.95 && pg > 0.95 && pb < 0.1) {
          // Pure yellow clip
          pr = 0.92;
          pg = 0.90;
        }
        if (pg > 0.88 && pr < 0.3) {
          // Green gamut clip
          pg = 0.82;
        }
      }

      if (proof.simulatePaperAndInk) {
        // SWOP paper white tint (warm off-white) and ink black floor (~6% DMax reflection)
        const paperBlack = 0.055;
        const paperWhiteR = 0.985;
        const paperWhiteG = 0.980;
        const paperWhiteB = 0.965;

        pr = paperBlack + pr * (paperWhiteR - paperBlack);
        pg = paperBlack + pg * (paperWhiteG - paperBlack);
        pb = paperBlack + pb * (paperWhiteB - paperBlack);
      }
    }

    return (
      r: pr.clamp(0.0, 1.0),
      g: pg.clamp(0.0, 1.0),
      b: pb.clamp(0.0, 1.0),
    );
  }
}
