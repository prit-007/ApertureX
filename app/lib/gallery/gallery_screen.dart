import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../core/log/activity_log.dart';
import '../core/log/log_providers.dart';
import '../core/theme/design_tokens.dart';
import '../edit/library_catalog.dart';
import '../edit/recipe.dart';
import '../edit/recipe_store.dart';
import '../edit/settings_clipboard.dart';
import '../features/editor/editor_screen.dart';
import '../ui/common/app_primitives.dart';
import '../ui/common/app_sheet.dart';
import '../ui/common/settings_sheet.dart';
import 'gallery_asset.dart';
import 'gallery_controller.dart';
import 'gallery_export.dart';
import 'gallery_grouping.dart';
import 'gallery_source.dart';

/// The app home: the device gallery, grouped by date (newest first) with album
/// switching — Google-Photos style. Tap a photo to edit it; long-press to
/// multi-select, then batch-paste a recipe or export (#12, #13). Every photo
/// can have zero or more virtual copies (#73, #61), rendered right below it.
class GalleryScreen extends ConsumerStatefulWidget {
  const GalleryScreen({super.key});

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(galleryControllerProvider.notifier).load();
      // Restore the persisted library (virtual copies, edits, ratings) so the
      // first frame already shows the real library state (#61).
      unawaited(ref.read(libraryCatalogProvider.notifier).hydrate());
    });
  }

  GallerySource get _source => ref.read(gallerySourceProvider);

  void _open(GalleryAsset asset) {
    axLog(LogDomain.editor, 'Opened photo ${asset.id}');
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => EditorScreen(asset: asset)));
  }

  /// Opens [asset]'s pixels under a specific catalog entry — a virtual copy
  /// shares the original's data but carries its own recipe (#73).
  void _openEntry(GalleryAsset asset, String entryId) {
    axLog(LogDomain.editor, 'Opened $entryId');
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EditorScreen(asset: asset, entryId: entryId),
      ),
    );
  }

  void _openSample() {
    axLog(LogDomain.editor, 'Opened sample image');
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const EditorScreen()));
  }

  void _paste() {
    final state = ref.read(galleryControllerProvider);
    if (state.selected.isEmpty) return;
    final recipe = ref.read(settingsClipboardProvider) ?? EditRecipe.neutral;
    ref
        .read(recipeStoreProvider.notifier)
        .pasteTo(state.selected.map(originalEntryId), recipe);
    ref.read(galleryControllerProvider.notifier).clearSelection();
    _snack('Applied settings to ${state.selectedCount} photo(s)');
  }

  void _createVirtualCopies() {
    final state = ref.read(galleryControllerProvider);
    if (state.selected.isEmpty) return;
    final store = ref.read(recipeStoreProvider);
    final catalog = ref.read(libraryCatalogProvider.notifier);
    for (final assetId in state.selected) {
      // Seed each copy from the original's current recipe, Lightroom-style.
      catalog.createVirtualCopy(
        sourceAssetId: assetId,
        recipe: store[originalEntryId(assetId)] ?? EditRecipe.neutral,
      );
    }
    final created = state.selectedCount;
    ref.read(galleryControllerProvider.notifier).clearSelection();
    _snack('Created $created virtual ${created == 1 ? 'copy' : 'copies'}');
  }

  Future<void> _vcMenu(CatalogEntry entry, Offset position) async {
    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, 0, 0),
      items: const [
        PopupMenuItem(value: 'rename', child: Text('Rename')),
        PopupMenuItem(value: 'delete', child: Text('Delete')),
      ],
    );
    if (!mounted || action == null) return;
    final catalog = ref.read(libraryCatalogProvider.notifier);
    switch (action) {
      case 'rename':
        await _renameVc(entry);
      case 'delete':
        catalog.deleteVirtualCopy(entry.entryId);
        _snack('Deleted virtual copy');
    }
  }

  Future<void> _renameVc(CatalogEntry entry) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _RenameVcDialog(initial: entry.label),
    );
    if (name == null || name.isEmpty || !mounted) return;
    ref.read(libraryCatalogProvider.notifier).rename(entry.entryId, name);
  }

  Future<void> _export() async {
    final state = ref.read(galleryControllerProvider);
    if (state.selected.isEmpty) return;
    try {
      final count = await GalleryExporter(_source).exportBatch(
        state.selected,
        (id) =>
            ref.read(recipeStoreProvider)[originalEntryId(id)] ??
            EditRecipe.neutral,
      );
      ref.read(galleryControllerProvider.notifier).clearSelection();
      _snack('Exported $count photo(s) to your gallery');
    } catch (e) {
      _snack('Export failed: $e');
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _openAlbumPicker() => showAppSheet(context, const _AlbumSheet());

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(galleryControllerProvider);
    final controller = ref.read(galleryControllerProvider.notifier);

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: state.selectionMode
              ? Text('${state.selectedCount} selected')
              : _AlbumTitle(title: state.title, onTap: _openAlbumPicker),
          actions: [
            if (state.selectionMode)
              IconButton(
                tooltip: 'Clear selection',
                onPressed: controller.clearSelection,
                icon: const Icon(Icons.close),
              )
            else ...[
              IconButton(
                tooltip: 'Select',
                onPressed: controller.selectAll,
                icon: const Icon(Icons.checklist),
              ),
              IconButton(
                tooltip: 'Settings',
                onPressed: () => showAppSheet(context, const SettingsSheet()),
                icon: const Icon(Icons.more_vert),
              ),
            ],
          ],
        ),
        body: _body(state, controller),
        bottomNavigationBar: state.selectionMode
            ? _SelectionBar(
                onVirtualCopy: _createVirtualCopies,
                onPaste: _paste,
                onExport: _export,
              )
            : null,
      ),
    );
  }

  Widget _body(GalleryState state, GalleryController controller) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.permissionDenied && state.assets.isEmpty) {
      return EmptyState(
        icon: Icons.photo_library_outlined,
        title: 'ApertureX needs your photos',
        message:
            'Allow photo access to browse and edit your library. '
            'You can change this any time in settings.',
        action: Wrap(
          spacing: Insets.sm,
          runSpacing: Insets.xs,
          alignment: WrapAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: controller.requestAccessAgain,
              icon: const Icon(Icons.lock_open, size: 18),
              label: const Text('Allow access'),
            ),
            OutlinedButton(
              onPressed: () {
                axLog(LogDomain.permission, 'Opened app settings');
                controller.openSettings();
              },
              child: const Text('Open settings'),
            ),
            TextButton(
              onPressed: _openSample,
              child: const Text('Open a sample'),
            ),
          ],
        ),
      );
    }
    if (state.error != null) {
      return EmptyState(
        icon: Icons.no_photography_outlined,
        title: 'Can’t read your gallery',
        message: state.error,
        action: Wrap(
          spacing: Insets.sm,
          alignment: WrapAlignment.center,
          children: [
            FilledButton.tonal(
              onPressed: controller.load,
              child: const Text('Retry'),
            ),
            TextButton(
              onPressed: _openSample,
              child: const Text('Open a sample'),
            ),
          ],
        ),
      );
    }
    if (state.assets.isEmpty) {
      return EmptyState(
        icon: Icons.photo_library_outlined,
        title: 'No photos here',
        message:
            'Photos on your device will appear here. '
            'Or try the editor with a sample image.',
        action: FilledButton.tonal(
          onPressed: _openSample,
          child: const Text('Open a sample'),
        ),
      );
    }

    final rows = buildGalleryRows(state.assets);
    return CustomScrollView(slivers: _slivers(rows, state));
  }

  List<Widget> _slivers(List<GalleryRow> rows, GalleryState state) {
    final controller = ref.read(galleryControllerProvider.notifier);
    final recipes = ref.watch(recipeStoreProvider);
    // Watch the catalog so creating/deleting a copy rebuilds the grid, and
    // resolve the per-photo copy lists (sorted oldest-first) once per build.
    ref.watch(libraryCatalogProvider);
    final vcsBySource = ref
        .read(libraryCatalogProvider.notifier)
        .virtualCopiesBySource();
    final slivers = <Widget>[];
    var i = 0;
    while (i < rows.length) {
      final row = rows[i];
      if (row is GalleryDateHeader) {
        slivers.add(SliverToBoxAdapter(child: _DateHeader(label: row.label)));
        i++;
        final photos = <GalleryAsset>[];
        while (i < rows.length && rows[i] is GalleryPhoto) {
          photos.add((rows[i] as GalleryPhoto).asset);
          i++;
        }
        // Expand each photo into its original cell followed by one cell per
        // virtual copy — the copies live "under" their source, Lightroom-style.
        final items = <_GridItem>[
          for (final asset in photos) ...[
            _OriginalItem(asset),
            for (final copy in vcsBySource[asset.id] ?? const <CatalogEntry>[])
              _VirtualItem(copy, asset),
          ],
        ];
        slivers.add(
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
              ),
              itemCount: items.length,
              itemBuilder: (context, j) => switch (items[j]) {
                _OriginalItem(:final asset) => _Cell(
                  source: _source,
                  asset: asset,
                  selected: state.isSelected(asset.id),
                  edited: recipes.containsKey(originalEntryId(asset.id)),
                  copyCount: vcsBySource[asset.id]?.length ?? 0,
                  selectionMode: state.selectionMode,
                  onTap: () => state.selectionMode
                      ? controller.toggle(asset.id)
                      : _open(asset),
                  onLongPress: () => controller.startSelection(asset.id),
                ),
                _VirtualItem(:final entry, :final asset) => _VirtualCell(
                  source: _source,
                  asset: asset,
                  entry: entry,
                  selected: state.isSelected(asset.id),
                  edited: recipes.containsKey(entry.entryId),
                  selectionMode: state.selectionMode,
                  onTap: () => state.selectionMode
                      ? controller.toggle(asset.id)
                      : _openEntry(asset, entry.entryId),
                  onLongPressStart: (details) => state.selectionMode
                      ? controller.startSelection(asset.id)
                      : _vcMenu(entry, details.globalPosition),
                ),
              },
            ),
          ),
        );
      } else {
        i++;
      }
    }
    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: Insets.lg)));
    return slivers;
  }
}

/// One grid slot: the photo itself, or a virtual copy of it.
sealed class _GridItem {
  const _GridItem();
}

final class _OriginalItem extends _GridItem {
  const _OriginalItem(this.asset);

  final GalleryAsset asset;
}

final class _VirtualItem extends _GridItem {
  const _VirtualItem(this.entry, this.asset);

  final CatalogEntry entry;
  final GalleryAsset asset;
}

class _AlbumTitle extends StatelessWidget {
  const _AlbumTitle({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: Radii.smAll,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.md,
        Insets.lg,
        Insets.md,
        Insets.sm,
      ),
      child: Text(
        label,
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.source,
    required this.asset,
    required this.selected,
    required this.edited,
    required this.selectionMode,
    required this.onTap,
    required this.onLongPress,
    this.copyCount = 0,
  });

  final GallerySource source;
  final GalleryAsset asset;
  final bool selected;
  final bool edited;
  final bool selectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  /// How many virtual copies this photo has (0 = none) — surfaced as a small
  /// count chip so an expanded photo is obvious at a glance (#73).
  final int copyCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Photo',
      button: true,
      selected: selected,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Stack(
          fit: StackFit.expand,
          children: [
            GalleryThumbnail(source: source, assetId: asset.id),
            AnimatedOpacity(
              opacity: selected ? 1 : 0,
              duration: Motion.fast,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: scheme.primary, width: 3),
                  color: scheme.primary.withValues(alpha: 0.22),
                ),
              ),
            ),
            if (edited && !selectionMode)
              Positioned(
                left: 4,
                bottom: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: Icon(Icons.tune, size: 12, color: scheme.onPrimary),
                  ),
                ),
              ),
            if (copyCount > 0 && !selectionMode)
              Positioned(
                right: 4,
                bottom: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surface.withValues(alpha: 0.85),
                    borderRadius: Radii.smAll,
                  ),
                  child: Padding(
                    key: Key('copy-count-${asset.id}'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    child: Text(
                      '×$copyCount',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ),
              ),
            if (selectionMode)
              Positioned(
                right: 4,
                top: 4,
                child: Icon(
                  selected ? Icons.check_circle : Icons.circle_outlined,
                  size: 22,
                  color: selected ? scheme.primary : Colors.white70,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A virtual copy of a photo: same pixels (its thumbnail requests resolve to
/// [GalleryAsset.id]), its own recipe and entry id, a `VC` badge, and a
/// long-press menu for rename/delete (#73).
class _VirtualCell extends StatelessWidget {
  const _VirtualCell({
    required this.source,
    required this.asset,
    required this.entry,
    required this.selected,
    required this.edited,
    required this.selectionMode,
    required this.onTap,
    required this.onLongPressStart,
  });

  final GallerySource source;
  final GalleryAsset asset;
  final CatalogEntry entry;
  final bool selected;
  final bool edited;
  final bool selectionMode;
  final VoidCallback onTap;
  final GestureLongPressStartCallback onLongPressStart;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Virtual copy',
      button: true,
      selected: selected,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        onLongPressStart: onLongPressStart,
        child: Stack(
          fit: StackFit.expand,
          children: [
            GalleryThumbnail(source: source, assetId: entry.sourceAssetId),
            AnimatedOpacity(
              opacity: selected ? 1 : 0,
              duration: Motion.fast,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: scheme.primary, width: 3),
                  color: scheme.primary.withValues(alpha: 0.22),
                ),
              ),
            ),
            Positioned(
              left: 4,
              top: 4,
              child: DecoratedBox(
                key: Key('vc-badge-${entry.entryId}'),
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer.withValues(alpha: 0.95),
                  borderRadius: Radii.smAll,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  child: Text(
                    'VC',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSecondaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            if (edited && !selectionMode)
              Positioned(
                left: 4,
                bottom: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: Icon(Icons.tune, size: 12, color: scheme.onPrimary),
                  ),
                ),
              ),
            if (selectionMode)
              Positioned(
                right: 4,
                top: 4,
                child: Icon(
                  selected ? Icons.check_circle : Icons.circle_outlined,
                  size: 22,
                  color: selected ? scheme.primary : Colors.white70,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A thumbnail that resolves **once** per asset (the previous implementation
/// re-decoded on every rebuild — a major jank source), and decodes at the
/// displayed pixel size ([cacheWidth]) so the codec never inflates a big bitmap.
class GalleryThumbnail extends StatefulWidget {
  const GalleryThumbnail({
    super.key,
    required this.source,
    required this.assetId,
    this.size = 512,
  });

  final GallerySource source;
  final String assetId;
  final int size;

  @override
  State<GalleryThumbnail> createState() => _GalleryThumbnailState();
}

class _GalleryThumbnailState extends State<GalleryThumbnail> {
  late Future<Uint8List> _future = _load();

  Future<Uint8List> _load() =>
      widget.source.loadThumbnail(widget.assetId, size: widget.size);

  @override
  void didUpdateWidget(GalleryThumbnail old) {
    super.didUpdateWidget(old);
    if (old.assetId != widget.assetId || old.source != widget.source) {
      _future = _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final w = constraints.maxWidth;
        final cacheWidth = w.isFinite && w > 0 ? (w * dpr).round() : null;
        return FutureBuilder<Uint8List>(
          future: _future,
          builder: (context, snapshot) {
            final bytes = snapshot.data;
            if (bytes == null || bytes.isEmpty) {
              return ColoredBox(
                color: scheme.surfaceContainerHigh,
                child: Icon(
                  Icons.image_outlined,
                  color: scheme.onSurfaceVariant,
                ),
              );
            }
            return Image.memory(
              bytes,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              cacheWidth: cacheWidth,
            );
          },
        );
      },
    );
  }
}

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.onVirtualCopy,
    required this.onPaste,
    required this.onExport,
  });

  final VoidCallback onVirtualCopy;
  final VoidCallback onPaste;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      child: Row(
        children: [
          const Spacer(),
          TextButton.icon(
            key: const Key('virtual-copy-action'),
            onPressed: onVirtualCopy,
            icon: const Icon(Icons.copy_all_outlined, size: 18),
            label: const Text('Virtual copy'),
          ),
          const SizedBox(width: Insets.sm),
          TextButton.icon(
            onPressed: onPaste,
            icon: const Icon(Icons.paste),
            label: const Text('Paste'),
          ),
          const SizedBox(width: Insets.sm),
          FilledButton.tonalIcon(
            onPressed: onExport,
            icon: const Icon(Icons.ios_share, size: 18),
            label: const Text('Export'),
          ),
        ],
      ),
    );
  }
}

/// Rename prompt for a virtual copy. Owns its [TextEditingController] so the
/// dialog can dispose it in its own `dispose` — popping the route keeps the
/// field mounted until the exit transition ends.
class _RenameVcDialog extends StatefulWidget {
  const _RenameVcDialog({this.initial});

  final String? initial;

  @override
  State<_RenameVcDialog> createState() => _RenameVcDialogState();
}

class _RenameVcDialogState extends State<_RenameVcDialog> {
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

/// Album picker: the default "Recent" stream plus every device album.
class _AlbumSheet extends ConsumerWidget {
  const _AlbumSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(galleryControllerProvider);
    final controller = ref.read(galleryControllerProvider.notifier);
    final source = ref.read(gallerySourceProvider);

    Widget tile(
      String? id,
      String name,
      String? coverAssetId,
      int count, {
      required bool selected,
    }) => ListTile(
      selected: selected,
      leading: SizedBox(
        width: 48,
        height: 48,
        child: ClipRRect(
          borderRadius: Radii.smAll,
          child: coverAssetId == null
              ? ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  child: const Icon(Icons.photo_album_outlined, size: 20),
                )
              : GalleryThumbnail(
                  source: source,
                  assetId: coverAssetId,
                  size: 96,
                ),
        ),
      ),
      title: Text(name),
      subtitle: Text('$count'),
      onTap: () {
        controller.selectAlbum(id);
        Navigator.of(context).maybePop();
      },
    );

    return AppSheet(
      title: 'Albums',
      children: [
        tile(
          null,
          'Recent',
          null,
          state.assets.length,
          selected: state.selectedAlbumId == null,
        ),
        for (final album in state.albums)
          tile(
            album.id,
            album.name,
            album.coverAssetId,
            album.count,
            selected: album.id == state.selectedAlbumId,
          ),
      ],
    );
  }
}
