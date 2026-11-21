import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/design_tokens.dart';

enum RubylithColor {
  red(Color(0xFFE53935), 'Red'),
  green(Color(0xFF43A047), 'Green'),
  blue(Color(0xFF1E88E5), 'Blue'),
  white(Color(0xFFFFFFFF), 'White');

  const RubylithColor(this.color, this.label);
  final Color color;
  final String label;
}

/// Settings for persistent Rubylith overlay bar (ADR 0013 / pro parity).
class RubylithOverlaySettings {
  const RubylithOverlaySettings({
    this.showOverlay = true,
    this.color = RubylithColor.red,
    this.opacity = 0.5,
  });

  final bool showOverlay;
  final RubylithColor color;
  final double opacity;

  RubylithOverlaySettings copyWith({
    bool? showOverlay,
    RubylithColor? color,
    double? opacity,
  }) => RubylithOverlaySettings(
    showOverlay: showOverlay ?? this.showOverlay,
    color: color ?? this.color,
    opacity: opacity ?? this.opacity,
  );
}

class RubylithOverlayNotifier extends Notifier<RubylithOverlaySettings> {
  @override
  RubylithOverlaySettings build() => const RubylithOverlaySettings();

  void toggleShowOverlay() => state = state.copyWith(showOverlay: !state.showOverlay);
  void setShowOverlay(bool value) => state = state.copyWith(showOverlay: value);
  void setColor(RubylithColor color) => state = state.copyWith(color: color);
  void setOpacity(double opacity) => state = state.copyWith(opacity: opacity);
}

final rubylithOverlayProvider =
    NotifierProvider<RubylithOverlayNotifier, RubylithOverlaySettings>(
  RubylithOverlayNotifier.new,
);

/// Persistent Rubylith Overlay Bar docked at the top of masking controls.
class RubylithOverlayBar extends ConsumerWidget {
  const RubylithOverlayBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final rubylith = ref.watch(rubylithOverlayProvider);
    final notifier = ref.read(rubylithOverlayProvider.notifier);

    return Material(
      type: MaterialType.transparency,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: Insets.xs),
        padding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 6),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh.withValues(alpha: 0.45),
          borderRadius: Radii.mdAll,
          border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.35)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                InkWell(
                  key: const Key('mask-overlay-toggle'),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    notifier.toggleShowOverlay();
                  },
                  borderRadius: Radii.smAll,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          rubylith.showOverlay ? Icons.visibility : Icons.visibility_off,
                          size: 16,
                          color: rubylith.showOverlay ? scheme.primary : scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Overlay [O]',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: rubylith.showOverlay ? scheme.onSurface : scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final rc in RubylithColor.values)
                      GestureDetector(
                        key: Key('mask-rubylith-${rc.name}'),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          notifier.setColor(rc);
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: rc.color,
                            border: Border.all(
                              color: rubylith.color == rc ? scheme.onSurface : scheme.outlineVariant,
                              width: rubylith.color == rc ? 2 : 1,
                            ),
                            boxShadow: rubylith.color == rc
                                ? [BoxShadow(color: rc.color.withValues(alpha: 0.6), blurRadius: 4)]
                                : null,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                SizedBox(
                  width: 52,
                  child: Text(
                    'Opacity',
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 2,
                      activeTrackColor: rubylith.color.color,
                      inactiveTrackColor: scheme.surfaceContainerHighest,
                      thumbColor: rubylith.color.color,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                    ),
                    child: Slider(
                      key: const Key('mask-rubylith-opacity'),
                      value: rubylith.opacity,
                      min: 0.0,
                      max: 1.0,
                      onChanged: (v) => notifier.setOpacity(v),
                    ),
                  ),
                ),
                SizedBox(
                  width: 36,
                  child: Text(
                    '${(rubylith.opacity * 100).round()}%',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
