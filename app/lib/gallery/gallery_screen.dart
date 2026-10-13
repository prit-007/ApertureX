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
import 'gallery_asset.dart';
import 'gallery_controller.dart';
import 'gallery_export.dart';
import 'gallery_source.dart';
import '../ui/common/app_primitives.dart';
import '../ui/common/app_sheet.dart';
import '../ui/common/settings_sheet.dart';

/// The app home: the device gallery. Tap a photo to edit it; long-press to
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
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => EditorScreen(asset: asset)),
    );
  }

  void _openSample() {
    axLog(LogDomain.editor, 'Opened sample image');
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const EditorScreen()),
    );
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(galleryControllerProvider);
    final controller = ref.read(galleryControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          state.selectionMode ? '${state.selectedCount} selected' : 'Gallery',
        ),
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
        message: 'Allow photo access to browse and edit your library. '
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
        title: 'No photos yet',
        message: 'Photos on your device will appear here. '
            'Or try the editor with a sample image.',
        action: FilledButton.tonal(
          onPressed: _openSample,
          child: const Text('Open a sample'),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: state.assets.length,
      itemBuilder: (context, i) {
        final asset = state.assets[i];
        final selected = state.isSelected(asset.id);
        return _Cell(
          source: _source,
          asset: asset,
          selected: selected,
          selectionMode: state.selectionMode,
          onTap: () => state.selectionMode
              ? controller.toggle(asset.id)
              : _open(asset),
          onLongPress: () => controller.startSelection(asset.id),
        );
      },
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.source,
    required this.asset,
    required this.selected,
    required this.selectionMode,
    required this.onTap,
    required this.onLongPress,
  });

  final GallerySource source;
  final GalleryAsset asset;
  final bool selected;
  final bool selectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _Thumbnail(source: source, asset: asset),
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

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.source, required this.asset});

  final GallerySource source;
  final GalleryAsset asset;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<Uint8List>(
      future: source.loadThumbnail(asset.id),
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
        return Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
      },
    );
  }
}
