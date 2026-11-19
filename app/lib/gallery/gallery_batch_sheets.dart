import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/design_tokens.dart';
import '../features/presets/preset_catalog.dart';
import '../ui/common/app_sheet.dart';
import 'gallery_controller.dart';
import 'gallery_screen.dart';

/// Modal dialog for renaming a virtual copy.
class RenameVcDialog extends StatefulWidget {
  const RenameVcDialog({super.key, this.initial});

  final String? initial;

  @override
  State<RenameVcDialog> createState() => _RenameVcDialogState();
}

class _RenameVcDialogState extends State<RenameVcDialog> {
  late final TextEditingController _field = TextEditingController(
    text: widget.initial ?? 'Virtual copy',
  );

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename virtual copy'),
      content: TextField(controller: _field, autofocus: true),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _field.text.trim()),
          child: const Text('Rename'),
        ),
      ],
    );
  }
}

/// Sheet for managing batch keywords across selected photos.
class KeywordsSheet extends StatefulWidget {
  const KeywordsSheet({
    super.key,
    required this.selectedCount,
    required this.initialKeywords,
    required this.onAddKeyword,
    required this.onRemoveKeyword,
  });

  final int selectedCount;
  final List<String> initialKeywords;
  final ValueChanged<String> onAddKeyword;
  final ValueChanged<String> onRemoveKeyword;

  @override
  State<KeywordsSheet> createState() => _KeywordsSheetState();
}

class _KeywordsSheetState extends State<KeywordsSheet> {
  late final List<String> _keywords = List.of(widget.initialKeywords);
  final _textController = TextEditingController();

  void _add() {
    final text = _textController.text.trim();
    if (text.isNotEmpty && !_keywords.contains(text)) {
      widget.onAddKeyword(text);
      setState(() {
        _keywords.add(text);
        _keywords.sort();
      });
      _textController.clear();
    }
  }

  void _remove(String kw) {
    widget.onRemoveKeyword(kw);
    setState(() => _keywords.remove(kw));
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: Insets.md,
        right: Insets.md,
        top: Insets.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + Insets.md,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Manage Keywords (${widget.selectedCount} selected)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: Insets.sm),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('keyword-input'),
                    controller: _textController,
                    decoration: const InputDecoration(
                      hintText: 'Enter keyword…',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _add(),
                  ),
                ),
                const SizedBox(width: Insets.sm),
                FilledButton(
                  key: const Key('add-keyword-button'),
                  onPressed: _add,
                  child: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: Insets.sm),
            if (_keywords.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final kw in _keywords)
                    Chip(
                      key: Key('keyword-chip-$kw'),
                      label: Text(kw),
                      deleteIcon: const Icon(Icons.close, size: 14),
                      onDeleted: () => _remove(kw),
                    ),
                ],
              )
            else
              const Padding(
                padding: EdgeInsets.symmetric(vertical: Insets.sm),
                child: Text(
                  'No keywords assigned to selected photos.',
                  style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Sheet for batch applying looks/presets across multiple assets.
class BatchPresetSheet extends StatefulWidget {
  const BatchPresetSheet({
    super.key,
    required this.selectedCount,
    required this.onApplyPreset,
  });

  final int selectedCount;
  final void Function(PresetItem preset, double amount) onApplyPreset;

  @override
  State<BatchPresetSheet> createState() => _BatchPresetSheetState();
}

class _BatchPresetSheetState extends State<BatchPresetSheet> {
  PresetCategory _selectedCategory = PresetCategory.all;
  double _strength = 1.0;
  late PresetItem _selectedPreset = PresetCatalog.allPresets.first;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<PresetItem> get _filteredPresets {
    if (_searchQuery.isNotEmpty) {
      return PresetCatalog.search(_searchQuery, category: _selectedCategory);
    }
    return PresetCatalog.getByCategory(_selectedCategory);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final presets = _filteredPresets;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: Insets.sm),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Apply Look (${widget.selectedCount} selected)',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: Insets.xs),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search looks…',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                ),
                onChanged: (q) => setState(() => _searchQuery = q.trim()),
              ),
              const SizedBox(height: Insets.xs),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final cat in PresetCategory.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          selected: _selectedCategory == cat,
                          label: Text(cat.label),
                          onSelected: (sel) {
                            if (sel) setState(() => _selectedCategory = cat);
                          },
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: Insets.xs),
              Row(
                children: [
                  Text(
                    'Strength: ${(_strength * 100).round()}%',
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Expanded(
                    child: Slider(
                      value: _strength,
                      min: 0.0,
                      max: 2.0,
                      divisions: 20,
                      label: '${(_strength * 100).round()}%',
                      onChanged: (v) => setState(() => _strength = v),
                    ),
                  ),
                ],
              ),
              const Divider(height: 1),
              Expanded(
                child: presets.isEmpty
                    ? Center(
                        child: Text(
                          'No looks found matching "$_searchQuery"',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: presets.length,
                        itemBuilder: (context, i) {
                          final p = presets[i];
                          final isSelected = p.id == _selectedPreset.id;
                          return ListTile(
                            key: Key('preset-item-${p.id}'),
                            selected: isSelected,
                            selectedTileColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            leading: CircleAvatar(
                              backgroundColor: isSelected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.surfaceContainerHighest,
                              child: Icon(
                                isSelected ? Icons.check : Icons.palette_outlined,
                                size: 18,
                                color: isSelected
                                    ? theme.colorScheme.onPrimary
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            title: Text(
                              p.name,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              '${p.category.label} • ${p.reference.isNotEmpty ? p.reference : p.description}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => setState(() => _selectedPreset = p),
                          );
                        },
                      ),
              ),
              const SizedBox(height: Insets.sm),
              FilledButton.icon(
                key: const Key('apply-preset-confirm-button'),
                icon: const Icon(Icons.check),
                label: Text('Apply "${_selectedPreset.name}" to ${widget.selectedCount} Photo(s)'),
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onApplyPreset(_selectedPreset, _strength);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Album picker: the default "Recent" stream plus every device album.
class AlbumSheet extends ConsumerWidget {
  const AlbumSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(galleryControllerProvider);
    final controller = ref.read(galleryControllerProvider.notifier);
    final source = ref.read(gallerySourceProvider);
    final scheme = Theme.of(context).colorScheme;

    Widget albumTile({
      required String? id,
      required String name,
      required String? coverAssetId,
      required int count,
      required bool selected,
      bool isAllPhotos = false,
    }) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: 3),
      child: Material(
        color: selected
            ? scheme.primaryContainer.withValues(alpha: 0.35)
            : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: selected
              ? BorderSide(color: scheme.primary.withValues(alpha: 0.5), width: 1.2)
              : BorderSide.none,
        ),
        child: ListTile(
          selected: selected,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          leading: SizedBox(
            width: 52,
            height: 52,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: coverAssetId == null
                  ? Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isAllPhotos
                              ? [scheme.primary, scheme.tertiary]
                              : [
                                  scheme.surfaceContainerHigh,
                                  scheme.surfaceContainerHighest,
                                ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Icon(
                        isAllPhotos ? Icons.photo_library : Icons.folder_outlined,
                        color: isAllPhotos ? scheme.onPrimary : scheme.onSurfaceVariant,
                        size: 24,
                      ),
                    )
                  : GalleryThumbnail(
                      source: source,
                      assetId: coverAssetId,
                      size: 104,
                    ),
            ),
          ),
          title: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              fontSize: 15,
            ),
          ),
          subtitle: Text(
            count == 1 ? '1 photo' : '$count photos',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: selected ? scheme.primary : scheme.onSurfaceVariant,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          trailing: selected
              ? Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.check, size: 16, color: scheme.onPrimary),
                )
              : null,
          onTap: () {
            controller.selectAlbum(id);
            Navigator.of(context).maybePop();
          },
        ),
      ),
    );

    return AppSheet(
      title: 'Albums',
      children: [
        albumTile(
          id: null,
          name: 'Recent & All Photos',
          coverAssetId: state.assets.isNotEmpty ? state.assets.first.id : null,
          count: state.assets.length,
          selected: state.selectedAlbumId == null,
          isAllPhotos: true,
        ),
        if (state.albums.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(Insets.md, Insets.sm, Insets.md, Insets.xs),
            child: Divider(height: 1),
          ),
          for (final album in state.albums)
            albumTile(
              id: album.id,
              name: album.name,
              coverAssetId: album.coverAssetId,
              count: album.count,
              selected: album.id == state.selectedAlbumId,
            ),
        ],
      ],
    );
  }
}
