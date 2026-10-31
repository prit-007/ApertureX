import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/log/log_providers.dart';
import '../../core/theme/design_tokens.dart';
import '../../edit/recipe_controller.dart';
import '../../edit/settings_clipboard.dart';
import '../../features/ai_plugins/ai_plugins_screen.dart';
import '../../features/guide/app_guide_screen.dart';
import '../../features/logs/logs_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../gallery/edited_versions_screen.dart';
import '../../settings/ai_consent.dart';
import '../../settings/app_settings.dart';
import '../../settings/export_settings.dart';
import '../../settings/settings_screen.dart';
import '../../settings/shell_preference.dart';
import '../../edit/active_image.dart'
    show activeImageBytesProvider, currentEditingAssetProvider;
import '../../edit/ai_mask_resolver.dart';
import '../../gallery/gallery_controller.dart' show gallerySourceProvider;
import 'app_sheet.dart';
import 'copy_settings_sheet.dart';
import 'looks_sheet.dart';
import 'lut_export_sheet.dart';
import 'lut_import_sheet.dart';
import 'mask_controls.dart';
import 'xmp_import_sheet.dart';
import 'editor_guide_sheet.dart';
import '../../features/editor/image_info_sheet.dart';
import '../../features/crop/crop_screen.dart';
import '../../viewport/exposure_assist.dart';
import 'history_tree_sheet.dart';

/// The verifiable trust line (#76): stated in the settings footer and the
/// About dialog, and enforced against pubspec drift by
/// `test/core/offline_guard_test.dart`.
const String kOfflineClaim =
    '100% Offline. Zero Cloud Analytics. No AI training on your photos. '
    'You own your data.';

/// The settings sheet: categorized into clean cards for quick tools, assist & peaking,
/// workspace shell, stylus input, and recipe presets (ADR 0008, 0009, 0011).
class SettingsSheet extends ConsumerWidget {
  const SettingsSheet({super.key});

  Widget _card({
    required BuildContext context,
    required List<Widget> children,
    EdgeInsetsGeometry? padding,
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
      child: Padding(
        padding: padding ?? const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: Insets.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }

  Widget _cardHeader(ThemeData theme, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Icon(icon, size: 15, color: theme.colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final clipboard = ref.watch(settingsClipboardProvider);
    final themeMode = ref.watch(themeModeProvider);
    final shell = ref.watch(shellPreferenceProvider);
    final stylus = ref.watch(stylusSettingsProvider);
    final notifier = ref.read(recipeControllerProvider.notifier);
    final exposureAssist = ref.watch(exposureAssistProvider);
    final scheme = theme.colorScheme;

    return AppSheet(
      title: 'Settings',
      children: [
        // ─── Card 1: Quick Tools & Guides ─────────────────────────────
        _card(
          context: context,
          children: [
            _cardHeader(theme, 'Quick Tools & Guides', Icons.explore_outlined),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () {
                      Navigator.of(context).maybePop();
                      EditorGuideSheet.show(context);
                    },
                    icon: const Icon(Icons.help_outline, size: 16),
                    label: const Text('Editor Guide'),
                  ),
                ),
                const SizedBox(width: Insets.xs),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () async {
                      final asset = ref.read(currentEditingAssetProvider);
                      if (!context.mounted) return;
                      Navigator.of(context).maybePop();
                      if (!context.mounted) return;
                      if (asset != null) {
                        final bytes = await ref
                            .read(gallerySourceProvider)
                            .loadImage(asset.id);
                        if (!context.mounted) return;
                        if (bytes.isNotEmpty) {
                          ImageInfoSheet.show(
                            context,
                            imageBytes: bytes,
                            recipe: ref.read(recipeControllerProvider).recipe,
                            asset: asset,
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.info_outline, size: 16),
                    label: const Text('Image Info & EXIF'),
                  ),
                ),
              ],
            ),
          ],
        ),

        // ─── Card 2: Assist & Peaking ──────────────────────────────────
        _card(
          context: context,
          children: [
            _cardHeader(theme, 'Assist & Cine Peaking', Icons.wb_iridescent_outlined),
            SegmentedButton<ExposureAssistMode>(
              segments: const [
                ButtonSegment(
                  value: ExposureAssistMode.off,
                  label: Text('Off'),
                ),
                ButtonSegment(
                  value: ExposureAssistMode.zebras,
                  icon: Icon(Icons.wb_iridescent_outlined, size: 16),
                  label: Text('Zebras'),
                ),
                ButtonSegment(
                  value: ExposureAssistMode.falseColor,
                  icon: Icon(Icons.palette_outlined, size: 16),
                  label: Text('False Color'),
                ),
              ],
              selected: {exposureAssist.mode},
              onSelectionChanged: (s) =>
                  ref.read(exposureAssistProvider.notifier).setMode(s.first),
            ),
            if (exposureAssist.mode == ExposureAssistMode.zebras) ...[
              const SizedBox(height: Insets.xs),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Insets.xs),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Highlight Clipping Zebras',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${(exposureAssist.zebraHigh * 100).round()}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: scheme.primary,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: exposureAssist.zebraHigh,
                      min: 0.80,
                      max: 1.00,
                      divisions: 20,
                      onChanged: (val) => ref
                          .read(exposureAssistProvider.notifier)
                          .setThresholds(high: val),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Shadow Crush Zebras',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${(exposureAssist.zebraLow * 100).round()}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: scheme.primary,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: exposureAssist.zebraLow,
                      min: 0.00,
                      max: 0.10,
                      divisions: 10,
                      onChanged: (val) => ref
                          .read(exposureAssistProvider.notifier)
                          .setThresholds(low: val),
                    ),
                  ],
                ),
              ),
            ],
            if (exposureAssist.mode == ExposureAssistMode.falseColor) ...[
              const SizedBox(height: Insets.xs),
              Container(
                padding: const EdgeInsets.all(Insets.xs),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'ARRI 16-Zone IRE Heatmap\n'
                  'Red: Clip (98-100 IRE) · Yellow: Highlight (85 IRE) · '
                  'Pink: Skin (70 IRE) · Green: 18% Neutral (40 IRE) · '
                  'Blue: Shadow (5-10 IRE) · Purple: Crushed Black (0-2 IRE)',
                  style: TextStyle(fontSize: 11, height: 1.3),
                ),
              ),
            ],
          ],
        ),

        // ─── Card 3: Workspace & Shell ────────────────────────────────
        _card(
          context: context,
          children: [
            _cardHeader(theme, 'Workspace & Shell', Icons.dashboard_customize_outlined),
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
            const SizedBox(height: Insets.xs),
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

        // ─── Card 4: Stylus & Input ───────────────────────────────────
        _card(
          context: context,
          children: [
            _cardHeader(theme, 'Stylus & Input', Icons.draw_outlined),
            SwitchListTile.adaptive(
              dense: true,
              key: const Key('settings-stylus-palm-rejection'),
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Palm Rejection',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
              subtitle: const Text(
                'Reject touch pointer events when using active pen',
                style: TextStyle(fontSize: 11),
              ),
              value: stylus.palmRejection,
              onChanged: (val) =>
                  ref.read(stylusSettingsProvider.notifier).setPalmRejection(val),
            ),
            const Divider(height: 1),
            SwitchListTile.adaptive(
              dense: true,
              key: const Key('settings-stylus-pressure-sensitivity'),
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Pressure Sensitivity',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
              subtitle: const Text(
                'Vary brush flow with pen pressure',
                style: TextStyle(fontSize: 11),
              ),
              value: stylus.pressureSensitivity,
              onChanged: (val) =>
                  ref.read(stylusSettingsProvider.notifier).setPressureSensitivity(val),
            ),
            const Divider(height: 1),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.cleaning_services_outlined, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Inverted Stylus: Flip pen to eraser mode',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        // ─── Card 5: Recipe & Presets ─────────────────────────────────
        _card(
          context: context,
          children: [
            _cardHeader(theme, 'Recipe & Presets', Icons.tune),
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
              icon: Icons.checklist_rtl,
              title: 'Selective copy settings...',
              onTap: () {
                Navigator.of(context).maybePop();
                showAppSheet(context, const CopySettingsSheet());
              },
            ),
            _Action(
              icon: Icons.paste,
              title: clipboard == null
                  ? 'Paste settings (nothing copied)'
                  : 'Paste settings',
              enabled: clipboard != null,
              onTap: () async {
                final cpSettings =
                    ref.read(settingsClipboardProvider.notifier).copiedSettings;
                final cp = cpSettings != null
                    ? cpSettings.applyTo(ref.read(recipeControllerProvider).recipe)
                    : clipboard!;
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
            const Divider(height: 1),
            _Action(
              icon: Icons.alt_route,
              title: 'Edit history & branches...',
              onTap: () {
                Navigator.of(context).maybePop();
                HistoryTreeSheet.show(context);
              },
            ),
            _Action(
              icon: Icons.crop,
              title: 'Crop & rotate...',
              onTap: () {
                final bytes = ref.read(activeImageBytesProvider);
                Navigator.of(context).maybePop();
                if (bytes != null) {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => CropScreen(imageBytes: bytes),
                    ),
                  );
                }
              },
            ),
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
            _Action(
              icon: Icons.collections_bookmark_outlined,
              title: 'Browse edited versions...',
              onTap: () {
                Navigator.of(context).maybePop();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const EditedVersionsScreen(),
                  ),
                );
              },
            ),
          ],
        ),

        // ─── Privacy & Local AI ───────────────────────────────────────
        _card(
          context: context,
          children: [
            _cardHeader(theme, 'Privacy & Local AI', Icons.lock_outline),
            SwitchListTile.adaptive(
              dense: true,
              key: const Key('settings-ai-consent-toggle'),
              contentPadding: EdgeInsets.zero,
              title: const Text('On-device AI processing', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              subtitle: const Text(
                'Enables local intelligent masking (Select Subject/Sky). 100% offline, zero telemetry.',
                style: TextStyle(fontSize: 11),
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
            _Action(
              icon: Icons.hub_outlined,
              title: 'AI Models & Plugins',
              onTap: () {
                Navigator.of(context).maybePop();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AiPluginsScreen(),
                  ),
                );
              },
            ),
          ],
        ),

        // ─── Export Settings ──────────────────────────────────────────
        _card(
          context: context,
          children: [
            _cardHeader(theme, 'Export Defaults', Icons.save_alt_rounded),
            const _ExportSection(),
          ],
        ),

        // ─── App & System ─────────────────────────────────────────────
        _card(
          context: context,
          children: [
            _cardHeader(theme, 'App & System', Icons.info_outline),
            _Action(
              icon: Icons.school_outlined,
              title: 'ApertureX Academy & Tool Guide...',
              onTap: () {
                Navigator.of(context).maybePop();
                AppGuideScreen.showModal(context);
              },
            ),
            _Action(
              icon: Icons.tour_outlined,
              title: 'App Onboarding Tour...',
              onTap: () {
                Navigator.of(context).maybePop();
                OnboardingScreen.show(context);
              },
            ),
            _Action(
              icon: Icons.settings_outlined,
              title: 'All app settings...',
              onTap: () {
                Navigator.of(context).maybePop();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SettingsScreen(),
                  ),
                );
              },
            ),
            ListenableBuilder(
              listenable: activityLog,
              builder: (context, _) => _Action(
                icon: Icons.receipt_long,
                title: 'Activity log (${activityLog.length})',
                onTap: () => _openLogs(context),
              ),
            ),
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
          ],
        ),

        const SizedBox(height: Insets.xs),
        Center(
          child: Text(
            'ApertureX 0.3.5 · P2',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
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
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
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
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, size: 18),
      title: Text(title, style: const TextStyle(fontSize: 13)),
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
    applicationVersion: '0.3.5',
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
    applicationVersion: '0.3.5',
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
            const SizedBox(width: 72, child: Text('Quality', style: TextStyle(fontSize: 12))),
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
              child: Text('${settings.quality}', textAlign: TextAlign.end, style: const TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.only(bottom: 2),
          child: Text('Max size (long side)', style: TextStyle(fontSize: 12)),
        ),
        Wrap(
          spacing: Insets.xs,
          children: [
            for (final (label, dim) in _sizes)
              ChoiceChip(
                label: Text(label, style: const TextStyle(fontSize: 11)),
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
