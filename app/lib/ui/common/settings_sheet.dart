import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../edit/recipe_controller.dart';
import '../../edit/settings_clipboard.dart';

/// Session actions: reset all, and copy/paste the whole recipe.
class SettingsSheet extends ConsumerWidget {
  const SettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clipboard = ref.watch(settingsClipboardProvider);
    final notifier = ref.read(recipeControllerProvider.notifier);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.restart_alt),
            title: const Text('Reset all'),
            onTap: () {
              notifier.resetAll();
              Navigator.of(context).maybePop();
            },
          ),
          ListTile(
            leading: const Icon(Icons.copy),
            title: const Text('Copy settings'),
            onTap: () {
              ref
                  .read(settingsClipboardProvider.notifier)
                  .copy(ref.read(recipeControllerProvider).recipe);
              Navigator.of(context).maybePop();
            },
          ),
          ListTile(
            leading: const Icon(Icons.paste),
            enabled: clipboard != null,
            title: Text(
              clipboard == null ? 'Paste settings (empty)' : 'Paste settings',
            ),
            onTap: clipboard == null
                ? null
                : () {
                    notifier.loadRecipe(clipboard, label: 'Paste settings');
                    Navigator.of(context).maybePop();
                  },
          ),
        ],
      ),
    );
  }
}
