import 'package:material_ui/material_ui.dart';

import '../core/theme/design_tokens.dart';
import '../l10n/app_strings.dart';

/// Selection toolbar for bulk operations in the gallery.
class GallerySelectionBar extends StatelessWidget {
  const GallerySelectionBar({
    super.key,
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
    this.onApplyLook,
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
  final VoidCallback? onApplyLook;

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
                key: const Key('apply-look-action'),
                onPressed: onApplyLook,
                child: const Tooltip(
                  message: 'Apply look to selected',
                  child: Icon(Icons.auto_fix_high, size: 18),
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
                label: Text(AppStrings.of(context).paste),
              ),
              const SizedBox(width: Insets.xs),
              FilledButton.tonalIcon(
                onPressed: onExport,
                icon: const Icon(Icons.ios_share, size: 18),
                label: Text(AppStrings.of(context).export),
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
class ExportProgressBar extends StatelessWidget {
  const ExportProgressBar({
    super.key,
    required this.done,
    required this.total,
    required this.onCancel,
    this.overall,
  });

  final int done;
  final int total;
  final VoidCallback onCancel;

  /// Aggregated `(done + Σ fractions) / total` from
  /// `BatchProgressAggregator`; null falls back to the coarse `done / total`.
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
