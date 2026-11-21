import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/design_tokens.dart';
import '../../edit/recipe.dart';
import '../../edit/recipe_controller.dart';
import '../../l10n/app_strings.dart';
import 'lightroom_common.dart';

/// The master tabs bar: a scrollable row of 6 consolidated Master Tabs.
///
/// Tapping a tab switches the active section. If the current tab has
/// uncommitted changes, an Apply / Discard / Cancel modal is shown first.
class MasterTabsBar extends ConsumerWidget {
  const MasterTabsBar({
    super.key,
    required this.activeTab,
    required this.tabEntryRecipe,
    required this.dirtyState,
    required this.onTabChanged,
    required this.scrollController,
  });

  final MasterTab activeTab;
  final EditRecipe? tabEntryRecipe;
  final LightroomDirtyState dirtyState;
  final ValueChanged<MasterTab> onTabChanged;
  final ScrollController scrollController;

  static const List<MasterTab> _masterTabs = [
    MasterTab.lightColor,
    MasterTab.effectsDetail,
    MasterTab.cropGeometry,
    MasterTab.proTools,
    MasterTab.looksPresets,
    MasterTab.masks,
    MasterTab.plugins,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final hasTabChanges = dirtyState.hasTabChanges;
    final controller = ref.read(recipeControllerProvider.notifier);

    Widget chip(MasterTab tab, bool selected, bool isModified,
        VoidCallback onTap) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ChoiceChip(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(masterTabLabel(tab, AppStrings.of(context))),
              if (isModified) ...[
                const SizedBox(width: 4),
                Container(
                  key: Key('applied-dot-${tab.name}'),
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected
                        ? scheme.primary
                        : scheme.primary.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ],
          ),
          selected: selected,
          onSelected: (_) => onTap(),
          showCheckmark: false,
          visualDensity: VisualDensity.compact,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          side: BorderSide(
            color: selected
                ? scheme.primary
                : isModified
                    ? scheme.primary.withValues(alpha: 0.5)
                    : scheme.outlineVariant.withValues(alpha: 0.4),
            width: selected ? 1.2 : 1.0,
          ),
          selectedColor: scheme.primary.withValues(alpha: 0.2),
          backgroundColor:
              scheme.surfaceContainerHigh.withValues(alpha: 0.45),
          labelStyle: TextStyle(
            fontSize: 12,
            letterSpacing: 0.4,
            color: selected
                ? scheme.primary
                : scheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      );
    }

    return SizedBox(
      height: 40,
      child: ListView(
        key: const Key('lightroom-master-tabs-bar'),
        controller: scrollController,
        physics: const BouncingScrollPhysics(),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        children: [
          for (final tab in _masterTabs)
            chip(
              tab,
              tab == activeTab,
              (dirtyState.modifiedMasterMask &
                      (1 << _masterTabs.indexOf(tab))) !=
                  0,
              () {
                HapticFeedback.selectionClick();
                // Tapping the currently active tab should never silently
                // commit changes.
                if (tab == activeTab) return;

                // Modal guard: block switching tabs while the current tab has
                // uncommitted changes. Offer Apply / Discard / Cancel so the
                // user is never stuck.
                if (hasTabChanges) {
                  HapticFeedback.heavyImpact();
                  _showUncommittedChangesDialog(
                    context: context,
                    notifier: controller,
                    tabLabel: masterTabLabel(activeTab),
                    onApply: () {
                      controller.commit(
                          label: 'Applied ${masterTabLabel(activeTab)}');
                      onTabChanged(tab);
                      final idx = _masterTabs.indexOf(tab);
                      _scrollToTab(scrollController, idx, context);
                    },
                    onDiscard: () {
                      controller.loadRecipe(
                        tabEntryRecipe!,
                        label:
                            'Discarded ${masterTabLabel(activeTab)} changes',
                      );
                      onTabChanged(tab);
                      final idx = _masterTabs.indexOf(tab);
                      _scrollToTab(scrollController, idx, context);
                    },
                  );
                  return;
                }
                onTabChanged(tab);
                final idx = _masterTabs.indexOf(tab);
                _scrollToTab(scrollController, idx, context);
              },
            ),
        ],
      ),
    );
  }
}

void _scrollToTab(ScrollController controller, int idx, BuildContext context) {
  if (!controller.hasClients) return;
  final target = (idx * 110.0 - 40.0).clamp(
    0.0,
    controller.position.maxScrollExtent,
  );
  controller.animateTo(
    target,
    duration: AppMotion.responsive(context, AppMotion.shortDuration),
    curve: AppMotion.standardCurve,
  );
}

Future<void> _showUncommittedChangesDialog({
  required BuildContext context,
  required RecipeController notifier,
  required String tabLabel,
  required VoidCallback onApply,
  required VoidCallback onDiscard,
}) async {
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Uncommitted changes in $tabLabel'),
      content: const Text(
        'You have uncommitted changes. Apply them, discard, or cancel?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop('discard'),
          child: const Text('Discard'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop('cancel'),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop('apply'),
          child: const Text('Apply'),
        ),
      ],
    ),
  );
  if (result == 'apply') {
    onApply();
  } else if (result == 'discard') {
    onDiscard();
  }
}
