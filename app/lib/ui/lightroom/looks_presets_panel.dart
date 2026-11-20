import 'dart:typed_data';

import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/design_tokens.dart';
import '../../edit/active_image.dart';
import '../../edit/parameter.dart';
import '../../edit/recipe.dart';
import '../../edit/recipe_controller.dart';
import '../../edit/tool_definition.dart';
import '../../features/presets/community_preset_model.dart';
import '../../features/presets/community_presets_provider.dart';
import '../../features/presets/preset_catalog.dart';
import '../common/app_sheet.dart';
import '../common/looks_sheet.dart';
import '../common/preset_preview_thumbnail.dart';

/// Panel for applying built-in looks and community presets to the current image.
class LooksPresetsPanel extends ConsumerStatefulWidget {
  const LooksPresetsPanel({super.key});

  @override
  ConsumerState<LooksPresetsPanel> createState() => _LooksPresetsPanelState();
}

class _LooksPresetsPanelState extends ConsumerState<LooksPresetsPanel> {
  String _selectedCategory = 'All';
  String _searchQuery = '';
  bool _searchOpen = false;
  bool _synced = false;
  ToolDefinition? _activePresetTool;
  double _activePresetAmount = 1.0;

  static const List<String> _categories = [
    'All',
    'Cinema',
    'Anime',
    'Film',
    'Nature',
    'Portraits',
    'Indian & Festive',
    'Travel',
    'Urban',
    'Community',
  ];

  String _mapCatalogCategory(PresetCategory cat) => switch (cat) {
    PresetCategory.all => 'All',
    PresetCategory.cinema => 'Cinema',
    PresetCategory.anime => 'Anime',
    PresetCategory.nature => 'Nature',
    PresetCategory.portrait => 'Portraits',
    PresetCategory.indian => 'Indian & Festive',
    PresetCategory.travel => 'Travel',
    PresetCategory.urban => 'Urban',
    PresetCategory.film => 'Film',
  };

  bool _matchesCategory(String itemCategory, String selectedCategory) {
    if (selectedCategory == 'All') return true;
    if (selectedCategory == itemCategory) return true;
    final s = selectedCategory.toLowerCase();
    final c = itemCategory.toLowerCase();
    return c.contains(s) || s.contains(c);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!_synced && mounted) {
        _synced = true;
        await ref.read(communityPresetsProvider.notifier).syncWithGitHub();
        if (mounted) setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final notifier = ref.read(recipeControllerProvider.notifier);
    final communityState = ref.watch(communityPresetsProvider);

    // ---- Unified preset list: Catalog (All Looks) + Community + Builtins ----
    final allItems = <_PresetItem>[];
    final seenNames = <String>{};

    // 1. All rich catalog presets from LooksSheet (Movie looks, anime styles, nature, portrait, indian, film)
    for (final p in PresetCatalog.allPresets) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!p.name.toLowerCase().contains(q) &&
            !p.description.toLowerCase().contains(q) &&
            !p.reference.toLowerCase().contains(q)) {
          continue;
        }
      }
      final catLabel = _mapCatalogCategory(p.category);
      if (!_matchesCategory(catLabel, _selectedCategory)) {
        continue;
      }
      seenNames.add(p.name.toLowerCase());
      allItems.add(_PresetItem.catalog(p, catLabel, () {
        HapticFeedback.lightImpact();
        setState(() {
          _activePresetTool = p.tool;
          _activePresetAmount = 1.0;
        });
        notifier.applyTool(p.tool);
        notifier.commit(label: 'Applied ${p.name}');
      }));
    }

    // 2. Community Hub presets
    final communityPresets = communityState.presets.where((preset) {
      if (_selectedCategory != 'All' &&
          _selectedCategory != 'Community' &&
          !_matchesCategory(preset.category, _selectedCategory)) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return preset.name.toLowerCase().contains(q) ||
            preset.description.toLowerCase().contains(q) ||
            preset.author.toLowerCase().contains(q) ||
            preset.tags.any((t) => t.toLowerCase().contains(q));
      }
      return true;
    });
    for (final preset in communityPresets) {
      if (seenNames.contains(preset.name.toLowerCase())) continue;
      seenNames.add(preset.name.toLowerCase());
      final communityTool = ToolDefinition(
        name: preset.name,
        description: preset.description,
        params: preset.params ?? const {},
      );
      allItems.add(_PresetItem.community(preset, () {
        HapticFeedback.lightImpact();
        setState(() {
          _activePresetTool = communityTool;
          _activePresetAmount = 1.0;
        });
        ref.read(communityPresetsProvider.notifier).applyPreset(ref, preset);
      }));
    }

    // 3. Fallback Builtins (if any extra exist in ToolLibrary)
    for (final tool in ToolLibrary.builtins) {
      if (seenNames.contains(tool.name.toLowerCase())) continue;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!tool.name.toLowerCase().contains(q) &&
            !tool.description.toLowerCase().contains(q)) {
          continue;
        }
      }
      allItems.add(_PresetItem.builtin(tool, 'Film', () {
        HapticFeedback.lightImpact();
        setState(() {
          _activePresetTool = tool;
          _activePresetAmount = 1.0;
        });
        notifier.applyTool(tool);
        notifier.commit(label: 'Applied ${tool.name}');
      }));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top compact header & actions bar
        Padding(
          padding: const EdgeInsets.fromLTRB(Insets.md, Insets.xs, Insets.md, Insets.xs),
          child: Row(
            children: [
              Icon(Icons.movie_filter_outlined, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                'Looks & Presets',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${allItems.length}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                key: const Key('preset-search-toggle'),
                icon: Icon(_searchOpen ? Icons.close : Icons.search, size: 18),
                tooltip: 'Search Presets',
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  setState(() {
                    _searchOpen = !_searchOpen;
                    if (!_searchOpen) _searchQuery = '';
                  });
                },
              ),
              IconButton(
                key: const Key('preset-scan-qr-btn'),
                icon: const Icon(Icons.qr_code_scanner, size: 18),
                tooltip: 'Scan QR Look',
                visualDensity: VisualDensity.compact,
                onPressed: () => showAppSheet(context, const LooksSheet()),
              ),
            ],
          ),
        ),
        if (_searchOpen)
          Padding(
            padding: const EdgeInsets.fromLTRB(Insets.md, 0, Insets.md, Insets.xs),
            child: SizedBox(
              height: 36,
              child: TextField(
                key: const Key('preset-search-input'),
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search movie looks, anime, film…',
                  prefixIcon: const Icon(Icons.search, size: 16),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 14),
                          onPressed: () => setState(() => _searchQuery = ''),
                        )
                      : null,
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.sm)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),
          ),
        // Horizontal category selector chips
        SizedBox(
          height: 36,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Insets.md),
            itemCount: _categories.length,
            itemBuilder: (context, idx) {
              final cat = _categories[idx];
              final selected = _selectedCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  key: Key('preset-cat-$cat'),
                  label: Text(cat, style: const TextStyle(fontSize: 11)),
                  selected: selected,
                  onSelected: (val) {
                    if (val) setState(() => _selectedCategory = cat);
                  },
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: Insets.xs),
        if (_activePresetTool != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.xs),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 4),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(Radii.sm),
                border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  Icon(Icons.tune, size: 16, color: scheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Strength ${(_activePresetAmount * 100).round()}%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                      ),
                      child: Slider(
                        key: const Key('preset-strength-slider'),
                        value: _activePresetAmount,
                        min: 0.0,
                        max: 2.0,
                        divisions: 40,
                        onChanged: (val) {
                          setState(() => _activePresetAmount = val);
                          notifier.applyTool(_activePresetTool!, amount: val);
                        },
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 14),
                    tooltip: 'Dismiss',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() => _activePresetTool = null),
                  ),
                ],
              ),
            ),
          ),
        // Horizontal film scroll view
        Expanded(
          child: allItems.isNotEmpty
              ? ListView.builder(
                  key: const Key('preset-filmstrip-list'),
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(Insets.md, Insets.xs, Insets.md, Insets.sm),
                  itemCount: allItems.length,
                  itemBuilder: (context, idx) {
                    final item = allItems[idx];
                    return _PresetStripItem(
                      item: item,
                      notifier: notifier,
                    );
                  },
                )
              : Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.style_outlined, size: 32, color: scheme.onSurfaceVariant),
                      const SizedBox(height: Insets.xs),
                      Text(
                        'No presets found in $_selectedCategory',
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

Parameter? _parameterByName(String name) {
  for (final p in Parameter.values) {
    if (p.name == name) return p;
  }
  return null;
}

bool _itemMatches(_PresetItem item, EditRecipe recipe) {
  if (item.params.isEmpty) return false;
  for (final entry in item.params.entries) {
    final param = _parameterByName(entry.key);
    if (param == null) continue;
    final current = valueOf(recipe, param);
    if ((current - entry.value).abs() > 0.01) return false;
  }
  return true;
}

/// Union of built-in looks and community presets for the cinema strip.
class _PresetItem {
  const _PresetItem._({
    required this.kind,
    required this.name,
    required this.description,
    required this.params,
    required this.category,
    required this.onTap,
    this.isApplied = false,
    this.tool,
    this.author,
    this.rating,
    this.reference,
    this.hasDepth = false,
    this.depthHint,
  });

  factory _PresetItem.catalog(
    PresetItem item,
    String category,
    VoidCallback onTap, {
    bool isApplied = false,
  }) {
    return _PresetItem._(
      kind: 'catalog',
      name: item.name,
      description: item.description,
      params: item.tool.params,
      category: category,
      isApplied: isApplied,
      onTap: onTap,
      tool: item.tool,
      reference: item.reference,
      hasDepth: item.hasDepth,
      depthHint: item.depthHint,
    );
  }

  factory _PresetItem.builtin(
    ToolDefinition tool,
    String category,
    VoidCallback onTap, {
    bool isApplied = false,
  }) {
    return _PresetItem._(
      kind: 'builtin',
      name: tool.name,
      description: tool.description,
      params: tool.params,
      category: category,
      isApplied: isApplied,
      onTap: onTap,
      tool: tool,
    );
  }

  factory _PresetItem.community(
    CommunityPreset preset,
    VoidCallback onTap, {
    bool isApplied = false,
  }) {
    final tool = ToolDefinition(
      name: preset.name,
      description: preset.description,
      params: preset.params ?? const {},
    );
    return _PresetItem._(
      kind: 'community',
      name: preset.name,
      description: preset.description,
      params: preset.params ?? const {},
      category: preset.category.isNotEmpty ? preset.category : 'Community',
      isApplied: isApplied,
      onTap: onTap,
      tool: tool,
      author: preset.author,
      rating: preset.rating,
    );
  }

  final String kind;
  final String name;
  final String description;
  final Map<String, double> params;
  final String category;
  final bool isApplied;
  final VoidCallback onTap;
  final ToolDefinition? tool;
  final String? author;
  final double? rating;
  final String? reference;
  final bool hasDepth;
  final String? depthHint;
}

/// Single cinema-strip preset card: large live thumbnail + name + applied badge.
class _PresetStripItem extends ConsumerWidget {
  const _PresetStripItem({
    required this.item,
    required this.notifier,
  });

  final _PresetItem item;
  final RecipeController notifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isApplied = ref.watch(
      recipeControllerProvider.select((s) => _itemMatches(item, s.recipe)),
    );
    final matrix = computePresetColorMatrix(item.params);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        item.onTap();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Applied look: ${item.name}'),
            duration: const Duration(seconds: 1),
          ),
        );
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: Insets.sm),
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(
            color: isApplied
                ? scheme.primary
                : scheme.outlineVariant.withValues(alpha: 0.4),
            width: isApplied ? 2 : 1,
          ),
          boxShadow: isApplied
              ? [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Live thumbnail
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.sm)),
                      child: ColorFiltered(
                        colorFilter: ColorFilter.matrix(matrix),
                        child: Image.memory(
                          ref.watch(activeImageBytesProvider) ?? Uint8List(0),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            color: scheme.surfaceContainerHighest,
                            child: Center(
                              child: Icon(
                                Icons.movie_filter_outlined,
                                size: 28,
                                color: scheme.primary.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (item.hasDepth)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.blur_on, size: 10, color: Colors.cyanAccent),
                            const SizedBox(width: 2),
                            Text(
                              item.depthHint ?? 'Depth',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (isApplied)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check, size: 10, color: Colors.white),
                            SizedBox(width: 2),
                            Text(
                              'ACTIVE',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Label + category/reference
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      color: isApplied ? scheme.primary : scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    item.reference ?? (item.author != null ? 'by ${item.author}' : item.category),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.0,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
