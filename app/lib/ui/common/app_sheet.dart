import 'dart:ui' show ImageFilter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/design_tokens.dart';
import '../../settings/app_settings.dart';

/// Shows a themed, drag-dismissable modal bottom sheet (consistent shape,
/// handle, safe-area and keyboard handling across the whole app).
Future<T?> showAppSheet<T>(BuildContext context, Widget child) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Colors.transparent,
    builder: (_) => child,
  );
}

/// A consistent bottom-sheet container: a title block, a divider, then either a
/// scrolling or a fixed-width body. Supports frosted glassmorphic UI.
class AppSheet extends ConsumerWidget {
  const AppSheet({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.children = const [],
    this.scrollable = true,
    this.maxHeightFactor = 0.9,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final List<Widget> children;
  final bool scrollable;
  final double maxHeightFactor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final isGlass = ref.watch(glassmorphicUiProvider);

    final body = scrollable
        ? ListView(
            shrinkWrap: true,
            padding: Insets.sheet,
            children: children,
          )
        : Padding(
            padding: Insets.sheet,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          );

    final content = Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: media.size.height * maxHeightFactor,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.lg,
                Insets.sm,
                Insets.lg,
                Insets.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleLarge),
                  if (subtitle != null) ...[
                    const SizedBox(height: Insets.xs),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Divider(height: 1, color: theme.colorScheme.outlineVariant),
            Flexible(child: body),
            if (actions != null && actions!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Insets.lg,
                  Insets.sm,
                  Insets.lg,
                  Insets.lg,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: actions!,
                ),
              ),
          ],
        ),
      ),
    );

    if (isGlass) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Material(
            color: theme.colorScheme.surface.withValues(alpha: 0.70),
            child: content,
          ),
        ),
      );
    }

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: content,
    );
  }
}
