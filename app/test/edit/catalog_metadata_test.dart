import 'package:aperturex/edit/library_catalog.dart';
import 'package:aperturex/edit/recipe.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ColorLabel & Keywords in CatalogEntry', () {
    test('parses and serializes color label correctly', () {
      expect(ColorLabel.tryParse('red'), ColorLabel.red);
      expect(ColorLabel.tryParse('yellow'), ColorLabel.yellow);
      expect(ColorLabel.tryParse('invalid'), isNull);
      expect(ColorLabel.tryParse(null), isNull);

      final entry = CatalogEntry(
        entryId: 'orig:photo1',
        sourceAssetId: 'photo1',
        kind: CatalogEntryKind.original,
        recipe: EditRecipe.neutral,
        created: DateTime.now(),
        colorLabel: ColorLabel.green,
        keywords: const ['landscape', 'sunset'],
      );

      expect(entry.hasMetadata, isTrue);

      final json = entry.toJson();
      expect(json['colorLabel'], 'green');
      expect(json['keywords'], ['landscape', 'sunset']);

      final restored = CatalogEntry.fromJson('orig:photo1', json);
      expect(restored.colorLabel, ColorLabel.green);
      expect(restored.keywords, ['landscape', 'sunset']);
    });

    test('copyWith allows setting, changing, and clearing color label', () {
      final base = CatalogEntry.original(
        entryId: 'orig:photo1',
        recipe: EditRecipe.neutral,
      );

      expect(base.hasMetadata, isFalse);

      final withLabel = base.copyWith(colorLabel: ColorLabel.blue);
      expect(withLabel.colorLabel, ColorLabel.blue);
      expect(withLabel.hasMetadata, isTrue);

      final cleared = withLabel.copyWith(clearColorLabel: true);
      expect(cleared.colorLabel, isNull);
      expect(cleared.hasMetadata, isFalse);
    });

    test('keywords manipulation', () {
      final base = CatalogEntry.original(
        entryId: 'orig:photo1',
        recipe: EditRecipe.neutral,
      );

      final withKeywords = base.copyWith(keywords: ['travel', 'japan']);
      expect(withKeywords.keywords, ['travel', 'japan']);
      expect(withKeywords.hasMetadata, isTrue);

      final updated = withKeywords.copyWith(keywords: ['travel']);
      expect(updated.keywords, ['travel']);
    });
  });
}
