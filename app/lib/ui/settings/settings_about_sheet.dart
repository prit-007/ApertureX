import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/theme/design_tokens.dart';
import '../../l10n/app_strings.dart';
import '../../settings/about_screen.dart';

/// The verifiable trust line (#76): stated in the settings footer and the
/// About dialog, and enforced against pubspec drift by
/// `test/core/offline_guard_test.dart`.
const String kOfflineClaim =
    '100% On-Device Processing. Zero Cloud Analytics. No AI training on your photos. '
    'You own your data.';

/// Settings sheet for About ApertureX, developers, and open-source licenses.
class SettingsAboutSheet extends StatelessWidget {
  const SettingsAboutSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const SafeArea(child: SettingsAboutSheet()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppStrings.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(strings.aboutApertureX, style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.info_outline),
            title: Text(strings.appOverviewAndPhilosophy, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).maybePop();
              showAboutDialog(
                context: context,
                applicationName: 'ApertureX',
                applicationVersion: 'v0.3.9',
                applicationLegalese: 'GPLv3 / FOSS Photo Editor',
                children: [
                  const SizedBox(height: 16),
                  const Text(kOfflineClaim),
                ],
              );
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.people_outline),
            title: Text(strings.developersAndMaintainers, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).maybePop();
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const AboutScreen()),
              );
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.article_outlined),
            title: Text(strings.openSourceLicenses, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).maybePop();
              showLicensePage(
                context: context,
                applicationName: 'ApertureX',
                applicationVersion: 'v0.3.9',
              );
            },
          ),
          const SizedBox(height: 16),
          Center(
            child: FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                final version = snapshot.data != null
                    ? '${snapshot.data!.appName} ${snapshot.data!.version} · 16-bit Linear Float'
                    : 'ApertureX · 16-bit Linear Float';
                return Text(
                  version,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: Insets.xs),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.md),
              child: Text(
                kOfflineClaim,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
