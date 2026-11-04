import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../gallery/photo_navigator.dart';
import '../../gallery/gallery_controller.dart';

/// Visible filmstrip / prev-next navigation for the editor.
///
/// Shows thumbnails of all photos in the current gallery, with the currently
/// edited photo highlighted. Tapping a thumbnail switches to that photo.
/// Prev/Next buttons cycle through the library (with wrap-around at the ends).
///
/// AGENTS.md: universal coverage — compact phones to 14" tablets.
class Filmstrip extends ConsumerWidget {
  const Filmstrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nav = ref.watch(photoNavigatorProvider);
    final notifier = ref.read(photoNavigatorProvider.notifier);
    final scheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Count indicator + prev/next controls
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Text(
                '${nav.assetCount} photos',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const Spacer(),
              IconButton(
                key: const Key('filmstrip-previous'),
                onPressed: nav.canGoPrevious ? notifier.goPrevious : null,
                icon: const Icon(Icons.chevron_left, size: 18),
                tooltip: 'Previous photo',
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                key: const Key('filmstrip-next'),
                onPressed: nav.canGoNext ? notifier.goNext : null,
                icon: const Icon(Icons.chevron_right, size: 18),
                tooltip: 'Next photo',
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
        // Thumbnail scroll row
        SizedBox(
          height: 72,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: nav.assetCount,
            itemBuilder: (context, index) {
              final asset = nav.assets[index];
              final isCurrent = index == nav.currentIndex;
              return GestureDetector(
                key: Key('filmstrip-thumbnail-${asset.id}'),
                onTap: () => notifier.jumpTo(index),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                    border: isCurrent
                        ? Border.all(
                            color: scheme.primary,
                            width: 3,
                          )
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: FutureBuilder<Uint8List>(
                      future: ref
                          .read(gallerySourceProvider)
                          .loadThumbnail(asset.id),
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                          return Image.memory(
                            snapshot.data!,
                            fit: BoxFit.cover,
                            width: 64,
                            height: 64,
                          );
                        }
                        return const Center(
                          child: Icon(Icons.image, size: 24),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
