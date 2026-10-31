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
import '../engine/engine.dart';
import '../features/editor/editor_screen.dart';
import '../settings/settings_screen.dart';
import '../ui/common/app_primitives.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/print/print_model.dart';
import '../features/print/print_screen.dart';
import '../features/tether/tether_screen.dart';
import '../features/video/video_editor_screen.dart';
import '../settings/onboarding.dart';
import '../ui/common/app_sheet.dart';
import 'edit_preview_store.dart';
import 'edited_versions_screen.dart';
import 'folder_gallery_source.dart';
import 'duplicate_detector.dart';
import 'folder_watcher.dart';
import 'photo_quality_evaluator.dart';
import 'smart_collection.dart';
import 'gallery_asset.dart';
import 'gallery_controller.dart';
import 'gallery_export.dart';
import 'gallery_grouping.dart';
import 'gallery_source.dart';
import 'hdr_merge_sheet.dart';
import 'staggered_photo_grid.dart';

/// Which gallery scope is displayed (#85).
enum GalleryScope { photos, edits }

/// Returns true if the asset filename/id indicates a RAW photo camera format.
bool isRawAsset(GalleryAsset asset) {
  // Safe inspection of asset properties including latestDate
  final _ = asset.latestDate;

  const rawExtensions = {
    'dng',
    'raw',
    'cr2',
    'cr3',
    'nef',
    'arw',
    'orf',
    'rw2',
    'pef',
    'raf',
    'nrw',
    'kdc',
    'srw',
  };

  // 1. Direct check on asset title / filename (e.g. real Android photo_manager titles like "DSC_0042.NEF")
  if (asset.title != null && asset.title!.isNotEmpty) {
    final title = asset.title!.trim().toLowerCase();
    for (final ext in rawExtensions) {
      if (title.endsWith('.$ext')) return true;
    }
  }

  // 2. Direct check on asset mimeType (e.g. "image/x-adobe-dng", "image/x-nikon-nef", "image/raw")
  if (asset.mimeType != null && asset.mimeType!.isNotEmpty) {
    final mime = asset.mimeType!.trim().toLowerCase();
    if (mime.contains('raw') || mime.contains('dng')) return true;
    for (final ext in rawExtensions) {
      if (mime.contains(ext)) return true;
    }
  }

  final id = asset.id.trim().toLowerCase();
  if (id.isEmpty) return false;

  // 3. Direct extension check on filename/path (strip query parameters or fragments if any)
  final clean = id.split('?').first.split('#').first;
  for (final ext in rawExtensions) {
    if (clean.endsWith('.$ext')) return true;
  }

  // 4. MIME type hint in id (e.g. image/x-adobe-dng, image/raw, etc.)
  if (clean.contains('image/') || clean.contains('mime')) {
    for (final ext in rawExtensions) {
      if (clean.contains(ext)) return true;
    }
  }

  // 5. Delimited token match for mobile/MediaStore hints, URIs, and UUIDs
  // e.g. /raw/, _dng_, -cr3-, .arw., or entity ids like "content://media/.../raw/100"
  final tokenPattern = RegExp(
    r'(?:^|[\/\._\-:= ])(dng|raw|cr2|cr3|nef|arw|orf|rw2|pef|raf|nrw|kdc|srw)(?:$|[\/\._\-:= ?#&])',
  );
  if (tokenPattern.hasMatch(clean)) {
    return true;
  }

  return false;
}

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

  ColorLabel? _filterColorLabel;
  int _filterMinRating = 0;
  bool _filterFlaggedOnly = false;
  bool _filterRawOnly = false;
  bool _isCompactGrid = false;
  SmartCollection? _activeSmartCollection;
  AutoImportFolderWatcher? _folderWatcher;

  /// Fades the AppBar + SelectionBar out during the hero flight into the
  /// editor so only the photo moves (issue: buttery gallery→editor transition).
  late final AnimationController _navFade;

  @override
  void initState() {
    super.initState();
    _navFade = AnimationController(
      vsync: this,
      value: 1.0,
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
    _folderWatcher?.dispose();
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

  Future<void> _open(GalleryAsset asset) async {
    axLog(LogDomain.editor, 'Opened photo ${asset.id}');
    // Fade chrome out as the photo begins its hero flight into the editor.
    await _navFade.reverse();
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
    if (mounted) await _navFade.forward();
    if (res == 'show_edits' && mounted) {
      setState(() => _scope = GalleryScope.edits);
    }
  }

  /// Opens [asset]'s pixels under a specific catalog entry — a virtual copy
  /// shares the original's data but carries its own recipe (#73).
  Future<void> _openEntry(GalleryAsset asset, String entryId) async {
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

  Future<void> _openSavedPreview(EditPreview preview) async {
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

  /// Syncs settings from the first selected photo to all other selected photos (Lightroom-style Batch Sync #13).
  void _syncEdits() {
    final state = ref.read(galleryControllerProvider);
    if (state.selectedCount < 2) return;
    final masterId = state.selected.first;
    final recipe =
        ref.read(recipeStoreProvider)[originalEntryId(masterId)] ??
        EditRecipe.neutral;
    final targets = state.selected.skip(1).map(originalEntryId);
    ref.read(recipeStoreProvider.notifier).pasteTo(targets, recipe);
    ref.read(galleryControllerProvider.notifier).clearSelection();
    _snack('Synced settings to ${state.selectedCount - 1} photo(s)');
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

  void _openPrintStudio() {
    final state = ref.read(galleryControllerProvider);
    final items = state.selected.map((id) {
      final matches = state.assets.where((a) => a.id == id);
      final asset = matches.isNotEmpty ? matches.first : null;
      return PrintPhotoItem(
        id: id,
        filename: id.contains('/') ? id.split('/').last : id,
        aspectRatio: (asset != null && asset.height > 0)
            ? asset.width / asset.height
            : 1.5,
      );
    }).toList();

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PrintScreen(items: items),
      ),
    );
  }

  void _showSmartCollectionsSheet() {
    final collections = SmartCollection.builtInCollections();
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Insets.md, horizontal: Insets.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Smart Collections',
                    style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  if (_activeSmartCollection != null)
                    TextButton(
                      onPressed: () {
                        setState(() => _activeSmartCollection = null);
                        Navigator.of(sheetContext).pop();
                      },
                      child: const Text('Clear'),
                    ),
                ],
              ),
              const SizedBox(height: Insets.xs),
              ...collections.map((col) {
                final isSelected = _activeSmartCollection?.id == col.id;
                return ListTile(
                  leading: Icon(
                    Icons.auto_awesome_motion,
                    color: isSelected ? Theme.of(sheetContext).colorScheme.primary : null,
                  ),
                  title: Text(col.name, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                  subtitle: col.description != null ? Text(col.description!, style: const TextStyle(fontSize: 12)) : null,
                  selected: isSelected,
                  onTap: () {
                    setState(() => _activeSmartCollection = col);
                    Navigator.of(sheetContext).pop();
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showDuplicateFinderSheet() async {
    final state = ref.read(galleryControllerProvider);
    if (state.assets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No photos loaded in gallery')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Scanning for duplicates using perceptual hashing…'),
        duration: Duration(seconds: 1),
      ),
    );

    // Compute hashes for up to 100 recent photos
    final hashes = <String, int>{};
    final source = _source;
    final sampleAssets = state.assets.take(100).toList();

    for (final asset in sampleAssets) {
      try {
        final thumb = await source.loadThumbnail(asset.id, size: 64);
        if (thumb.isNotEmpty) {
          final decoded = await AxEngine.decodeAnalysisProxy(thumb);
          final h = DuplicateDetector.computeDHash(decoded.rgba, decoded.width, decoded.height);
          hashes[asset.id] = h;
        }
      } catch (_) {
        // Skip unreadable assets
      }
    }

    final duplicates = DuplicateDetector.findDuplicates(hashes, maxDistance: 6);

    if (!mounted) return;

    if (duplicates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Scanned ${hashes.length} photos: No duplicates found!'),
        ),
      );
      return;
    }

    final totalDupes = duplicates.fold<int>(0, (sum, g) => sum + g.duplicateAssetIds.length);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.7,
          ),
          padding: const EdgeInsets.all(Insets.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Duplicate Groups ($totalDupes duplicates)',
                    style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.select_all, size: 16),
                    label: const Text('Select Duplicates'),
                    onPressed: () {
                      final controller = ref.read(galleryControllerProvider.notifier);
                      for (final g in duplicates) {
                        for (final dupId in g.duplicateAssetIds) {
                          if (!ref.read(galleryControllerProvider).isSelected(dupId)) {
                            controller.toggle(dupId);
                          }
                        }
                      }
                      Navigator.of(sheetContext).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Selected $totalDupes duplicates for review/action')),
                      );
                    },
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: duplicates.length,
                  itemBuilder: (ctx, idx) {
                    final group = duplicates[idx];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cluster #${idx + 1} (${group.totalCount} shots)',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              children: [
                                Chip(
                                  avatar: const Icon(Icons.star, size: 12),
                                  label: Text('Primary: ${group.primaryAssetId.split('/').last}'),
                                  visualDensity: VisualDensity.compact,
                                ),
                                for (final dupId in group.duplicateAssetIds)
                                  Chip(
                                    avatar: const Icon(Icons.copy, size: 12),
                                    label: Text(
                                      '${dupId.split('/').last} (diff: ${group.distances[dupId]})',
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showQualityCullingSheet() async {
    final state = ref.read(galleryControllerProvider);
    if (state.assets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No photos loaded in gallery')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Scanning photos for blur & eye quality…'),
        duration: Duration(seconds: 1),
      ),
    );

    final source = _source;
    final cullResults = <String, QualityScore>{};
    final sampleAssets = state.assets.take(100).toList();

    for (final asset in sampleAssets) {
      try {
        final thumb = await source.loadThumbnail(asset.id, size: 64);
        if (thumb.isNotEmpty) {
          final decoded = await AxEngine.decodeAnalysisProxy(thumb);
          final score = PhotoQualityEvaluator.evaluateQuality(
            decoded.rgba,
            decoded.width,
            decoded.height,
          );
          if (score.isBlurry || score.hasClosedEyes) {
            cullResults[asset.id] = score;
          }
        }
      } catch (_) {
        // Skip unreadable assets
      }
    }

    if (!mounted) return;

    if (cullResults.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scan complete: All scanned photos look sharp!')),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.7,
          ),
          padding: const EdgeInsets.all(Insets.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Quality Culling (${cullResults.length} flagged)',
                    style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.label, size: 16),
                    label: const Text('Tag in Catalog'),
                    onPressed: () {
                      final catalogNotifier = ref.read(libraryCatalogProvider.notifier);
                      for (final entry in cullResults.entries) {
                        final tag = entry.value.cullingBadge;
                        if (tag != null) {
                          catalogNotifier.addKeyword(originalEntryId(entry.key), tag);
                        }
                      }
                      Navigator.of(sheetContext).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Tagged ${cullResults.length} photos in catalog')),
                      );
                    },
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: cullResults.length,
                  itemBuilder: (ctx, idx) {
                    final assetId = cullResults.keys.elementAt(idx);
                    final score = cullResults[assetId]!;
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        score.hasClosedEyes ? Icons.visibility_off : Icons.blur_on,
                        color: score.hasClosedEyes ? Colors.orange : Colors.red,
                      ),
                      title: Text(assetId.split('/').last),
                      subtitle: Text(
                        score.hasClosedEyes
                            ? 'Closed eyes detected'
                            : 'Blurry (sharpness: ${score.sharpnessScore.toStringAsFixed(1)})',
                      ),
                      trailing: TextButton(
                        child: const Text('Select'),
                        onPressed: () {
                          ref.read(galleryControllerProvider.notifier).toggle(assetId);
                          Navigator.of(sheetContext).pop();
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleFolderWatcher() async {
    if (_folderWatcher != null && _folderWatcher!.isWatching) {
      await _folderWatcher!.stop();
      _folderWatcher = null;
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Auto-import folder watcher stopped')),
        );
      }
      return;
    }

    final source = _source;
    final String targetPath;
    if (source is FolderGallerySource && source.rootPath != null) {
      targetPath = source.rootPath!;
    } else {
      targetPath = Directory.current.path;
    }

    _folderWatcher = AutoImportFolderWatcher(
      directoryPath: targetPath,
      onPhotoDiscovered: (file) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Auto-imported new photo: ${file.path.split('/').last}'),
              duration: const Duration(seconds: 2),
            ),
          );
          ref.read(galleryControllerProvider.notifier).load();
        }
      },
    );

    await _folderWatcher!.start();
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Watching folder for auto-import: $targetPath')),
      );
    }
  }

  Future<void> _showColorLabelSheet() async {
    final state = ref.read(galleryControllerProvider);
    if (state.selected.isEmpty) return;
    final catalogNotifier = ref.read(libraryCatalogProvider.notifier);

    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Insets.sm, horizontal: Insets.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Set Color Label (${state.selectedCount} selected)',
                style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: Insets.sm),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final label in ColorLabel.values)
                    ActionChip(
                      key: Key('color-label-chip-${label.name}'),
                      avatar: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Color(label.colorValue),
                          shape: BoxShape.circle,
                        ),
                      ),
                      label: Text(label.displayName),
                      onPressed: () {
                        for (final id in state.selected) {
                          catalogNotifier.setColorLabel(originalEntryId(id), label);
                        }
                        Navigator.of(sheetContext).pop();
                        _snack('Applied ${label.displayName} label to ${state.selectedCount} photo(s)');
                      },
                    ),
                  ActionChip(
                    key: const Key('color-label-chip-none'),
                    avatar: const Icon(Icons.close, size: 14),
                    label: const Text('None'),
                    onPressed: () {
                      for (final id in state.selected) {
                        catalogNotifier.setColorLabel(originalEntryId(id), null);
                      }
                      Navigator.of(sheetContext).pop();
                      _snack('Cleared color label on ${state.selectedCount} photo(s)');
                    },
                  ),
                ],
              ),
              const SizedBox(height: Insets.sm),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showKeywordsSheet() async {
    final state = ref.read(galleryControllerProvider);
    if (state.selected.isEmpty) return;
    final catalogNotifier = ref.read(libraryCatalogProvider.notifier);
    final catalog = ref.read(libraryCatalogProvider);

    final existingKeywords = <String>{};
    for (final id in state.selected) {
      final entry = catalog[originalEntryId(id)];
      if (entry != null) {
        existingKeywords.addAll(entry.keywords);
      }
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _KeywordsSheet(
        selectedCount: state.selectedCount,
        initialKeywords: existingKeywords.toList()..sort(),
        onAddKeyword: (kw) {
          for (final id in state.selected) {
            catalogNotifier.addKeyword(originalEntryId(id), kw);
          }
        },
        onRemoveKeyword: (kw) {
          for (final id in state.selected) {
            catalogNotifier.removeKeyword(originalEntryId(id), kw);
          }
        },
      ),
    );
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
          child: FadeTransition(
            opacity: _navFade,
            child: AppBar(
              title: state.selectionMode
                  ? Text(
                      '${state.selectedCount} selected',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    )
                  : _AlbumTitle(title: state.title, onTap: _openAlbumPicker),
              actions: [
                if (state.selectionMode) ...[
                  IconButton(
                    tooltip: 'Select all',
                    onPressed: controller.selectAll,
                    icon: const Icon(Icons.select_all),
                  ),
                  IconButton(
                    tooltip: 'Clear selection',
                    onPressed: controller.clearSelection,
                    icon: const Icon(Icons.close),
                  ),
                ] else ...[
                  IconButton(
                    tooltip: _isCompactGrid ? 'Comfort grid' : 'Compact grid',
                    onPressed: () => setState(() => _isCompactGrid = !_isCompactGrid),
                    icon: Icon(_isCompactGrid ? Icons.grid_view : Icons.view_comfy_alt_outlined),
                  ),
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
                  PopupMenuButton<String>(
                    tooltip: 'Pro Studios',
                    icon: const Icon(Icons.more_vert),
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'tether',
                        child: Row(
                          children: [
                            Icon(Icons.camera_alt_outlined, size: 20),
                            SizedBox(width: 12),
                            Text('Studio Tethered Shooting'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'video',
                        child: Row(
                          children: [
                            Icon(Icons.movie_outlined, size: 20),
                            SizedBox(width: 12),
                            Text('Video Color Studio'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'print',
                        child: Row(
                          children: [
                            Icon(Icons.print_outlined, size: 20),
                            SizedBox(width: 12),
                            Text('Print & Contact Sheet'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'smart_collections',
                        child: Row(
                          children: [
                            Icon(Icons.auto_awesome_motion_outlined, size: 20),
                            SizedBox(width: 12),
                            Text('Smart Collections'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'duplicates',
                        child: Row(
                          children: [
                            Icon(Icons.copy_all_outlined, size: 20),
                            SizedBox(width: 12),
                            Text('Find & Clean Duplicates'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'quality_culling',
                        child: Row(
                          children: [
                            Icon(Icons.auto_fix_high_outlined, size: 20),
                            SizedBox(width: 12),
                            Text('Cull Blurry / Closed Eyes'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'auto_import',
                        child: Row(
                          children: [
                            Icon(Icons.folder_shared_outlined, size: 20),
                            SizedBox(width: 12),
                            Text('Auto-Import Folder Watcher'),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (val) {
                      if (val == 'tether') {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (_) => const TetherScreen()),
                        );
                      } else if (val == 'video') {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (_) => const VideoEditorScreen()),
                        );
                      } else if (val == 'print') {
                        _openPrintStudio();
                      } else if (val == 'smart_collections') {
                        _showSmartCollectionsSheet();
                      } else if (val == 'duplicates') {
                        _showDuplicateFinderSheet();
                      } else if (val == 'quality_culling') {
                        _showQualityCullingSheet();
                      } else if (val == 'auto_import') {
                        _toggleFolderWatcher();
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
        body: _buildBody(state, controller),
        bottomNavigationBar: FadeTransition(
          opacity: _navFade,
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
                  canSync: state.selectedCount >= 2,
                  onSync: _syncEdits,
                  onVirtualCopy: _createVirtualCopies,
                  onPaste: _paste,
                  onExport: _export,
                  canMerge: state.selectedCount >= 2,
                  onMergeHdr: _mergeHdr,
                  onColorLabel: _showColorLabelSheet,
                  onKeywords: _showKeywordsSheet,
                  onPrint: _openPrintStudio,
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
        if (!state.selectionMode && _scope == GalleryScope.photos) _buildFilterBar(),
        Expanded(
          child: _scope == GalleryScope.photos
              ? _body(state, controller)
              : _editsBody(state),
        ),
      ],
    );
  }

  bool _matchesFilter(CatalogEntry? entry, [GalleryAsset? asset]) {
    if (_activeSmartCollection != null) {
      if (entry == null) return false;
      return _activeSmartCollection!.matches(entry, assetDate: asset?.latestDate);
    }
    if (_filterRawOnly) {
      if (asset == null || !isRawAsset(asset)) {
        return false;
      }
    }
    if (_filterColorLabel != null) {
      if (entry == null || entry.colorLabel != _filterColorLabel) {
        return false;
      }
    }
    if (_filterMinRating > 0) {
      if (entry == null || entry.rating < _filterMinRating) {
        return false;
      }
    }
    if (_filterFlaggedOnly) {
      if (entry == null || !entry.flag) {
        return false;
      }
    }
    return true;
  }

  Widget _buildFilterBar() {
    final hasActiveFilter = _activeSmartCollection != null ||
        _filterColorLabel != null ||
        _filterMinRating > 0 ||
        _filterFlaggedOnly ||
        _filterRawOnly;
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: 2),
        children: [
          FilterChip(
            key: const Key('filter-all'),
            label: const Text('All', style: TextStyle(fontSize: 12)),
            selected: !hasActiveFilter,
            onSelected: (_) {
              setState(() {
                _activeSmartCollection = null;
                _filterColorLabel = null;
                _filterMinRating = 0;
                _filterFlaggedOnly = false;
                _filterRawOnly = false;
              });
            },
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 6),
          FilterChip(
            key: const Key('filter-raw'),
            avatar: const Icon(Icons.camera_outlined, size: 12),
            label: const Text('RAW', style: TextStyle(fontSize: 12)),
            selected: _filterRawOnly,
            onSelected: (val) {
              setState(() => _filterRawOnly = val);
            },
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 6),
          FilterChip(
            key: const Key('filter-flagged'),
            avatar: const Icon(Icons.flag, size: 12),
            label: const Text('Flagged', style: TextStyle(fontSize: 12)),
            selected: _filterFlaggedOnly,
            onSelected: (val) {
              setState(() => _filterFlaggedOnly = val);
            },
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 6),
          FilterChip(
            key: const Key('filter-rating-1'),
            avatar: const Icon(Icons.star, size: 12, color: Colors.amber),
            label: const Text('1+ ★', style: TextStyle(fontSize: 12)),
            selected: _filterMinRating == 1,
            onSelected: (val) {
              setState(() => _filterMinRating = val ? 1 : 0);
            },
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 6),
          FilterChip(
            key: const Key('filter-rating-3'),
            avatar: const Icon(Icons.star, size: 12, color: Colors.amber),
            label: const Text('3+ ★', style: TextStyle(fontSize: 12)),
            selected: _filterMinRating == 3,
            onSelected: (val) {
              setState(() => _filterMinRating = val ? 3 : 0);
            },
            visualDensity: VisualDensity.compact,
          ),
          for (final label in ColorLabel.values) ...[
            const SizedBox(width: 6),
            FilterChip(
              key: Key('filter-color-${label.name}'),
              avatar: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Color(label.colorValue),
                  shape: BoxShape.circle,
                ),
              ),
              label: Text(label.displayName, style: const TextStyle(fontSize: 12)),
              selected: _filterColorLabel == label,
              onSelected: (val) {
                setState(() => _filterColorLabel = val ? label : null);
              },
              visualDensity: VisualDensity.compact,
            ),
          ],
          const SizedBox(width: 6),
          FilterChip(
            key: const Key('filter-smart-collection'),
            avatar: const Icon(Icons.auto_awesome_motion, size: 12),
            label: Text(
              _activeSmartCollection?.name ?? 'Smart Collections',
              style: const TextStyle(fontSize: 12),
            ),
            selected: _activeSmartCollection != null,
            onSelected: (_) => _showSmartCollectionsSheet(),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
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

        final catalog = ref.watch(libraryCatalogProvider);

        final grouped = <String, List<EditPreview>>{};
        for (final p in previews) {
          final catalogEntry = catalog[p.entryId];
          final sourceId = sourceAssetIdFor(p.entryId);
          final matchingAsset = state.assets
              .cast<GalleryAsset?>()
              .firstWhere(
                (a) => a?.id == sourceId,
                orElse: () => GalleryAsset(id: sourceId, width: 0, height: 0),
              );
          if (_matchesFilter(catalogEntry, matchingAsset)) {
            final label = dateHeaderLabel(p.created);
            (grouped[label] ??= []).add(p);
          }
        }

        final slivers = <Widget>[];
        if (grouped.isEmpty && previews.isNotEmpty) {
          slivers.add(
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyFilterCard(
                onClearFilters: () {
                  setState(() {
                    _activeSmartCollection = null;
                    _filterColorLabel = null;
                    _filterMinRating = 0;
                    _filterFlaggedOnly = false;
                    _filterRawOnly = false;
                  });
                },
              ),
            ),
          );
        }
        for (final entry in grouped.entries) {
          slivers.add(SliverToBoxAdapter(child: _DateHeader(label: entry.key)));
          final items = entry.value;
          slivers.add(
            StaggeredPhotoGrid(
              crossAxisCount: _isCompactGrid ? 4 : null,
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
                  child: RepaintBoundary(
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
    final catalog = ref.watch(libraryCatalogProvider);
    final vcsBySource = ref
        .read(libraryCatalogProvider.notifier)
        .virtualCopiesBySource();
    final slivers = <Widget>[];
    final hasCompletedOnboarding = ref.watch(hasCompletedOnboardingProvider);
    if (!hasCompletedOnboarding) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Insets.md, Insets.sm, Insets.md, Insets.xs),
            child: Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(Insets.md),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(Insets.sm),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lens_blur,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: Insets.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome to ApertureX',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Take a quick tour of dual shells & pro tools',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.tonal(
                      onPressed: () => OnboardingScreen.show(context),
                      child: const Text('Tour'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: 'Dismiss',
                      onPressed: () => ref
                          .read(hasCompletedOnboardingProvider.notifier)
                          .complete(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    var matchingCount = 0;
    var i = 0;
    while (i < rows.length) {
      final row = rows[i];
      if (row is GalleryDateHeader) {
        i++;
        final photos = <GalleryAsset>[];
        while (i < rows.length && rows[i] is GalleryPhoto) {
          final asset = (rows[i] as GalleryPhoto).asset;
          final entry = catalog[originalEntryId(asset.id)];
          if (_matchesFilter(entry, asset)) {
            photos.add(asset);
          }
          i++;
        }
        // Expand each photo into its original cell followed by one cell per
        // virtual copy — the copies live "under" their source, Lightroom-style.
        final items = <_GridItem>[
          for (final asset in photos) ...[
            _OriginalItem(asset),
            for (final copy in vcsBySource[asset.id] ?? const <CatalogEntry>[])
              if (_matchesFilter(copy, asset))
                _VirtualItem(copy, asset),
          ],
        ];
        matchingCount += items.length;
        if (items.isNotEmpty) {
          slivers.add(SliverToBoxAdapter(child: _DateHeader(label: row.label)));
          slivers.add(
            StaggeredPhotoGrid(
              crossAxisCount: _isCompactGrid ? 4 : null,
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
                      catalogEntry: catalog[originalEntryId(asset.id)],
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
        }
      } else {
        i++;
      }
    }
    if (matchingCount == 0 && rows.isNotEmpty) {
      slivers.add(
        SliverFillRemaining(
          hasScrollBody: false,
          child: _EmptyFilterCard(
            onClearFilters: () {
              setState(() {
                _activeSmartCollection = null;
                _filterColorLabel = null;
                _filterMinRating = 0;
                _filterFlaggedOnly = false;
                _filterRawOnly = false;
              });
            },
          ),
        ),
      );
    }
    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: Insets.lg)));
    return slivers;
  }
}

/// Displayed when filters exclude every photo in the gallery or edits view.
class _EmptyFilterCard extends StatelessWidget {
  const _EmptyFilterCard({required this.onClearFilters});

  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Insets.lg),
        child: Card(
          key: const Key('empty-filter-card'),
          elevation: 0,
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.xl,
              vertical: Insets.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.filter_alt_off_outlined,
                  size: 48,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: Insets.md),
                Text(
                  'No photos match the selected filter',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Insets.sm),
                Text(
                  'Try adjusting or resetting your filter criteria.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Insets.lg),
                FilledButton.tonal(
                  key: const Key('clear-filters-button'),
                  onPressed: onClearFilters,
                  child: const Text('Clear Filters'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
    return Semantics(
      button: true,
      label: 'Select album, current album: $title',
      hint: 'Double tap to open album list',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        splashColor: scheme.primary.withValues(alpha: 0.12),
        highlightColor: scheme.primary.withValues(alpha: 0.06),
        mouseCursor: WidgetStateMouseCursor.clickable,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 220, minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.35),
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_library_outlined, size: 16, color: scheme.primary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.1,
                    ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
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
      begin: const Offset(0, 0.18),
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
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.md,
        Insets.lg,
        Insets.md,
        Insets.sm,
      ),
      child: Row(
        children: [
          Text(
            label,
            style: theme.textTheme.titleMedium?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Divider(
              color: scheme.outlineVariant.withValues(alpha: 0.25),
              thickness: 0.75,
            ),
          ),
        ],
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
    this.catalogEntry,
    this.copyCount = 0,
    this.exporting = false,
    this.exported = false,
  });

  final GallerySource source;
  final GalleryAsset asset;
  final CatalogEntry? catalogEntry;
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
            if (catalogEntry != null &&
                (catalogEntry!.rating > 0 ||
                    catalogEntry!.flag ||
                    catalogEntry!.colorLabel != null ||
                    catalogEntry!.keywords.isNotEmpty))
              Positioned(
                left: 4,
                top: 4,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (catalogEntry!.rating > 0)
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
                              '${catalogEntry!.rating}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (catalogEntry!.flag) ...[
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
                    if (catalogEntry!.colorLabel != null) ...[
                      const SizedBox(width: 4),
                      Container(
                        key: Key('color-badge-${asset.id}'),
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(catalogEntry!.colorLabel!.colorValue),
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                      ),
                    ],
                    if (catalogEntry!.keywords.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Container(
                        key: Key('keywords-badge-${asset.id}'),
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.sell_outlined,
                          size: 10,
                          color: Colors.white,
                        ),
                      ),
                    ],
                    if (catalogEntry?.keywords.contains('blurry') ?? false) ...[
                      const SizedBox(width: 4),
                      Container(
                        key: Key('blurry-badge-${asset.id}'),
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.blur_on,
                          size: 10,
                          color: Colors.white,
                        ),
                      ),
                    ],
                    if (catalogEntry?.keywords.contains('closed_eyes') ?? false) ...[
                      const SizedBox(width: 4),
                      Container(
                        key: Key('closed-eyes-badge-${asset.id}'),
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.visibility_off_outlined,
                          size: 10,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ],
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
              )
            else if (isRawAsset(asset))
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  key: Key('raw-badge-${asset.id}'),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: Colors.white54, width: 0.6),
                  ),
                  child: const Text(
                    'RAW',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DecoratedBox(
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
                  if (entry.rating > 0) ...[
                    const SizedBox(width: 4),
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
                            '${entry.rating}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (entry.flag) ...[
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
                  if (entry.colorLabel != null) ...[
                    const SizedBox(width: 4),
                    Container(
                      key: Key('color-badge-${asset.id}'),
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(entry.colorLabel!.colorValue),
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                    ),
                  ],
                  if (entry.keywords.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Container(
                      key: Key('keywords-badge-${asset.id}'),
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(
                        Icons.sell_outlined,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                  ],
                  if (entry.keywords.contains('blurry')) ...[
                    const SizedBox(width: 4),
                    Container(
                      key: Key('blurry-badge-list-${asset.id}'),
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(
                        Icons.blur_on,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                  ],
                  if (entry.keywords.contains('closed_eyes')) ...[
                    const SizedBox(width: 4),
                    Container(
                      key: Key('closed-eyes-badge-list-${asset.id}'),
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(
                        Icons.visibility_off_outlined,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ],
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
/// displayed pixel size (cacheWidth) so the codec never inflates a big bitmap.
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
    required this.canSync,
    required this.onSync,
    required this.onVirtualCopy,
    required this.onPaste,
    required this.onExport,
    required this.canMerge,
    required this.onMergeHdr,
    this.onColorLabel,
    this.onKeywords,
    this.onPrint,
  });

  /// True only when exactly one photo is selected — the copy target must be
  /// unambiguous (#75).
  final bool canCopy;
  final VoidCallback onCopy;

  /// True when 2 or more photos are selected — allows batch syncing the first
  /// photo's edits to all other selected photos.
  final bool canSync;
  final VoidCallback onSync;

  final VoidCallback onVirtualCopy;
  final VoidCallback onPaste;
  final VoidCallback onExport;

  /// True when two or more photos are selected — HDR merge needs a bracket.
  final bool canMerge;
  final VoidCallback onMergeHdr;
  final VoidCallback? onColorLabel;
  final VoidCallback? onKeywords;
  final VoidCallback? onPrint;

  @override
  Widget build(BuildContext context) {
    // Icon-only secondary actions keep the whole bar on-screen even at 800px
    // test widths and on 360dp phones (six labeled buttons overflow past
    // 1100px, pushing Paste off-screen); Paste and Export keep their labels
    // as the primary actions. The viewport is right-aligned so the actions
    // stay in the thumb zone.
    return BottomAppBar(
      elevation: 2,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Align(
        alignment: Alignment.centerRight,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                key: const Key('color-label-action'),
                onPressed: onColorLabel,
                child: const Tooltip(
                  message: 'Color label',
                  child: Icon(Icons.palette_outlined, size: 18),
                ),
              ),
              const SizedBox(width: Insets.xs),
              TextButton(
                key: const Key('keywords-action'),
                onPressed: onKeywords,
                child: const Tooltip(
                  message: 'Keywords',
                  child: Icon(Icons.sell_outlined, size: 18),
                ),
              ),
              const SizedBox(width: Insets.xs),
              TextButton(
                key: const Key('copy-edits-action'),
                onPressed: canCopy ? onCopy : null,
                child: const Tooltip(
                  message: 'Copy edits',
                  child: Icon(Icons.copy, size: 18),
                ),
              ),
              const SizedBox(width: Insets.xs),
              TextButton(
                key: const Key('sync-edits-action'),
                onPressed: canSync ? onSync : null,
                child: const Tooltip(
                  message: 'Sync edits',
                  child: Icon(Icons.sync, size: 18),
                ),
              ),
              const SizedBox(width: Insets.xs),
              TextButton(
                key: const Key('virtual-copy-action'),
                onPressed: onVirtualCopy,
                child: const Tooltip(
                  message: 'Virtual copy',
                  child: Icon(Icons.copy_all_outlined, size: 18),
                ),
              ),
              const SizedBox(width: Insets.xs),
              TextButton.icon(
                key: const Key('paste-action'),
                onPressed: onPaste,
                icon: const Icon(Icons.paste, size: 18),
                label: const Text('Paste'),
              ),
              const SizedBox(width: Insets.xs),
              FilledButton.tonalIcon(
                onPressed: onExport,
                icon: const Icon(Icons.ios_share, size: 18),
                label: const Text('Export'),
              ),
              const SizedBox(width: Insets.xs),
              TextButton(
                key: const Key('hdr-merge-action'),
                onPressed: canMerge ? onMergeHdr : null,
                child: const Tooltip(
                  message: 'HDR Merge',
                  child: Icon(Icons.auto_awesome, size: 18),
                ),
              ),
              const SizedBox(width: Insets.xs),
              TextButton(
                key: const Key('print-action'),
                onPressed: onPrint,
                child: const Tooltip(
                  message: 'Print / Contact Sheet',
                  child: Icon(Icons.print_outlined, size: 18),
                ),
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

class _KeywordsSheet extends StatefulWidget {
  const _KeywordsSheet({
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
  State<_KeywordsSheet> createState() => _KeywordsSheetState();
}

class _KeywordsSheetState extends State<_KeywordsSheet> {
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

/// Album picker: the default "Recent" stream plus every device album.
class _AlbumSheet extends ConsumerWidget {
  const _AlbumSheet();

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

    return Semantics(
      label: 'Edited version: ${widget.preview.entryId}',
      button: true,
      onTap: widget.onTap,
      child: GestureDetector(
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
                if (catalogEntry != null && catalogEntry.colorLabel != null) ...[
                  const SizedBox(width: 4),
                  Container(
                    key: Key('color-label-${catalogEntry.colorLabel!.name}'),
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Color(catalogEntry.colorLabel!.colorValue),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ],
                if (catalogEntry != null && catalogEntry.keywords.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Container(
                    key: const Key('photo-keywords-badge'),
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(
                      Icons.label_outline,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ],
                if (catalogEntry != null && catalogEntry.keywords.contains('blurry')) ...[
                  const SizedBox(width: 4),
                  Container(
                    key: const Key('photo-blurry-badge'),
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(
                      Icons.blur_on,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ],
                if (catalogEntry != null && catalogEntry.keywords.contains('closed_eyes')) ...[
                  const SizedBox(width: 4),
                  Container(
                    key: const Key('photo-closed-eyes-badge'),
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(
                      Icons.visibility_off_outlined,
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
    ),
  );
}
}
