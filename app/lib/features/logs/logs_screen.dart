import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

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
  String? _domain; // null = all

  @override
  Widget build(BuildContext context) {
    final log = ref.watch(activityLogProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity log'),
        actions: [
          ListenableBuilder(
            listenable: log,
            builder: (context, _) => IconButton(
              tooltip: 'Copy log',
              onPressed: log.isEmpty
                  ? null
                  : () {
                      final text = log.entries
                          .map(
                            (e) =>
                                '${e.time.toIso8601String()} '
                                '[${e.domain}/${e.level.name}] ${e.message}',
                          )
                          .join('\n');
                      Clipboard.setData(ClipboardData(text: text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Log copied')),
                      );
                    },
              icon: const Icon(Icons.copy_all),
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
      body: Column(
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
                final entries = log.entries
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
      ),
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
      leading: Icon(_levelIcon(entry.level), color: _levelColor(entry.level, scheme), size: 20),
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
