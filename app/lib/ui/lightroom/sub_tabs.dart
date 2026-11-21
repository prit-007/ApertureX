import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A row of pill-style sub-tabs with Apply/Cancel overflow buttons when
/// there are uncommitted changes. Extracted from LightroomShell.
class SubTabs<T> extends StatelessWidget {
  const SubTabs({
    super.key,
    required this.tabs,
    required this.current,
    required this.onSelect,
    required this.hasTabChanges,
    required this.onCancel,
    required this.onApply,
  });

  final List<(String label, T value, String keyName, bool isModified)> tabs;
  final T current;
  final ValueChanged<T> onSelect;
  final bool hasTabChanges;
  final VoidCallback onCancel;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget tab(String label, T value, String keyName, bool isModified) {
      final selected = current == value;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HapticFeedback.selectionClick();
            if (hasTabChanges) {
              onApply();
            }
            onSelect(value);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: selected
                  ? scheme.primary.withValues(alpha: 0.2)
                  : scheme.surfaceContainerHigh.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? scheme.primary
                    : isModified
                    ? scheme.primary.withValues(alpha: 0.5)
                    : scheme.outlineVariant.withValues(alpha: 0.4),
                width: selected ? 1.2 : 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 0.4,
                    color: selected ? scheme.primary : scheme.onSurfaceVariant,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                if (isModified) ...[
                  const SizedBox(width: 4),
                  Container(
                    key: Key('applied-dot-$keyName'),
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected
                          ? scheme.primary
                          : scheme.primary.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: SizedBox(
        height: 34,
        child: Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final item in tabs)
                      tab(item.$1, item.$2, item.$3, item.$4),
                  ],
                ),
              ),
            ),
            if (hasTabChanges) ...[
              VerticalDivider(
                width: 1,
                indent: 8,
                endIndent: 8,
                color: scheme.outlineVariant.withValues(alpha: 0.3),
              ),
              IconButton(
                key: const Key('subtab-cancel'),
                tooltip: 'Discard changes',
                visualDensity: VisualDensity.compact,
                iconSize: 18,
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
                onPressed: onCancel,
                icon: Icon(Icons.close, color: scheme.error, size: 18),
              ),
              const SizedBox(width: 4),
              IconButton(
                key: const Key('subtab-apply'),
                tooltip: 'Apply changes',
                visualDensity: VisualDensity.compact,
                iconSize: 18,
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
                onPressed: onApply,
                icon: Icon(Icons.check, color: scheme.primary, size: 18),
              ),
              const SizedBox(width: 6),
            ],
          ],
        ),
      ),
    );
  }
}
