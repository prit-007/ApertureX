import 'package:material_ui/material_ui.dart';

import '../theme/design_tokens.dart';
import 'error_dialog.dart';
import 'error_reporter.dart';

/// In-place replacement for a failed subtree (ADR 0012 §1 — the
/// `ErrorWidget.builder` leg of the error boundary): instead of a dead grey
/// region, the subtree becomes a tappable card that opens the same error
/// popup, keeping the rest of the app fully navigable.
class BoundaryFallback extends StatelessWidget {
  const BoundaryFallback({super.key, required this.details});

  final FlutterErrorDetails details;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: scheme.errorContainer.withValues(alpha: 0.55),
      child: InkWell(
        onTap: () => showDialog<void>(
          context: context,
          builder: (_) => ErrorDialog(
            reported: ReportedError(
              error: details.exception,
              stack: details.stack ?? StackTrace.empty,
              fatal: false,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Insets.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.broken_image_outlined, color: scheme.onErrorContainer),
              const SizedBox(height: Insets.sm),
              Text(
                "This section couldn't render",
                textAlign: TextAlign.center,
                style: textTheme.titleSmall?.copyWith(
                  color: scheme.onErrorContainer,
                ),
              ),
              const SizedBox(height: Insets.xs),
              Text(
                'Tap to see what happened',
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onErrorContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
