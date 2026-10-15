import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/edit/parameter.dart';
import 'package:aperturex/edit/recipe.dart';

void main() {
  group('parameter catalog', () {
    test('every Parameter has a spec with a valid range', () {
      for (final p in Parameter.values) {
        final s = specOf(p);
        expect(s.id, p);
        expect(s.min, lessThan(s.max));
        expect(s.neutral, inInclusiveRange(s.min, s.max));
        expect(s.scale, greaterThan(0));
        expect(s.label, isNotEmpty);
        expect(s.kind, ParameterKind.slider);
      }
    });

    test('neutral values match parameter specifications', () {
      for (final p in Parameter.values) {
        if (p == Parameter.gradeBlending ||
            p == Parameter.vignetteMidpoint ||
            p == Parameter.vignetteFeather ||
            p == Parameter.grainRoughness ||
            p == Parameter.blurFocalPoint) {
          expect(specOf(p).neutral, 0.5);
        } else if (p == Parameter.sharpenRadius ||
            p == Parameter.profileDistortion ||
            p == Parameter.profileVignetting) {
          expect(specOf(p).neutral, 1.0);
        } else if (p == Parameter.sharpenDetail || p == Parameter.grainSize) {
          expect(specOf(p).neutral, 0.25);
        } else if (p == Parameter.blurFocalRange) {
          expect(specOf(p).neutral, 0.2);
        } else {
          expect(specOf(p).neutral, 0);
        }
      }
    });

    test('the catalog covers exactly the renderable fields today', () {
      expect(Parameter.values.length, 46);
    });
  });

  group('valueOf', () {
    test('reads the matching recipe field per parameter', () {
      const r = EditRecipe(
        exposure: 1,
        contrast: 2,
        highlights: 3,
        shadows: 4,
        whites: 5,
        blacks: 6,
        sharpen: 0.7,
        sharpenRadius: 2.5,
        sharpenDetail: 0.8,
        sharpenMasking: 0.6,
        temperature: 7,
        tint: 8,
        vibrance: 9,
        saturation: 10,
        gradeShadowLum: -0.2,
        gradeMidLum: 0.3,
        gradeHighlightLum: 0.4,
        gradeBlending: 0.8,
        gradeBalance: -0.5,
        vignetteMidpoint: 0.3,
        vignetteFeather: 0.7,
        vignetteRoundness: -0.4,
        vignetteHighlights: 0.6,
        grainSize: 0.4,
        grainRoughness: 0.8,
        defringePurpleAmount: 0.6,
        defringeGreenAmount: 0.4,
        profileDistortion: 1.2,
        profileVignetting: 0.8,
        blurAmount: 0.75,
        blurFocalPoint: 0.45,
        blurFocalRange: 0.15,
        blurBokehBoost: 0.6,
      );
      expect(valueOf(r, Parameter.exposure), 1);
      expect(valueOf(r, Parameter.contrast), 2);
      expect(valueOf(r, Parameter.highlights), 3);
      expect(valueOf(r, Parameter.shadows), 4);
      expect(valueOf(r, Parameter.whites), 5);
      expect(valueOf(r, Parameter.blacks), 6);
      expect(valueOf(r, Parameter.sharpen), 0.7);
      expect(valueOf(r, Parameter.sharpenRadius), 2.5);
      expect(valueOf(r, Parameter.sharpenDetail), 0.8);
      expect(valueOf(r, Parameter.sharpenMasking), 0.6);
      expect(valueOf(r, Parameter.temperature), 7);
      expect(valueOf(r, Parameter.tint), 8);
      expect(valueOf(r, Parameter.vibrance), 9);
      expect(valueOf(r, Parameter.saturation), 10);
      expect(valueOf(r, Parameter.gradeShadowLum), -0.2);
      expect(valueOf(r, Parameter.gradeMidLum), 0.3);
      expect(valueOf(r, Parameter.gradeHighlightLum), 0.4);
      expect(valueOf(r, Parameter.gradeBlending), 0.8);
      expect(valueOf(r, Parameter.gradeBalance), -0.5);
      expect(valueOf(r, Parameter.vignetteMidpoint), 0.3);
      expect(valueOf(r, Parameter.vignetteFeather), 0.7);
      expect(valueOf(r, Parameter.vignetteRoundness), -0.4);
      expect(valueOf(r, Parameter.vignetteHighlights), 0.6);
      expect(valueOf(r, Parameter.grainSize), 0.4);
      expect(valueOf(r, Parameter.grainRoughness), 0.8);
      expect(valueOf(r, Parameter.defringePurpleAmount), 0.6);
      expect(valueOf(r, Parameter.defringeGreenAmount), 0.4);
      expect(valueOf(r, Parameter.profileDistortion), 1.2);
      expect(valueOf(r, Parameter.profileVignetting), 0.8);
      expect(valueOf(r, Parameter.blurAmount), 0.75);
      expect(valueOf(r, Parameter.blurFocalPoint), 0.45);
      expect(valueOf(r, Parameter.blurFocalRange), 0.15);
      expect(valueOf(r, Parameter.blurBokehBoost), 0.6);
    });
  });

  group('withValue / clampParameter', () {
    test('sets only the named parameter', () {
      final r = withValue(EditRecipe.neutral, Parameter.exposure, 1.5);
      expect(r.exposure, 1.5);
      expect(r.contrast, 0);
      expect(r.saturation, 0);
    });

    test('clamps to the exclusive range', () {
      expect(withValue(EditRecipe.neutral, Parameter.exposure, 99).exposure, 4);
      expect(
        withValue(EditRecipe.neutral, Parameter.exposure, -99).exposure,
        -4,
      );
      expect(
        withValue(EditRecipe.neutral, Parameter.contrast, 99).contrast,
        1,
      );
    });

    test('exposure range is wide enough for the EV slider', () {
      expect(clampParameter(Parameter.exposure, 2), 2);
      expect(clampParameter(Parameter.exposure, -2), -2);
    });

    test('is pure — the receiver is never mutated', () {
      const before = EditRecipe.neutral;
      withValue(before, Parameter.tint, 0.5);
      expect(before, EditRecipe.neutral);
    });
  });

  group('withMuted (tap-to-mute bypass)', () {
    test('neutralises exactly the muted parameters', () {
      final recipe = EditRecipe.neutral.copyWith(
        exposure: 1.5,
        contrast: 0.4,
        vignette: -0.3,
      );

      final muted = withMuted(recipe, {Parameter.exposure});

      expect(muted.exposure, 0);
      expect(muted.contrast, 0.4);
      expect(muted.vignette, -0.3);
      expect(recipe.exposure, 1.5); // stored value survives
    });

    test('mutes several at once', () {
      final recipe = EditRecipe.neutral.copyWith(
        exposure: 1,
        saturation: 0.5,
        sharpen: 0.8,
      );

      final muted = withMuted(recipe, {
        Parameter.exposure,
        Parameter.saturation,
        Parameter.sharpen,
      });

      expect(muted.exposure, 0);
      expect(muted.saturation, 0);
      expect(muted.sharpen, 0);
    });

    test('an empty mute set returns the same instance', () {
      final recipe = EditRecipe.neutral.copyWith(exposure: 2);
      expect(identical(withMuted(recipe, const {}), recipe), isTrue);
    });

    test('every parameter can be muted independently', () {
      for (final p in Parameter.values) {
        final recipe = withValue(EditRecipe.neutral, p, specOf(p).max);
        final muted = withMuted(recipe, {p});
        expect(valueOf(muted, p), specOf(p).neutral, reason: '$p');
        // Neighbours are untouched.
        for (final other in Parameter.values) {
          if (other == p) continue;
          expect(
            valueOf(muted, other),
            valueOf(recipe, other),
            reason: '$p muted must not disturb $other',
          );
        }
      }
    });
  });
}