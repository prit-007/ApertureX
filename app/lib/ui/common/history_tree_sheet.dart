import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../edit/history_tree.dart';
import '../../edit/recipe_controller.dart';

/// Interactive modal sheet visualizing the Git-style Directed Acyclic Graph
/// (DAG) of non-destructive edit history and parallel branches (Issue #97).
class HistoryTreeSheet extends ConsumerWidget {
  const HistoryTreeSheet({super.key});

  /// Displays the [HistoryTreeSheet] in a modal bottom sheet.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const HistoryTreeSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recipeControllerProvider);
    final tree = state.historyTree ??
        HistoryTree.initial(initialRecipe: state.committed);
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
                  Icon(Icons.alt_route, color: scheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Edit History & Branches',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        Text(
                          'Non-linear DAG history · ${tree.nodes.length} commits',
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
}
