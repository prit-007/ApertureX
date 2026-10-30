import 'package:aperturex/viewport/soft_proofing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SoftProofState & SoftProofingNotifier', () {
    test('default state has soft proofing disabled and SWOP CMYK default', () {
      const state = SoftProofState();
      expect(state.enabled, isFalse);
      expect(state.profile, ProofProfile.cmykSwop);
      expect(state.intent, ProofIntent.relativeColorimetric);
      expect(state.simulatePaperAndInk, isTrue);
      expect(state.gamutWarning, isFalse);
    });

    test('notifier transitions update state cleanly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(softProofingProvider.notifier);
      expect(container.read(softProofingProvider).enabled, isFalse);

      notifier.toggleEnabled();
      expect(container.read(softProofingProvider).enabled, isTrue);

      notifier.setProfile(ProofProfile.displayP3);
      expect(container.read(softProofingProvider).profile, ProofProfile.displayP3);

      notifier.setIntent(ProofIntent.perceptual);
      expect(container.read(softProofingProvider).intent, ProofIntent.perceptual);

      notifier.toggleGamutWarning();
      expect(container.read(softProofingProvider).gamutWarning, isTrue);

      notifier.togglePaperAndInk();
      expect(container.read(softProofingProvider).simulatePaperAndInk, isFalse);
    });
  });

  group('SoftProofMath Gamut Checking', () {
    test('neutral and moderate colors fall within CMYK SWOP gamut', () {
      // 50% middle gray
      expect(
        SoftProofMath.isOutOfGamut(0.5, 0.5, 0.5, ProofProfile.cmykSwop),
        isFalse,
      );
      // Typical warm skin tone (r=0.8, g=0.6, b=0.45)
      expect(
        SoftProofMath.isOutOfGamut(0.8, 0.6, 0.45, ProofProfile.cmykSwop),
        isFalse,
      );
    });

    test('extreme electric cyan and vivid green trigger out-of-gamut in CMYK SWOP', () {
      // Electric cyan (r=0.0, g=0.95, b=0.95)
      expect(
        SoftProofMath.isOutOfGamut(0.0, 0.95, 0.95, ProofProfile.cmykSwop),
        isTrue,
      );

      // Saturated laser green (r=0.1, g=0.95, b=0.1)
      expect(
        SoftProofMath.isOutOfGamut(0.1, 0.95, 0.1, ProofProfile.cmykSwop),
        isTrue,
      );
    });

    test('wide-gamut targets (Display P3, Adobe RGB) encompass standard sRGB range', () {
      expect(
        SoftProofMath.isOutOfGamut(0.9, 0.1, 0.1, ProofProfile.displayP3),
        isFalse,
      );
      expect(
        SoftProofMath.isOutOfGamut(0.1, 0.9, 0.1, ProofProfile.adobeRgb),
        isFalse,
      );
    });
  });

  group('SoftProofMath Simulation', () {
    test('disabled proofing returns exact input RGB', () {
      const state = SoftProofState(enabled: false);
      final out = SoftProofMath.simulateProof(0.2, 0.4, 0.6, state);
      expect(out.r, closeTo(0.2, 1e-4));
      expect(out.g, closeTo(0.4, 1e-4));
      expect(out.b, closeTo(0.6, 1e-4));
    });

    test('paper & ink simulation elevates black point DMax and tints white', () {
      const state = SoftProofState(
        enabled: true,
        profile: ProofProfile.cmykSwop,
        simulatePaperAndInk: true,
      );

      // Pure black (0,0,0) in input should have non-zero black floor in print proof
      final blackProof = SoftProofMath.simulateProof(0.0, 0.0, 0.0, state);
      expect(blackProof.r, greaterThan(0.05));
      expect(blackProof.g, greaterThan(0.05));
      expect(blackProof.b, greaterThan(0.05));

      // Pure white (1,1,1) in input should reflect paper warm white (< 1.0)
      final whiteProof = SoftProofMath.simulateProof(1.0, 1.0, 1.0, state);
      expect(whiteProof.r, lessThan(1.0));
      expect(whiteProof.b, lessThan(whiteProof.r)); // Warm paper has slightly less blue
    });
  });
}
