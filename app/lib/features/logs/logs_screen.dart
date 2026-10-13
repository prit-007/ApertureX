import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/log/activity_log.dart';
import '../../core/log/log_providers.dart';
import '../../core/theme/design_tokens.dart';
import '../../ui/common/app_primitives.dart';

Color _domainColor(String domain, ColorScheme scheme) => switch (domain) {
  LogDomain.app => scheme.primary,
  LogDomain.gallery => const Color(0xFF16A085),
  LogDomain.editor => const Color(0xFFF39C12),
  LogDomain.export => const Color(0xFF2E7D32),
  LogDomain.permission => const Color(0xFFD81B60),
  LogDomain.preset => const Color(0xFF8E44AD),
  _ => scheme.onSurfaceVariant,
};

Color _levelColor(LogLevel level, ColorScheme scheme) => switch (level) {
  LogLevel.debug => scheme.onSurfaceVariant,
  LogLevel.info => scheme.primary,
  LogLevel.warning => const Color(0xFFE67E22),
  LogLevel.error => scheme.error,
};

IconData _levelIcon(LogLevel level) => switch (level) {
  LogLevel.debug => Icons.circle,
  LogLevel.info => Icons.info_outline,
  LogLevel.warning => Icons.warning_amber,
  LogLevel.error => Icons.error_outline,
};

/// The on-device, offline activity feed: every gallery / editor / export /
/// permission action and error, filterable by domain. Mirrors the nook "App
/// Logs" experience, built natively for ApertureX's Material theme.
class LogsScreen extends ConsumerStatefulWidget {
  const LogsScreen({super.key});

  @override
  ConsumerState<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends ConsumerState<LogsScreen> {
  static const _helpSeenKey = 'logs_help_seen';

  String? _domain; // null = all
  bool _showGuide = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool(_helpSeenKey) ?? false) && mounted) {
        setState(() => _showGuide = true);
      }
    });
  }

  Future<void> _dismissGuide() async {
    setState(() => _showGuide = false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_helpSeenKey, true);
  }

  void _copy() {
    final log = ref.read(activityLogProvider);
    Clipboard.setData(ClipboardData(text: activityLogReport(log.entries)));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Log copied')));
  }

  Future<void> _export() async {
    final log = ref.read(activityLogProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/aperturex-activity-log.txt');
      await file.writeAsString(activityLogReport(log.entries), flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'text/plain')],
          subject: 'ApertureX activity log',
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final log = ref.watch(activityLogProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity log'),
        actions: [
          IconButton(
            tooltip: 'Guide',
            onPressed: () => setState(() => _showGuide = true),
            icon: const Icon(Icons.help_outline),
          ),
          ListenableBuilder(
            listenable: log,
            builder: (context, _) => IconButton(
              tooltip: 'Copy log',
              onPressed: log.isEmpty ? null : _copy,
              icon: const Icon(Icons.copy_all),
            ),
          ),
          ListenableBuilder(
            listenable: log,
            builder: (context, _) => IconButton(
              tooltip: 'Export log',
              onPressed: log.isEmpty ? null : _export,
              icon: const Icon(Icons.ios_share),
            ),
          ),
          ListenableBuilder(
            listenable: log,
            builder: (context, _) => IconButton(
              tooltip: 'Clear',
              onPressed: log.isEmpty ? null : log.clear,
              icon: const Icon(Icons.delete_outline),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(child: _feed(context, log, scheme)),
          if (_showGuide)
            Positioned.fill(child: _GuideOverlay(onDone: _dismissGuide)),
        ],
      ),
    );
  }

  Widget _feed(BuildContext context, ActivityLog log, ColorScheme scheme) {
    return Column(
      children: [
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
            children: [
              _chip(context, 'All', null),
              for (final domain in LogDomain.all)
                _chip(context, domain, domain),
            ],
          ),
        ),
        Divider(height: 1, color: scheme.outlineVariant),
        Expanded(
          child: ListenableBuilder(
            listenable: log,
            builder: (context, _) {
              final all = log.entries;
              final entries = all
                  .where((e) => _domain == null || e.domain == _domain)
                  .toList()
                  .reversed
                  .toList();
              if (entries.isEmpty) {
                return const EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'No activity yet',
                  message: 'Actions you take are logged here, on your device.',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: Insets.sm),
                itemCount: entries.length,
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  indent: Insets.lg,
                  color: scheme.outlineVariant.withValues(alpha: 0.6),
                ),
                itemBuilder: (context, i) => _EntryTile(entry: entries[i]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _chip(BuildContext context, String label, String? domain) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _domain == domain;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        avatar: domain == null
            ? null
            : CircleAvatar(backgroundColor: _domainColor(domain, scheme)),
        showCheckmark: false,
        onSelected: (_) => setState(() => _domain = domain),
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});

  final LogEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final time =
        '${entry.time.hour.toString().padLeft(2, '0')}:'
        '${entry.time.minute.toString().padLeft(2, '0')}:'
        '${entry.time.second.toString().padLeft(2, '0')}';
    return ListTile(
      dense: true,
      leading: Icon(
        _levelIcon(entry.level),
        color: _levelColor(entry.level, scheme),
        size: 20,
      ),
      title: Text(entry.message, style: theme.textTheme.bodyMedium),
      subtitle: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: _domainColor(entry.domain, scheme),
              shape: BoxShape.circle,
            ),
          ),
          Text(
            '${entry.domain} · $time',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

typedef _Legend = ({String label, Color color});

class _Step {
  const _Step({
    required this.title,
    required this.description,
    required this.icon,
    this.legend,
  });

  final String title;
  final String description;
  final IconData icon;
  final List<_Legend>? legend;
}

/// A first-run walkthrough of the log viewer, shown once (then reachable from
/// the Guide action) — the same idea as nook's logs tour.
class _GuideOverlay extends StatefulWidget {
  const _GuideOverlay({required this.onDone});

  final VoidCallback onDone;

  @override
  State<_GuideOverlay> createState() => _GuideOverlayState();
}

class _GuideOverlayState extends State<_GuideOverlay> {
  int _step = 0;

  List<_Step> _steps(ColorScheme scheme) => [
    const _Step(
      title: 'Welcome',
      description:
          'Everything ApertureX does — opening photos, edits, exports and '
          'permission prompts — is recorded here, on your device, offline.',
      icon: Icons.receipt_long,
    ),
    const _Step(
      title: 'Filter by domain',
      description:
          'Tap the chips to isolate a single stream: gallery, editor, export, '
          'permission or preset events.',
      icon: Icons.filter_alt_outlined,
    ),
    _Step(
      title: 'Colour coding',
      description: 'Levels and domains are colour-coded for quick scanning.',
      icon: Icons.palette_outlined,
      legend: [
        (label: 'Debug', color: scheme.onSurfaceVariant),
        (label: 'Info', color: scheme.primary),
        (label: 'Warning', color: const Color(0xFFE67E22)),
        (label: 'Error', color: scheme.error),
      ],
    ),
    const _Step(
      title: 'Copy, export, clear',
      description:
          'Copy a snapshot, export the whole log as a .txt file to share, or '
          'clear it — all from the top bar.',
      icon: Icons.ios_share,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final steps = _steps(scheme);
    final step = steps[_step];
    final isLast = _step == steps.length - 1;

    return Stack(
      children: [
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: ColoredBox(color: scheme.surface.withValues(alpha: 0.82)),
          ),
        ),
        Positioned(
          top: MediaQuery.paddingOf(context).top + 8,
          right: 20,
          child: TextButton(
            onPressed: widget.onDone,
            child: const Text('Skip'),
          ),
        ),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.xl,
              vertical: Insets.xxl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AnimatedSwitcher(
                duration: Motion.medium,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.05),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: Card(
                  key: ValueKey(_step),
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Insets.xl,
                      Insets.xl,
                      Insets.xl,
                      Insets.lg,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 34,
                          backgroundColor: scheme.primary.withValues(alpha: 0.12),
                          child: Icon(step.icon, color: scheme.primary, size: 30),
                        ),
                        const SizedBox(height: Insets.lg),
                        Text(
                          step.title,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: Insets.sm),
                        Text(
                          step.description,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                        if (step.legend != null) ...[
                          const SizedBox(height: Insets.lg),
                          _LegendList(entries: step.legend!),
                        ],
                        const SizedBox(height: Insets.xl),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: isLast
                                ? widget.onDone
                                : () => setState(() => _step++),
                            child: Text(isLast ? 'Enter logs' : 'Continue'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: MediaQuery.paddingOf(context).bottom + Insets.lg,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(steps.length, (i) {
              final active = i == _step;
              return AnimatedContainer(
                duration: Motion.medium,
                curve: Motion.emphasized,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                width: active ? 32 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: active ? scheme.primary : scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _LegendList extends StatelessWidget {
  const _LegendList({required this.entries});

  final List<_Legend> entries;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: Insets.md,
      runSpacing: Insets.sm,
      children: [
        for (final entry in entries)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.md,
              vertical: Insets.sm,
            ),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: Radii.mdAll,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: entry.color,
                  ),
                ),
                const SizedBox(width: Insets.sm),
                Text(entry.label),
              ],
            ),
          ),
      ],
    );
  }
}
