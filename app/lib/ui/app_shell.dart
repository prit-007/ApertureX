import 'dart:typed_data';
import 'dart:ui' show ImageFilter;

import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../color/histogram_view.dart';
import '../color/interactive_histogram.dart';
import '../core/haptics.dart';
import '../core/theme/design_tokens.dart';
import '../edit/parameter.dart';
import '../edit/recipe_controller.dart';
import '../edit/recipe_mapping.dart';
import '../gesture/gesture_interpreter.dart';
import '../settings/shell_preference.dart';
import '../viewport/image_canvas.dart';
import 'lightroom/lightroom_shell.dart';
import 'snapseed/snapseed_shell.dart';

/// The editor body shared by the app: one [ImageCanvas] over one recipe.
///
/// * **Gestures** ship (the Snapseed "Ghost UI") renders the photo
///   **edge-to-edge** with the tool HUD floating above it — the canvas owns all
///   touch (1-finger edits, 2-finger zoom/pan).
/// * **Lightroom** renders the canvas above a scrollable tool panel.
///
/// Switching shells never touches the canvas or the recipe (ADR 0008).
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, this.imageBytes});

  final Uint8List? imageBytes;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _showHistogram = false;
  bool _panelCollapsed = false;
  GradeTool _active = GradeTool.exposure;
  ToolCategory _category = ToolCategory.light;
  late final GestureInterpreter _fsm;

  @override
  void initState() {
    super.initState();
    _fsm = GestureInterpreter(
      tools: gestureCategories[_category]!,
      onToolChanged: (tool) {
        HapticFeedback.selectionClick();
        if (mounted) setState(() => _active = tool);
      },
      onValueChanged: (tool, delta) {
        final parameter = snapseedToolParameters[tool]!.first;
        final spec = specOf(parameter);
        final previous = valueOf(ref.read(recipeControllerProvider).recipe, parameter);
        ref.read(recipeControllerProvider.notifier).applyDelta(parameter, delta);
        final next = clampParameter(parameter, previous + delta * spec.scale);
        fireHaptic(hapticFor(previous, next, spec.min, spec.max));
      },
      onReset: (tool) => ref
          .read(recipeControllerProvider.notifier)
          .reset(snapseedToolParameters[tool]!.first),
    );
  }

  void _cycleCategory() {
    const order = ToolCategory.values;
    final next = order[(order.indexOf(_category) + 1) % order.length];
    final tools = gestureCategories[next]!;
    _fsm.setTools(tools, select: tools.first);
    HapticFeedback.selectionClick();
    setState(() {
      _category = next;
      _active = tools.first;
    });
  }

  @override
  Widget build(BuildContext context) {
    final kind = ref.watch(shellPreferenceProvider);
    final scheme = Theme.of(context).colorScheme;

    final overlays = <Widget>[
      _CompareHint(),
      _HistogramToggle(
        enabled: ref.watch(histogramProvider) != null,
        selected: _showHistogram,
        onPressed: () => setState(() => _showHistogram = !_showHistogram),
      ),
    ];

    if (kind == AppShellKind.snapseed) {
      return ColoredBox(
        color: scheme.surface,
        child: Stack(
          children: [
            Positioned.fill(
              child: ImageCanvas(
                imageBytes: widget.imageBytes,
                editInterpreter: _fsm,
              ),
            ),
            SnapseedShell(
              tool: _active,
              category: _category,
              tools: gestureCategories[_category]!,
              onCycleCategory: _cycleCategory,
              onPickTool: (t) {
                _fsm.setTool(t);
                setState(() => _active = t);
              },
            ),
            if (_showHistogram && ref.watch(histogramProvider) != null)
              const Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: _HistogramOverlay(),
              ),
            Positioned(left: Insets.sm, bottom: Insets.sm, child: overlays[0]),
            Positioned(right: Insets.sm, bottom: Insets.sm, child: overlays[1]),
          ],
        ),
      );
    }

    return ColoredBox(
      color: scheme.surface,
      child: Column(
        children: [
          Expanded(
            flex: _panelCollapsed ? 10 : 3,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ImageCanvas(imageBytes: widget.imageBytes),
                ),
                if (_showHistogram && ref.watch(histogramProvider) != null)
                  const Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    child: _HistogramOverlay(),
                  ),
                Positioned(left: Insets.sm, bottom: Insets.sm, child: overlays[0]),
                Positioned(right: Insets.sm, bottom: Insets.sm, child: overlays[1]),
              ],
            ),
          ),
          _PanelHandle(
            collapsed: _panelCollapsed,
            onToggle: () => setState(() => _panelCollapsed = !_panelCollapsed),
          ),
          if (!_panelCollapsed)
            const Expanded(flex: 2, child: LightroomShell()),
        ],
      ),
    );
  }
}

/// The grab-handle between the image and the Lightroom panel. Tapping it
/// collapses the tools so the photo can fill the screen.
class _PanelHandle extends StatelessWidget {
  const _PanelHandle({required this.collapsed, required this.onToggle});

  final bool collapsed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      child: InkWell(
        onTap: onToggle,
        child: SizedBox(
          height: 28,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                collapsed ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: Insets.xs),
              Text(
                collapsed ? 'Show tools' : 'Hide tools',
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The live interactive histogram as a translucent overlay on the image.
class _HistogramOverlay extends StatelessWidget {
  const _HistogramOverlay();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        bottom: Radius.circular(Radii.md),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: ColoredBox(
          color: scheme.surface.withValues(alpha: 0.55),
          child: const Padding(
            padding: EdgeInsets.symmetric(
              horizontal: Insets.sm,
              vertical: Insets.xs,
            ),
            child: InteractiveHistogram(),
          ),
        ),
      ),
    );
  }
}

class _HistogramToggle extends StatelessWidget {
  const _HistogramToggle({
    required this.enabled,
    required this.selected,
    required this.onPressed,
  });

  final bool enabled;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton.filledTonal(
      onPressed: enabled ? onPressed : null,
      isSelected: selected,
      tooltip: selected ? 'Hide histogram' : 'Show histogram',
      icon: const Icon(Icons.bar_chart, size: 20),
      style: IconButton.styleFrom(
        backgroundColor: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
      ),
    );
  }
}

/// A compact, non-interactive affordance on the image: long-press shows the
/// unedited "before".
class _CompareHint extends StatelessWidget {
  const _CompareHint();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: Radii.smAll,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.sm,
            vertical: Insets.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.compare, size: 14, color: scheme.onSurfaceVariant),
              const SizedBox(width: Insets.xs),
              Text(
                'Hold to compare',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
