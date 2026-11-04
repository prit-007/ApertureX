import 'dart:io' show Platform;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/error_dialog.dart' show rootNavigatorKey;
import '../../edit/recipe_controller.dart';
import '../../edit/settings_clipboard.dart';
import '../../features/editor/editor_screen.dart';
import '../../features/editor/export_screen.dart';
import '../../features/print/print_screen.dart';
import '../../features/tether/tether_screen.dart';
import '../../features/video/video_editor_screen.dart';
import '../../viewport/split_compare.dart';
import '../../viewport/wiper_compare.dart';

/// Wraps [child] with native macOS/desktop [PlatformMenuBar] when running on
/// desktop targets (macOS, Linux, Windows).
class DesktopMenuBar extends ConsumerWidget {
  const DesktopMenuBar({required this.child, super.key});

  final Widget child;

  bool get isDesktopPlatform {
    if (kIsWeb) return false;
    return Platform.isMacOS || Platform.isWindows || Platform.isLinux;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isDesktopPlatform) {
      return child;
    }

    final hasUndo = ref.watch(
      recipeControllerProvider.select((s) => s.index > 0),
    );
    final hasRedo = ref.watch(
      recipeControllerProvider.select((s) => s.index < s.history.length - 1),
    );
    final hasCopied = ref.watch(
      settingsClipboardProvider.select((s) => s != null),
    );
    final isWiperActive = ref.watch(
      wiperCompareProvider.select((s) => s.isActive),
    );
    final isSplitCompareActive = ref.watch(
      splitCompareProvider.select((s) => s.isEnabled),
    );

    return PlatformMenuBar(
      menus: [
        PlatformMenu(
          label: 'File',
          menus: [
            PlatformMenuItem(
              label: 'Open Photo…',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyO,
                meta: true,
              ),
              onSelected: () async {
                try {
                  final picked = await FilePicker.pickFile(type: FileType.image);
                  if (picked != null) {
                    final bytes = await picked.readAsBytes();
                    rootNavigatorKey.currentState?.push(
                      MaterialPageRoute<void>(builder: (_) => EditorScreen(imageBytes: bytes)),
                    );
                  }
                } catch (_) {}
              },
            ),
            PlatformMenuItem(
              label: 'Export Image…',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyS,
                meta: true,
              ),
              onSelected: () {
                final ctx = rootNavigatorKey.currentContext;
                if (ctx != null) {
                  final recipe = ref.read(recipeControllerProvider).recipe;
                  ExportScreen.open(ctx, recipe: recipe);
                }
              },
            ),
            PlatformMenuItem(
              label: 'Print / Contact Sheet…',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyP,
                meta: true,
              ),
              onSelected: () {
                rootNavigatorKey.currentState?.push(
                  MaterialPageRoute<void>(builder: (_) => const PrintScreen(items: [])),
                );
              },
            ),
            PlatformMenuItem(
              label: 'Studio Tethered Capture…',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyT,
                meta: true,
              ),
              onSelected: () {
                rootNavigatorKey.currentState?.push(
                  MaterialPageRoute<void>(builder: (_) => const TetherScreen()),
                );
              },
            ),
            PlatformMenuItem(
              label: 'Video Color Studio…',
              onSelected: () {
                rootNavigatorKey.currentState?.push(
                  MaterialPageRoute<void>(builder: (_) => const VideoEditorScreen()),
                );
              },
            ),
            const PlatformMenuItemGroup(
              members: [
                PlatformMenuItem(
                  label: 'Close Window',
                  shortcut: SingleActivator(
                    LogicalKeyboardKey.keyW,
                    meta: true,
                  ),
                  onSelected: null,
                ),
              ],
            ),
          ],
        ),
        PlatformMenu(
          label: 'Edit',
          menus: [
            PlatformMenuItem(
              label: 'Undo',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyZ,
                meta: true,
              ),
              onSelected: hasUndo
                  ? () => ref.read(recipeControllerProvider.notifier).undo()
                  : null,
            ),
            PlatformMenuItem(
              label: 'Redo',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyZ,
                meta: true,
                shift: true,
              ),
              onSelected: hasRedo
                  ? () => ref.read(recipeControllerProvider.notifier).redo()
                  : null,
            ),
            PlatformMenuItem(
              label: 'Copy Settings',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyC,
                meta: true,
                shift: true,
              ),
              onSelected: () {
                final recipe = ref.read(recipeControllerProvider).recipe;
                ref
                    .read(settingsClipboardProvider.notifier)
                    .copy(recipe);
              },
            ),
            PlatformMenuItem(
              label: 'Paste Settings',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyV,
                meta: true,
                shift: true,
              ),
              onSelected: hasCopied
                  ? () {
                      final copied = ref.read(settingsClipboardProvider);
                      if (copied != null) {
                        ref
                            .read(recipeControllerProvider.notifier)
                            .loadRecipe(copied, label: 'Pasted');
                      }
                    }
                  : null,
            ),
          ],
        ),
        PlatformMenu(
          label: 'View',
          menus: [
            PlatformMenuItem(
              label: isWiperActive
                  ? 'Exit A/B Wiper Compare'
                  : 'Split Curtain Wiper Compare',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.backslash,
              ),
              onSelected: () {
                ref.read(wiperCompareProvider.notifier).toggle();
              },
            ),
            PlatformMenuItem(
              label: 'Toggle Wiper Orientation',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.backslash,
                shift: true,
              ),
              onSelected: isWiperActive
                  ? () {
                      ref
                          .read(wiperCompareProvider.notifier)
                          .toggleOrientation();
                    }
                  : null,
            ),
            PlatformMenuItem(
              label: 'Reset Wiper to Center',
              onSelected: isWiperActive
                  ? () {
                      ref
                          .read(wiperCompareProvider.notifier)
                          .resetPosition();
                    }
                  : null,
            ),
            PlatformMenuItem(
              label: isSplitCompareActive
                  ? 'Exit Before/After Split View'
                  : 'Toggle Before/After Split View',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyY,
              ),
              onSelected: () {
                ref.read(splitCompareProvider.notifier).toggle();
              },
            ),
            PlatformMenuItem(
              label: 'Toggle Split View Orientation',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyY,
                shift: true,
              ),
              onSelected: isSplitCompareActive
                  ? () {
                      ref
                          .read(splitCompareProvider.notifier)
                          .toggleOrientation();
                    }
                  : null,
            ),
          ],
        ),
      ],
      child: child,
    );
  }
}
