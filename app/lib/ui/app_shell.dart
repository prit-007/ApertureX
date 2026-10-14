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
import '../edit/node_editor.dart';
import '../edit/recipe_controller.dart';
import '../edit/recipe_mapping.dart';
import '../gesture/gesture_interpreter.dart';
import '../settings/shell_preference.dart';
import '../settings/onboarding.dart';
import '../viewport/image_canvas.dart';
import '../viewport/mask_peek.dart';
import 'edit_activity.dart';
import 'lightroom/lightroom_shell.dart';
import 'common/node_controls.dart';
import 'common/node_overlay.dart';
import 'snapseed/ghost_hint.dart';
import 'snapseed/snapseed_shell.dart';

/// The editor body shared by the app: one [ImageCanvas] over one recipe.
///
/// * **Gestures** (the Snapseed "Ghost UI") renders the photo **edge-to-edge**
///   with the tool HUD floating above it — the canvas owns all touch (1-finger
///   edits, 2-finger zoom/pan).
/// * **Lightroom** renders the canvas above a scrollable tool panel.
///
/// Switching shells never touches the canvas or the recipe (ADR 0008).
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, this.imageBytes, this.topHud});

  final Uint8List? imageBytes;

  /// Floating action row rendered over the top of the image (the gesture
  /// shell's "top gradient HUD"). Null in the Lightroom shell, whose chrome
  /// lives in the app bar and panel instead.
  final Widget? topHud;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _showHistogram = false;
  bool _histogramOpen = false;
  bool _panelCollapsed = false;
  GradeTool _active = GradeTool.exposure;
  ToolCategory _category = ToolCategory.light;
  late final GestureInterpreter _fsm;
  final HapticGradientPacer _gradient = HapticGradientPacer();
  final Stopwatch _gestureSw = Stopwatch()..start();

  @override
  void initState() {
    super.initState();
    _fsm = GestureInterpreter(
      tools: gestureCategories[_category]!,
      onToolChanged: (tool) {
        HapticFeedback.selectionClick();
        _gradient.reset();
        _gestureSw
          ..reset()
          ..start();
        if (mounted) setState(() => _active = tool);
      },
      onValueChanged: (tool, delta) {
        final parameter = snapseedToolParameters[tool]!.first;
        final spec = specOf(parameter);
        // Detail tools auto-peek their mask while scrubbing (#27); the canvas
        // clears it when the finger lifts (scale end).
        if (maskPeekParameters.contains(parameter)) {
          ref.read(maskPeekProvider.notifier).set(true);
        }
        final previous = valueOf(ref.read(recipeControllerProvider).recipe, parameter);
        ref.read(recipeControllerProvider.notifier).applyDelta(parameter, delta);
        final next = clampParameter(parameter, previous + delta * spec.scale);
        fireHaptic(hapticFor(previous, next, spec.min, spec.max));
        final elapsed = _gestureSw.elapsed;
        _gestureSw.reset();
        if (_gradient.tick(elapsed, value: next, min: spec.min, max: spec.max)) {
          HapticFeedback.selectionClick();
        }
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

  /// The photo, wrapped so that touching it starts/ends Active Mode (the
  /// chrome fades while the pointer is down).
  Widget _canvas({GestureInterpreter? interpreter}) {
    return Listener(
      behavior: HitTestBehavior.deferToChild,
      onPointerDown: (_) => ref.read(editActivityProvider.notifier).begin(),
      onPointerUp: (_) => ref.read(editActivityProvider.notifier).end(),
      onPointerCancel: (_) => ref.read(editActivityProvider.notifier).end(),
      child: ImageCanvas(
        imageBytes: widget.imageBytes,
        editInterpreter: interpreter,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kind = ref.watch(shellPreferenceProvider);
    final active = ref.watch(editActivityProvider);
    final nodeMode = ref.watch(nodeEditorProvider.select((s) => s.enabled));
    final scheme = Theme.of(context).colorScheme;
    // Only rebuild when the histogram's *presence* changes (not on every bake).
    final hasHistogram = ref.watch(
      histogramProvider.select((h) => h != null),
    );

    final overlays = <Widget>[
      _CompareHint(),
      _HistogramToggle(
        enabled: hasHistogram,
        selected: _showHistogram,
        onPressed: () => setState(() => _showHistogram = !_showHistogram),
      ),
    ];

    if (kind == AppShellKind.snapseed) {
      final hintSeen = ref.watch(gestureHintSeenProvider);
      return ColoredBox(
        color: scheme.surface,
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: hintSeen
              ? null
              : (_) => ref
                    .read(gestureHintSeenProvider.notifier)
                    .markGestureHintSeen(),
          child: Stack(
            children: [
              Positioned.fill(child: _canvas(interpreter: _fsm)),
              // Selective editing (issue #25): the node layer sits above the
              // canvas and absorbs every pointer until Done is tapped.
              if (nodeMode) const Positioned.fill(child: NodeOverlay()),
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
              if (widget.topHud != null)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _Fade(
                    active: active,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.5),
                            Colors.black.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Insets.xs,
                            vertical: Insets.xs,
                          ),
                          child: widget.topHud,
                        ),
                      ),
                    ),
                  ),
                ),
              if (_showHistogram && hasHistogram)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: _Fade(
                    active: active,
                    child: const _HistogramOverlay(),
                  ),
                ),
              if (!hintSeen) const Positioned.fill(child: GhostHint()),
              // The bottom-corner affordances make room for the node adjust
              // bar while node mode is active.
              if (!nodeMode)
                Positioned(
                  left: Insets.sm,
                  bottom: Insets.sm,
                  child: _Fade(
                    active: active,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SelectiveToggle(),
                        const SizedBox(height: Insets.xs),
                        overlays[0],
                      ],
                    ),
                  ),
                ),
              if (!nodeMode)
                Positioned(
                  right: Insets.sm,
                  bottom: Insets.sm,
                  child: _Fade(active: active, child: overlays[1]),
                ),
              if (nodeMode)
                Positioned(
                  left: Insets.sm,
                  right: Insets.sm,
                  bottom: 0,
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: Insets.lg),
                      child: const NodeControls(),
                    ),
                  ),
                ),
            ],
          ),
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
                Positioned.fill(child: _canvas()),
                // Selective editing (issue #25) over the photo, with the
                // adjust bar floating at its bottom edge.
                if (nodeMode) const Positioned.fill(child: NodeOverlay()),
                if (nodeMode)
                  Positioned(
                    left: Insets.sm,
                    right: Insets.sm,
                    bottom: Insets.sm,
                    child: const NodeControls(),
                  ),
                if (!nodeMode)
                  Positioned(
                    left: Insets.sm,
                    bottom: Insets.sm,
                    child: _Fade(active: active, child: overlays[0]),
                  ),
              ],
            ),
          ),
          // The histogram lives in a pull-up drawer nested at the top of the
          // bottom panel (issue #28) — it never steals canvas space.
          if (!_panelCollapsed && hasHistogram)
            _HistogramDrawer(
              open: _histogramOpen,
              setOpen: (v) => setState(() => _histogramOpen = v),
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

/// Fades a piece of chrome out (and stops hit-testing it) while the user is
/// actively editing.
class _Fade extends StatelessWidget {
  const _Fade({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: active ? 0 : 1,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: IgnorePointer(ignoring: active, child: child),
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

/// The histogram as a pull-up drawer nested at the top of the bottom panel
/// (issue #28): tap the handle — or swipe it up/down — to reveal/hide it, so
/// it never steals canvas space.
class _HistogramDrawer extends StatelessWidget {
  const _HistogramDrawer({required this.open, required this.setOpen});

  final bool open;
  final ValueChanged<bool> setOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            key: const Key('histogram-drawer-handle'),
            onTap: () => setOpen(!open),
            onVerticalDragUpdate: (d) {
              final dy = d.primaryDelta ?? 0;
              if (!open && dy < -6) {
                setOpen(true);
              } else if (open && dy > 6) {
                setOpen(false);
              }
            },
            child: SizedBox(
              height: 30,
              child: Row(
                children: [
                  const SizedBox(width: Insets.sm),
                  const Icon(Icons.bar_chart, size: 16),
                  const SizedBox(width: Insets.xs),
                  Text(
                    'Histogram',
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    open ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: Insets.sm),
                ],
              ),
            ),
          ),
          ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: open
                  ? SizedBox(
                      height: 96,
                      width: double.infinity,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          Insets.md,
                          0,
                          Insets.md,
                          Insets.xs,
                        ),
                        child: const InteractiveHistogram(height: 90),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
          Divider(height: 1, color: scheme.outlineVariant),
        ],
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

/// Entry point for node-based selective editing (issue #25) in the gesture
/// shell: drops radial control points on the photo. Steps aside for the
/// node adjust bar while node mode is active.
class _SelectiveToggle extends ConsumerWidget {
  const _SelectiveToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
      borderRadius: Radii.smAll,
      child: InkWell(
        key: const Key('selective-toggle'),
        borderRadius: Radii.smAll,
        onTap: () => ref.read(nodeEditorProvider.notifier).enable(),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.sm,
            vertical: Insets.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_location_alt,
                size: 14,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: Insets.xs),
              Text(
                'Selective',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
