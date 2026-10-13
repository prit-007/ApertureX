import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../color/lut_demo_screen.dart';
import '../gallery/gallery_screen.dart';
import '../settings/shell_preference.dart';
import '../viewport/image_canvas.dart';
import '../viewport/tile_viewport_demo.dart';
import 'common/history_sheet.dart';
import 'common/lut_import_sheet.dart';
import 'common/settings_sheet.dart';
import 'common/xmp_import_sheet.dart';
import 'lightroom/lightroom_shell.dart';
import 'snapseed/snapseed_shell.dart';

/// The app root (P2 Slice C): one shared [ImageCanvas] over one recipe, with
/// the shell chrome swapped below it. Switching shells never touches the
/// canvas or the recipe (ADR 0008 invariant).
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kind = ref.watch(shellPreferenceProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  const ImageCanvas(),
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FloatingActionButton.small(
                          heroTag: 'gallery',
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const GalleryScreen(),
                            ),
                          ),
                          child: const Icon(Icons.photo_library),
                        ),
                        const SizedBox(height: 8),
                        FloatingActionButton.small(
                          heroTag: 'history',
                          onPressed: () => showModalBottomSheet<void>(
                            context: context,
                            builder: (_) => const HistorySheet(),
                          ),
                          child: const Icon(Icons.history),
                        ),
                        const SizedBox(height: 8),
                        FloatingActionButton.small(
                          heroTag: 'lut-import',
                          onPressed: () => showModalBottomSheet<void>(
                            context: context,
                            builder: (_) => const LutImportSheet(),
                          ),
                          child: const Icon(Icons.gradient),
                        ),
                        const SizedBox(height: 8),
                        FloatingActionButton.small(
                          heroTag: 'xmp-import',
                          onPressed: () => showModalBottomSheet<void>(
                            context: context,
                            builder: (_) => const XmpImportSheet(),
                          ),
                          child: const Icon(Icons.auto_awesome),
                        ),
                        const SizedBox(height: 8),
                        FloatingActionButton.small(
                          heroTag: 'settings',
                          onPressed: () => showModalBottomSheet<void>(
                            context: context,
                            builder: (_) => const SettingsSheet(),
                          ),
                          child: const Icon(Icons.more_horiz),
                        ),
                        const SizedBox(height: 8),
                        FloatingActionButton.small(
                          heroTag: 'lut-demo',
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const LutDemoScreen(),
                            ),
                          ),
                          child: const Icon(Icons.science),
                        ),
                        const SizedBox(height: 8),
                        FloatingActionButton.small(
                          heroTag: 'viewport-demo',
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const TileViewportDemo(),
                            ),
                          ),
                          child: const Icon(Icons.zoom_out_map),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const _ShellToggle(),
            if (kind == AppShellKind.snapseed)
              const SnapseedShell()
            else
              const LightroomShell(),
          ],
        ),
      ),
    );
  }
}

class _ShellToggle extends ConsumerWidget {
  const _ShellToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kind = ref.watch(shellPreferenceProvider);

    Widget item(AppShellKind value, String label) {
      final selected = value == kind;
      return TextButton(
        onPressed: () => ref.read(shellPreferenceProvider.notifier).select(value),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white38,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        item(AppShellKind.lightroom, 'Lightroom'),
        item(AppShellKind.snapseed, 'Snapseed'),
      ],
    );
  }
}
