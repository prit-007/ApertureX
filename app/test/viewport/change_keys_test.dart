import 'package:aperturex/edit/recipe.dart';
import 'package:aperturex/viewport/change_keys.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every control that feeds the base frame or the grade LUT must perturb the
/// matching change key — otherwise `_scheduleBake` early-returns and the
/// slider appears dead in the live preview (Whites/Blacks bug, #cbade1d).
void main() {
  EditRecipe withGrade(String field, double value) {
    // Build via copyWith so the test stays robust to field additions.
    switch (field) {
      case 'exposure':
        return const EditRecipe().copyWith(exposure: value);
      case 'contrast':
        return const EditRecipe().copyWith(contrast: value);
      case 'whites':
        return const EditRecipe().copyWith(whites: value);
      case 'blacks':
        return const EditRecipe().copyWith(blacks: value);
      case 'saturation':
        return const EditRecipe().copyWith(saturation: value);
      case 'temperature':
        return const EditRecipe().copyWith(temperature: value);
      case 'tint':
        return const EditRecipe().copyWith(tint: value);
      case 'vibrance':
        return const EditRecipe().copyWith(vibrance: value);
      case 'gradeShadowLum':
        return const EditRecipe().copyWith(gradeShadowLum: value);
      case 'gradeMidLum':
        return const EditRecipe().copyWith(gradeMidLum: value);
      case 'gradeHighlightLum':
        return const EditRecipe().copyWith(gradeHighlightLum: value);
      case 'gradeBlending':
        return const EditRecipe().copyWith(gradeBlending: value);
      case 'gradeBalance':
        return const EditRecipe().copyWith(gradeBalance: value);
      case 'highlights':
        return const EditRecipe().copyWith(highlights: value);
      case 'shadows':
        return const EditRecipe().copyWith(shadows: value);
      case 'clarity':
        return const EditRecipe().copyWith(clarity: value);
      case 'defringePurpleAmount':
        return const EditRecipe().copyWith(defringePurpleAmount: value);
      case 'blurAmount':
        return const EditRecipe().copyWith(blurAmount: value);
      case 'sharpenRadius':
        return const EditRecipe().copyWith(sharpenRadius: value);
      case 'vignetteMidpoint':
        return const EditRecipe().copyWith(vignetteMidpoint: value);
      case 'grainSize':
        return const EditRecipe().copyWith(grainSize: value);
      case 'filmHalation':
        return const EditRecipe().copyWith(filmHalation: value);
      default:
        throw ArgumentError('unknown field $field');
    }
  }

  group('gradeKeyOf', () {
    test('is stable for identical recipes', () {
      expect(gradeKeyOf(const EditRecipe()), gradeKeyOf(const EditRecipe()));
    });

    for (final field in [
      'exposure',
      'contrast',
      'whites',
      'blacks',
      'saturation',
      'temperature',
      'tint',
      'vibrance',
      'gradeShadowLum',
      'gradeMidLum',
      'gradeHighlightLum',
      'gradeBlending',
      'gradeBalance',
    ]) {
      test('$field perturbs the grade key (rebake trigger)', () {
        final base = gradeKeyOf(const EditRecipe());
        expect(gradeKeyOf(withGrade(field, field == 'gradeBlending' ? 0.9 : 0.4)),
            isNot(base), reason: '$field missing from gradeKeyOf — slider would be dead');
      });
    }
  });

  group('baseKeyOf', () {
    test('is stable for identical recipes', () {
      expect(baseKeyOf(const EditRecipe()), baseKeyOf(const EditRecipe()));
    });

    for (final field in [
      'highlights',
      'shadows',
      'clarity',
      'defringePurpleAmount',
      'blurAmount',
      'sharpenRadius',
      'vignetteMidpoint',
      'grainSize',
      'filmHalation',
    ]) {
      test('$field perturbs the base key (rebake trigger)', () {
        final base = baseKeyOf(const EditRecipe());
        expect(baseKeyOf(withGrade(field, 0.4)), isNot(base),
            reason: '$field missing from baseKeyOf — slider would be dead');
      });
    }

    test('blur enable/focal plane perturbs the base key', () {
      final base = baseKeyOf(const EditRecipe());
      expect(
        baseKeyOf(const EditRecipe().copyWith(blurEnabled: true, blurAmount: 0.5)),
        isNot(base),
      );
      expect(
        baseKeyOf(
          const EditRecipe().copyWith(blurEnabled: true, blurAmount: 0.5, blurFocalPoint: 0.8),
        ),
        isNot(baseKeyOf(
          const EditRecipe().copyWith(blurEnabled: true, blurAmount: 0.5, blurFocalPoint: 0.2),
        )),
      );
    });

    test('grade-only edits do not perturb the base key', () {
      expect(baseKeyOf(withGrade('exposure', 0.7)), baseKeyOf(const EditRecipe()));
    });

    test('spatial-only edits do not perturb the grade key', () {
      expect(gradeKeyOf(withGrade('clarity', 0.7)), gradeKeyOf(const EditRecipe()));
    });
  });
}
