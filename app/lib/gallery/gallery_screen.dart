import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../edit/recipe.dart';
import '../edit/recipe_store.dart';
import '../edit/settings_clipboard.dart';
import 'gallery_asset.dart';
import 'gallery_controller.dart';
import 'gallery_export.dart';
import 'gallery_source.dart';

/// Device gallery with multi-select and **batch paste-recipe** (#13). Opening
/// the screen loads thumbnails; long-press enters selection; "Paste" writes the
/// clipboard recipe to every selected asset; "Export" bakes them to DCIM (#12).
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

  void _paste() {
    final state = ref.read(galleryControllerProvider);
    if (state.selected.isEmpty) return;
    final recipe =
        ref.read(settingsClipboardProvider) ?? EditRecipe.neutral;
    ref
        .read(recipeStoreProvider.notifier)
        .pasteTo(state.selected, recipe);
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
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          state.selectionMode ? '${state.selectedCount} selected' : 'Gallery',
        ),
        actions: [
          if (state.selectionMode) ...[
            TextButton(onPressed: _paste, child: const Text('Paste')),
            TextButton(onPressed: _export, child: const Text('Export')),
            IconButton(
              onPressed: controller.clearSelection,
              icon: const Icon(Icons.close),
            ),
          ] else
            IconButton(
              onPressed: controller.selectAll,
              icon: const Icon(Icons.select_all),
            ),
        ],
      ),
      body: _body(state, controller),
    );
  }

  Widget _body(GalleryState state, GalleryController controller) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Could not read the gallery:\n${state.error}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      );
    }
    if (state.assets.isEmpty) {
      return const Center(
        child: Text(
          'No photos found.',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: state.assets.length,
      itemBuilder: (context, i) {
        final asset = state.assets[i];
        final selected = state.isSelected(asset.id);
        return GestureDetector(
          onLongPress: () => controller.startSelection(asset.id),
          onTap: () => state.selectionMode
              ? controller.toggle(asset.id)
              : controller.startSelection(asset.id),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _Thumbnail(source: _source, asset: asset),
              if (selected)
                Container(color: Colors.white24)
              else
                const SizedBox.shrink(),
              if (selected)
                const Positioned(
                  right: 4,
                  top: 4,
                  child: Icon(Icons.check_circle, color: Colors.white),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.source, required this.asset});

  final GallerySource source;
  final GalleryAsset asset;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: source.loadThumbnail(asset.id),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null || bytes.isEmpty) {
          return const ColoredBox(color: Color(0xFF1A1A1A));
        }
        return Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
      },
    );
  }
}
