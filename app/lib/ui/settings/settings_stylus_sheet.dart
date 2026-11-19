import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/app_settings.dart';

/// Settings sheet for Stylus & Pen Input (Pressure, Palm Rejection, Inverted Stylus).
class SettingsStylusSheet extends ConsumerWidget {
  const SettingsStylusSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const SafeArea(child: SettingsStylusSheet()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final stylus = ref.watch(stylusSettingsProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.draw_outlined, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text('Stylus & Input', style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 16),
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
          const Divider(height: 16),
          SwitchListTile.adaptive(
            dense: true,
            key: const Key('settings-stylus-pressure-sensitivity'),
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Pressure Sensitivity',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            subtitle: const Text(
              'Vary brush flow with dynamic pen pressure (event.pressure)',
              style: TextStyle(fontSize: 11),
            ),
            value: stylus.pressureSensitivity,
            onChanged: (val) =>
                ref.read(stylusSettingsProvider.notifier).setPressureSensitivity(val),
          ),
          const Divider(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(Icons.cleaning_services_outlined, size: 20, color: theme.colorScheme.secondary),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Inverted Stylus Support',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Flip active pen to instantly switch to precision eraser mode',
                        style: TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
