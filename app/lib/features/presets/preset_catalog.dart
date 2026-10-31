// Comprehensive Preset Catalog with Category Separation, Depth Awareness, and Search.
//
// Unifies movie-reference color grades, anime aesthetics, scenario-optimized
// nature presets, and analog film emulations into a searchable catalog.
import '../../color/blur_spec.dart';
import '../../edit/tool_definition.dart';
import 'cultural_travel_presets.dart';
import 'movie_presets.dart';
import 'nature_presets.dart';

/// Categories for organizing the ApertureX preset catalog.
enum PresetCategory {
  all('All'),
  cinema('Cinema & Movies'),
  anime('Anime Styles'),
  nature('Nature & Landscapes'),
  portrait('Portraits & People'),
  indian('Indian & Festive'),
  travel('Travel & Tourism'),
  urban('Urban & Night'),
  film('Analog & Film');

  const PresetCategory(this.label);
  final String label;
}

/// A categorized preset entry combining visual metadata, grading parameters, and depth.
class PresetItem {
  const PresetItem({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.reference,
    required this.tool,
    this.depthHint,
    this.blurAmount = 0.0,
    this.bokehShape = BokehShape.circle,
  });

  final String id;
  final String name;
  final PresetCategory category;
  final String description;
  final String reference;
  final ToolDefinition tool;
  final String? depthHint;
  final double blurAmount;
  final BokehShape bokehShape;

  bool get hasDepth => blurAmount > 0;
}

/// Central catalog providing access to all built-in grading presets.
class PresetCatalog {
  const PresetCatalog._();

  /// All catalog presets across all categories.
  static final List<PresetItem> allPresets = _buildCatalog();

  static List<PresetItem> _buildCatalog() {
    final list = <PresetItem>[];

    // ─── 1. Classic & Analog Film Emulation Presets (Punch first) ──
    for (final f in ToolLibrary.builtins) {
      final isFilm = f.description.toLowerCase().contains('film') ||
          f.description.toLowerCase().contains('analog') ||
          f.name.toLowerCase().contains('kodak') ||
          f.name.toLowerCase().contains('fuji') ||
          f.name.toLowerCase().contains('ilford') ||
          f.name.toLowerCase().contains('agfa') ||
          f.name.toLowerCase().contains('cinestill');

      list.add(
        PresetItem(
          id: 'film_${f.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}',
          name: f.name,
          category: isFilm ? PresetCategory.film : PresetCategory.urban,
          description: f.description,
          reference: 'ApertureX Film Library',
          tool: f,
          depthHint: null,
          blurAmount: 0.0,
          bokehShape: BokehShape.circle,
        ),
      );
    }

    // ─── 2. Movie & Anime Presets ────────────────────────────────
    for (final m in movieLooks) {
      final isAnime = m.name.toLowerCase().startsWith('anime:');
      final category = isAnime ? PresetCategory.anime : PresetCategory.cinema;
      final shapeIndex = m.bokehShape.clamp(0, BokehShape.values.length - 1);

      list.add(
        PresetItem(
          id: 'movie_${m.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}',
          name: m.name,
          category: category,
          description: m.description,
          reference: m.reference,
          tool: m.toToolDefinition(),
          depthHint: m.depthHint,
          blurAmount: m.blurAmount,
          bokehShape: BokehShape.values[shapeIndex],
        ),
      );
    }

    // ─── 3. Nature & Scenario Presets ────────────────────────────
    for (final n in natureLooks) {
      final isPortrait = n.scenario.toLowerCase().contains('portrait') ||
          n.name.toLowerCase().contains('portrait');
      final isUrban = n.scenario.toLowerCase().contains('indoor') ||
          n.name.toLowerCase().contains('indoor') ||
          n.scenario.toLowerCase().contains('sports') ||
          n.name.toLowerCase().contains('sports');
      final category = isPortrait
          ? PresetCategory.portrait
          : (isUrban ? PresetCategory.urban : PresetCategory.nature);
      final shapeIndex = n.bokehShape.clamp(0, BokehShape.values.length - 1);

      list.add(
        PresetItem(
          id: 'nature_${n.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}',
          name: n.name,
          category: category,
          description: n.description,
          reference: n.scenario,
          tool: n.toToolDefinition(),
          depthHint: n.depthHint,
          blurAmount: n.blurAmount,
          bokehShape: BokehShape.values[shapeIndex],
        ),
      );
    }

    // ─── 4. Cultural, Festive & Travel Presets ────────────────────
    for (final c in culturalTravelLooks) {
      final themeLower = c.theme.toLowerCase();
      final isFilm = themeLower.contains('film');
      final isIndian = themeLower.contains('indian');
      final isTravel = themeLower.contains('travel');
      final isNature = themeLower.contains('nature') || themeLower.contains('landscape');
      final isUniversal = themeLower.contains('universal');

      final PresetCategory category;
      if (isFilm) {
        category = PresetCategory.film;
      } else if (isIndian) {
        category = PresetCategory.indian;
      } else if (isTravel) {
        category = PresetCategory.travel;
      } else if (isNature) {
        category = PresetCategory.nature;
      } else if (isUniversal) {
        category = PresetCategory.portrait;
      } else {
        category = PresetCategory.urban;
      }
      final shapeIndex = c.bokehShape.clamp(0, BokehShape.values.length - 1);

      list.add(
        PresetItem(
          id: 'cultural_${c.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}',
          name: c.name,
          category: category,
          description: c.description,
          reference: c.theme,
          tool: c.toToolDefinition(),
          depthHint: c.depthHint,
          blurAmount: c.blurAmount,
          bokehShape: BokehShape.values[shapeIndex],
        ),
      );
    }

    return List.unmodifiable(list);
  }

  /// Filters presets by category.
  static List<PresetItem> getByCategory(PresetCategory category) {
    if (category == PresetCategory.all) return allPresets;
    return allPresets.where((p) => p.category == category).toList();
  }

  /// Searches presets across name, description, and reference tags.
  static List<PresetItem> search(
    String query, {
    PresetCategory category = PresetCategory.all,
  }) {
    final q = query.trim().toLowerCase();
    final base = getByCategory(category);
    if (q.isEmpty) return base;

    return base.where((p) {
      return p.name.toLowerCase().contains(q) ||
          p.description.toLowerCase().contains(q) ||
          p.reference.toLowerCase().contains(q) ||
          p.category.label.toLowerCase().contains(q);
    }).toList();
  }

  /// Returns all [ToolDefinition] instances in the catalog for tool libraries.
  static List<ToolDefinition> get allToolDefinitions =>
      allPresets.map((p) => p.tool).toList();
}
