import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../core/log/activity_log.dart';
import '../core/log/log_providers.dart';
import '../core/theme/design_tokens.dart';
import '../edit/library_catalog.dart';
import '../edit/parameter.dart';
import '../edit/recipe.dart';
import '../edit/recipe_store.dart';
import '../edit/selective_recipe.dart';
import '../edit/settings_clipboard.dart';
import '../features/editor/editor_screen.dart';
import '../settings/app_settings.dart';
import '../ui/common/app_primitives.dart';
import 'edit_preview_store.dart';
import 'gallery_asset.dart';
import 'gallery_controller.dart';
import 'gallery_grouping.dart';
import 'staggered_photo_grid.dart';

enum EditedFilter { all, saved, copies }

/// Dedicated view showing only edited versions with rendered thumbnails,
/// recipe tags, and direct one-tap opening in the editor (Lightroom Edits parity).
class EditedVersionsScreen extends ConsumerStatefulWidget {
  const EditedVersionsScreen({super.key});

  @override
  ConsumerState<EditedVersionsScreen> createState() => _EditedVersionsScreenState();
}

class _EditedVersionsScreenState extends ConsumerState<EditedVersionsScreen> {
  EditedFilter _filter = EditedFilter.all;

  void _openPreview(EditPreview preview) async {
    final file = File(preview.path);
    if (!file.existsSync()) return;
    final bytes = file.readAsBytesSync();
    axLog(LogDomain.editor, 'Opened edited version ${preview.entryId}');

    final assets = ref.read(galleryControllerProvider).assets;
    final matching = assets.cast<GalleryAsset?>().firstWhere(
      (a) => a?.id == sourceAssetIdFor(preview.entryId),
      orElse: () => null,
    );

    await Navigator.of(context).push<dynamic>(
      MaterialPageRoute<dynamic>(
        builder: (_) => EditorScreen(
          asset: matching,
          entryId: preview.entryId,
          imageBytes: bytes,
        ),
      ),
    );
  }

  void _copySettings(EditRecipe recipe) {
    ref.read(settingsClipboardProvider.notifier).copy(recipe);
    axLog(LogDomain.editor, 'Copied settings from edited version');
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text('Copied edit settings to clipboard'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isGlass = ref.watch(glassmorphicUiProvider);
    final theme = Theme.of(context);
    final previewsAsync = ref.watch(editPreviewsStreamProvider);
    final catalog = ref.watch(libraryCatalogProvider);
    final recipeStore = ref.watch(recipeStoreProvider);

    return Scaffold(
      extendBodyBehindAppBar: isGlass,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: isGlass
            ? ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: AppBar(
                    backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.65),
                    elevation: 0,
                    title: const Text('Edited Versions'),
                  ),
                ),
              )
            : AppBar(
                title: const Text('Edited Versions'),
              ),
      ),
      body: previewsAsync.when(
        loading: () => const SizedBox.shrink(),
        error: (e, _) => Center(child: Text('Error loading edits: $e')),
        data: (previews) {
          // Filter previews if needed
          final displayed = previews.where((p) {
            final isCopy = !p.entryId.startsWith('orig:');
            return switch (_filter) {
              EditedFilter.all => true,
              EditedFilter.saved => !isCopy,
              EditedFilter.copies => isCopy,
            };
          }).toList();

          if (displayed.isEmpty) {
            return _emptyState();
          }

          return Column(
            children: [
              if (isGlass) const SizedBox(height: kToolbarHeight),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
                child: SegmentedButton<EditedFilter>(
                  segments: const [
                    ButtonSegment(value: EditedFilter.all, label: Text('All Edits')),
                    ButtonSegment(value: EditedFilter.saved, label: Text('Saved')),
                    ButtonSegment(value: EditedFilter.copies, label: Text('Virtual Copies')),
                  ],
                  selected: {_filter},
                  onSelectionChanged: (set) => setState(() => _filter = set.first),
                ),
              ),
              Expanded(
                child: () {
                  final sorted = [...displayed]..sort((a, b) => b.created.compareTo(a.created));
                  final grouped = <String, List<EditPreview>>{};
                  for (final item in sorted) {
                    final label = dateHeaderLabel(item.created);
                    (grouped[label] ??= []).add(item);
                  }

                  return CustomScrollView(
                    slivers: [
                      for (final entry in grouped.entries) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              Insets.md,
                              Insets.md,
                              Insets.md,
                              Insets.xs,
                            ),
                            child: Text(
                              entry.key,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Insets.sm,
                            vertical: Insets.xs,
                          ),
                          sliver: SliverToBoxAdapter(
                            child: StaggeredPhotoGrid(
                              crossAxisCount: 2,
                              spacing: Insets.sm,
                              itemCount: entry.value.length,
                              itemBuilder: (context, index) {
                                final item = entry.value[index];
                                final catEntry = catalog[item.entryId];
                                final recipe = recipeStore[item.entryId] ??
                                    catEntry?.recipe ??
                                    EditRecipe.neutral;
                                final modifiedSections =
                                    CopiedSettings.detectModifiedSections(recipe);

                                return _EditedCard(
                                  preview: item,
                                  title: catEntry?.label ?? item.entryId,
                                  sections: modifiedSections,
                                  onTap: () => _openPreview(item),
                                  onCopy: () => _copySettings(recipe),
                                  onDelete: () {
                                    ref
                                        .read(editPreviewStoreProvider)
                                        .delete(item.entryId);
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                      const SliverToBoxAdapter(child: SizedBox(height: Insets.lg)),
                    ],
                  );
                }(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _emptyState() {
    return EmptyState(
      icon: Icons.auto_fix_normal_outlined,
      title: 'No edited versions yet',
      message:
          'Edits, virtual copies, and saved versions will appear here with rich recipe thumbnails just like Lightroom.',
      action: FilledButton.tonal(
        onPressed: () => Navigator.of(context).maybePop(),
        child: const Text('Back to Gallery'),
      ),
    );
  }
}

class _EditedCard extends StatelessWidget {
  const _EditedCard({
    required this.preview,
    required this.title,
    required this.sections,
    required this.onTap,
    required this.onCopy,
    required this.onDelete,
  });

  final EditPreview preview;
  final String title;
  final Set<RecipeSection> sections;
  final VoidCallback onTap;
  final VoidCallback onCopy;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final file = File(preview.path);

    final aspect = (preview.width > 0 && preview.height > 0)
        ? (preview.width / preview.height).clamp(0.65, 1.8)
        : 1.0;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: aspect,
              child: file.existsSync()
                  ? Image.file(file, fit: BoxFit.cover)
                  : Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.broken_image, size: 36),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(Insets.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        iconSize: 18,
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'copy', child: Text('Copy Settings')),
                          const PopupMenuItem(value: 'delete', child: Text('Delete Preview')),
                        ],
                        onSelected: (val) {
                          if (val == 'copy') onCopy();
                          if (val == 'delete') onDelete();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: sections.take(3).map((s) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _sectionName(s),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontSize: 10,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _sectionName(RecipeSection s) => switch (s) {
    RecipeSection.light => 'Light',
    RecipeSection.color => 'Color',
    RecipeSection.tone => 'Curves',
    RecipeSection.effects => 'Effects',
    RecipeSection.detail => 'Detail',
    RecipeSection.optics => 'Optics',
    RecipeSection.geometry => 'Geometry',
    RecipeSection.blur => 'Blur',
    RecipeSection.masking => 'Masking',
    RecipeSection.retouch => 'Retouch',
    RecipeSection.film => 'Film',
    RecipeSection.lab => 'Lab',
  };
}
