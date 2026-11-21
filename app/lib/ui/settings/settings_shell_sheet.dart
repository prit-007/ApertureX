import 'package:flutter/material.dart' hide ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' show ThemeMode;

import '../../l10n/app_strings.dart';
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
    final strings = AppStrings.of(context);

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
              Text(strings.workspaceAndShell, style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 16),
          Text(strings.editorShellLayout, style: theme.textTheme.labelMedium),
          const SizedBox(height: 6),
          SegmentedButton<AppShellKind>(
            key: const Key('shell-selector-segmented'),
            segments: [
              ButtonSegment(
                value: AppShellKind.lightroom,
                icon: const Icon(Icons.tune),
                label: Text(strings.panelsLightroom),
              ),
              ButtonSegment(
                value: AppShellKind.snapseed,
                icon: const Icon(Icons.gesture),
                label: Text(strings.gesturesSnapseed),
              ),
            ],
            selected: {shell},
            onSelectionChanged: (s) =>
                ref.read(shellPreferenceProvider.notifier).select(s.first),
          ),
          const SizedBox(height: 16),
          Text(strings.themeMode, style: theme.textTheme.labelMedium),
          const SizedBox(height: 6),
          SegmentedButton<ThemeMode>(
            key: const Key('theme-selector-segmented'),
            segments: [
              ButtonSegment(value: ThemeMode.system, label: Text(strings.systemTheme)),
              ButtonSegment(value: ThemeMode.light, label: Text(strings.lightTheme)),
              ButtonSegment(value: ThemeMode.dark, label: Text(strings.darkTheme)),
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
            title: Text(
              strings.glassmorphicUi,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              strings.glassmorphicUiDesc,
              style: const TextStyle(fontSize: 12.0),
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
