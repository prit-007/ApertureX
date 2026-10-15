import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../../features/logs/logs_screen.dart';
import '../log/activity_log.dart';
import 'error_reporter.dart';

/// Root navigator shared by the app shell and every error popup (ADR 0012) —
/// lets the reporter present from anywhere without plumbing a context.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// Presents [reported] as the error popup. Errors can arrive during build, so
/// the dialog is deferred past the current frame; with no navigator attached
/// (very early bootstrap) it is a no-op — the log entry and crash marker
/// still exist either way.
void showErrorDialog(ReportedError reported) {
  final context = rootNavigatorKey.currentContext;
  if (context == null || !context.mounted) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => ErrorDialog(reported: reported),
    );
  });
}

/// The error popup (ADR 0012 §2): what failed, with a one-tap path into the
/// log page that holds the full record.
class ErrorDialog extends StatelessWidget {
  const ErrorDialog({super.key, required this.reported});

  final ReportedError reported;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return AlertDialog(
      icon: Icon(
        reported.fatal ? Icons.error_outline : Icons.warning_amber_rounded,
        color: reported.fatal ? scheme.error : scheme.onSurfaceVariant,
      ),
      title: const Text('Something went wrong'),
      content: SingleChildScrollView(
        child: SelectableText(
          reported.error.toString(),
          style: textTheme.bodyMedium,
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
          onPressed: () => _copy(context),
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
        builder: (_) => LogsScreen(
          initialDomain: reported.fatal ? LogDomain.crash : LogDomain.error,
        ),
      ),
    );
  }

  void _copy(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    _copyDetails(reported, messenger);
  }
}

/// Copies the full failure record (error + stack) to the clipboard.
void _copyDetails(ReportedError reported, ScaffoldMessengerState messenger) {
  Clipboard.setData(
    ClipboardData(text: '${reported.error}\n${reported.stack}'),
  ).then((_) {
    messenger.showSnackBar(const SnackBar(content: Text('Details copied')));
  }).catchError((_) {
    // clipboard failures must not crash the popup
  });
}
