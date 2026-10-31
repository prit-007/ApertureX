import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';
import 'tool_guide_model.dart';
import 'tool_guide_registry.dart';

/// Full-screen interactive user guide and learning academy for ApertureX.
class AppGuideScreen extends StatefulWidget {

  const AppGuideScreen({
    super.key,
    this.initialToolId,
    this.initialCategory,
    this.onSelectTool,
    this.isModal = false,
  });
  final String? initialToolId;
  final ToolCategory? initialCategory;
  final ValueChanged<String>? onSelectTool;
  final bool isModal;

  /// Opens the guide as a modal bottom sheet.
  static Future<void> showModal(
    BuildContext context, {
    String? initialToolId,
    ToolCategory? initialCategory,
    ValueChanged<String>? onSelectTool,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AppGuideScreen(
        initialToolId: initialToolId,
        initialCategory: initialCategory,
        onSelectTool: onSelectTool,
        isModal: true,
      ),
    );
  }

  @override
  State<AppGuideScreen> createState() => _AppGuideScreenState();
}

class _AppGuideScreenState extends State<AppGuideScreen> {
  final TextEditingController _searchController = TextEditingController();
  ToolCategory? _selectedCategory;
  String? _expandedToolId;

  @override
  void initState() {
    super.initState();
    _expandedToolId = widget.initialToolId;
    if (widget.initialCategory != null) {
      _selectedCategory = widget.initialCategory;
    } else if (widget.initialToolId != null) {
      final g = ToolGuideRegistry.getById(widget.initialToolId!);
      if (g != null) {
        _selectedCategory = g.category;
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ToolGuideModel> _getFilteredGuides() {
    List<ToolGuideModel> list;
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      list = ToolGuideRegistry.search(query);
    } else if (_selectedCategory != null) {
      list = ToolGuideRegistry.getByCategory(_selectedCategory!);
    } else {
      list = ToolGuideRegistry.allGuides;
    }

    if (_selectedCategory != null && query.isNotEmpty) {
      list = list.where((g) => g.category == _selectedCategory).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final guides = _getFilteredGuides();

    final content = Column(
      children: [
        if (widget.isModal) ...[
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: Insets.sm, bottom: Insets.xs),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: Radii.pillAll,
              ),
            ),
          ),
          // Modal Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.lg, vertical: Insets.xs),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(Insets.xs),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.school_outlined, size: 20, color: scheme.onPrimaryContainer),
                ),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ApertureX Academy',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'Interactive tool masterclasses & pro tips',
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
        ],

        // Search Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(Insets.md, Insets.sm, Insets.md, Insets.xs),
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search tools, gestures, pro tips…',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    )
                  : null,
              isDense: true,
              filled: true,
              fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
            ),
          ),
        ),

        // Category Filter Chips
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: 6),
            children: [
              FilterChip(
                label: const Text('All'),
                selected: _selectedCategory == null,
                onSelected: (_) => setState(() => _selectedCategory = null),
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: Insets.xs),
              for (final cat in ToolCategory.values) ...[
                FilterChip(
                  avatar: Icon(cat.icon, size: 16),
                  label: Text(cat.label),
                  selected: _selectedCategory == cat,
                  onSelected: (selected) => setState(() => _selectedCategory = selected ? cat : null),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: Insets.xs),
              ],
            ],
          ),
        ),

        // Guides List
        Expanded(
          child: guides.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 48, color: scheme.onSurfaceVariant),
                      const SizedBox(height: Insets.sm),
                      Text(
                        'No matching guides found',
                        style: theme.textTheme.titleSmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(Insets.md),
                  itemCount: guides.length,
                  separatorBuilder: (_, _) => const SizedBox(height: Insets.sm),
                  itemBuilder: (context, index) {
                    final guide = guides[index];
                    final isExpanded = _expandedToolId == guide.id;

                    return _ToolGuideCard(
                      guide: guide,
                      isExpanded: isExpanded,
                      onToggle: () {
                        setState(() {
                          _expandedToolId = isExpanded ? null : guide.id;
                        });
                      },
                      onSelectTool: widget.onSelectTool != null
                          ? () {
                              if (widget.isModal) Navigator.of(context).maybePop();
                              widget.onSelectTool!(guide.id);
                            }
                          : null,
                    );
                  },
                ),
        ),
      ],
    );

    if (widget.isModal) {
      final size = MediaQuery.of(context).size;
      return Container(
        height: size.height * 0.85,
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: content,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('ApertureX Academy'),
        centerTitle: false,
      ),
      body: content,
    );
  }
}

class _ToolGuideCard extends StatefulWidget {
  const _ToolGuideCard({
    required this.guide,
    required this.isExpanded,
    required this.onToggle,
    this.onSelectTool,
  });

  final ToolGuideModel guide;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback? onSelectTool;

  @override
  State<_ToolGuideCard> createState() => _ToolGuideCardState();
}

class _ToolGuideCardState extends State<_ToolGuideCard> {
  late double _demoValue;

  @override
  void initState() {
    super.initState();
    _demoValue = widget.guide.demoDefault ?? 0.0;
  }

  @override
  void didUpdateWidget(_ToolGuideCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.guide.id != widget.guide.id) {
      _demoValue = widget.guide.demoDefault ?? 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final guide = widget.guide;
    final isExpanded = widget.isExpanded;

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isExpanded
              ? scheme.primary.withValues(alpha: 0.6)
              : scheme.outlineVariant.withValues(alpha: 0.4),
          width: isExpanded ? 1.5 : 1.0,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onToggle,
        child: Padding(
          padding: const EdgeInsets.all(Insets.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(Insets.sm),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(guide.icon, color: scheme.primary, size: 22),
                  ),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                guide.title,
                                style: theme.textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.secondaryContainer,
                                borderRadius: Radii.pillAll,
                              ),
                              child: Text(
                                guide.category.label,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: scheme.onSecondaryContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          guide.summary,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Insets.xs),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),

              // Expanded Detailed Body
              if (isExpanded) ...[
                const SizedBox(height: Insets.md),
                const Divider(height: 1),
                const SizedBox(height: Insets.sm),

                // Full Description
                Text(
                  guide.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: Insets.md),

                // Interactive Simulator / Sandbox (if demo bounds exist)
                if (guide.demoMin != null && guide.demoMax != null) ...[
                  Container(
                    padding: const EdgeInsets.all(Insets.sm),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.tune,
                                  size: 16,
                                  color: scheme.primary,
                                ),
                                const SizedBox(width: Insets.xs),
                                Text(
                                  'Interactive Simulator',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: scheme.primary,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Text(
                                  '${_demoValue > 0 && (guide.demoUnit ?? '').contains('EV') ? '+' : ''}${_demoValue.toStringAsFixed(_demoValue.truncateToDouble() == _demoValue ? 0 : 1)}${guide.demoUnit ?? ''}',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                if (widget.guide.demoDefault != null &&
                                    _demoValue != widget.guide.demoDefault)
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 24,
                                      minHeight: 24,
                                    ),
                                    icon: const Icon(Icons.refresh, size: 14),
                                    tooltip: 'Reset simulator',
                                    onPressed: () {
                                      setState(() {
                                        _demoValue = widget.guide.demoDefault!;
                                      });
                                    },
                                  ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: Insets.xs),
                        // Live interactive swatch gradient
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            height: 36,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: scheme.outlineVariant.withValues(alpha: 0.4),
                              ),
                              gradient: LinearGradient(
                                colors: [
                                  scheme.surface.withValues(
                                    alpha: (0.4 + (_demoValue / (guide.demoMax! * 2)))
                                        .clamp(0.15, 0.95),
                                  ),
                                  scheme.primary.withValues(
                                    alpha: (0.4 + (_demoValue / (guide.demoMax! * 2)))
                                        .clamp(0.2, 0.95),
                                  ),
                                  scheme.surfaceContainerHighest.withValues(
                                    alpha: (0.4 + (_demoValue / (guide.demoMax! * 2)))
                                        .clamp(0.15, 0.95),
                                  ),
                                ],
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'Simulated Output',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurface,
                                  shadows: [
                                    Shadow(
                                      color: scheme.surface.withValues(alpha: 0.6),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Slider(
                          value: _demoValue.clamp(guide.demoMin!, guide.demoMax!),
                          min: guide.demoMin!,
                          max: guide.demoMax!,
                          onChanged: (val) {
                            setState(() => _demoValue = val);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Insets.md),
                ],

                // Best Used For Banner
                Container(
                  padding: const EdgeInsets.all(Insets.sm),
                  decoration: BoxDecoration(
                    color: scheme.tertiaryContainer.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: scheme.tertiary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.stars_outlined, size: 18, color: scheme.tertiary),
                      const SizedBox(width: Insets.xs + 2),
                      Expanded(
                        child: Text(
                          'Best for: ${guide.bestUsedFor}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onTertiaryContainer,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Insets.md),

                // Pro Tips
                Text(
                  'Pro Tips:',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: Insets.xs),
                for (final tip in guide.proTips) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          size: 16,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: Insets.xs + 2),
                        Expanded(
                          child: Text(
                            tip,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (guide.shortcut != null) ...[
                  const SizedBox(height: Insets.xs),
                  Row(
                    children: [
                      Icon(
                        Icons.keyboard_outlined,
                        size: 16,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: Insets.xs),
                      Text(
                        'Shortcut: ${guide.shortcut}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ],

                if (widget.onSelectTool != null) ...[
                  const SizedBox(height: Insets.md),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonalIcon(
                      onPressed: widget.onSelectTool,
                      icon: const Icon(Icons.arrow_forward, size: 16),
                      label: const Text('Try in Editor'),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
