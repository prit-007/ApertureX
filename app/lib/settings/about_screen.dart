import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../core/theme/design_tokens.dart';
import '../core/updater/app_updater.dart';
import '../ui/common/settings_sheet.dart';

/// About App, Developers, Licensing, and Third-Party Attribution Screen.
///
/// Highlights Developer's Paradise, Prit Vasani, GPL-3.0 licensing,
/// and comprehensive third-party attribution from THIRD_PARTY.md.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('About & Developers'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.lg,
          vertical: Insets.md,
        ),
        children: [
          // ─── 1. App Header & Version ──────────────────────────────────
          Center(
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primary,
                        colorScheme.tertiary,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.camera,
                      size: 44,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: Insets.md),
                Text(
                  'ApertureX',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: Insets.xs),
                FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snapshot) {
                    final ver = snapshot.data != null
                        ? 'v${snapshot.data!.version}+${snapshot.data!.buildNumber}'
                        : 'v${AppUpdater.currentVersion}';
                    return Text(
                      ver,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  },
                ),
                const SizedBox(height: Insets.xs),
                Text(
                  'Pro-Grade Mobile-Native FOSS Photo Editor',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Insets.sm),
                Wrap(
                  spacing: Insets.xs,
                  runSpacing: Insets.xs,
                  alignment: WrapAlignment.center,
                  children: [
                    _chip(context, 'GPL-3.0 License', Icons.balance),
                    _chip(context, '100% Offline', Icons.cloud_off),
                    _chip(context, 'Zero Telemetry', Icons.security),
                    _chip(context, 'Compiled Rust Engine', Icons.speed),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: Insets.xl),

          // ─── 2. About the Developers ──────────────────────────────────
          _sectionTitle(context, 'Developers & Architecture'),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: Radii.mdAll,
              side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(Insets.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: colorScheme.primaryContainer,
                      child: Icon(Icons.hub, color: colorScheme.onPrimaryContainer),
                    ),
                    title: const Text(
                      "Developer's Paradise",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text('Open-Source Software Studio & Organization'),
                  ),
                  const SizedBox(height: Insets.xs),
                  Text(
                    "Developer's Paradise is dedicated to creating uncompromising, privacy-first, professional-grade creative software for mobile and desktop creators. Zero cloud lock-in, zero telemetry, and 100% user data ownership.",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Divider(height: Insets.xl),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: colorScheme.tertiaryContainer,
                      child: Icon(Icons.person, color: colorScheme.onTertiaryContainer),
                    ),
                    title: const Text(
                      'Prit Vasani',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text('Lead Architect & Developer'),
                  ),
                  const SizedBox(height: Insets.xs),
                  Text(
                    'Architected the dual-UI shells (Lightroom-style precision panels & Snapseed gesture mode) over a unified non-destructive recipe, zero-copy Rust engine, Depth Anything V2 monocular depth integration, 55+ master preset catalog, and open Look QR standard.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: Insets.md),
                  Row(
                    children: [
                      Icon(Icons.code, size: 18, color: colorScheme.primary),
                      const SizedBox(width: Insets.sm),
                      Expanded(
                        child: Text(
                          'github.com/prit-007/ApertureX',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.primary,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: Insets.lg),

          // ─── 3. Privacy & Zero-Cloud Guarantee ────────────────────────
          _sectionTitle(context, 'Privacy Guarantee'),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: Radii.mdAll,
              side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(Insets.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.shield_outlined, color: Colors.green.shade600),
                      const SizedBox(width: Insets.sm),
                      Text(
                        '100% Offline Integrity',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Insets.sm),
                  Text(
                    kOfflineClaim,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: Insets.lg),

          // ─── 4. Licensing ─────────────────────────────────────────────
          _sectionTitle(context, 'Licensing'),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: Radii.mdAll,
              side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.gavel),
                  title: const Text('GNU General Public License v3.0'),
                  subtitle: const Text('GPL-3.0-or-later · Free and open-source forever'),
                  trailing: TextButton(
                    onPressed: () => showLicensePage(
                      context: context,
                      applicationName: 'ApertureX',
                      applicationVersion: AppUpdater.currentVersion,
                      applicationLegalese: 'GPL-3.0-or-later',
                    ),
                    child: const Text('Licenses'),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(Insets.md, 0, Insets.md, Insets.md),
                  child: Text(
                    'You are free to inspect, modify, adapt, and distribute this software under the terms of the GNU General Public License v3.0. Source code is 100% auditable and available in the official repository.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: Insets.lg),

          // ─── 5. Third-Party Components & Attribution ──────────────────
          _sectionTitle(context, 'Third-Party Components & Attribution'),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: Radii.mdAll,
              side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Column(
              children: [
                _thirdPartyTile(
                  title: 'Rust Core & Decoders',
                  subtitle: 'rawler (LGPL-2.1), jpeg-encoder (MIT/IJG), zune-jpeg (MIT), miniz_oxide (MIT/Zlib), flutter_rust_bridge (MIT)',
                  description: 'Powers RAW sensor demosaicing, zero-copy preview base baking, JPEG tile encoding, and high-frequency Dart FFI bridge.',
                ),
                const Divider(height: 1),
                _thirdPartyTile(
                  title: 'On-Device AI & Computer Vision',
                  subtitle: 'Depth Anything V2 (Apache-2.0), YuNet (MIT), U²-NetP (Apache-2.0), ort / ONNX Runtime (MIT)',
                  description: 'Drives monocular depth bokeh estimation with 7 iris apertures, face-first landmark detection, and subject isolation.',
                ),
                const Divider(height: 1),
                _thirdPartyTile(
                  title: 'Local Database & Storage',
                  subtitle: 'Drift (MIT), sqlite3 (BSD-3-Clause)',
                  description: 'Reactive local SQLite query engine for catalog indexing, virtual copies, smart collections, and non-destructive recipe sidecars.',
                ),
                const Divider(height: 1),
                _thirdPartyTile(
                  title: 'UI, Touch & Gestures',
                  subtitle: 'extended_image (MIT), pro_image_editor fork (BSD-3-Clause, hm21), dynamic_color (Apache-2.0)',
                  description: 'Enables 120 FPS pinch/pan tile compositing, Material You color harmonization, and fluid slider controls.',
                ),
                const Divider(height: 1),
                _thirdPartyTile(
                  title: 'Standards, Codecs & Film Science',
                  subtitle: 'Pat David Film Curves (PIXLS.US), zxing2 (Apache-2.0), qr_flutter (BSD-3-Clause), intl (BSD-3-Clause)',
                  description: 'Classical photochemical film emulations (Portra, Fuji, HP5, Cinestill), open Look QR preset interchange, and 6-language i18n.',
                ),
              ],
            ),
          ),

          const SizedBox(height: Insets.xl),
        ],
      ),
    );
  }

  static Widget _chip(BuildContext context, String label, IconData icon) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: Insets.xs),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: Radii.pillAll,
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.primary),
          const SizedBox(width: Insets.xs),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _sectionTitle(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: Insets.xs, bottom: Insets.xs),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  static Widget _thirdPartyTile({
    required String title,
    required String subtitle,
    required String description,
  }) {
    return ListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(description, style: const TextStyle(fontSize: 12)),
        ],
      ),
      isThreeLine: true,
    );
  }
}
