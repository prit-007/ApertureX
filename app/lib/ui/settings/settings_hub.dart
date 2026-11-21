import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/design_tokens.dart';
import '../../l10n/app_strings.dart';
import 'settings_about_sheet.dart';
import 'settings_ai_sheet.dart';
import 'settings_export_defaults_sheet.dart';
import 'settings_shell_sheet.dart';
import 'settings_stylus_sheet.dart';

/// Settings Hub offering modular navigation into dedicated configuration sheets.
class SettingsHub extends ConsumerWidget {
  const SettingsHub({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const SafeArea(child: SettingsHub()),
    );
  }

  Widget _categoryTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: Insets.xs),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      color: theme.colorScheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12.0)),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final s = AppStrings.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.tune, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(s.settingsHub, style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 12),
          _categoryTile(
            context,
            icon: Icons.dashboard_customize_outlined,
            title: s.workspaceAndShell,
            subtitle: s.workspaceAndShellDesc,
            onTap: () => SettingsShellSheet.show(context),
          ),
          _categoryTile(
            context,
            icon: Icons.draw_outlined,
            title: s.stylusAndInput,
            subtitle: s.stylusAndInputDesc,
            onTap: () => SettingsStylusSheet.show(context),
          ),
          _categoryTile(
            context,
            icon: Icons.save_alt_rounded,
            title: s.exportDefaults,
            subtitle: s.exportDefaultsDesc,
            onTap: () => SettingsExportDefaultsSheet.show(context),
          ),
          _categoryTile(
            context,
            icon: Icons.lock_outline,
            title: s.privacyAndLocalAi,
            subtitle: s.privacyAndLocalAiDesc,
            onTap: () => SettingsAiSheet.show(context),
          ),
          _categoryTile(
            context,
            icon: Icons.info_outline,
            title: s.aboutApertureX,
            subtitle: s.aboutApertureXDesc,
            onTap: () => SettingsAboutSheet.show(context),
          ),
        ],
      ),
    );
  }
}
