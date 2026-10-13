import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/design_tokens.dart';
import '../../edit/recipe_controller.dart';
import '../../edit/settings_clipboard.dart';
import '../../settings/app_settings.dart';
import '../../settings/shell_preference.dart';
import 'app_sheet.dart';
import 'looks_sheet.dart';
import 'lut_import_sheet.dart';
import 'xmp_import_sheet.dart';

/// The settings sheet: appearance, which interface shell is active, session
/// actions (reset / copy / paste) and preset & look import (ADR 0008, 0009,
/// 0011). Everything the old debug FAB pile used to expose lives here.
class SettingsSheet extends ConsumerWidget {
  const SettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clipboard = ref.watch(settingsClipboardProvider);
    final themeMode = ref.watch(themeModeProvider);
    final shell = ref.watch(shellPreferenceProvider);
    final notifier = ref.read(recipeControllerProvider.notifier);

    return AppSheet(
      title: 'Settings',
      children: [
        const _Label('Appearance'),
        SegmentedButton<ThemeMode>(
          segments: const [
            ButtonSegment(value: ThemeMode.system, label: Text('System')),
            ButtonSegment(value: ThemeMode.light, label: Text('Light')),
            ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
          ],
          selected: {themeMode},
          onSelectionChanged: (s) =>
              ref.read(themeModeProvider.notifier).setThemeMode(s.first),
        ),
        const SizedBox(height: Insets.lg),
        const _Label('Interface'),
        SegmentedButton<AppShellKind>(
          segments: const [
            ButtonSegment(
              value: AppShellKind.lightroom,
              icon: Icon(Icons.tune),
              label: Text('Panels'),
            ),
            ButtonSegment(
              value: AppShellKind.snapseed,
              icon: Icon(Icons.gesture),
              label: Text('Gestures'),
            ),
          ],
          selected: {shell},
          onSelectionChanged: (s) =>
              ref.read(shellPreferenceProvider.notifier).select(s.first),
        ),
        const SizedBox(height: Insets.lg),
        const _Label('Session'),
        _Action(
          icon: Icons.restart_alt,
          title: 'Reset all',
          onTap: () {
            notifier.resetAll();
            Navigator.of(context).maybePop();
          },
        ),
        _Action(
          icon: Icons.copy,
          title: 'Copy settings',
          onTap: () {
            ref
                .read(settingsClipboardProvider.notifier)
                .copy(ref.read(recipeControllerProvider).recipe);
            Navigator.of(context).maybePop();
          },
        ),
        _Action(
          icon: Icons.paste,
          title: clipboard == null
              ? 'Paste settings (nothing copied)'
              : 'Paste settings',
          enabled: clipboard != null,
          onTap: () {
            notifier.loadRecipe(clipboard!, label: 'Paste settings');
            Navigator.of(context).maybePop();
          },
        ),
        const SizedBox(height: Insets.lg),
        const _Label('Presets & looks'),
        _Action(
          icon: Icons.gradient,
          title: 'Import a .cube LUT',
          onTap: () => showAppSheet(context, const LutImportSheet()),
        ),
        _Action(
          icon: Icons.auto_awesome,
          title: 'Import a Lightroom .xmp preset',
          onTap: () => showAppSheet(context, const XmpImportSheet()),
        ),
        _Action(
          icon: Icons.auto_fix_high,
          title: 'Browse looks',
          onTap: () => showAppSheet(context, const LooksSheet()),
        ),
        const SizedBox(height: Insets.lg),
        Center(
          child: Text(
            'ApertureX 0.0.1 · P2',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.title,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      enabled: enabled,
      onTap: enabled ? onTap : null,
    );
  }
}
