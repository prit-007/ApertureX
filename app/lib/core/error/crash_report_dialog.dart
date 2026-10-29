import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:material_ui/material_ui.dart';

import '../../features/logs/logs_screen.dart';
import '../theme/design_tokens.dart';
import '../log/activity_log.dart';
import '../log/native_log_bridge.dart';
import 'crash_marker.dart';
import 'error_dialog.dart' show rootNavigatorKey;

/// The pending crash record from any layer — the Dart zone marker first, then
/// Kotlin's (platform) marker over the channel — or null when nothing crashed.
/// Both layers write the same `{t, where, error, stack}` shape (ADR 0012 §3/§6).
Future<Map<String, Object?>?> peekPendingCrash({
  CrashMarker? marker,
  NativeLogBridge? bridge,
}) async {
  final fromDart = await marker?.peek();
  if (fromDart != null) return fromDart;
  if (bridge == null) return null;
  return bridge.readCrashMarker();
}

/// One-time next-launch offer: when the previous session left a crash marker
/// (Dart **or** native layer), show a dialog whose only real job is getting the
/// user onto the log page that holds the record (ADR 0012 §3).
///
/// Both markers are consumed first — the offer is made at most once — and the
/// dialog is deferred past the current frame, so calling this before `runApp`
/// is safe.
Future<void> showCrashReport({
  CrashMarker? marker,
  NativeLogBridge? bridge,
}) async {
  final record = await peekPendingCrash(marker: marker, bridge: bridge);
  if (record == null) return;
  await marker?.clear();
  await bridge?.clearCrashMarker();

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CrashReportDialog(record: record),
    );
  });
}

/// The next-launch crash popup: what died last session, with a one-tap path
/// into the log page (deep-linked to the crash domain) — the "crash → option
/// to navigate to the logs" requirement (ADR 0012 §3).
class CrashReportDialog extends StatelessWidget {
  const CrashReportDialog({super.key, required this.record});

  /// `{t, where, error, stack}` from either layer's marker.
  final Map<String, Object?> record;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final error = (record['error'] ?? record['m'] ?? 'Unknown failure').toString();
    final stack = record['stack']?.toString();
    return AlertDialog(
      icon: Icon(Icons.history_toggle_off, color: scheme.error),
      title: const Text('ApertureX crashed last time'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SelectableText(error, style: textTheme.bodyMedium),
            if (stack != null && stack.isNotEmpty) ...[
              const SizedBox(height: Insets.sm),
              SelectableText(
                stack,
                style: textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            _openLogs(context);
          },
          child: const Text('View logs'),
        ),
        TextButton(
          onPressed: () => _copy(context, error, stack),
          child: const Text('Copy'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Dismiss'),
        ),
      ],
    );
  }

  void _openLogs(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const LogsScreen(initialDomain: LogDomain.crash),
      ),
    );
  }

  void _copy(BuildContext context, String error, String? stack) {
    final messenger = ScaffoldMessenger.of(context);
    Clipboard.setData(ClipboardData(text: stack == null ? error : '$error\n$stack'))
        .then((_) {
          if (!messenger.mounted) return;
          messenger.showSnackBar(const SnackBar(content: Text('Details copied')));
        })
        .catchError((_) {
          // clipboard failures must not crash the popup
        });
  }
}
