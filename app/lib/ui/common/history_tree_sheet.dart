import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../edit/adjustment_layer.dart';
import '../../edit/history_tree.dart';
import '../../edit/node_editor.dart';
import '../../edit/recipe.dart';
import '../../edit/recipe_controller.dart';
import '../../edit/snapshots_provider.dart';
import '../../viewport/split_compare.dart';

/// Interactive modal sheet visualizing the Git-style Directed Acyclic Graph
/// (DAG) of non-destructive edit history, parallel branches, and named snapshots (Issue #97).
class HistoryTreeSheet extends ConsumerStatefulWidget {
  const HistoryTreeSheet({super.key});

  /// Displays the [HistoryTreeSheet] in a modal bottom sheet.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const HistoryTreeSheet(),
    );
  }

  @override
  ConsumerState<HistoryTreeSheet> createState() => _HistoryTreeSheetState();
}

class _HistoryTreeSheetState extends ConsumerState<HistoryTreeSheet> {
  int _selectedView = 0; // 0: History & Branches, 1: Snapshots

  String _formatRelativeTime(DateTime dt) {
    final now = DateTime.now().toUtc();
    final diff = now.difference(dt.toUtc());
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.month}/${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recipeControllerProvider);
    final tree = state.historyTree ??
        HistoryTree.initial(initialRecipe: state.committed);
    final snapshots = ref.watch(snapshotsProvider);
    final scheme = Theme.of(context).colorScheme;
    final activeBranch = tree.activeBranch;
    final branches = tree.branches.keys.toList();
    final lineage = tree.activeLineage;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.82,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.3)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    _selectedView == 0
                        ? Icons.alt_route
                        : _selectedView == 1
                            ? Icons.layers
                            : Icons.bookmarks_outlined,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedView == 0
                              ? 'Edit History & Branches'
                              : _selectedView == 1
                                  ? 'Edit Stacks (Snapseed Parity)'
                                  : 'Snapshots & Virtual Copies',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        Text(
                          _selectedView == 0
                              ? 'Non-linear DAG history · ${tree.nodes.length} commits'
                              : _selectedView == 1
                                  ? 'Stack view with selective brush re-entry'
                                  : 'Saved creative milestones · ${snapshots.length} saved',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Segmented switch: History vs Stacks vs Snapshots
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: SegmentedButton<int>(
                segments: [
                  ButtonSegment<int>(
                    value: 0,
                    label: Text('History (${lineage.length})'),
                    icon: const Icon(Icons.alt_route, size: 16),
                  ),
                  ButtonSegment<int>(
                    value: 1,
                    label: Text('Stacks (${state.recipe.layers.length + (lineage.length > 1 ? lineage.length - 1 : 0)})'),
                    icon: const Icon(Icons.layers, size: 16),
                  ),
                  ButtonSegment<int>(
                    value: 2,
                    label: Text('Snapshots (${snapshots.length})'),
                    icon: const Icon(Icons.bookmark_border, size: 16),
                  ),
                ],
                selected: {_selectedView},
                onSelectionChanged: (set) {
                  setState(() {
                    _selectedView = set.first;
                  });
                  HapticFeedback.selectionClick();
                },
              ),
            ),

            const SizedBox(height: 6),

            if (_selectedView == 0) ...[
              // Branch selector row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  height: 42,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final branch in branches)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            selected: branch == activeBranch,
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.call_split,
                                  size: 14,
                                  color: branch == activeBranch
                                      ? scheme.onPrimaryContainer
                                      : scheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Text(branch),
                              ],
                            ),
                            onSelected: (selected) {
                              if (branch != activeBranch) {
                                ref
                                    .read(recipeControllerProvider.notifier)
                                    .switchBranch(branch);
                                HapticFeedback.selectionClick();
                              }
                            },
                          ),
                        ),
                      ActionChip(
                        avatar: const Icon(Icons.add, size: 16),
                        label: const Text('New Branch'),
                        onPressed: () => _promptNewBranch(context, ref),
                      ),
                    ],
                  ),
                ),
              ),

              const Divider(height: 16),

              // Commit lineage tree list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: lineage.length,
                  itemBuilder: (context, idx) {
                    // Display from newest to oldest for intuitive history viewing
                    final node = lineage[lineage.length - 1 - idx];
                    final isCurrent = node.id == tree.currentNodeId;
                    final isRoot = node.parentId == null;
                    final branchHead = tree.branches[node.branchName] == node.id;

                    final branchColor = switch (node.branchName) {
                      'main' => scheme.primary,
                      'moody' || 'bw' || 'bw-moody' => Colors.purpleAccent,
                      'film' || 'vintage' => Colors.amber,
                      _ => Colors.tealAccent,
                    };

                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        ref
                            .read(recipeControllerProvider.notifier)
                            .jumpToNode(node.id);
                        HapticFeedback.lightImpact();
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? scheme.primaryContainer.withValues(alpha: 0.3)
                              : scheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isCurrent
                                ? scheme.primary
                                : scheme.outlineVariant.withValues(alpha: 0.2),
                            width: isCurrent ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Commit node indicator
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: branchColor,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: isCurrent ? 2.5 : 1,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            // Label and metadata
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          node.label,
                                          style: TextStyle(
                                            fontWeight: isCurrent
                                                ? FontWeight.bold
                                                : FontWeight.w500,
                                            color: isCurrent
                                                ? scheme.primary
                                                : scheme.onSurface,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      if (isCurrent)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: scheme.primary,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'HEAD',
                                            style: TextStyle(
                                              color: scheme.onPrimary,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 4,
                                    runSpacing: 2,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 5,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: branchColor.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          node.branchName,
                                          style: TextStyle(
                                            color: branchColor,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      if (branchHead) ...[
                                        Text(
                                          '· branch head',
                                          style: TextStyle(
                                            color: scheme.onSurfaceVariant,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                      if (isRoot) ...[
                                        Text(
                                          '· original unedited',
                                          style: TextStyle(
                                            color: scheme.onSurfaceVariant,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Branch from here button
                            IconButton(
                              icon: const Icon(Icons.add_road, size: 18),
                              tooltip: 'Branch from here',
                              onPressed: () {
                                ref
                                    .read(recipeControllerProvider.notifier)
                                    .jumpToNode(node.id);
                                _promptNewBranch(context, ref);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ] else if (_selectedView == 1) ...[
              // Stacks View (Snapseed parity: edit stack with per-step re-entry & masking)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Text(
                      'Applied Edits Stack',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const Spacer(),
                    Text(
                      'Tap 🖌️ to brush mask effect',
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 8),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  children: [
                    // Selective Adjustment Layers in reverse order (top of stack first)
                    for (int i = state.recipe.layers.length - 1; i >= 0; i--) ...[
                      Builder(builder: (context) {
                        final layer = state.recipe.layers[i];
                        final maskName = switch (layer.maskKind) {
                          MaskKind.linear => 'Linear Gradient',
                          MaskKind.radial => 'Radial Gradient',
                          MaskKind.brush => 'Brush Mask',
                          MaskKind.colorRange => 'Color Range Mask',
                          MaskKind.luminance => 'Luminance Range Mask',
                          MaskKind.depthRange => 'Depth Range Mask',
                          MaskKind.subject => 'AI Subject Mask',
                          MaskKind.sky => 'AI Sky Mask',
                          MaskKind.bitmap => 'Bitmap Mask',
                          MaskKind.autoBrush => 'Edge-Aware Auto Brush',
                        };
                        return Card.outlined(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              radius: 18,
                              backgroundColor: scheme.primaryContainer,
                              child: Icon(Icons.masks, size: 18, color: scheme.primary),
                            ),
                            title: Text(
                              maskName,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            subtitle: Text(
                              'Exp ${(layer.exposure >= 0 ? "+" : "")}${layer.exposure.toStringAsFixed(2)} · Sat ${(layer.saturation >= 0 ? "+" : "")}${layer.saturation.toStringAsFixed(2)}',
                              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.brush, size: 18),
                                  tooltip: 'Brush Selective Mask',
                                  onPressed: () {
                                    ref.read(nodeEditorProvider.notifier).enable();
                                    ref.read(nodeEditorProvider.notifier).select(i);
                                    Navigator.of(context).pop();
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18),
                                  tooltip: 'Delete Layer',
                                  onPressed: () {
                                    ref.read(recipeControllerProvider.notifier).removeLayerAt(i);
                                    HapticFeedback.lightImpact();
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                    // History steps along current lineage (excluding root initial)
                    for (int j = lineage.length - 1; j >= 1; j--) ...[
                      Builder(builder: (context) {
                        final node = lineage[j];
                        final isHead = node.id == tree.currentNodeId;
                        return Card.outlined(
                          margin: const EdgeInsets.only(bottom: 8),
                          color: isHead ? scheme.primary.withValues(alpha: 0.06) : null,
                          child: ListTile(
                            leading: CircleAvatar(
                              radius: 18,
                              backgroundColor: scheme.surfaceContainerHighest,
                              child: Icon(Icons.tune, size: 18, color: scheme.onSurfaceVariant),
                            ),
                            title: Text(
                              node.label,
                              style: TextStyle(
                                fontWeight: isHead ? FontWeight.bold : FontWeight.w600,
                                fontSize: 14,
                                color: isHead ? scheme.primary : null,
                              ),
                            ),
                            subtitle: Text(
                              'Commit #${node.id.substring(0, math.min(6, node.id.length))}',
                              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                            ),
                            trailing: TextButton.icon(
                              icon: const Icon(Icons.replay, size: 16),
                              label: const Text('Re-enter', style: TextStyle(fontSize: 12)),
                              onPressed: () {
                                ref.read(recipeControllerProvider.notifier).jumpToNode(node.id);
                                Navigator.of(context).pop();
                              },
                            ),
                          ),
                        );
                      }),
                    ],
                    // Base photo (Original)
                    Card.outlined(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: scheme.surfaceContainerHighest,
                          child: Icon(Icons.photo_outlined, size: 18, color: scheme.onSurfaceVariant),
                        ),
                        title: const Text(
                          'Original Photo',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        subtitle: const Text(
                          'Base unedited image',
                          style: TextStyle(fontSize: 11),
                        ),
                        trailing: TextButton(
                          onPressed: () {
                            ref.read(recipeControllerProvider.notifier).resetAll();
                            Navigator.of(context).pop();
                          },
                          child: const Text('Revert to Original', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Snapshots View
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Text(
                      'Saved Snapshots',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const Spacer(),
                    FilledButton.tonalIcon(
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('New Snapshot'),
                      onPressed: () =>
                          _promptNewSnapshot(context, ref, state.recipe),
                    ),
                  ],
                ),
              ),
              const Divider(height: 8),
              if (snapshots.isEmpty)
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.bookmark_add_outlined,
                            size: 48,
                            color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No Snapshots Saved',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Capture milestones or virtual copies of your look to compare or restore anytime.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            icon: const Icon(Icons.bookmark_add, size: 18),
                            label: const Text('Capture Current Edit'),
                            onPressed: () =>
                                _promptNewSnapshot(context, ref, state.recipe),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: snapshots.length,
                    itemBuilder: (context, idx) {
                      final snap = snapshots[idx];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        color: scheme.surfaceContainer,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: scheme.outlineVariant.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: scheme.primaryContainer
                                      .withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.bookmark,
                                  size: 20,
                                  color: scheme.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      snap.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _formatRelativeTime(snap.timestamp),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.restore, size: 16),
                                label: const Text('Restore'),
                                style: OutlinedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () {
                                  ref
                                      .read(recipeControllerProvider.notifier)
                                      .restoreRecipe(snap.recipe,
                                          label: 'Snapshot: ${snap.name}');
                                  HapticFeedback.lightImpact();
                                  Navigator.of(context).pop();
                                },
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.compare_arrows, size: 18),
                                tooltip: 'A/B Compare vs current',
                                onPressed: () {
                                  ref.read(snapshotCompareRecipeProvider.notifier).setRecipe(snap.recipe);
                                  ref.read(splitCompareProvider.notifier).setEnabled(true);
                                  HapticFeedback.mediumImpact();
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('A/B Split comparing against "${snap.name}"'),
                                      action: SnackBarAction(
                                        label: 'Restore',
                                        onPressed: () {
                                          ref.read(recipeControllerProvider.notifier).restoreRecipe(
                                            snap.recipe,
                                            label: 'Restored from ${snap.name}',
                                          );
                                        },
                                      ),
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18),
                                tooltip: 'Delete snapshot',
                                onPressed: () {
                                  ref
                                      .read(snapshotsProvider.notifier)
                                      .deleteSnapshot(snap.id);
                                  HapticFeedback.selectionClick();
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _promptNewBranch(BuildContext context, WidgetRef ref) async {
    final textController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Create New Branch'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Branch Name',
            hintText: 'e.g. bw-moody, film-gold, high-contrast',
          ),
          onSubmitted: (val) => Navigator.of(dialogCtx).pop(val.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.of(dialogCtx).pop(textController.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      ref.read(recipeControllerProvider.notifier).createBranch(name);
      HapticFeedback.mediumImpact();
    }
  }

  Future<void> _promptNewSnapshot(
    BuildContext context,
    WidgetRef ref,
    EditRecipe recipe,
  ) async {
    final textController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Create New Snapshot'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Snapshot Name',
            hintText: 'e.g. Golden Hour, Moody B&W, High Contrast',
          ),
          onSubmitted: (val) => Navigator.of(dialogCtx).pop(val.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.of(dialogCtx).pop(textController.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (name != null) {
      ref.read(snapshotsProvider.notifier).createSnapshot(
            name: name,
            recipe: recipe,
          );
      HapticFeedback.mediumImpact();
    }
  }
}
