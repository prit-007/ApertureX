import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_strings.dart';
import '../../settings/export_branding_settings.dart';
import '../../settings/export_settings.dart';

/// Settings sheet for Export Defaults (Quality, Max Dimensions, C2PA).
class SettingsExportDefaultsSheet extends ConsumerWidget {
  const SettingsExportDefaultsSheet({super.key});

  static const _sizes = <(String, int)>[
    ('Original', 0),
    ('2048', 2048),
    ('1080', 1080),
    ('720', 720),
  ];

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const SafeArea(child: SettingsExportDefaultsSheet()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(exportSettingsProvider);
    final notifier = ref.read(exportSettingsProvider.notifier);
    final branding = ref.watch(exportBrandingProvider);
    final strings = AppStrings.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.save_alt_rounded, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(strings.exportDefaults, style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(width: 72, child: Text(strings.quality, style: const TextStyle(fontSize: 12.0))),
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
                width: 36,
                child: Text('${settings.quality}%', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12.0)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(strings.maxSizeLongSide, style: const TextStyle(fontSize: 12.0)),
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final (label, dim) in _sizes)
                ChoiceChip(
                  label: Text(dim == 0 ? strings.sizeOriginal : label, style: const TextStyle(fontSize: 12.0)),
                  selected: settings.maxDim == dim,
                  showCheckmark: false,
                  onSelected: (_) => notifier.setMaxDim(dim),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SwitchListTile.adaptive(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(strings.c2paContentCredentials, style: const TextStyle(fontSize: 12.0)),
            subtitle: Text(strings.c2paDesc, style: const TextStyle(fontSize: 12.0)),
            value: branding.enableC2pa,
            onChanged: (val) {
              ref.read(exportBrandingProvider.notifier).setC2pa(val);
            },
          ),
        ],
      ),
    );
  }
}
