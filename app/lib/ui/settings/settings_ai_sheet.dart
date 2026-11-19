import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/ai_plugins/ai_plugins_screen.dart';
import '../../settings/ai_consent.dart';

/// Settings sheet for On-Device AI, Intelligent Masking, and Local Models.
class SettingsAiSheet extends ConsumerWidget {
  const SettingsAiSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const SafeArea(child: SettingsAiSheet()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final consent = ref.watch(aiConsentProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.lock_outline, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text('Privacy & Local AI', style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 16),
          SwitchListTile.adaptive(
            dense: true,
            key: const Key('settings-ai-consent-toggle'),
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'On-device AI processing',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            subtitle: const Text(
              'Enables local intelligent masking (Select Subject/Sky) via Depth Anything & U2Net. 100% offline, zero telemetry.',
              style: TextStyle(fontSize: 11),
            ),
            value: consent == AiConsentStatus.granted,
            onChanged: (val) {
              if (val) {
                ref.read(aiConsentProvider.notifier).grantConsent();
              } else {
                ref.read(aiConsentProvider.notifier).revokeConsent();
              }
            },
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.hub_outlined),
            title: const Text('AI Models & Neural Runtimes', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            subtitle: const Text('Manage ONNX runtime, model weights, and inference hardware', style: TextStyle(fontSize: 11)),
            trailing: const Icon(Icons.chevron_right),
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
    );
  }
}
