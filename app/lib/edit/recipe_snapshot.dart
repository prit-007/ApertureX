import 'recipe.dart';

/// A named snapshot of an [EditRecipe] (Lightroom Snapshots / Virtual Copies).
///
/// Enables photographers to save multiple distinct creative versions (e.g.,
/// "Warm Golden Hour", "High-Contrast B&W", "Moody Teal & Orange") of the same
/// photo without duplicating image files on disk.
class RecipeSnapshot {
  const RecipeSnapshot({
    required this.id,
    required this.name,
    required this.recipe,
    required this.timestamp,
  });

  factory RecipeSnapshot.fromJson(Map<String, dynamic> json) => RecipeSnapshot(
    id: json['id'] as String,
    name: json['name'] as String,
    recipe: EditRecipe.fromJson(json['recipe'] as Map<String, dynamic>),
    timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
        DateTime.now().toUtc(),
  );

  final String id;
  final String name;
  final EditRecipe recipe;
  final DateTime timestamp;

  RecipeSnapshot copyWith({
    String? id,
    String? name,
    EditRecipe? recipe,
    DateTime? timestamp,
  }) {
    return RecipeSnapshot(
      id: id ?? this.id,
      name: name ?? this.name,
      recipe: recipe ?? this.recipe,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'recipe': recipe.toJson(),
    'timestamp': timestamp.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecipeSnapshot &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          recipe == other.recipe &&
          timestamp == other.timestamp;

  @override
  int get hashCode => Object.hash(id, name, recipe, timestamp);
}
