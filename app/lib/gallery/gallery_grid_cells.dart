import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:universal_io/io.dart';

import '../core/log/activity_log.dart';
import '../core/log/log_providers.dart';
import '../core/theme/design_tokens.dart';
import '../edit/library_catalog.dart';
import 'edit_preview_store.dart';
import 'gallery_asset.dart';
import 'gallery_source.dart';

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

/// Displayed when filters exclude every photo in the gallery or edits view.
class EmptyFilterCard extends StatelessWidget {
  const EmptyFilterCard({super.key, required this.onClearFilters});

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
sealed class GridItem {
  const GridItem();
}

final class OriginalItem extends GridItem {
  const OriginalItem(this.asset);

  final GalleryAsset asset;
}

final class VirtualItem extends GridItem {
  const VirtualItem(this.entry, this.asset);

  final CatalogEntry entry;
  final GalleryAsset asset;
}

class AlbumTitle extends StatelessWidget {
  const AlbumTitle({super.key, required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: 'Select album, current album: $title',
      hint: 'Double tap to open album list',
      child: Material(
        color: Colors.transparent,
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
      ),
    );
  }
}

/// Wraps a gallery cell with a staggered entrance animation: each cell fades
/// in and slides up slightly, delayed by its grid index, creating a ripple
/// effect when the library loads.
class StaggeredCell extends StatefulWidget {
  const StaggeredCell({super.key, required this.child, required this.index});

  final Widget child;
  final int index;

  @override
  State<StaggeredCell> createState() => _StaggeredCellState();
}

class _StaggeredCellState extends State<StaggeredCell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
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

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() {});
      }
    });

    if (AppMotion.reduceMotion || widget.index >= 12) {
      _controller.value = 1.0;
    } else {
      final delay = Duration(milliseconds: 30 * widget.index);
      Future.delayed(delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller.isCompleted) return widget.child;
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _offset,
        child: widget.child,
      ),
    );
  }
}

class DateHeader extends StatelessWidget {
  const DateHeader({super.key, required this.label});

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

class GalleryCell extends StatelessWidget {
  const GalleryCell({
    super.key,
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
                      fontSize: 12.0,
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
class VirtualCell extends StatelessWidget {
  const VirtualCell({
    super.key,
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

class EditPreviewCell extends StatefulWidget {
  const EditPreviewCell({
    super.key,
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
  State<EditPreviewCell> createState() => _EditPreviewCellState();
}

class _EditPreviewCellState extends State<EditPreviewCell> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _loadBytes();
  }

  @override
  void didUpdateWidget(EditPreviewCell old) {
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
      } catch (e, st) {
        axLog(LogDomain.gallery, 'Preview load bytes failed', level: LogLevel.warning, error: e.toString(), stack: st.toString());
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
