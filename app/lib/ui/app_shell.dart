import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../core/theme/design_tokens.dart';
import '../settings/shell_preference.dart';
import '../viewport/image_canvas.dart';
import 'lightroom/lightroom_shell.dart';
import 'snapseed/snapseed_shell.dart';

/// The editor body shared by the app: the one [ImageCanvas] over the one recipe,
/// with the active shell's toolbar swapped below it. Switching shells never
/// touches the canvas or the recipe (ADR 0008 invariant) — which shell is active
/// is a user preference, not part of the edit.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, this.imageBytes});

  final Uint8List? imageBytes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kind = ref.watch(shellPreferenceProvider);
    final scheme = Theme.of(context).colorScheme;

    return ColoredBox(
      color: scheme.surface,
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: ImageCanvas(imageBytes: imageBytes),
                ),
                const _CompareHint(),
              ],
            ),
          ),
          Divider(height: 1, color: scheme.outlineVariant),
          if (kind == AppShellKind.snapseed)
            const SnapseedShell()
          else
            const LightroomShell(),
        ],
      ),
    );
  }
}

/// A quiet, non-interactive affordance reminding the user that long-pressing the
/// image shows the unedited "before".
class _CompareHint extends StatelessWidget {
  const _CompareHint();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.all(Insets.md),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
              borderRadius: Radii.smAll,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Insets.sm,
                vertical: Insets.xs,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.compare,
                    size: 14,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: Insets.xs),
                  Text(
                    'Hold to compare',
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
