import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/design_tokens.dart';
import '../../ui/common/app_sheet.dart';
import 'ai_plugin_model.dart';
import 'ai_plugin_store.dart';

/// Neural Forge screen for managing on-device AI models and installing plugins via GitHub/URLs.
class AiPluginsScreen extends ConsumerWidget {
  const AiPluginsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(aiPluginProvider);
    final notifier = ref.read(aiPluginProvider.notifier);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('AI Models & Plugins'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Installed'),
              Tab(text: 'Community Hub'),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Add custom model',
              icon: const Icon(Icons.add_link_rounded),
              onPressed: () => _showAddPluginSheet(context, notifier),
            ),
          ],
        ),
        body: TabBarView(
          children: [
            // ─── Tab 1: Installed Models ────────────────────────────────
            _InstalledTab(state: state, notifier: notifier),

            // ─── Tab 2: Community Hub ───────────────────────────────────
            _CommunityTab(state: state, notifier: notifier),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showAddPluginSheet(context, notifier),
          icon: const Icon(Icons.add),
          label: const Text('Add via GitHub / Link'),
        ),
      ),
    );
  }

  void _showAddPluginSheet(BuildContext context, AiPluginNotifier notifier) {
    showAppSheet<void>(
      context,
      _AddPluginSheet(notifier: notifier),
    );
  }
}

class _InstalledTab extends StatelessWidget {
  const _InstalledTab({required this.state, required this.notifier});

  final AiPluginState state;
  final AiPluginNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final installed = state.installedPlugins;

    if (installed.isEmpty) {
      return const Center(child: Text('No AI models installed.'));
    }

    return SafeArea(
      bottom: true,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          Insets.md,
          Insets.md,
          Insets.md,
          kFloatingActionButtonMargin + 88,
        ),
        children: [
        _BannerCard(
          theme: theme,
          title: 'ApertureX Neural Forge',
          description:
              'Models execute 100% on-device via zero-copy tensor runtime. Zero telemetry, zero cloud inference.',
          icon: Icons.offline_bolt_rounded,
        ),
        const SizedBox(height: Insets.md),
        // ─── Active model per task ───────────────────────────────────────
        _TaskRouterCard(
          theme: theme,
          notifier: notifier,
        ),
        const SizedBox(height: Insets.md),
        const Text(
          'Installed Models',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: Insets.sm),
        for (final plugin in installed) ...[
          Builder(
            builder: (context) {
              final isActive = state.activePluginPerTask[plugin.task] == plugin.id;
              return Card.outlined(
                margin: const EdgeInsets.only(bottom: Insets.sm),
                child: Padding(
                  padding: const EdgeInsets.all(Insets.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? theme.colorScheme.primaryContainer
                                  : theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isActive) ...[
                                  const Icon(Icons.check_circle_rounded, size: 12, color: Colors.green),
                                  const SizedBox(width: 4),
                                ],
                                Text(
                                  isActive ? 'Active for ${plugin.task.label}' : plugin.task.label,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: isActive
                                        ? theme.colorScheme.onPrimaryContainer
                                        : theme.colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: Insets.xs),
                          if (plugin.isBuiltIn)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('Built-in', style: TextStyle(fontSize: 10)),
                            )
                          else if (isActive)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Ready in Editor',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          const Spacer(),
                          Switch.adaptive(
                            value: plugin.isEnabled,
                            onChanged: (val) => notifier.togglePlugin(plugin.id, val),
                          ),
                        ],
                      ),
                      const SizedBox(height: Insets.xs),
                      Text(
                        plugin.name,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        plugin.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Divider(height: Insets.md),
                      Row(
                        children: [
                          Icon(Icons.memory, size: 14, color: theme.colorScheme.primary),
                          const SizedBox(width: 4),
                          Text(
                            'Tensor: ${plugin.tensorShapeLabel}',
                            style: theme.textTheme.labelSmall,
                          ),
                          const SizedBox(width: Insets.md),
                          Icon(Icons.person_outline, size: 14, color: theme.colorScheme.primary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              plugin.author,
                              style: theme.textTheme.labelSmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!isActive && plugin.isEnabled)
                            TextButton.icon(
                              onPressed: () {
                                notifier.setActivePluginForTask(plugin.task, plugin.id);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('${plugin.name} is now active for ${plugin.task.label}!'),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.check_circle_outline, size: 16),
                              label: const Text('Set Active'),
                            ),
                          if (!plugin.isBuiltIn)
                            IconButton(
                              tooltip: 'Delete model',
                              icon: const Icon(Icons.delete_outline, size: 18),
                              onPressed: () => notifier.deletePlugin(plugin.id),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
        ],
      ),
    );
  }
}

class _CommunityTab extends StatelessWidget {
  const _CommunityTab({required this.state, required this.notifier});

  final AiPluginState state;
  final AiPluginNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final community = state.communityPlugins;

    return SafeArea(
      bottom: true,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          Insets.md,
          Insets.md,
          Insets.md,
          kFloatingActionButtonMargin + 88,
        ),
        children: [
        _BannerCard(
          theme: theme,
          title: 'Verified Open-Source Models',
          description:
              'Curated state-of-the-art vision models from GitHub & HuggingFace with verified offline architectures.',
          icon: Icons.hub_outlined,
        ),
        const SizedBox(height: Insets.md),
        for (final plugin in community) ...[
          Builder(
            builder: (context) {
              final isInstalled = state.installedPlugins.any((p) => p.id == plugin.id);
              final isActive = state.activePluginPerTask[plugin.task] == plugin.id;
              return _CommunityPluginCard(
                plugin: plugin,
                isInstalled: isInstalled,
                isActive: isActive,
                isDownloading: state.downloadingId == plugin.id,
                progress: state.downloadProgress,
                onInstall: () async {
                  await notifier.installCommunityPlugin(plugin);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${plugin.name} downloaded & ready! Active for ${plugin.task.label} in Masks & Editor.',
                        ),
                      ),
                    );
                  }
                },
              );
            },
          ),
          const SizedBox(height: Insets.sm),
        ],
        ],
      ),
    );
  }
}

class _CommunityPluginCard extends StatelessWidget {
  const _CommunityPluginCard({
    required this.plugin,
    required this.isInstalled,
    required this.isActive,
    required this.isDownloading,
    required this.progress,
    required this.onInstall,
  });

  final AiPluginModel plugin;
  final bool isInstalled;
  final bool isActive;
  final bool isDownloading;
  final double progress;
  final VoidCallback onInstall;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(Insets.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    plugin.task.label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: Insets.xs),
                Text(
                  'v${plugin.version}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                if (isDownloading)
                  SizedBox(
                    width: 100,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        LinearProgressIndicator(value: progress),
                        const SizedBox(height: 2),
                        Text('${(progress * 100).round()}%', style: const TextStyle(fontSize: 10)),
                      ],
                    ),
                  )
                else if (isInstalled)
                  FilledButton.tonalIcon(
                    onPressed: null,
                    icon: Icon(
                      isActive ? Icons.check_circle_rounded : Icons.check,
                      size: 16,
                      color: isActive ? Colors.green : null,
                    ),
                    label: Text(isActive ? 'Active' : 'Installed'),
                  )
                else
                  FilledButton.icon(
                    onPressed: onInstall,
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text('Install'),
                  ),
              ],
            ),
            const SizedBox(height: Insets.xs),
            Text(
              plugin.name,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              plugin.description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Insets.xs),
            Row(
              children: [
                Icon(Icons.link, size: 14, color: theme.colorScheme.primary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    plugin.sourceUrl,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (plugin.fileSizeBytes > 0)
                  Text(
                    '${(plugin.fileSizeBytes / (1024 * 1024)).toStringAsFixed(0)} MB',
                    style: theme.textTheme.labelSmall,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({
    required this.theme,
    required this.title,
    required this.description,
    required this.icon,
  });

  final ThemeData theme;
  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 24),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddPluginSheet extends StatefulWidget {
  const _AddPluginSheet({required this.notifier});

  final AiPluginNotifier notifier;

  @override
  State<_AddPluginSheet> createState() => _AddPluginSheetState();
}

class _AddPluginSheetState extends State<_AddPluginSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  final _authorController = TextEditingController(text: 'Community');
  AiTask _task = AiTask.subjectSegmentation;
  int _dim = 512;

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _authorController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    widget.notifier.addCustomPlugin(
      name: _nameController.text.trim(),
      url: _urlController.text.trim(),
      task: _task,
      width: _dim,
      height: _dim,
      author: _authorController.text.trim(),
    );
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Installed AI plugin: ${_nameController.text.trim()}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(Insets.md),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Add Custom AI Plugin',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: Insets.sm),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Model Name',
                    hintText: 'e.g. My Custom Depth Model',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Please enter a name' : null,
                ),
                const SizedBox(height: Insets.sm),
                TextFormField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                    labelText: 'GitHub / HuggingFace Model URL',
                    hintText: 'https://github.com/.../model.onnx',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Please enter a URL';
                    if (!val.startsWith('http://') && !val.startsWith('https://')) {
                      return 'Must be an HTTP/HTTPS URL';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: Insets.sm),
                DropdownButtonFormField<AiTask>(
                  initialValue: _task,
                  decoration: const InputDecoration(
                    labelText: 'AI Task',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final t in AiTask.values)
                      DropdownMenuItem(value: t, child: Text(t.label)),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _task = val);
                  },
                ),
                const SizedBox(height: Insets.sm),
                DropdownButtonFormField<int>(
                  initialValue: _dim,
                  decoration: const InputDecoration(
                    labelText: 'Input Tensor Resolution',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 256, child: Text('256 × 256 (Fastest)')),
                    DropdownMenuItem(value: 512, child: Text('512 × 512 (Standard)')),
                    DropdownMenuItem(value: 1024, child: Text('1024 × 1024 (High Precision)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _dim = val);
                  },
                ),
                const SizedBox(height: Insets.md),
                FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.install_desktop),
                  label: const Text('Install & Activate Plugin'),
                ),
                const SizedBox(height: Insets.xs),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Card showing which model is active for each AI task, with ability to
/// switch when multiple enabled+installed plugins exist for the same task.
class _TaskRouterCard extends ConsumerWidget {
  const _TaskRouterCard({
    required this.theme,
    required this.notifier,
  });

  final ThemeData theme;
  final AiPluginNotifier notifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card.outlined(
      margin: const EdgeInsets.only(bottom: Insets.md),
      child: Padding(
        padding: const EdgeInsets.all(Insets.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.settings,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: Insets.xs),
                Text(
                  'Active Model per Task',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.md),
            for (final task in AiTask.values)
              _TaskRow(
                theme: theme,
                task: task,
                notifier: notifier,
              ),
          ],
        ),
      ),
    );
  }
}

/// One row: task name, active model, and dropdown to switch active model.
class _TaskRow extends ConsumerWidget {
  const _TaskRow({
    required this.theme,
    required this.task,
    required this.notifier,
  });

  final ThemeData theme;
  final AiTask task;
  final AiPluginNotifier notifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(aiPluginProvider);
    final active = notifier.getActivePluginForTask(task);
    final candidates = state.installedPlugins.where(
      (p) => p.task == task && p.isEnabled && p.isInstalled,
    ).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.xs),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  task.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  active?.name ?? 'None assigned',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Insets.md),
          if (candidates.length > 1)
            Expanded(
              child: DropdownButton<String>(
                value: active?.id,
                isExpanded: true,
                items: [
                  for (final p in candidates)
                    DropdownMenuItem(
                      value: p.id,
                      child: Text(
                        p.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (id) {
                  if (id != null) {
                    notifier.setActivePluginForTask(task, id);
                  }
                },
              ),
            )
          else
            Text(
              candidates.isEmpty ? 'No model installed' : 'Only option',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }
}
