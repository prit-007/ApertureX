import '../../edit/tool_definition.dart';

/// Represents a color grading preset from the ApertureX Community Hub.
class CommunityPreset {
  const CommunityPreset({
    required this.id,
    required this.name,
    required this.category,
    required this.author,
    required this.description,
    this.previewUrl,
    this.recipeUrl,
    this.downloadCount = 0,
    this.rating = 5.0,
    this.params,
    this.tags = const [],
  });

  factory CommunityPreset.fromJson(Map<String, dynamic> json) {
    Map<String, double>? parsedParams;
    if (json['params'] is Map) {
      final rawMap = json['params'] as Map;
      parsedParams = {};
      rawMap.forEach((k, v) {
        if (v is num) {
          parsedParams![k.toString()] = v.toDouble();
        }
      });
    }

    return CommunityPreset(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Untitled Look',
      category: json['category'] as String? ?? 'General',
      author: json['author'] as String? ?? 'Community',
      description: json['description'] as String? ?? '',
      previewUrl: json['previewUrl'] as String?,
      recipeUrl: json['recipeUrl'] as String?,
      downloadCount: (json['downloadCount'] as num?)?.toInt() ?? 0,
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      params: parsedParams,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }

  final String id;
  final String name;
  final String category;
  final String author;
  final String description;
  final String? previewUrl;
  final String? recipeUrl;
  final int downloadCount;
  final double rating;
  final Map<String, double>? params;
  final List<String> tags;

  /// Converts this preset into an ApertureX [ToolDefinition] for instant application.
  ToolDefinition toToolDefinition() {
    return ToolDefinition(
      name: name,
      description: '$description • by $author',
      params: params ?? const {},
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'author': author,
    'description': description,
    if (previewUrl != null) 'previewUrl': previewUrl,
    if (recipeUrl != null) 'recipeUrl': recipeUrl,
    'downloadCount': downloadCount,
    'rating': rating,
    if (params != null) 'params': params,
    'tags': tags,
  };

  CommunityPreset copyWith({
    String? id,
    String? name,
    String? category,
    String? author,
    String? description,
    String? previewUrl,
    String? recipeUrl,
    int? downloadCount,
    double? rating,
    Map<String, double>? params,
    List<String>? tags,
  }) {
    return CommunityPreset(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      author: author ?? this.author,
      description: description ?? this.description,
      previewUrl: previewUrl ?? this.previewUrl,
      recipeUrl: recipeUrl ?? this.recipeUrl,
      downloadCount: downloadCount ?? this.downloadCount,
      rating: rating ?? this.rating,
      params: params ?? this.params,
      tags: tags ?? this.tags,
    );
  }
}
