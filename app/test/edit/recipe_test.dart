import 'package:flutter_test/flutter_test.dart';
import 'package:tessera/edit/recipe.dart';

void main() {
  group('EditRecipe.neutral', () {
    test('every field is zero and the schema version is current', () {
      const r = EditRecipe.neutral;
      expect(r.schemaVersion, EditRecipe.currentSchemaVersion);
      expect(r.exposure, 0);
      expect(r.contrast, 0);
      expect(r.highlights, 0);
      expect(r.shadows, 0);
      expect(r.whites, 0);
      expect(r.blacks, 0);
      expect(r.temperature, 0);
      expect(r.tint, 0);
      expect(r.vibrance, 0);
      expect(r.saturation, 0);
    });

    test('the default constructor is also neutral', () {
      expect(const EditRecipe(), EditRecipe.neutral);
    });
  });

  group('copyWith', () {
    test('replaces only the named field and leaves the receiver unchanged', () {
      final base = const EditRecipe().copyWith(exposure: 1.5);
      final next = base.copyWith(contrast: 0.25);

      expect(next.exposure, 1.5); // carried over
      expect(next.contrast, 0.25); // replaced
      expect(base.contrast, 0); // base untouched
      expect(const EditRecipe().exposure, 0); // neutral untouched
    });

    test('omitted fields keep their current values', () {
      final base = const EditRecipe().copyWith(saturation: -0.4, tint: 0.1);
      final next = base.copyWith(exposure: 2.0);
      expect(next.saturation, -0.4);
      expect(next.tint, 0.1);
    });
  });

  group('JSON', () {
    test('round-trips every field through toJson/fromJson', () {
      const original = EditRecipe(
        exposure: 1.25,
        contrast: -0.5,
        highlights: 0.3,
        shadows: -0.2,
        whites: 0.1,
        blacks: -0.1,
        temperature: 0.4,
        tint: -0.3,
        vibrance: 0.6,
        saturation: -0.7,
      );

      final restored = EditRecipe.fromJson(original.toJson());

      expect(restored, original);
    });

    test('fromJson defaults missing keys to neutral', () {
      final restored = EditRecipe.fromJson(<String, Object?>{
        'exposure': 2.0,
        // every other key absent
      });

      expect(restored.exposure, 2.0);
      expect(restored.contrast, 0);
      expect(restored.temperature, 0);
      expect(restored.schemaVersion, EditRecipe.currentSchemaVersion);
    });

    test('fromJson ignores unknown keys so an older reader survives', () {
      final restored = EditRecipe.fromJson(<String, Object?>{
        ...const EditRecipe().toJson(),
        'futureKnob': 42,
      });

      expect(restored, EditRecipe.neutral);
    });

    test('fromJson coerces ints to doubles', () {
      final restored = EditRecipe.fromJson(<String, Object?>{'exposure': 1});
      expect(restored.exposure, 1.0);
      expect(restored.exposure, isA<double>());
    });
  });

  group('equality', () {
    test('identical recipes are equal and share a hashCode', () {
      final a = const EditRecipe().copyWith(exposure: 0.5, saturation: 0.2);
      final b = const EditRecipe().copyWith(exposure: 0.5, saturation: 0.2);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('a differing field breaks equality', () {
      final a = const EditRecipe().copyWith(exposure: 0.5);
      final b = const EditRecipe().copyWith(exposure: 0.6);
      expect(a, isNot(b));
    });
  });
}
