import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/ai_plugins/ai_plugins_screen.dart';
import '../../l10n/app_strings.dart';
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
    final strings = AppStrings.of(context);

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
              Text(strings.privacyAndLocalAi, style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 16),
          SwitchListTile.adaptive(
            dense: true,
            key: const Key('settings-ai-consent-toggle'),
            contentPadding: EdgeInsets.zero,
            title: Text(
              strings.onDeviceAiProcessing,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              strings.onDeviceAiProcessingDesc,
              style: const TextStyle(fontSize: 12.0),
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
            title: Text(strings.aiModelsAndNeuralRuntimes, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            subtitle: Text(strings.aiModelsAndNeuralRuntimesDesc, style: const TextStyle(fontSize: 12.0)),
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
