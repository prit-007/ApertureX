import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/design_tokens.dart';
import '../../features/ai_plugins/ai_plugin_model.dart';
import '../../features/ai_plugins/ai_plugin_store.dart';
import '../../features/ai_plugins/ai_plugins_screen.dart';
import '../common/app_primitives.dart';

class PluginsPanelView extends ConsumerWidget {
  const PluginsPanelView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(aiPluginProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final installed = state.installedPlugins;
    final notifier = ref.read(aiPluginProvider.notifier);

    return ListView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: const EdgeInsets.all(Insets.md),
      children: [
        Card.outlined(
          child: Padding(
            padding: const EdgeInsets.all(Insets.md),
            child: Row(
              children: [
                Icon(Icons.offline_bolt_rounded, color: scheme.primary, size: 28),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Neural Forge On-Device AI',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Zero cloud inference. Local zero-copy tensors.',
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                FilledButton.tonal(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const AiPluginsScreen()),
                    );
                  },
                  child: const Text('Manage'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Insets.sm),
        const SectionHeader('Active AI Pipeline'),
        Padding(
          padding: const EdgeInsets.only(bottom: Insets.sm),
          child: Text(
            'Hardware-accelerated neural tasks running on-device via NPU/GPU.',
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
        ),
        Builder(builder: (context) {
          final activeSaliency = notifier.getActivePluginForTask(AiTask.subjectSegmentation);
          final activeDepth = notifier.getActivePluginForTask(AiTask.depthEstimation);
          final activeMatting = notifier.getActivePluginForTask(AiTask.portraitHair);
          final activeSky = notifier.getActivePluginForTask(AiTask.skySegmentation);

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _aiTaskCard(
                context,
                icon: Icons.person_search_rounded,
                taskName: 'Subject & Object Saliency',
                modelName: activeSaliency?.name ?? 'Built-in Saliency Alg.',
                status: activeSaliency != null ? 'Active · Neural' : 'Active · Heuristic',
              ),
              _aiTaskCard(
                context,
                icon: Icons.blur_on_rounded,
                taskName: 'Monocular Depth Estimation',
                modelName: activeDepth?.name ?? 'Depth Gradient Fusion',
                status: activeDepth != null ? 'Active · Neural' : 'Active · Gradient',
              ),
              _aiTaskCard(
                context,
                icon: Icons.auto_fix_high_rounded,
                taskName: 'Edge Refinement & Matting',
                modelName: activeMatting?.name ?? 'Guided Filter Matting',
                status: activeMatting != null ? 'Active · Neural' : 'Active · Guided Filter',
              ),
              _aiTaskCard(
                context,
                icon: Icons.cloud_outlined,
                taskName: 'Sky & Horizon Detection',
                modelName: activeSky?.name ?? 'Chromatic Sky Segmenter',
                status: activeSky != null ? 'Active · Neural' : 'Active · Color Mask',
              ),
            ],
          );
        }),
        const SizedBox(height: Insets.md),
        const SectionHeader('Installed Models'),
        for (final p in installed)
          ListTile(
            dense: true,
            leading: Icon(
              p.isBuiltIn ? Icons.verified_rounded : Icons.extension_rounded,
              color: scheme.primary,
            ),
            title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(p.description, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                p.task.label,
                style: TextStyle(
                  color: scheme.onPrimaryContainer,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        const SizedBox(height: Insets.md),
        const SectionHeader('Community Model Hub'),
        Padding(
          padding: const EdgeInsets.only(bottom: Insets.sm),
          child: Text(
            'Explore high-performance vision models available for instant on-device installation.',
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
        ),
        for (final m in kCommunityAiPlugins) ...[
          Builder(builder: (context) {
            final isInstalled = installed.any((p) => p.id == m.id);
            final isDownloading = state.downloadingId == m.id;
            return Card.outlined(
              margin: const EdgeInsets.only(bottom: Insets.xs),
              child: ListTile(
                dense: true,
                leading: Icon(
                  Icons.hub_outlined,
                  color: isInstalled ? scheme.primary : scheme.onSurfaceVariant,
                ),
                title: Text(
                  m.name,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${m.task.label} · ${(m.fileSizeBytes / 1000000).toStringAsFixed(0)} MB',
                  style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                ),
                trailing: isDownloading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : isInstalled
                        ? Icon(Icons.check_circle, color: scheme.primary, size: 20)
                        : OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            onPressed: () => notifier.installCommunityPlugin(m),
                            child: const Text('Install', style: TextStyle(fontSize: 11)),
                          ),
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _aiTaskCard(
    BuildContext context, {
    required IconData icon,
    required String taskName,
    required String modelName,
    required String status,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: Insets.xs),
      elevation: 0,
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: Insets.xs),
        child: Row(
          children: [
            Icon(icon, size: 20, color: scheme.primary),
            const SizedBox(width: Insets.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    taskName,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    modelName,
                    style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                status,
                style: TextStyle(
                  fontSize: 12.0,
                  fontWeight: FontWeight.w600,
                  color: scheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
