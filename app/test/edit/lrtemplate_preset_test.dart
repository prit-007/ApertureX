import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/edit/lrtemplate_preset.dart';
import 'package:aperturex/edit/xmp_preset.dart';

const _standardLrtemplate = '''
s = {
	id = "F6D25471-DAA8-438B-9336-39D97E0C0DC5",
	internalName = "Moody Portrait",
	title = "Moody Portrait",
	type = "Develop",
	value = {
		settings = {
			AutoExposure = false,
			Clarity2012 = 15,
			Contrast2012 = 20,
			Exposure2012 = 0.50,
			Highlights2012 = -25,
			Shadows2012 = 30,
			Whites2012 = 10,
			Blacks2012 = -15,
			Dehaze = 10,
			Texture = 5,
			Vibrance = 15,
			Saturation = -10,
			Temperature = 5500,
			Tint = 12,
			PostCropVignetteAmount = -25,
			PostCropVignetteMidpoint = 50,
			PostCropVignetteFeather = 50,
			GrainAmount = 18,
			GrainSize = 30,
			Sharpness = 40,
			SharpenRadius = 1.2,
			SharpenDetail = 25,
			SharpenEdgeMasking = 10,
			LuminanceSmoothing = 20,
			ColorNoiseReduction = 25,
			SplitToningHighlightHue = 45,
			SplitToningHighlightSaturation = 20,
			SplitToningShadowHue = 215,
			SplitToningShadowSaturation = 25,
			SplitToningBalance = 0,
			ToneCurvePV2012 = {
				0, 0,
				64, 55,
				192, 200,
				255, 255,
			},
			ToneCurvePV2012Red = {
				0, 0,
				255, 255,
			},
			HueAdjustmentRed = -5,
			SaturationAdjustmentRed = 15,
			LuminanceAdjustmentRed = 10,
			CropLeft = 0.05,
			CropTop = 0.05,
			CropRight = 0.95,
			CropBottom = 0.95,
			Rotation = 90,
			LensProfileEnable = 1,
			UnknownPropXYZ = "val",
		},
	},
	version = 0,
}
''';

const _legacyLrtemplate = '''
s = {
	value = {
		settings = {
			Exposure = 0.75,
			Contrast = 30,
			HighlightRecovery = 40,
			FillLight = 20,
			Whites = 15,
			Blacks = -10,
			Clarity = 25,
			Sharpness = 50,
			ToneCurve = {
				0, 0,
				255, 255,
			},
		},
	},
}
''';

void main() {
  group('parseLrtemplatePreset', () {
    test('applies standard Lightroom settings to recipe', () {
      final import = parseLrtemplatePreset(_standardLrtemplate);

      // Basic tone controls
      expect(import.recipe.exposure, 0.50);
      expect(import.recipe.contrast, closeTo(0.20, 1e-6));
      expect(import.recipe.highlights, closeTo(-0.25, 1e-6));
      expect(import.recipe.shadows, closeTo(0.30, 1e-6));
      expect(import.recipe.whites, closeTo(0.10, 1e-6));
      expect(import.recipe.blacks, closeTo(-0.15, 1e-6));
      expect(import.recipe.clarity, closeTo(0.15, 1e-6));
      expect(import.recipe.dehaze, closeTo(0.10, 1e-6));
      expect(import.recipe.texture, closeTo(0.05, 1e-6));
      expect(import.recipe.vibrance, closeTo(0.15, 1e-6));
      expect(import.recipe.saturation, closeTo(-0.10, 1e-6));

      // Vignette & Grain
      expect(import.recipe.vignette, closeTo(0.25, 1e-6)); // -25 * -0.01 = 0.25
      expect(import.recipe.grain, closeTo(0.18, 1e-6));

      // Detail & noise
      expect(import.recipe.sharpen, closeTo(0.40, 1e-6));
      expect(import.recipe.sharpenRadius, closeTo(1.2, 1e-6));
      expect(import.recipe.sharpenDetail, closeTo(0.25, 1e-6));
      expect(import.recipe.sharpenMasking, closeTo(0.10, 1e-6));
      expect(import.recipe.denoiseLuma, closeTo(0.20, 1e-6));
      expect(import.recipe.denoiseChroma, closeTo(0.25, 1e-6));

      // Split toning / Color grading
      expect(import.recipe.gradeHighlightHue, closeTo(45 / 360.0, 1e-6));
      expect(import.recipe.gradeHighlightSat, closeTo(0.20, 1e-6));
      expect(import.recipe.gradeShadowHue, closeTo(215 / 360.0, 1e-6));
      expect(import.recipe.gradeShadowSat, closeTo(0.25, 1e-6));

      // Tone Curve
      expect(import.recipe.masterCurve.points.length, 8); // 4 points (x, y)
      expect(import.recipe.masterCurve.points[0], 0.0);
      expect(import.recipe.masterCurve.points[1], 0.0);
      expect(import.recipe.masterCurve.points[2], closeTo(64 / 255.0, 1e-4));
      expect(import.recipe.masterCurve.points[3], closeTo(55 / 255.0, 1e-4));

      // HSL
      // Band 0 is Red: hue, sat, lum
      expect(import.recipe.hsl[0], closeTo(-0.05, 1e-6));
      expect(import.recipe.hsl[1], closeTo(0.15, 1e-6));
      expect(import.recipe.hsl[2], closeTo(0.10, 1e-6));

      // Crop & rotation
      expect(import.recipe.crop, [0.05, 0.05, 0.95, 0.95]);
      expect(import.recipe.rotation, 1); // 90 degrees = 1 quarter turn

      // Unsupported settings are reported
      final notes = {for (final n in import.notes) n.setting: n.status};
      expect(notes['Exposure'], PresetStatus.applied);
      expect(notes['LensProfileEnable'], PresetStatus.unsupported);
      expect(notes['UnknownPropXYZ'], PresetStatus.unsupported);
      expect(import.hasUnsupported, isTrue);
    });

    test('handles legacy (pre-2012) parameter names', () {
      final import = parseLrtemplatePreset(_legacyLrtemplate);
      expect(import.recipe.exposure, 0.75);
      expect(import.recipe.contrast, closeTo(0.30, 1e-6));
      expect(import.recipe.highlights, closeTo(0.40, 1e-6));
      expect(import.recipe.shadows, closeTo(0.20, 1e-6));
      expect(import.recipe.whites, closeTo(0.15, 1e-6));
      expect(import.recipe.blacks, closeTo(-0.10, 1e-6));
      expect(import.recipe.clarity, closeTo(0.25, 1e-6));
      expect(import.recipe.sharpen, closeTo(0.50, 1e-6));
      expect(import.recipe.masterCurve.isIdentity, isTrue);
    });

    test('handles malformed / invalid input without throwing', () {
      expect(parseLrtemplatePreset('').recipe, isNotNull);
      expect(parseLrtemplatePreset('not a lua table').recipe, isNotNull);
      expect(parseLrtemplatePreset('s = { settings = { Exposure2012 = ').recipe, isNotNull);
      expect(parseLrtemplatePreset('s = { settings = { Exposure2012 = "abc" } }').recipe, isNotNull);
    });
  });
}
