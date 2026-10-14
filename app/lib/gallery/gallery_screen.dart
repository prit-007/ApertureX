import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../core/log/activity_log.dart';
import '../core/log/log_providers.dart';
import '../core/theme/design_tokens.dart';
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
/// multi-select, then batch-paste a recipe or export (#12, #13).
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
    });
  }

  GallerySource get _source => ref.read(gallerySourceProvider);

  void _open(GalleryAsset asset) {
    axLog(LogDomain.editor, 'Opened photo ${asset.id}');
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => EditorScreen(asset: asset)));
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
    ref.read(recipeStoreProvider.notifier).pasteTo(state.selected, recipe);
    ref.read(galleryControllerProvider.notifier).clearSelection();
    _snack('Applied settings to ${state.selectedCount} photo(s)');
  }

  Future<void> _export() async {
    final state = ref.read(galleryControllerProvider);
    if (state.selected.isEmpty) return;
    try {
      final count = await GalleryExporter(_source).exportBatch(
        state.selected,
        (id) => ref.read(recipeStoreProvider)[id] ?? EditRecipe.neutral,
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

    return Scaffold(
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
          ? _SelectionBar(onPaste: _paste, onExport: _export)
          : null,
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
    final edited = ref.watch(recipeStoreProvider);
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
        slivers.add(
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
              ),
              itemCount: photos.length,
              itemBuilder: (context, j) {
                final asset = photos[j];
                return _Cell(
                  source: _source,
                  asset: asset,
                  selected: state.isSelected(asset.id),
                  edited: edited.containsKey(asset.id),
                  selectionMode: state.selectionMode,
                  onTap: () => state.selectionMode
                      ? controller.toggle(asset.id)
                      : _open(asset),
                  onLongPress: () => controller.startSelection(asset.id),
                );
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
  });

  final GallerySource source;
  final GalleryAsset asset;
  final bool selected;
  final bool edited;
  final bool selectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

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
  const _SelectionBar({required this.onPaste, required this.onExport});

  final VoidCallback onPaste;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      child: Row(
        children: [
          const Spacer(),
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
