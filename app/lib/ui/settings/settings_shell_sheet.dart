import 'package:flutter/material.dart' hide ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' show ThemeMode;

import '../../settings/app_settings.dart';
import '../../settings/shell_preference.dart';

/// Settings sheet for Workspace & Shell configuration (Lightroom vs Snapseed, Theme, Glassmorphism).
class SettingsShellSheet extends ConsumerWidget {
  const SettingsShellSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const SafeArea(child: SettingsShellSheet()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final shell = ref.watch(shellPreferenceProvider);
    final themeMode = ref.watch(themeModeProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.dashboard_customize_outlined, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text('Workspace & Shell', style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 16),
          Text('Editor Shell Layout', style: theme.textTheme.labelMedium),
          const SizedBox(height: 6),
          SegmentedButton<AppShellKind>(
            key: const Key('shell-selector-segmented'),
            segments: const [
              ButtonSegment(
                value: AppShellKind.lightroom,
                icon: Icon(Icons.tune),
                label: Text('Panels (Lightroom)'),
              ),
              ButtonSegment(
                value: AppShellKind.snapseed,
                icon: Icon(Icons.gesture),
                label: Text('Gestures (Snapseed)'),
              ),
            ],
            selected: {shell},
            onSelectionChanged: (s) =>
                ref.read(shellPreferenceProvider.notifier).select(s.first),
          ),
          const SizedBox(height: 16),
          Text('Theme Mode', style: theme.textTheme.labelMedium),
          const SizedBox(height: 6),
          SegmentedButton<ThemeMode>(
            key: const Key('theme-selector-segmented'),
            segments: const [
              ButtonSegment(value: ThemeMode.system, label: Text('System')),
              ButtonSegment(value: ThemeMode.light, label: Text('Light')),
              ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
            ],
            selected: {themeMode},
            onSelectionChanged: (s) =>
                ref.read(themeModeProvider.notifier).setThemeMode(s.first),
          ),
          const SizedBox(height: 16),
          SwitchListTile.adaptive(
            dense: true,
            key: const Key('settings-glassmorphic-toggle'),
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Glassmorphic UI',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            subtitle: const Text(
              'Translucent frosted-glass panels and HUD so photo stays visible',
              style: TextStyle(fontSize: 11),
            ),
            value: ref.watch(glassmorphicUiProvider),
            onChanged: (val) =>
                ref.read(glassmorphicUiProvider.notifier).setEnabled(val),
          ),
        ],
      ),
    );
  }
}
