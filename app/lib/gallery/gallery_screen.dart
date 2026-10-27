import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:material_ui/material_ui.dart';

import '../core/log/activity_log.dart';
import '../core/log/log_providers.dart';
import '../core/theme/design_tokens.dart';
import '../edit/library_catalog.dart';
import '../edit/recipe.dart';
import '../edit/recipe_store.dart';
import '../edit/settings_clipboard.dart';
import '../features/editor/editor_screen.dart';
import '../settings/settings_screen.dart';
import '../ui/common/app_primitives.dart';
import '../ui/common/app_sheet.dart';
import 'edit_preview_store.dart';
import 'edited_versions_screen.dart';
import 'folder_gallery_source.dart';
import 'gallery_asset.dart';
import 'gallery_controller.dart';
import 'gallery_export.dart';
import 'gallery_grouping.dart';
import 'gallery_source.dart';
import 'hdr_merge_sheet.dart';
import 'staggered_photo_grid.dart';

/// Which gallery scope is displayed (#85).
enum GalleryScope { photos, edits }

/// The app home: the device gallery, grouped by date (newest first) with album
/// switching — Google-Photos style. Tap a photo to edit it; long-press to
/// multi-select, then batch-paste a recipe or export (#12, #13). Every photo
/// can have zero or more virtual copies (#73, #61), rendered right below it.
class GalleryScreen extends ConsumerStatefulWidget {
  const GalleryScreen({super.key});

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen>
    with SingleTickerProviderStateMixin {
  GalleryScope _scope = GalleryScope.photos;

  /// Non-null while a batch export runs — owns the cooperative cancel and
  /// drives the bottom-bar progress UI (#75).
  BatchCancel? _exportCancel;

  /// Live aggregator: `(done + Σ in-flight fractions) / total`, so the bar
  /// creeps forward *within* a long item instead of freezing until it
  /// finishes.
  BatchProgressAggregator? _exportAgg;
  int _exportDone = 0;
  int _exportTotal = 0;
  final Set<String> _exportingIds = <String>{};
  final Set<String> _exportedIds = <String>{};

  /// Fades the AppBar + SelectionBar out during the hero flight into the
  /// editor so only the photo moves (issue: buttery gallery→editor transition).
  late final AnimationController _navFade;
  double get _navOpacity => _navFade.value;

  @override
  void initState() {
    super.initState();
    _navFade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(galleryControllerProvider.notifier).load();
      // Restore the persisted library (virtual copies, edits, ratings) so the
      // first frame already shows the real library state (#61).
      unawaited(ref.read(libraryCatalogProvider.notifier).hydrate());
    });
  }

  @override
  void dispose() {
    _navFade.dispose();
    super.dispose();
  }

  GallerySource get _source => ref.read(gallerySourceProvider);

  /// Runs the native folder dialog for the desktop library and reloads the
  /// grid (#103). A cancelled pick leaves the current state untouched.
  Future<void> _pickFolder() async {
    final source = _source;
    if (source is! FolderGallerySource) return;
    final picked = await source.pickRoot();
    if (!picked) return;
    axLog(LogDomain.app, 'Desktop library root: ${source.rootPath}');
    if (mounted) {
      await ref.read(galleryControllerProvider.notifier).load();
    }
  }

  void _open(GalleryAsset asset) async {
    axLog(LogDomain.editor, 'Opened photo ${asset.id}');
    // Fade chrome out as the photo begins its hero flight into the editor.
    await _navFade.forward();
    if (!mounted) return;
    final navigator = Navigator.of(context);
    final res = await navigator.push<dynamic>(
      PageRouteBuilder<dynamic>(
        transitionDuration: const Duration(milliseconds: 400),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, _, _) => EditorScreen(asset: asset),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.fastOutSlowIn,
            ),
            child: child,
          );
        },
      ),
    );
    // Fade chrome back in when returning from the editor.
    if (mounted) await _navFade.reverse();
    if (res == 'show_edits' && mounted) {
      setState(() => _scope = GalleryScope.edits);
    }
  }

  /// Opens [asset]'s pixels under a specific catalog entry — a virtual copy
  /// shares the original's data but carries its own recipe (#73).
  void _openEntry(GalleryAsset asset, String entryId) async {
    axLog(LogDomain.editor, 'Opened $entryId');
    final res = await Navigator.of(context).push<dynamic>(
      PageRouteBuilder<dynamic>(
        transitionDuration: const Duration(milliseconds: 400),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, _, _) => EditorScreen(asset: asset, entryId: entryId),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.fastOutSlowIn,
            ),
            child: child,
          );
        },
      ),
    );
    if (res == 'show_edits' && mounted) {
      setState(() => _scope = GalleryScope.edits);
    }
  }

  void _openSavedPreview(EditPreview preview) async {
    final file = File(preview.path);
    if (!file.existsSync()) return;
    final bytes = file.readAsBytesSync();
    axLog(LogDomain.editor, 'Opened saved edit ${preview.entryId}');
    await Navigator.of(context).push<dynamic>(
      PageRouteBuilder<dynamic>(
        transitionDuration: const Duration(milliseconds: 400),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, _, _) =>
            EditorScreen(imageBytes: bytes, entryId: preview.entryId),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.fastOutSlowIn,
            ),
            child: child,
          );
        },
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
        ref.read(editPreviewStoreProvider).delete(entry.entryId);
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

  /// Copies the single selected photo's recipe into the settings clipboard
  /// (#75). Enabled for exactly one selection so the copy target is never
  /// ambiguous.
  void _copyEdits() {
    final state = ref.read(galleryControllerProvider);
    if (state.selectedCount != 1) return;
    final id = state.selected.first;
    final recipe =
        ref.read(recipeStoreProvider)[originalEntryId(id)] ??
        EditRecipe.neutral;
    ref.read(settingsClipboardProvider.notifier).copy(recipe);
    _snack('Copied edit settings from 1 photo');
  }

  Future<void> _export() async {
    final state = ref.read(galleryControllerProvider);
    if (state.selected.isEmpty || _exportCancel != null) return;
    final cancel = BatchCancel();
    final agg = BatchProgressAggregator(total: state.selectedCount);
    setState(() {
      _exportCancel = cancel;
      _exportAgg = agg;
      _exportDone = 0;
      _exportTotal = state.selectedCount;
      _exportingIds
        ..clear()
        ..addAll(state.selected);
      _exportedIds.clear();
    });
    try {
      final result = await ref
          .read(galleryExporterProvider)
          .exportBatch(
            state.selected,
            (id) =>
                ref.read(recipeStoreProvider)[originalEntryId(id)] ??
                EditRecipe.neutral,
            cancel: cancel,
            onProgress: (progress) {
              if (!mounted) return;
              setState(() {
                _exportDone = progress.done;
                if (progress.started) {
                  agg.start(progress.id);
                  _exportingIds.add(progress.id);
                } else {
                  agg.finish(progress.id);
                  _exportingIds.remove(progress.id);
                  _exportedIds.add(progress.id);
                }
              });
            },
            onItemProgress: (id, fraction) {
              if (!mounted) return;
              setState(() => agg.fraction(id, fraction));
            },
          );
      ref.read(galleryControllerProvider.notifier).clearSelection();
      if (!mounted) return;
      _snack(
        result.cancelled
            ? 'Export cancelled — ${result.exported} of $_exportTotal exported'
            : 'Exported ${result.exported} photo(s) to your gallery',
      );
    } finally {
      if (mounted) {
        setState(() {
          _exportCancel = null;
          _exportAgg = null;
          _exportingIds.clear();
        });
      }
    }
  }

  void _mergeHdr() {
    final state = ref.read(galleryControllerProvider);
    if (state.selected.length < 2) return;
    final assets = state.selected
        .map((id) => state.assets.firstWhere((a) => a.id == id))
        .toList();
    showAppSheet(context, HdrMergeSheet(assets: assets));
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
        appBar: PreferredSize(
          preferredSize: const Size(double.infinity, kToolbarHeight),
          child: AnimatedOpacity(
            opacity: _navOpacity,
            duration: const Duration(milliseconds: 180),
            child: AppBar(
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
                    tooltip: 'Edited versions',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const EditedVersionsScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.collections_bookmark_outlined),
                  ),
                  IconButton(
                    tooltip: 'Settings',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SettingsScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.settings_outlined),
                  ),
                ],
              ],
            ),
          ),
        ),
        body: _buildBody(state, controller),
        bottomNavigationBar: AnimatedOpacity(
          opacity: _navOpacity,
          duration: const Duration(milliseconds: 180),
          child: _exportCancel != null
              ? _ExportProgressBar(
                  done: _exportDone,
                  total: _exportTotal,
                  overall: _exportAgg?.overall,
                  onCancel: () => _exportCancel?.request(),
                )
              : state.selectionMode
              ? _SelectionBar(
                  canCopy: state.selectedCount == 1,
                  onCopy: _copyEdits,
                  onVirtualCopy: _createVirtualCopies,
                  onPaste: _paste,
                  onExport: _export,
                  canMerge: state.selectedCount >= 2,
                  onMergeHdr: _mergeHdr,
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildBody(GalleryState state, GalleryController controller) {
    return Column(
      children: [
        if (!state.selectionMode)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.md,
              vertical: Insets.xs,
            ),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<GalleryScope>(
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                segments: const [
                  ButtonSegment<GalleryScope>(
                    value: GalleryScope.photos,
                    label: Text('Photos'),
                    icon: Icon(Icons.photo_library_outlined, size: 16),
                  ),
                  ButtonSegment<GalleryScope>(
                    value: GalleryScope.edits,
                    label: Text('Edits'),
                    icon: Icon(Icons.auto_fix_high_outlined, size: 16),
                  ),
                ],
                selected: {_scope},
                onSelectionChanged: (set) => setState(() => _scope = set.first),
              ),
            ),
          ),
        Expanded(
          child: _scope == GalleryScope.photos
              ? _body(state, controller)
              : _editsBody(state),
        ),
      ],
    );
  }

  Widget _editsBody(GalleryState state) {
    final previewsAsync = ref.watch(editPreviewsStreamProvider);
    return previewsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => Center(child: Text('Error loading edits: $e')),
      data: (previews) {
        if (previews.isEmpty) {
          return EmptyState(
            icon: Icons.auto_fix_normal_outlined,
            title: 'No edits saved yet',
            message:
                'Use "Save to ApertureX" in the editor export sheet to keep your rendered edits here.',
            action: FilledButton.tonal(
              onPressed: _openSample,
              child: const Text('Try the editor'),
            ),
          );
        }

        final grouped = <String, List<EditPreview>>{};
        for (final p in previews) {
          final label = dateHeaderLabel(p.created);
          (grouped[label] ??= []).add(p);
        }

        final catalog = ref.watch(libraryCatalogProvider);

        final slivers = <Widget>[];
        for (final entry in grouped.entries) {
          slivers.add(SliverToBoxAdapter(child: _DateHeader(label: entry.key)));
          final items = entry.value;
          slivers.add(
            StaggeredPhotoGrid(
              spacing: 2,
              itemCount: items.length,
              itemBuilder: (context, idx) {
                final preview = items[idx];
                final catalogEntry = catalog[preview.entryId];
                final matchingAsset = state.assets
                    .cast<GalleryAsset?>()
                    .firstWhere(
                      (a) => a?.id == sourceAssetIdFor(preview.entryId),
                      orElse: () => null,
                    );
                final aspect = (preview.width > 0 && preview.height > 0)
                    ? (preview.width / preview.height).clamp(0.65, 1.8)
                    : 1.0;

                return AspectRatio(
                  aspectRatio: aspect,
                  child: _EditPreviewCell(
                    preview: preview,
                    catalogEntry: catalogEntry,
                    onTap: () {
                      if (matchingAsset != null) {
                        _openEntry(matchingAsset, preview.entryId);
                      } else {
                        _openSavedPreview(preview);
                      }
                    },
                    onLongPressStart: (pos) => _editPreviewMenu(
                      preview,
                      matchingAsset,
                      catalogEntry,
                      pos,
                    ),
                  ),
                );
              },
            ),
          );
        }
        slivers.add(
          const SliverToBoxAdapter(child: SizedBox(height: Insets.lg)),
        );
        return CustomScrollView(slivers: slivers);
      },
    );
  }

  void _editPreviewMenu(
    EditPreview preview,
    GalleryAsset? asset,
    CatalogEntry? catalogEntry,
    Offset pos,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Insets.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Insets.md,
                  vertical: Insets.xs,
                ),
                child: Text(
                  catalogEntry?.label ?? 'Edit Preview',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Open'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  if (asset != null) {
                    _openEntry(asset, preview.entryId);
                  } else {
                    _openSavedPreview(preview);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: const Text('Share'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  SharePlus.instance.share(
                    ShareParams(
                      files: [XFile(preview.path, mimeType: 'image/jpeg')],
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () async {
                  final previewStore = ref.read(editPreviewStoreProvider);
                  final catalogNotifier = ref.read(
                    libraryCatalogProvider.notifier,
                  );
                  Navigator.of(sheetContext).pop();
                  await previewStore.delete(preview.entryId);
                  if (preview.entryId.startsWith('vc:')) {
                    catalogNotifier.deleteVirtualCopy(preview.entryId);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(GalleryState state, GalleryController controller) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    // Desktop folder source (#103): there is no OS photo permission to
    // explain — the only empty states are "no folder chosen yet" and
    // "the chosen folder has nothing in it".
    if (_source is FolderGallerySource && state.assets.isEmpty) {
      final root = (_source as FolderGallerySource).rootPath;
      if (root == null) {
        return EmptyState(
          icon: Icons.folder_open_outlined,
          title: 'Choose a photo folder',
          message:
              'Pick a folder of photos to browse and edit. '
              'ApertureX remembers your choice on this computer.',
          action: FilledButton.icon(
            onPressed: _pickFolder,
            icon: const Icon(Icons.folder_open, size: 18),
            label: const Text('Choose a folder'),
          ),
        );
      }
      return EmptyState(
        icon: Icons.folder_outlined,
        title: 'No photos in this folder',
        message: 'Looked in $root',
        action: Wrap(
          spacing: Insets.sm,
          runSpacing: Insets.xs,
          alignment: WrapAlignment.center,
          children: [
            FilledButton.tonal(
              onPressed: _pickFolder,
              child: const Text('Choose a folder'),
            ),
            TextButton(
              onPressed: _openSample,
              child: const Text('Open a sample'),
            ),
          ],
        ),
      );
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
        title: state.selectedAlbumId == null
            ? 'No photos here'
            : 'No photos in this album',
        message: state.selectedAlbumId == null
            ? 'Photos on your device will appear here. '
                  'Or try the editor with a sample image.'
            : 'This album has no photos yet.',
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
          StaggeredPhotoGrid(
            spacing: 2,
            itemCount: items.length,
            itemBuilder: (context, j) => switch (items[j]) {
              _OriginalItem(:final asset) => AspectRatio(
                aspectRatio: (asset.width > 0 && asset.height > 0)
                    ? (asset.width / asset.height).clamp(0.65, 1.8)
                    : 1.0,
                child: _StaggeredCell(
                  index: j,
                  child: _Cell(
                    source: _source,
                    asset: asset,
                    heroTag: 'photo-${asset.id}',
                    selected: state.isSelected(asset.id),
                    edited: recipes.containsKey(originalEntryId(asset.id)),
                    copyCount: vcsBySource[asset.id]?.length ?? 0,
                    selectionMode: state.selectionMode,
                    exporting: _exportingIds.contains(asset.id),
                    exported: _exportedIds.contains(asset.id),
                    onTap: () => state.selectionMode
                        ? controller.toggle(asset.id)
                        : _open(asset),
                    onLongPress: () => controller.startSelection(asset.id),
                  ),
                ),
              ),
              _VirtualItem(:final entry, :final asset) => AspectRatio(
                aspectRatio: (asset.width > 0 && asset.height > 0)
                    ? (asset.width / asset.height).clamp(0.65, 1.8)
                    : 1.0,
                child: _StaggeredCell(
                  index: j,
                  child: _VirtualCell(
                    source: _source,
                    asset: asset,
                    entry: entry,
                    heroTag: 'photo-vc-${entry.entryId}',
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
                ),
              ),
            },
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
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: Radii.smAll,
      splashColor: scheme.primary.withValues(alpha: 0.12),
      highlightColor: scheme.primary.withValues(alpha: 0.06),
      mouseCursor: WidgetStateMouseCursor.clickable,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(width: Insets.xs),
            Icon(Icons.arrow_drop_down, size: 20),
          ],
        ),
      ),
    );
  }
}

/// Wraps a gallery cell with a staggered entrance animation: each cell fades
/// in and slides up slightly, delayed by its grid index, creating a ripple
/// effect when the library loads.
class _StaggeredCell extends StatefulWidget {
  const _StaggeredCell({required this.child, required this.index});

  final Widget child;
  final int index;

  @override
  State<_StaggeredCell> createState() => _StaggeredCellState();
}

class _StaggeredCellState extends State<_StaggeredCell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    final delay = Duration(milliseconds: 40 * widget.index);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _opacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _offset = Tween<Offset>(
      begin: Offset(0, 0.18),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    Future.delayed(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: Transform.translate(offset: _offset.value, child: child),
        );
      },
      child: widget.child,
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
    required this.heroTag,
    this.copyCount = 0,
    this.exporting = false,
    this.exported = false,
  });

  final GallerySource source;
  final GalleryAsset asset;
  final bool selected;
  final bool edited;
  final bool selectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  /// Unique hero tag for the shared-element transition into the editor.
  final String heroTag;

  /// How many virtual copies this photo has (0 = none) — surfaced as a small
  /// count chip so an expanded photo is obvious at a glance (#73).
  final int copyCount;

  /// A batch export currently covers this photo (live ring, #75).
  final bool exporting;

  /// This photo's export finished in the last batch (#75).
  final bool exported;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Photo',
      button: true,
      selected: selected,
      onTap: onTap,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        onLongPress: () {
          HapticFeedback.mediumImpact();
          onLongPress();
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            Hero(
              tag: heroTag,
              child: GalleryThumbnail(source: source, assetId: asset.id),
            ),
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
            if (exporting)
              Positioned(
                right: 4,
                top: 4,
                child: SizedBox(
                  key: Key('export-ring-${asset.id}'),
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: scheme.primary,
                  ),
                ),
              )
            else if (exported)
              Positioned(
                right: 4,
                top: 4,
                child: Icon(
                  key: Key('export-done-${asset.id}'),
                  Icons.check_circle,
                  size: 22,
                  color: scheme.primary,
                ),
              )
            else if (selectionMode)
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
    required this.heroTag,
  });

  final GallerySource source;
  final GalleryAsset asset;
  final CatalogEntry entry;
  final bool selected;
  final bool edited;
  final bool selectionMode;
  final VoidCallback onTap;
  final GestureLongPressStartCallback onLongPressStart;
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Virtual copy',
      button: true,
      selected: selected,
      onTap: onTap,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        onLongPressStart: (d) {
          HapticFeedback.mediumImpact();
          onLongPressStart(d);
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            Hero(
              tag: heroTag,
              child: GalleryThumbnail(
                source: source,
                assetId: entry.sourceAssetId,
              ),
            ),
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
    this.size = 200,
  });

  final GallerySource source;
  final String assetId;
  final int size;

  @override
  State<GalleryThumbnail> createState() => _GalleryThumbnailState();
}

class _GalleryThumbnailState extends State<GalleryThumbnail> {
  Uint8List? _cached;
  Future<Uint8List>? _future;

  @override
  void initState() {
    super.initState();
    _initLoad();
  }

  void _initLoad() {
    final cached = widget.source.thumbnailCache.get(widget.assetId);
    if (cached != null) {
      _cached = cached;
      _future = null;
    } else {
      _cached = null;
      _future = widget.source
          .loadThumbnail(widget.assetId, size: widget.size)
          .then((bytes) {
            widget.source.thumbnailCache.put(widget.assetId, bytes);
            if (mounted) {
              setState(() {
                _cached = bytes;
              });
            }
            return bytes;
          });
    }
  }

  @override
  void didUpdateWidget(GalleryThumbnail old) {
    super.didUpdateWidget(old);
    if (old.assetId != widget.assetId || old.source != widget.source) {
      _initLoad();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final dpr = MediaQuery.devicePixelRatioOf(context);
          final w = constraints.maxWidth;
          final cacheWidth = w.isFinite && w > 0 ? (w * dpr).round() : null;

          final bytes = _cached;
          if (bytes != null && bytes.isNotEmpty) {
            return Image.memory(
              bytes,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              cacheWidth: cacheWidth,
            );
          }

          return FutureBuilder<Uint8List>(
            future: _future,
            builder: (context, snapshot) {
              final data = snapshot.data;
              if (data == null || data.isEmpty) {
                return ColoredBox(
                  color: scheme.surfaceContainerHigh,
                  child: Icon(
                    Icons.image_outlined,
                    color: scheme.onSurfaceVariant,
                  ),
                );
              }
              return Image.memory(
                data,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                cacheWidth: cacheWidth,
              );
            },
          );
        },
      ),
    );
  }
}

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.canCopy,
    required this.onCopy,
    required this.onVirtualCopy,
    required this.onPaste,
    required this.onExport,
    required this.canMerge,
    required this.onMergeHdr,
  });

  /// True only when exactly one photo is selected — the copy target must be
  /// unambiguous (#75).
  final bool canCopy;
  final VoidCallback onCopy;
  final VoidCallback onVirtualCopy;
  final VoidCallback onPaste;
  final VoidCallback onExport;

  /// True when two or more photos are selected — HDR merge needs a bracket.
  final bool canMerge;
  final VoidCallback onMergeHdr;

  @override
  Widget build(BuildContext context) {
    // Horizontal scroll so actions never overflow a 360dp phone; the viewport
    // is right-aligned so the actions stay in the thumb zone.
    return BottomAppBar(
      child: Align(
        alignment: Alignment.centerRight,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton.icon(
                key: const Key('copy-edits-action'),
                onPressed: canCopy ? onCopy : null,
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copy edits'),
              ),
              const SizedBox(width: Insets.sm),
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
              const SizedBox(width: Insets.sm),
              FilledButton.tonalIcon(
                key: const Key('hdr-merge-action'),
                onPressed: canMerge ? onMergeHdr : null,
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text('HDR Merge'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom bar while a batch export runs: live "12/40" count, determinate
/// progress (smoothed by [overall] so long items creep forward) and a global
/// cancel (#75).
class _ExportProgressBar extends StatelessWidget {
  const _ExportProgressBar({
    required this.done,
    required this.total,
    required this.onCancel,
    this.overall,
  });

  final int done;
  final int total;
  final VoidCallback onCancel;

  /// Aggregated `(done + Σ fractions) / total` from
  /// [BatchProgressAggregator]; null falls back to the coarse `done / total`.
  final double? overall;

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: Insets.sm),
            child: Text('$done/$total'),
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: overall ?? (total == 0 ? null : done / total),
            ),
          ),
          const SizedBox(width: Insets.sm),
          TextButton.icon(
            key: const Key('export-cancel'),
            onPressed: onCancel,
            icon: const Icon(Icons.close, size: 18),
            label: const Text('Cancel'),
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

class _EditPreviewCell extends StatefulWidget {
  const _EditPreviewCell({
    required this.preview,
    required this.catalogEntry,
    required this.onTap,
    required this.onLongPressStart,
  });

  final EditPreview preview;
  final CatalogEntry? catalogEntry;
  final VoidCallback onTap;
  final ValueChanged<Offset> onLongPressStart;

  @override
  State<_EditPreviewCell> createState() => _EditPreviewCellState();
}

class _EditPreviewCellState extends State<_EditPreviewCell> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _loadBytes();
  }

  @override
  void didUpdateWidget(_EditPreviewCell old) {
    super.didUpdateWidget(old);
    if (old.preview.path != widget.preview.path) {
      _loadBytes();
    }
  }

  void _loadBytes() {
    final file = File(widget.preview.path);
    if (file.existsSync()) {
      try {
        _bytes = file.readAsBytesSync();
      } catch (_) {
        _bytes = null;
      }
    } else {
      _bytes = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bytes = _bytes;
    final catalogEntry = widget.catalogEntry;

    return GestureDetector(
      onTap: widget.onTap,
      onLongPressStart: (d) => widget.onLongPressStart(d.globalPosition),
      child: Stack(
        fit: StackFit.expand,
        children: [
          bytes != null && bytes.isNotEmpty
              ? Image.memory(
                  bytes,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (context, error, stackTrace) =>
                      const ColoredBox(
                        color: Colors.black26,
                        child: Icon(Icons.broken_image, size: 24),
                      ),
                )
              : const ColoredBox(
                  color: Colors.black12,
                  child: Center(
                    child: Icon(Icons.photo, color: Colors.black26),
                  ),
                ),
          // Top badges: rating and flag
          Positioned(
            top: 4,
            left: 4,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (catalogEntry != null && catalogEntry.rating > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, size: 12, color: Colors.amber),
                        const SizedBox(width: 2),
                        Text(
                          '${catalogEntry.rating}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (catalogEntry != null && catalogEntry.flag) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(
                      Icons.flag,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Bottom badge: label if present
          if (catalogEntry?.label != null && catalogEntry!.label!.isNotEmpty)
            Positioned(
              left: 4,
              right: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  catalogEntry.label!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
