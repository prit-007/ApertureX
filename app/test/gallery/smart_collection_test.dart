import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/edit/library_catalog.dart';
import 'package:aperturex/edit/recipe.dart';
import 'package:aperturex/gallery/smart_collection.dart';

void main() {
  group('SmartCollection & SmartRule Tests', () {
    test('rating rule matches greater than or equal', () {
      const rule = SmartRule(
        field: SmartRuleField.rating,
        comparison: SmartComparison.greaterThanOrEqual,
        intValue: 4,
      );

      final entry3 = CatalogEntry(
        entryId: 'e1',
        sourceAssetId: 'a1',
        kind: CatalogEntryKind.original,
        recipe: const EditRecipe(),
        created: DateTime.now(),
        rating: 3,
      );

      final entry4 = CatalogEntry(
        entryId: 'e2',
        sourceAssetId: 'a2',
        kind: CatalogEntryKind.original,
        recipe: const EditRecipe(),
        created: DateTime.now(),
        rating: 4,
      );

      final entry5 = CatalogEntry(
        entryId: 'e3',
        sourceAssetId: 'a3',
        kind: CatalogEntryKind.original,
        recipe: const EditRecipe(),
        created: DateTime.now(),
        rating: 5,
      );

      expect(rule.matches(entry3), isFalse);
      expect(rule.matches(entry4), isTrue);
      expect(rule.matches(entry5), isTrue);
    });

    test('flag and color label rules match correctly', () {
      const flagRule = SmartRule(
        field: SmartRuleField.flag,
        comparison: SmartComparison.equals,
        boolValue: true,
      );

      const colorRule = SmartRule(
        field: SmartRuleField.colorLabel,
        comparison: SmartComparison.equals,
        colorLabel: ColorLabel.red,
      );

      final flaggedRed = CatalogEntry(
        entryId: 'e1',
        sourceAssetId: 'a1',
        kind: CatalogEntryKind.original,
        recipe: const EditRecipe(),
        created: DateTime.now(),
        flag: true,
        colorLabel: ColorLabel.red,
      );

      final unflaggedYellow = CatalogEntry(
        entryId: 'e2',
        sourceAssetId: 'a2',
        kind: CatalogEntryKind.original,
        recipe: const EditRecipe(),
        created: DateTime.now(),
        flag: false,
        colorLabel: ColorLabel.yellow,
      );

      expect(flagRule.matches(flaggedRed), isTrue);
      expect(flagRule.matches(unflaggedYellow), isFalse);
      expect(colorRule.matches(flaggedRed), isTrue);
      expect(colorRule.matches(unflaggedYellow), isFalse);
    });

    test('keyword rule performs case-insensitive substring search', () {
      const rule = SmartRule(
        field: SmartRuleField.keyword,
        stringValue: 'portrait',
      );

      final matchEntry = CatalogEntry(
        entryId: 'e1',
        sourceAssetId: 'a1',
        kind: CatalogEntryKind.original,
        recipe: const EditRecipe(),
        created: DateTime.now(),
        keywords: ['Wedding', 'Studio Portrait', 'Outdoor'],
      );

      final nonMatchEntry = CatalogEntry(
        entryId: 'e2',
        sourceAssetId: 'a2',
        kind: CatalogEntryKind.original,
        recipe: const EditRecipe(),
        created: DateTime.now(),
        keywords: ['Landscape', 'Nature'],
      );

      expect(rule.matches(matchEntry), isTrue);
      expect(rule.matches(nonMatchEntry), isFalse);
    });

    test('hasEdits rule detects modified recipe', () {
      const rule = SmartRule(
        field: SmartRuleField.hasEdits,
        boolValue: true,
      );

      final pristine = CatalogEntry(
        entryId: 'e1',
        sourceAssetId: 'a1',
        kind: CatalogEntryKind.original,
        recipe: const EditRecipe(),
        created: DateTime.now(),
      );

      final edited = CatalogEntry(
        entryId: 'e2',
        sourceAssetId: 'a2',
        kind: CatalogEntryKind.original,
        recipe: const EditRecipe(exposure: 0.5),
        created: DateTime.now(),
      );

      expect(rule.matches(pristine), isFalse);
      expect(rule.matches(edited), isTrue);
    });

    test('smart collection combines multiple rules with all vs any', () {
      const colAll = SmartCollection(
        id: 'test_all',
        name: '4+ Star Picks',
        matchMode: SmartMatchMode.all,
        rules: [
          SmartRule(
            field: SmartRuleField.rating,
            comparison: SmartComparison.greaterThanOrEqual,
            intValue: 4,
          ),
          SmartRule(
            field: SmartRuleField.flag,
            boolValue: true,
          ),
        ],
      );

      const colAny = SmartCollection(
        id: 'test_any',
        name: '4+ Stars OR Pick',
        matchMode: SmartMatchMode.any,
        rules: [
          SmartRule(
            field: SmartRuleField.rating,
            comparison: SmartComparison.greaterThanOrEqual,
            intValue: 4,
          ),
          SmartRule(
            field: SmartRuleField.flag,
            boolValue: true,
          ),
        ],
      );

      final onlyStars = CatalogEntry(
        entryId: 'e1',
        sourceAssetId: 'a1',
        kind: CatalogEntryKind.original,
        recipe: const EditRecipe(),
        created: DateTime.now(),
        rating: 5,
        flag: false,
      );

      final onlyFlag = CatalogEntry(
        entryId: 'e2',
        sourceAssetId: 'a2',
        kind: CatalogEntryKind.original,
        recipe: const EditRecipe(),
        created: DateTime.now(),
        rating: 2,
        flag: true,
      );

      final both = CatalogEntry(
        entryId: 'e3',
        sourceAssetId: 'a3',
        kind: CatalogEntryKind.original,
        recipe: const EditRecipe(),
        created: DateTime.now(),
        rating: 4,
        flag: true,
      );

      expect(colAll.matches(onlyStars), isFalse);
      expect(colAll.matches(onlyFlag), isFalse);
      expect(colAll.matches(both), isTrue);

      expect(colAny.matches(onlyStars), isTrue);
      expect(colAny.matches(onlyFlag), isTrue);
      expect(colAny.matches(both), isTrue);
    });

    test('serializes and deserializes smart collection JSON round-trip', () {
      const col = SmartCollection(
        id: 'smart:custom',
        name: 'Custom Query',
        matchMode: SmartMatchMode.any,
        rules: [
          SmartRule(
            field: SmartRuleField.rating,
            comparison: SmartComparison.greaterThanOrEqual,
            intValue: 4,
          ),
          SmartRule(
            field: SmartRuleField.keyword,
            stringValue: 'travel',
          ),
        ],
      );

      final json = col.toJson();
      final restored = SmartCollection.fromJson(json);

      expect(restored.id, col.id);
      expect(restored.name, col.name);
      expect(restored.matchMode, col.matchMode);
      expect(restored.rules.length, 2);
      expect(restored.rules[0].field, SmartRuleField.rating);
      expect(restored.rules[0].intValue, 4);
      expect(restored.rules[1].stringValue, 'travel');
    });
  });
}
