import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/log/log_providers.dart';
import '../../core/theme/design_tokens.dart';
import '../../edit/recipe_controller.dart';
import '../../edit/settings_clipboard.dart';
import '../../features/logs/logs_screen.dart';
import '../../settings/ai_consent.dart';
import '../../settings/app_settings.dart';
import '../../settings/export_settings.dart';
import '../../settings/shell_preference.dart';
import '../../edit/active_image.dart';
import '../../edit/ai_mask_resolver.dart';
import 'app_sheet.dart';
import 'looks_sheet.dart';
import 'lut_export_sheet.dart';
import 'lut_import_sheet.dart';
import 'mask_controls.dart';
import 'xmp_import_sheet.dart';

/// The verifiable trust line (#76): stated in the settings footer and the
/// About dialog, and enforced against pubspec drift by
/// `test/core/offline_guard_test.dart`.
const String kOfflineClaim =
    '100% Offline. Zero Cloud Analytics. No AI training on your photos. '
    'You own your data.';

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
          onTap: () async {
            final cp = clipboard!;
            Navigator.of(context).maybePop();
            if (cp.layers.any((l) => l.aiIntent != null)) {
              final bytes = ref.read(activeImageBytesProvider);
              if (bytes != null) {
                ref.read(aiMaskInferringProvider.notifier).setInferring(true);
                ref.read(aiMaskStatusMessageProvider.notifier).setMessage(
                    'Smart Paste: Re-inferring AI masks for this photo… Please wait a moment');
                try {
                  final resolver = ref.read(aiMaskResolverProvider);
                  final segmenter = ref.read(subjectSegmenterProvider);
                  final skyDetector = ref.read(skyDetectorProvider);
                  final resolved = await resolver.resolveRecipe(
                    cp,
                    targetAssetId: 'photo_${bytes.hashCode}',
                    targetProxyBytes: bytes,
                    segmenter: segmenter,
                    skyDetector: skyDetector,
                  );
                  notifier.loadRecipe(resolved, label: 'Paste settings');
                } finally {
                  ref.read(aiMaskInferringProvider.notifier).setInferring(false);
                  ref.read(aiMaskStatusMessageProvider.notifier).setMessage(null);
                }
                return;
              }
            }
            notifier.loadRecipe(cp, label: 'Paste settings');
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
          icon: Icons.file_upload,
          title: 'Export Grade as .CUBE LUT',
          onTap: () => showAppSheet(context, const LutExportSheet()),
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
        const _Label('Export'),
        const _ExportSection(),
        const SizedBox(height: Insets.lg),
        const _Label('Diagnostics'),
        ListenableBuilder(
          listenable: activityLog,
          builder: (context, _) => _Action(
            icon: Icons.receipt_long,
            title: 'Activity log (${activityLog.length})',
            onTap: () => _openLogs(context),
          ),
        ),
        const SizedBox(height: Insets.lg),
        const _Label('Privacy & Local AI'),
        SwitchListTile.adaptive(
          key: const Key('settings-ai-consent-toggle'),
          title: const Text('On-device AI processing', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          subtitle: const Text(
            'Enables local intelligent masking (Select Subject/Sky). 100% offline, zero telemetry.',
            style: TextStyle(fontSize: 12),
          ),
          value: ref.watch(aiConsentProvider) == AiConsentStatus.granted,
          onChanged: (val) {
            if (val) {
              ref.read(aiConsentProvider.notifier).grantConsent();
            } else {
              ref.read(aiConsentProvider.notifier).revokeConsent();
            }
          },
        ),
        const SizedBox(height: Insets.lg),
        const _Label('About'),
        _Action(
          icon: Icons.info_outline,
          title: 'About ApertureX',
          onTap: () => _openAbout(context),
        ),
        _Action(
          icon: Icons.article_outlined,
          title: 'Open-source licenses',
          onTap: () => _openLicenses(context),
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
        const SizedBox(height: Insets.xs),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
            child: Text(
              kOfflineClaim,
              key: const Key('offline-claim'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
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

/// Closes the settings sheet, then opens the activity log on the same
/// navigator.
void _openLogs(BuildContext context) {
  final navigator = Navigator.of(context);
  navigator.maybePop();
  navigator.push(
    MaterialPageRoute<void>(builder: (_) => const LogsScreen()),
  );
}

void _openAbout(BuildContext context) {
  final navigator = Navigator.of(context);
  navigator.maybePop();
  showAboutDialog(
    context: navigator.context,
    applicationName: 'ApertureX',
    applicationVersion: '0.0.1 · P2',
    applicationLegalese: '© 2026 ApertureX contributors · GPL-3.0-or-later',
    children: const [
      SizedBox(height: Insets.md),
      Text(
        'A mobile-native, non-destructive, free and open-source photo editor.',
      ),
      SizedBox(height: Insets.sm),
      Text(kOfflineClaim),
    ],
  );
}

void _openLicenses(BuildContext context) {
  final navigator = Navigator.of(context);
  navigator.maybePop();
  showLicensePage(
    context: navigator.context,
    applicationName: 'ApertureX',
    applicationVersion: '0.0.1 · P2',
    applicationLegalese: 'GPL-3.0-or-later',
  );
}

/// Export quality + maximum-size controls (persisted).
class _ExportSection extends ConsumerWidget {
  const _ExportSection();

  static const _sizes = <(String, int)>[
    ('Original', 0),
    ('2048', 2048),
    ('1080', 1080),
    ('720', 720),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(exportSettingsProvider);
    final notifier = ref.read(exportSettingsProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const SizedBox(width: 72, child: Text('Quality')),
            Expanded(
              child: Slider(
                value: settings.quality.toDouble(),
                min: 60,
                max: 100,
                divisions: 40,
                label: '${settings.quality}',
                onChanged: (v) => notifier.setQuality(v.round()),
              ),
            ),
            SizedBox(
              width: 32,
              child: Text('${settings.quality}', textAlign: TextAlign.end),
            ),
          ],
        ),
        const SizedBox(height: Insets.sm),
        const Padding(
          padding: EdgeInsets.only(bottom: Insets.sm),
          child: Text('Max size (long side)'),
        ),
        Wrap(
          spacing: Insets.sm,
          children: [
            for (final (label, dim) in _sizes)
              ChoiceChip(
                label: Text(label),
                selected: settings.maxDim == dim,
                showCheckmark: false,
                onSelected: (_) => notifier.setMaxDim(dim),
              ),
          ],
        ),
      ],
    );
  }
}
