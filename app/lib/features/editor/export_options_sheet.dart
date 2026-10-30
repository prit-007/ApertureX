import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/design_tokens.dart';
import '../../settings/export_branding_settings.dart';
import '../../settings/export_settings.dart';
import '../../ui/common/app_sheet.dart';

enum ExportAction {
  saveToApertureX,
  saveToPhotos,
  savePng,
  saveDngWithXmp,
  saveTiff16,
  share,
  sharePresetCard,
}

/// Action sheet shown when the user taps "Export" in the editor (#85, #79).
/// Features progressive disclosure for pro-grade custom branding, museum frame,
/// vector signatures, and C2PA Content Credentials signing.
class ExportOptionsSheet extends StatelessWidget {
  const ExportOptionsSheet({super.key, this.isRaw = false});

  final bool isRaw;

  static Future<ExportAction?> show(BuildContext context, {bool isRaw = false}) {
    return showAppSheet<ExportAction>(
      context,
      ExportOptionsSheet(isRaw: isRaw),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content = _ExportOptionsSheetContent(isRaw: isRaw);

    bool hasLocalizations = true;
    try {
      MaterialLocalizations.of(context);
    } catch (_) {
      hasLocalizations = false;
    }
    if (!hasLocalizations) {
      content = Localizations(
        locale: const Locale('en', 'US'),
        delegates: const [
          DefaultMaterialLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
        child: content,
      );
    }

    bool hasScope = true;
    try {
      ProviderScope.containerOf(context);
    } catch (_) {
      hasScope = false;
    }

    final focusedContent = FocusTraversalGroup(
      policy: WidgetOrderTraversalPolicy(),
      child: content,
    );

    if (!hasScope) {
      return ProviderScope(child: focusedContent);
    }
    return focusedContent;
  }
}

class _ExportOptionsSheetContent extends ConsumerStatefulWidget {
  const _ExportOptionsSheetContent({required this.isRaw});

  final bool isRaw;

  @override
  ConsumerState<_ExportOptionsSheetContent> createState() =>
      _ExportOptionsSheetContentState();
}

class _ExportOptionsSheetContentState
    extends ConsumerState<_ExportOptionsSheetContent> {
  late final TextEditingController _signatureController;
  late final TextEditingController _exifLine1Controller;
  late final TextEditingController _exifLine2Controller;
  late final TextEditingController _patternController;
  bool _brandingExpanded = false;

  @override
  void initState() {
    super.initState();
    final branding = ref.read(exportBrandingProvider);
    final settings = ref.read(exportSettingsProvider);
    _signatureController = TextEditingController(text: branding.signatureText);
    _exifLine1Controller = TextEditingController(text: branding.exifLine1);
    _exifLine2Controller = TextEditingController(text: branding.exifLine2);
    _patternController = TextEditingController(text: settings.filenamePattern);
  }

  @override
  void dispose() {
    _signatureController.dispose();
    _exifLine1Controller.dispose();
    _exifLine2Controller.dispose();
    _patternController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final branding = ref.watch(exportBrandingProvider);
    final brandingNotifier = ref.read(exportBrandingProvider.notifier);
    final exportSettings = ref.watch(exportSettingsProvider);
    final exportNotifier = ref.read(exportSettingsProvider.notifier);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.88,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: Insets.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Insets.md,
                    vertical: Insets.xs,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Export & Save',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        autofocus: true,
                        icon: const Icon(Icons.close, size: 20),
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Primary Export Actions
                ListTile(
                  leading: const Icon(Icons.auto_fix_high_outlined),
                  title: const Text('Save to ApertureX'),
                  subtitle:
                      const Text('Render and index in the in-app Edits gallery'),
                  trailing: _formatBadge('LIBRARY', theme),
                  onTap: () =>
                      Navigator.of(context).pop(ExportAction.saveToApertureX),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Save to Photos'),
                  subtitle: const Text(
                    'Full-resolution JPEG with XMP sidecar to device',
                  ),
                  trailing: _formatBadge('JPEG', theme),
                  onTap: () =>
                      Navigator.of(context).pop(ExportAction.saveToPhotos),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_size_select_actual_outlined),
                  title: const Text('Export PNG (Lossless 8-bit)'),
                  subtitle: const Text(
                    'Lossless compressed PNG for print, web & archival',
                  ),
                  trailing: _formatBadge('PNG', theme),
                  onTap: () =>
                      Navigator.of(context).pop(ExportAction.savePng),
                ),
                if (widget.isRaw)
                  ListTile(
                    leading: const Icon(Icons.raw_on_outlined),
                    title: const Text('Export DNG (Lossless + Edits)'),
                    subtitle: const Text(
                      'Original raw CFA sensor data with injected XMP recipe',
                    ),
                    trailing: _formatBadge('RAW DNG', theme),
                    onTap: () =>
                        Navigator.of(context).pop(ExportAction.saveDngWithXmp),
                  ),
                ListTile(
                  leading: const Icon(Icons.image_outlined),
                  title: const Text('Export TIFF 16-bit'),
                  subtitle: const Text(
                    'Uncompressed 16-bit-per-channel TIFF with full edit bake-in',
                  ),
                  trailing: _formatBadge('16-BIT', theme),
                  onTap: () =>
                      Navigator.of(context).pop(ExportAction.saveTiff16),
                ),
                ListTile(
                  leading: const Icon(Icons.share_outlined),
                  title: const Text('Share…'),
                  subtitle: const Text(
                    'Share image and XMP sidecar with other apps',
                  ),
                  onTap: () => Navigator.of(context).pop(ExportAction.share),
                ),
                ListTile(
                  leading: const Icon(Icons.qr_code_2),
                  title: const Text('Export as Preset Card (QR)'),
                  subtitle: const Text(
                    'Share color grade as a watermarked QR card for Instagram & Reddit',
                  ),
                  trailing: _formatBadge('PRESET', theme),
                  onTap: () =>
                      Navigator.of(context).pop(ExportAction.sharePresetCard),
                ),

                const Divider(height: 1),

                // Export Presets Quick Profile Bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Insets.md,
                    vertical: Insets.xs,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.auto_awesome_outlined, size: 16),
                          const SizedBox(width: Insets.xs),
                          Text(
                            'Quick Export Profile',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Insets.xs),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final preset in ExportPresetKind.values)
                              Padding(
                                padding: const EdgeInsets.only(right: Insets.xs),
                                child: ActionChip(
                                  label: Text(preset.title),
                                  tooltip: preset.description,
                                  onPressed: () {
                                    exportNotifier.applyPreset(preset);
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Filename Pattern Template Section
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Insets.md,
                    vertical: Insets.xs,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.label_outlined, size: 16),
                          const SizedBox(width: Insets.xs),
                          Text(
                            'Filename Template',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Preview: ${exportSettings.formatFilename(original: 'IMG_4021', preset: 'graded')}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _patternController,
                        style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                        decoration: const InputDecoration(
                          hintText: '{original}_{date}',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: Insets.sm,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (val) => exportNotifier.setFilenamePattern(val),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        children: [
                          for (final token in ['{original}', '{date}', '{preset}', '{counter}'])
                            InkWell(
                              onTap: () {
                                final text = _patternController.text;
                                final newText = text.isEmpty ? token : '$text-$token';
                                _patternController.text = newText;
                                exportNotifier.setFilenamePattern(newText);
                              },
                              borderRadius: BorderRadius.circular(4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  token,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontFamily: 'monospace',
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                // Export Quality Slider
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Insets.md,
                    vertical: Insets.xs,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.tune, size: 18),
                      const SizedBox(width: Insets.sm),
                      Text(
                        'Quality: ${exportSettings.quality}%',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          value: exportSettings.quality.toDouble(),
                          min: 60,
                          max: 100,
                          divisions: 40,
                          onChanged: (val) {
                            exportNotifier.setQuality(val.round());
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // Color Space (Wide Color Gamut #15)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Insets.md,
                    vertical: Insets.xs,
                  ),
                  child: Wrap(
                    spacing: Insets.sm,
                    runSpacing: Insets.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Icon(Icons.palette_outlined, size: 18),
                      const SizedBox(width: Insets.sm),
                      Text(
                        'Gamut:',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: Insets.md),
                      ChoiceChip(
                        key: const Key('color_space_srgb_chip'),
                        label: const Text('sRGB'),
                        selected: exportSettings.colorSpace == 0,
                        onSelected: (selected) {
                          if (selected) exportNotifier.setColorSpace(0);
                        },
                      ),
                      const SizedBox(width: Insets.xs),
                      ChoiceChip(
                        key: const Key('color_space_p3_chip'),
                        label: const Text('Display-P3 (WCG)'),
                        selected: exportSettings.colorSpace == 1,
                        onSelected: (selected) {
                          if (selected) exportNotifier.setColorSpace(1);
                        },
                      ),
                    ],
                  ),
                ),

                // Ultra HDR (ISO 21496-1 Gain Map #20)
                SwitchListTile(
                  key: const Key('ultra_hdr_switch'),
                  secondary: const Icon(Icons.hdr_on_outlined),
                  title: const Text(
                    'Ultra HDR (Gain Map)',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'ISO 21496-1 gain map for HDR OLED displays & Google Photos',
                  ),
                  value: exportSettings.ultraHdr,
                  onChanged: (enabled) {
                    exportNotifier.setUltraHdr(enabled);
                  },
                ),
                if (exportSettings.ultraHdr)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Insets.lg,
                      vertical: Insets.xs,
                    ),
                    child: Row(
                      children: [
                        Text(
                          'Peak Headroom: +${exportSettings.hdrHeadroom.toStringAsFixed(1)} EV',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Expanded(
                          child: Slider(
                            value: exportSettings.hdrHeadroom,
                            min: 1.0,
                            max: 4.0,
                            divisions: 30,
                            onChanged: (val) {
                              exportNotifier.setHdrHeadroom(val);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                const Divider(height: 1),

                // Progressive Disclosure Section: Watermarks & Custom Branding
                ListTile(
                  leading: const Icon(Icons.branding_watermark_outlined),
                  title: const Text(
                    'Branding & Watermark',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    branding.enableMuseumFrame
                        ? 'Museum Frame Active'
                        : branding.enableSignature
                            ? 'Custom Signature Active'
                            : branding.enableFossBadge
                                ? 'FOSS Badge Active'
                                : 'Configure frames, signatures & badges',
                    style: theme.textTheme.bodySmall,
                  ),
                  trailing: Icon(
                    _brandingExpanded ? Icons.expand_less : Icons.expand_more,
                  ),
                  onTap: () {
                    setState(() => _brandingExpanded = !_brandingExpanded);
                  },
                ),
                if (_brandingExpanded) ...[
                  // 1. Museum Frame (EXIF Print)
                  SwitchListTile(
                    key: const Key('museum_frame_switch'),
                    secondary: const Icon(Icons.crop_original_outlined),
                    title: const Text('Add Museum Frame'),
                    subtitle: const Text(
                      'Pristine border with camera & exposure typography',
                    ),
                    value: branding.enableMuseumFrame,
                    onChanged: (enabled) {
                      brandingNotifier.setMuseumFrame(
                        enabled: enabled,
                        themeIndex: branding.frameThemeIndex,
                        line1: _exifLine1Controller.text,
                        line2: _exifLine2Controller.text,
                      );
                    },
                  ),
                  if (branding.enableMuseumFrame) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Insets.lg,
                        vertical: Insets.xs,
                      ),
                      child: Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Studio White'),
                            selected: branding.frameThemeIndex == 0,
                            onSelected: (selected) {
                              if (selected) {
                                brandingNotifier.setMuseumFrame(
                                  enabled: true,
                                  themeIndex: 0,
                                );
                              }
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Matte Dark'),
                            selected: branding.frameThemeIndex == 1,
                            onSelected: (selected) {
                              if (selected) {
                                brandingNotifier.setMuseumFrame(
                                  enabled: true,
                                  themeIndex: 1,
                                );
                              }
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Warm Gallery'),
                            selected: branding.frameThemeIndex == 2,
                            onSelected: (selected) {
                              if (selected) {
                                brandingNotifier.setMuseumFrame(
                                  enabled: true,
                                  themeIndex: 2,
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Insets.lg,
                        vertical: Insets.xs,
                      ),
                      child: TextField(
                        controller: _exifLine1Controller,
                        decoration: const InputDecoration(
                          labelText: 'Custom Camera / Title (optional)',
                          hintText: 'e.g. SONY A7III • FE 35MM F1.4',
                          isDense: true,
                        ),
                        onChanged: (val) {
                          brandingNotifier.setMuseumFrame(
                            enabled: true,
                            line1: val,
                          );
                        },
                      ),
                    ),
                  ],

                  const Divider(indent: Insets.lg, endIndent: Insets.lg),

                  // 2. Custom Photographer Signature
                  SwitchListTile(
                    key: const Key('signature_switch'),
                    secondary: const Icon(Icons.draw_outlined),
                    title: const Text('Photographer Signature'),
                    subtitle: const Text(
                      'Anti-aliased vector text with anti-halation drop shadow',
                    ),
                    value: branding.enableSignature,
                    onChanged: (enabled) {
                      brandingNotifier.setSignature(
                        enabled: enabled,
                        text: _signatureController.text,
                      );
                    },
                  ),
                  if (branding.enableSignature) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Insets.lg,
                        vertical: Insets.xs,
                      ),
                      child: TextField(
                        key: const Key('signature_text_field'),
                        controller: _signatureController,
                        decoration: const InputDecoration(
                          labelText: 'Signature Text',
                          hintText: '© 2026 Jane Doe',
                          isDense: true,
                        ),
                        onChanged: (val) {
                          brandingNotifier.setSignature(
                            enabled: true,
                            text: val,
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Insets.lg,
                        vertical: Insets.xs,
                      ),
                      child: Row(
                        children: [
                          Text(
                            'Position:',
                            style: theme.textTheme.labelMedium,
                          ),
                          const SizedBox(width: Insets.sm),
                          Expanded(
                            child: Wrap(
                              spacing: 6,
                              children: [
                                ChoiceChip(
                                  label: const Text('Bottom Right'),
                                  selected: branding.signatureAnchorIndex == 8,
                                  onSelected: (s) {
                                    if (s) {
                                      brandingNotifier.setSignature(
                                        enabled: true,
                                        anchorIndex: 8,
                                      );
                                    }
                                  },
                                ),
                                ChoiceChip(
                                  label: const Text('Bottom Left'),
                                  selected: branding.signatureAnchorIndex == 6,
                                  onSelected: (s) {
                                    if (s) {
                                      brandingNotifier.setSignature(
                                        enabled: true,
                                        anchorIndex: 6,
                                      );
                                    }
                                  },
                                ),
                                ChoiceChip(
                                  label: const Text('Top Right'),
                                  selected: branding.signatureAnchorIndex == 2,
                                  onSelected: (s) {
                                    if (s) {
                                      brandingNotifier.setSignature(
                                        enabled: true,
                                        anchorIndex: 2,
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Insets.lg,
                        vertical: Insets.xs,
                      ),
                      child: Row(
                        children: [
                          Text(
                            'Opacity (${(branding.signatureOpacity * 100).round()}%):',
                            style: theme.textTheme.labelMedium,
                          ),
                          Expanded(
                            child: Slider(
                              value: branding.signatureOpacity,
                              min: 0.1,
                              max: 1.0,
                              divisions: 18,
                              onChanged: (val) {
                                brandingNotifier.setSignature(
                                  enabled: true,
                                  opacity: val,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const Divider(indent: Insets.lg, endIndent: Insets.lg),

                  // 3. Opt-in FOSS Flex Badge
                  SwitchListTile(
                    key: const Key('foss_badge_switch'),
                    secondary: const Icon(Icons.verified_outlined),
                    title: const Text('Show ApertureX Badge'),
                    subtitle: const Text(
                      '⬡ Edited in ApertureX | 100% Offline',
                    ),
                    value: branding.enableFossBadge,
                    onChanged: (enabled) {
                      brandingNotifier.setFossBadge(enabled);
                    },
                  ),
                ],

                const Divider(height: 1),

                // Progressive Disclosure Section: C2PA Content Credentials
                SwitchListTile(
                  key: const Key('c2pa_switch'),
                  secondary: const Icon(Icons.fingerprint_outlined),
                  title: const Text('Cryptographic Provenance (C2PA)'),
                  subtitle: const Text(
                    'Offline hardware key signature embedded in APP11 metadata to prove authenticity',
                  ),
                  value: branding.enableC2pa,
                  onChanged: (enabled) {
                    brandingNotifier.setC2pa(enabled);
                  },
                ),
                const SizedBox(height: Insets.sm),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget _formatBadge(String label, ThemeData theme) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
