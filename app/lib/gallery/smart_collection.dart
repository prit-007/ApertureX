import '../edit/library_catalog.dart';

/// Which attribute a smart rule filters on.
enum SmartRuleField {
  rating,
  flag,
  colorLabel,
  keyword,
  hasEdits,
  date,
}

/// Comparison operator for a smart rule.
enum SmartComparison {
  equals,
  greaterThanOrEqual,
  lessThanOrEqual,
  contains,
}

/// A single predicate inside a [SmartCollection].
class SmartRule {
  const SmartRule({
    required this.field,
    this.comparison = SmartComparison.equals,
    this.intValue,
    this.boolValue,
    this.stringValue,
    this.colorLabel,
    this.dateValue,
  });

  factory SmartRule.fromJson(Map<String, Object?> json) {
    final fieldName = json['field'] as String? ?? 'rating';
    final compName = json['comparison'] as String? ?? 'equals';
    final field = SmartRuleField.values.firstWhere(
      (f) => f.name == fieldName,
      orElse: () => SmartRuleField.rating,
    );
    final comp = SmartComparison.values.firstWhere(
      (c) => c.name == compName,
      orElse: () => SmartComparison.equals,
    );

    return SmartRule(
      field: field,
      comparison: comp,
      intValue: json['intValue'] as int?,
      boolValue: json['boolValue'] as bool?,
      stringValue: json['stringValue'] as String?,
      colorLabel: ColorLabel.tryParse(json['colorLabel'] as String?),
      dateValue: json['dateValue'] != null
          ? DateTime.tryParse(json['dateValue'] as String)
          : null,
    );
  }

  final SmartRuleField field;
  final SmartComparison comparison;
  final int? intValue;
  final bool? boolValue;
  final String? stringValue;
  final ColorLabel? colorLabel;
  final DateTime? dateValue;

  /// Evaluates this rule against a catalog entry.
  bool matches(CatalogEntry entry, {DateTime? assetDate}) {
    switch (field) {
      case SmartRuleField.rating:
        final r = entry.rating;
        final target = intValue ?? 0;
        return switch (comparison) {
          SmartComparison.greaterThanOrEqual => r >= target,
          SmartComparison.lessThanOrEqual => r <= target,
          _ => r == target,
        };

      case SmartRuleField.flag:
        return entry.flag == (boolValue ?? true);

      case SmartRuleField.colorLabel:
        return entry.colorLabel == colorLabel;

      case SmartRuleField.keyword:
        if (stringValue == null || stringValue!.isEmpty) return true;
        final target = stringValue!.toLowerCase();
        return entry.keywords.any((k) => k.toLowerCase().contains(target));

      case SmartRuleField.hasEdits:
        final hasEdits = entry.recipe.exposure != 0 ||
            entry.recipe.contrast != 0 ||
            entry.recipe.highlights != 0 ||
            entry.recipe.shadows != 0 ||
            entry.recipe.temperature != 0 ||
            entry.recipe.tint != 0 ||
            entry.recipe.vibrance != 0 ||
            entry.recipe.saturation != 0 ||
            entry.recipe.sharpen != 0 ||
            entry.recipe.layers.isNotEmpty ||
            entry.recipe.crop[0] != 0 ||
            entry.recipe.crop[1] != 0 ||
            entry.recipe.crop[2] != 1 ||
            entry.recipe.crop[3] != 1;
        return hasEdits == (boolValue ?? true);

      case SmartRuleField.date:
        final d = assetDate ?? entry.created;
        if (dateValue == null) return true;
        return switch (comparison) {
          SmartComparison.greaterThanOrEqual =>
            d.isAfter(dateValue!) || d.isAtSameMomentAs(dateValue!),
          SmartComparison.lessThanOrEqual =>
            d.isBefore(dateValue!) || d.isAtSameMomentAs(dateValue!),
          _ => d.year == dateValue!.year &&
              d.month == dateValue!.month &&
              d.day == dateValue!.day,
        };
    }
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'field': field.name,
        'comparison': comparison.name,
        if (intValue != null) 'intValue': intValue,
        if (boolValue != null) 'boolValue': boolValue,
        if (stringValue != null) 'stringValue': stringValue,
        if (colorLabel != null) 'colorLabel': colorLabel!.name,
        if (dateValue != null) 'dateValue': dateValue!.toIso8601String(),
      };
}

/// How multiple smart rules are combined.
enum SmartMatchMode { all, any }

/// A dynamic photo collection defined by rules (Lightroom-aligned).
class SmartCollection {
  const SmartCollection({
    required this.id,
    required this.name,
    this.rules = const [],
    this.matchMode = SmartMatchMode.all,
    this.description,
  });

  factory SmartCollection.fromJson(Map<String, Object?> json) {
    final rawRules = json['rules'] as List?;
    final rules = rawRules != null
        ? rawRules
            .whereType<Map<String, Object?>>()
            .map(SmartRule.fromJson)
            .toList()
        : const <SmartRule>[];
    final matchName = json['matchMode'] as String? ?? 'all';
    final matchMode = SmartMatchMode.values.firstWhere(
      (m) => m.name == matchName,
      orElse: () => SmartMatchMode.all,
    );

    return SmartCollection(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Smart Collection',
      rules: rules,
      matchMode: matchMode,
      description: json['description'] as String?,
    );
  }

  final String id;
  final String name;
  final List<SmartRule> rules;
  final SmartMatchMode matchMode;
  final String? description;

  /// Tests whether [entry] satisfies this smart collection's query.
  bool matches(CatalogEntry entry, {DateTime? assetDate}) {
    if (rules.isEmpty) return true;
    if (matchMode == SmartMatchMode.all) {
      return rules.every((r) => r.matches(entry, assetDate: assetDate));
    } else {
      return rules.any((r) => r.matches(entry, assetDate: assetDate));
    }
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'name': name,
        'rules': rules.map((r) => r.toJson()).toList(),
        'matchMode': matchMode.name,
        if (description != null) 'description': description,
      };

  /// Built-in pro smart collections.
  static List<SmartCollection> builtInCollections() => [
        const SmartCollection(
          id: 'smart:five_stars',
          name: 'Five Stars ★★★★★',
          description: 'Photos rated 5 stars',
          rules: [
            SmartRule(
              field: SmartRuleField.rating,
              comparison: SmartComparison.greaterThanOrEqual,
              intValue: 5,
            ),
          ],
        ),
        const SmartCollection(
          id: 'smart:four_plus',
          name: 'Top Rated (≥ 4 Stars)',
          description: 'Photos rated 4 stars or above',
          rules: [
            SmartRule(
              field: SmartRuleField.rating,
              comparison: SmartComparison.greaterThanOrEqual,
              intValue: 4,
            ),
          ],
        ),
        const SmartCollection(
          id: 'smart:picks',
          name: 'Flagged / Picks ⚑',
          description: 'Photos flagged for editing or export',
          rules: [
            SmartRule(
              field: SmartRuleField.flag,
              comparison: SmartComparison.equals,
              boolValue: true,
            ),
          ],
        ),
        const SmartCollection(
          id: 'smart:edited',
          name: 'Has Adjustments ✎',
          description: 'Photos with non-default development recipes',
          rules: [
            SmartRule(
              field: SmartRuleField.hasEdits,
              comparison: SmartComparison.equals,
              boolValue: true,
            ),
          ],
        ),
        const SmartCollection(
          id: 'smart:red_label',
          name: 'Red Label',
          description: 'Photos marked with red label',
          rules: [
            SmartRule(
              field: SmartRuleField.colorLabel,
              comparison: SmartComparison.equals,
              colorLabel: ColorLabel.red,
            ),
          ],
        ),
      ];
}
