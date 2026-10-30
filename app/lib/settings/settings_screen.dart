import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../core/log/log_providers.dart';
import '../core/theme/design_tokens.dart';
import '../core/updater/update_dialog.dart';
import '../features/ai_plugins/ai_plugins_screen.dart';
import '../features/guide/app_guide_screen.dart';
import '../features/logs/logs_screen.dart';
import '../ui/common/app_primitives.dart';
import '../ui/common/editor_guide_sheet.dart';
import '../ui/common/settings_sheet.dart' show kOfflineClaim;
import 'ai_consent.dart';
import 'app_settings.dart';
import 'export_settings.dart';
import 'shell_preference.dart';

/// App-wide comprehensive settings screen.
///
/// Centralizes appearance, interface shell, stylus controls, engine performance,
/// export presets, local AI privacy, and diagnostics so three-dot menus remain lean.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Widget _cardSection({required BuildContext context, required List<Widget> children}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: 4),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
        color: theme.colorScheme.surfaceContainerLow,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final glassmorphic = ref.watch(glassmorphicUiProvider);
    final shell = ref.watch(shellPreferenceProvider);
    final stylus = ref.watch(stylusSettingsProvider);
    final tileLimit = ref.watch(tileCacheSettingsProvider);
    final export = ref.watch(exportSettingsProvider);
    final aiConsent = ref.watch(aiConsentProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: Insets.md),
        children: [
          // ─── 1. Appearance ──────────────────────────────────────────
          const SectionHeader('Appearance'),
          _cardSection(
            context: context,
            children: [
              Padding(
                padding: const EdgeInsets.all(Insets.md),
                child: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(value: ThemeMode.system, label: Text('System')),
                    ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                    ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                  ],
                  selected: {themeMode},
                  onSelectionChanged: (s) =>
                      ref.read(themeModeProvider.notifier).setThemeMode(s.first),
                ),
              ),
              SwitchListTile.adaptive(
                key: const Key('settings-screen-glassmorphic-toggle'),
                title: const Text('Glassmorphic UI'),
                subtitle: const Text(
                  'Translucent frosted-glass panels and HUD so the photo stays visible behind controls',
                ),
                value: glassmorphic,
                onChanged: (val) =>
                    ref.read(glassmorphicUiProvider.notifier).setEnabled(val),
              ),
            ],
          ),

          // ─── 2. Interface Shell ─────────────────────────────────────
          const SectionHeader('Interface Shell'),
          _cardSection(
            context: context,
            children: [
              Padding(
                padding: const EdgeInsets.all(Insets.md),
                child: SegmentedButton<AppShellKind>(
                  segments: const [
                    ButtonSegment(
                      value: AppShellKind.lightroom,
                      icon: Icon(Icons.tune),
                      label: Text('Precision Panels'),
                    ),
                    ButtonSegment(
                      value: AppShellKind.snapseed,
                      icon: Icon(Icons.gesture),
                      label: Text('Snapseed Gestures'),
                    ),
                  ],
                  selected: {shell},
                  onSelectionChanged: (s) =>
                      ref.read(shellPreferenceProvider.notifier).select(s.first),
                ),
              ),
            ],
          ),

          // ─── 3. Stylus & Touch Input ────────────────────────────────
          const SectionHeader('Stylus & Input'),
          _cardSection(
            context: context,
            children: [
              SwitchListTile.adaptive(
                key: const Key('settings-screen-palm-rejection'),
                title: const Text('Palm Rejection'),
                subtitle: const Text('Filter touch events when using an active stylus pen'),
                value: stylus.palmRejection,
                onChanged: (val) =>
                    ref.read(stylusSettingsProvider.notifier).setPalmRejection(val),
              ),
              const Divider(height: 1),
              SwitchListTile.adaptive(
                key: const Key('settings-screen-pressure-sensitivity'),
                title: const Text('Pressure Sensitivity'),
                subtitle: const Text('Vary brush flow and stroke thickness with pen pressure'),
                value: stylus.pressureSensitivity,
                onChanged: (val) =>
                    ref.read(stylusSettingsProvider.notifier).setPressureSensitivity(val),
              ),
            ],
          ),

          // ─── 4. Engine & Performance ────────────────────────────────
          const SectionHeader('Engine & Performance'),
          _cardSection(
            context: context,
            children: [
              Padding(
                padding: const EdgeInsets.all(Insets.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tile LRU Cache Limit',
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: Insets.xs),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 256, label: Text('256 MB')),
                        ButtonSegment(value: 512, label: Text('512 MB (Default)')),
                        ButtonSegment(value: 1024, label: Text('1024 MB')),
                      ],
                      selected: {tileLimit},
                      onSelectionChanged: (s) =>
                          ref.read(tileCacheSettingsProvider.notifier).setLimitMb(s.first),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              const ListTile(
                leading: Icon(Icons.speed),
                title: Text('60 FPS Zero-Copy Pipeline'),
                subtitle: Text('Direct Impeller GPU 3D LUT fragment shader chain enabled'),
              ),
              const Divider(height: 1),
              const ListTile(
                leading: Icon(Icons.color_lens_outlined),
                title: Text('Color Accuracy'),
                subtitle: Text('Wide-gamut Display-P3 to sRGB accurate preview & export'),
              ),
            ],
          ),

          // ─── 5. Export Defaults ─────────────────────────────────────
          const SectionHeader('Export Defaults'),
          _cardSection(
            context: context,
            children: [
              Padding(
                padding: const EdgeInsets.all(Insets.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Quality: ${export.quality}%'),
                        const Spacer(),
                      ],
                    ),
                    Slider(
                      value: export.quality.toDouble(),
                      min: 60,
                      max: 100,
                      divisions: 40,
                      label: '${export.quality}%',
                      onChanged: (v) =>
                          ref.read(exportSettingsProvider.notifier).setQuality(v.round()),
                    ),
                    const SizedBox(height: Insets.xs),
                    Text(
                      'Maximum Dimension',
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: Insets.xs),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 0, label: Text('Original')),
                        ButtonSegment(value: 2048, label: Text('2048 px')),
                        ButtonSegment(value: 1080, label: Text('1080 px')),
                        ButtonSegment(value: 720, label: Text('720 px')),
                      ],
                      selected: {export.maxDim},
                      onSelectionChanged: (s) =>
                          ref.read(exportSettingsProvider.notifier).setMaxDim(s.first),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ─── 6. Privacy & Local AI ──────────────────────────────────
          const SectionHeader('Privacy & Local AI'),
          _cardSection(
            context: context,
            children: [
              SwitchListTile.adaptive(
                key: const Key('settings-screen-ai-consent'),
                title: const Text('On-device AI Processing'),
                subtitle: const Text(
                  'Enables intelligent masking: Select Subject, Sky, and Depth-based Lens Blur. 100% offline, zero network access.',
                ),
                value: aiConsent == AiConsentStatus.granted,
                onChanged: (val) {
                  if (val) {
                    ref.read(aiConsentProvider.notifier).grantConsent();
                  } else {
                    ref.read(aiConsentProvider.notifier).revokeConsent();
                  }
                },
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(Insets.md),
                child: Card.outlined(
                  child: Padding(
                    padding: const EdgeInsets.all(Insets.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.security, size: 20, color: theme.colorScheme.primary),
                            const SizedBox(width: Insets.sm),
                            Text(
                              'F-Droid Privacy Guarantee',
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: Insets.xs),
                        Text(
                          kOfflineClaim,
                          key: const Key('settings-offline-claim'),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.hub_outlined),
                title: const Text('AI Models & Plugins (Neural Forge)'),
                subtitle: const Text('Install custom AI models via GitHub links, HuggingFace, or files'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AiPluginsScreen(),
                    ),
                  );
                },
              ),
            ],
          ),

          // ─── 7. Diagnostics & Logs ──────────────────────────────────
          const SectionHeader('Diagnostics'),
          _cardSection(
            context: context,
            children: [
              ListenableBuilder(
                listenable: activityLog,
                builder: (context, _) => ListTile(
                  leading: const Icon(Icons.receipt_long),
                  title: Text('Activity Log (${activityLog.length} events)'),
                  subtitle: const Text('On-device diagnostic feed of editor and engine events'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const LogsScreen()),
                    );
                  },
                ),
              ),
            ],
          ),

          // ─── 8. Help & Masterclasses ─────────────────────────────────
          const SectionHeader('Help & Academy'),
          _cardSection(
            context: context,
            children: [
              ListTile(
                leading: const Icon(Icons.school_outlined),
                title: const Text('ApertureX Academy'),
                subtitle: const Text('Interactive tool guides, pro tips, and photography masterclasses'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const AppGuideScreen()),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.gesture),
                title: const Text('Editor Gestures & Shortcuts'),
                subtitle: const Text('Interactive touch gestures, stylus workflow, and keyboard shortcuts'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => EditorGuideSheet.show(context),
              ),
            ],
          ),

          // ─── 9. About & Updates ──────────────────────────────────────
          const SectionHeader('About'),
          _cardSection(
            context: context,
            children: [
              ListTile(
                leading: const Icon(Icons.system_update_outlined),
                title: const Text('Check for Updates'),
                subtitle: const Text('Check GitHub Releases for the latest version & changelog'),
                trailing: const Icon(Icons.cloud_download_outlined),
                onTap: () => UpdateDialog.checkAndShow(context),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('About ApertureX'),
                subtitle: const Text('Version 0.2.0 · Pro-level FOSS Photo Editor'),
                onTap: () {
                  showAboutDialog(
                    context: context,
                    applicationName: 'ApertureX',
                    applicationVersion: '0.2.0',
                    applicationLegalese: 'Copyright © 2026 ApertureX Contributors\n\n$kOfflineClaim',
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.article_outlined),
                title: const Text('Open-Source Licenses'),
                subtitle: const Text('Material, Riverpod, Drift, and engine dependencies'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'ApertureX',
                  applicationVersion: '0.2.0',
                ),
              ),
              const Divider(height: 1),
              const ListTile(
                leading: Icon(Icons.balance_outlined),
                title: Text('LGPL Compliance Notice (#67)'),
                subtitle: Text('Dynamically links LibRaw and Lensfun under LGPL v2.1/v3.'),
              ),
            ],
          ),
          const SizedBox(height: Insets.xxl),
        ],
      ),
    );
  }
}
