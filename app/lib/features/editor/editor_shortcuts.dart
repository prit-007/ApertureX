import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../edit/library_catalog.dart';
import '../../edit/recipe_controller.dart';
import '../../edit/settings_clipboard.dart';
import '../../viewport/compare_hold.dart';

/// What a keyboard shortcut does — mapped 1:1 onto existing Riverpod notifiers
/// so shortcuts and touch UI always share one source of truth (#74).
enum EditorShortcutAction {
  toggleCompare,
  undo,
  redo,
  copySettings,
  pasteSettings,
  rate1,
  rate2,
  rate3,
  rate4,
  rate5,
  flag,
  help,
}

class EditorShortcutIntent extends Intent {
  const EditorShortcutIntent(this.action);

  final EditorShortcutAction action;
}

/// Desktop-class keyboard shortcuts for the editor (#74): Magic Keyboard /
/// Galaxy Tab pros never need to touch the screen for undo, copy/paste,
/// compare, ratings or flags.
///
/// Wraps its [child] in Flutter's `Shortcuts` → `Actions` → focus chain.
/// Dispatch reads the same notifiers the UI uses (one source of truth) and is
/// guarded: while a text field owns focus (rename dialogs, numeric inputs),
/// every shortcut is ignored so typing never mutates the library.
class EditorShortcuts extends ConsumerWidget {
  const EditorShortcuts({super.key, required this.entryId, required this.child});

  /// Catalog entry ratings/flags apply to — `orig:<assetId>` or `vc:<id>`.
  /// Null in sample mode (rating/flag shortcuts become no-ops).
  final String? entryId;

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Shortcuts(
      shortcuts: _shortcuts,
      child: Actions(
        actions: <Type, Action<Intent>>{
          EditorShortcutIntent: CallbackAction<EditorShortcutIntent>(
            onInvoke: (intent) {
              _invoke(context, ref, intent.action);
              return null;
            },
          ),
        },
        child: Focus(autofocus: true, child: child),
      ),
    );
  }

  /// Exact-modifier activators (SingleActivator requires a full match), so
  /// Ctrl+Z and Ctrl+Shift+Z never collide.
  static const Map<ShortcutActivator, Intent> _shortcuts = {
    SingleActivator(LogicalKeyboardKey.backslash): EditorShortcutIntent(
      EditorShortcutAction.toggleCompare,
    ),
    SingleActivator(LogicalKeyboardKey.keyZ, control: true): EditorShortcutIntent(
      EditorShortcutAction.undo,
    ),
    SingleActivator(LogicalKeyboardKey.keyZ, meta: true): EditorShortcutIntent(
      EditorShortcutAction.undo,
    ),
    SingleActivator(
      LogicalKeyboardKey.keyZ,
      control: true,
      shift: true,
    ): EditorShortcutIntent(EditorShortcutAction.redo),
    SingleActivator(
      LogicalKeyboardKey.keyZ,
      meta: true,
      shift: true,
    ): EditorShortcutIntent(EditorShortcutAction.redo),
    SingleActivator(LogicalKeyboardKey.keyY, control: true): EditorShortcutIntent(
      EditorShortcutAction.redo,
    ),
    SingleActivator(LogicalKeyboardKey.keyC, control: true): EditorShortcutIntent(
      EditorShortcutAction.copySettings,
    ),
    SingleActivator(LogicalKeyboardKey.keyC, meta: true): EditorShortcutIntent(
      EditorShortcutAction.copySettings,
    ),
    SingleActivator(LogicalKeyboardKey.keyV, control: true): EditorShortcutIntent(
      EditorShortcutAction.pasteSettings,
    ),
    SingleActivator(LogicalKeyboardKey.keyV, meta: true): EditorShortcutIntent(
      EditorShortcutAction.pasteSettings,
    ),
    SingleActivator(LogicalKeyboardKey.digit1): EditorShortcutIntent(
      EditorShortcutAction.rate1,
    ),
    SingleActivator(LogicalKeyboardKey.digit2): EditorShortcutIntent(
      EditorShortcutAction.rate2,
    ),
    SingleActivator(LogicalKeyboardKey.digit3): EditorShortcutIntent(
      EditorShortcutAction.rate3,
    ),
    SingleActivator(LogicalKeyboardKey.digit4): EditorShortcutIntent(
      EditorShortcutAction.rate4,
    ),
    SingleActivator(LogicalKeyboardKey.digit5): EditorShortcutIntent(
      EditorShortcutAction.rate5,
    ),
    SingleActivator(LogicalKeyboardKey.keyX): EditorShortcutIntent(
      EditorShortcutAction.flag,
    ),
    SingleActivator(
      LogicalKeyboardKey.slash,
      shift: true,
    ): EditorShortcutIntent(EditorShortcutAction.help),
  };

  void _invoke(
    BuildContext context,
    WidgetRef ref,
    EditorShortcutAction action,
  ) {
    if (_textFocused()) return;
    switch (action) {
      case EditorShortcutAction.toggleCompare:
        final hold = ref.read(compareHoldProvider);
        ref.read(compareHoldProvider.notifier).set(!hold);
      case EditorShortcutAction.undo:
        ref.read(recipeControllerProvider.notifier).undo();
      case EditorShortcutAction.redo:
        ref.read(recipeControllerProvider.notifier).redo();
      case EditorShortcutAction.copySettings:
        ref
            .read(settingsClipboardProvider.notifier)
            .copy(ref.read(recipeControllerProvider).recipe);
      case EditorShortcutAction.pasteSettings:
        final recipe = ref.read(settingsClipboardProvider);
        if (recipe != null) {
          ref
              .read(recipeControllerProvider.notifier)
              .loadRecipe(recipe, label: 'Pasted');
        }
      case EditorShortcutAction.rate1:
        _rate(ref, 1);
      case EditorShortcutAction.rate2:
        _rate(ref, 2);
      case EditorShortcutAction.rate3:
        _rate(ref, 3);
      case EditorShortcutAction.rate4:
        _rate(ref, 4);
      case EditorShortcutAction.rate5:
        _rate(ref, 5);
      case EditorShortcutAction.flag:
        final id = entryId;
        if (id != null) {
          final entry = ref.read(libraryCatalogProvider)[id];
          ref.read(libraryCatalogProvider.notifier).setFlag(id, !(entry?.flag ?? false));
        }
      case EditorShortcutAction.help:
        showDialog<void>(
          context: context,
          builder: (context) => const _ShortcutsSheet(),
        );
    }
  }

  void _rate(WidgetRef ref, int stars) {
    final id = entryId;
    if (id == null) return;
    ref.read(libraryCatalogProvider.notifier).setRating(id, stars);
  }

  /// True while the key press belongs to text input, not the editor: the
  /// focused node sits inside an [EditableText] (rename dialogs, numeric
  /// fields) and would otherwise race the shortcut.
  static bool _textFocused() {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null) return false;
    return context.widget is EditableText ||
        context.findAncestorWidgetOfExactType<EditableText>() != null;
  }
}

/// The `?` cheat sheet — every active shortcut in one place.
class _ShortcutsSheet extends StatelessWidget {
  const _ShortcutsSheet();

  static const _rows = [
    '\\ — Before/after',
    'Cmd/Ctrl+Z — Undo',
    'Cmd/Ctrl+Shift+Z — Redo',
    'Cmd/Ctrl+C — Copy settings',
    'Cmd/Ctrl+V — Paste settings',
    '1-5 — Star rating',
    'X — Flag for reject',
    '? — This sheet',
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Keyboard shortcuts'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [for (final row in _rows) Text(row)],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
