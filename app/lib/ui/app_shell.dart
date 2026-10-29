import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show ImageFilter;

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../color/histogram_view.dart';
import '../color/interactive_histogram.dart';
import '../core/haptics.dart';
import '../core/theme/design_tokens.dart';
import '../edit/parameter.dart';
import '../edit/active_image.dart';
import '../edit/node_editor.dart';
import '../edit/recipe_controller.dart';
import '../edit/recipe_mapping.dart';
import '../edit/settings_clipboard.dart';
import '../gesture/gesture_interpreter.dart';
import '../gesture/speed_editor.dart';
import '../gesture/zone_mask.dart';
import 'snapseed/macro_action_hud.dart';
import '../settings/shell_preference.dart';
import '../settings/app_settings.dart';
import '../settings/onboarding.dart';
import '../viewport/compare_hold.dart';
import '../viewport/wiper_compare.dart';
import '../viewport/exposure_assist.dart';
import '../viewport/image_canvas.dart';
import '../viewport/mask_peek.dart';
import 'edit_activity.dart';
import 'lightroom/lightroom_shell.dart';
import 'common/brush_toolbar.dart';
import 'common/mask_controls.dart';
import 'common/node_controls.dart';
import 'common/node_overlay.dart';
import 'common/retouch_canvas_overlay.dart';
import 'common/retouch_toolbar.dart';
import 'snapseed/ghost_hint.dart';
import 'snapseed/snapseed_shell.dart';
import '../core/theme/window_size_class.dart';

/// The editor body shared by the app: one [ImageCanvas] over one recipe.
///
/// * **Gestures** (the Snapseed "Ghost UI") renders the photo **edge-to-edge**
///   with the tool HUD floating above it — the canvas owns all touch (1-finger
///   edits, 2-finger zoom/pan).
/// * **Lightroom** renders the canvas above a scrollable tool panel.
///
/// Switching shells never touches the canvas or the recipe (ADR 0008).
class AppShell extends ConsumerStatefulWidget {
  const AppShell({
    super.key,
    this.imageBytes,
    this.heroTag,
    this.topHud,
    this.onNextPhoto,
    this.onPreviousPhoto,
  });

  final Uint8List? imageBytes;

  /// Optional hero tag shared with the gallery thumbnail for the fly-in
  /// transition into the editor canvas.
  final String? heroTag;

  /// Floating action row rendered over the top of the image (the gesture
  /// shell's "top gradient HUD"). Null in the Lightroom shell, whose chrome
  /// lives in the app bar and panel instead.
  final Widget? topHud;

  /// Optional callbacks for Three-Finger Speed Editor navigation.
  final VoidCallback? onNextPhoto;
  final VoidCallback? onPreviousPhoto;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _showHistogram = false;
  bool _histogramOpen = false;
  bool _panelCollapsed = false;
  _SheetSnap _sheetSnap = _SheetSnap.half;
  GradeTool _active = GradeTool.exposure;
  ToolCategory _category = ToolCategory.light;
  GesturePhase _gesturePhase = GesturePhase.idle;
  late final GestureInterpreter _fsm;
  final HapticGradientPacer _gradient = HapticGradientPacer();
  final Stopwatch _gestureSw = Stopwatch()..start();
  final SpeedEditorTracker _speedTracker = SpeedEditorTracker();

  void _handleMacroAction(SpeedMacroAction action) {
    switch (action) {
      case SpeedMacroAction.copy:
        final recipe = ref.read(recipeControllerProvider).recipe;
        ref.read(settingsClipboardProvider.notifier).copy(recipe);
        HapticFeedback.mediumImpact();
        ref.read(macroHudProvider.notifier).show('Recipe Copied', Icons.copy);
        break;
      case SpeedMacroAction.paste:
        final recipe = ref.read(settingsClipboardProvider);
        if (recipe != null) {
          ref
              .read(recipeControllerProvider.notifier)
              .loadRecipe(recipe, label: 'Pasted');
          HapticFeedback.mediumImpact();
          ref
              .read(macroHudProvider.notifier)
              .show('Recipe Pasted', Icons.paste);
        }
        break;
      case SpeedMacroAction.nextPhoto:
        if (widget.onNextPhoto != null) {
          widget.onNextPhoto!();
          HapticFeedback.lightImpact();
          ref
              .read(macroHudProvider.notifier)
              .show('Next Photo', Icons.skip_next);
        }
        break;
      case SpeedMacroAction.previousPhoto:
        if (widget.onPreviousPhoto != null) {
          widget.onPreviousPhoto!();
          HapticFeedback.lightImpact();
          ref
              .read(macroHudProvider.notifier)
              .show('Previous Photo', Icons.skip_previous);
        }
        break;
    }
  }

  @override
  void initState() {
    super.initState();
    _fsm = GestureInterpreter(
      tools: gestureCategories[_category]!,
      onPhaseChanged: (phase) {
        if (mounted) setState(() => _gesturePhase = phase);
      },
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

        // Haptic Zone Masking: if a luminosity zone mask is locked,
        // target that specific layer's parameters!
        final zoneMask = ref.read(zoneMaskProvider);
        final lockedIdx = zoneMask.lockedLayerIndex;
        final layers = ref.read(recipeControllerProvider).recipe.layers;
        if (lockedIdx != null && lockedIdx < layers.length) {
          final layer = layers[lockedIdx];
          final updatedLayer = switch (parameter) {
            Parameter.exposure => layer.copyWith(
              exposure: (layer.exposure + delta * spec.scale).clamp(-4.0, 4.0),
            ),
            Parameter.contrast => layer.copyWith(
              contrast: (layer.contrast + delta * spec.scale).clamp(-1.0, 1.0),
            ),
            Parameter.highlights => layer.copyWith(
              highlights: (layer.highlights + delta * spec.scale).clamp(
                -1.0,
                1.0,
              ),
            ),
            Parameter.shadows => layer.copyWith(
              shadows: (layer.shadows + delta * spec.scale).clamp(-1.0, 1.0),
            ),
            Parameter.saturation => layer.copyWith(
              saturation: (layer.saturation + delta * spec.scale).clamp(
                -1.0,
                1.0,
              ),
            ),
            Parameter.temperature => layer.copyWith(
              temperature: (layer.temperature + delta * spec.scale).clamp(
                -1.0,
                1.0,
              ),
            ),
            Parameter.tint => layer.copyWith(
              tint: (layer.tint + delta * spec.scale).clamp(-1.0, 1.0),
            ),
            _ => null,
          };
          if (updatedLayer != null) {
            ref
                .read(recipeControllerProvider.notifier)
                .updateLayerAt(lockedIdx, updatedLayer);
            final nextVal = switch (parameter) {
              Parameter.exposure => updatedLayer.exposure,
              Parameter.contrast => updatedLayer.contrast,
              Parameter.highlights => updatedLayer.highlights,
              Parameter.shadows => updatedLayer.shadows,
              Parameter.saturation => updatedLayer.saturation,
              Parameter.temperature => updatedLayer.temperature,
              Parameter.tint => updatedLayer.tint,
              _ => 0.0,
            };
            fireHaptic(hapticFor(0.0, nextVal, spec.min, spec.max));
            return;
          }
        }

        final previous = valueOf(
          ref.read(recipeControllerProvider).recipe,
          parameter,
        );
        ref
            .read(recipeControllerProvider.notifier)
            .applyDelta(parameter, delta);
        final next = clampParameter(parameter, previous + delta * spec.scale);
        fireHaptic(hapticFor(previous, next, spec.min, spec.max));
        final elapsed = _gestureSw.elapsed;
        _gestureSw.reset();
        if (_gradient.tick(
          elapsed,
          value: next,
          min: spec.min,
          max: spec.max,
        )) {
          HapticFeedback.selectionClick();
        }
      },
      onValue2DChanged: (tool, deltaX, deltaY) {
        final zone = switch (tool) {
          GradeTool.shadowsGrade => GradeWheelZone.shadows,
          GradeTool.midtonesGrade => GradeWheelZone.midtones,
          GradeTool.highlightsGrade => GradeWheelZone.highlights,
          _ => null,
        };
        if (zone == null) return;
        final recipe = ref.read(recipeControllerProvider).recipe;
        final (prevHue, prevSat) = switch (zone) {
          GradeWheelZone.shadows => (
            recipe.gradeShadowHue,
            recipe.gradeShadowSat,
          ),
          GradeWheelZone.midtones => (recipe.gradeMidHue, recipe.gradeMidSat),
          GradeWheelZone.highlights => (
            recipe.gradeHighlightHue,
            recipe.gradeHighlightSat,
          ),
        };
        // Hue delta in degrees (full swipe = 360°), sat delta in 0..1 (full swipe = 1.0)
        final hueDelta = deltaY * 360.0;
        final satDelta = deltaX * 1.0;
        ref
            .read(recipeControllerProvider.notifier)
            .applyGradeWheel2DDelta(
              zone,
              hueDelta: hueDelta,
              satDelta: satDelta,
            );
        final nextRecipe = ref.read(recipeControllerProvider).recipe;
        final (nextHue, nextSat) = switch (zone) {
          GradeWheelZone.shadows => (
            nextRecipe.gradeShadowHue,
            nextRecipe.gradeShadowSat,
          ),
          GradeWheelZone.midtones => (
            nextRecipe.gradeMidHue,
            nextRecipe.gradeMidSat,
          ),
          GradeWheelZone.highlights => (
            nextRecipe.gradeHighlightHue,
            nextRecipe.gradeHighlightSat,
          ),
        };
        // Haptics: neutral crossing (sat=0) and limits (sat=1)
        fireHaptic(hapticFor(prevSat, nextSat, 0.0, 1.0));
        // Hue primary detent tick (every 60 degrees: 0, 60, 120, 180, 240, 300)
        final prevSector = (prevHue / 60.0).floor();
        final nextSector = (nextHue / 60.0).floor();
        if (prevSector != nextSector) {
          HapticFeedback.selectionClick();
        }
        final elapsed = _gestureSw.elapsed;
        _gestureSw.reset();
        if (_gradient.tick(elapsed, value: nextSat, min: 0.0, max: 1.0)) {
          HapticFeedback.selectionClick();
        }
      },
      onReset: (tool) {
        if (tool == GradeTool.shadowsGrade) {
          ref
              .read(recipeControllerProvider.notifier)
              .setGradeWheel(GradeWheelZone.shadows, hue: 0, sat: 0);
        } else if (tool == GradeTool.midtonesGrade) {
          ref
              .read(recipeControllerProvider.notifier)
              .setGradeWheel(GradeWheelZone.midtones, hue: 0, sat: 0);
        } else if (tool == GradeTool.highlightsGrade) {
          ref
              .read(recipeControllerProvider.notifier)
              .setGradeWheel(GradeWheelZone.highlights, hue: 0, sat: 0);
        } else {
          ref
              .read(recipeControllerProvider.notifier)
              .reset(snapseedToolParameters[tool]!.first);
        }
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(activeImageBytesProvider.notifier).setBytes(widget.imageBytes);
      }
    });
  }

  @override
  void didUpdateWidget(AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.imageBytes != oldWidget.imageBytes) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref
              .read(activeImageBytesProvider.notifier)
              .setBytes(widget.imageBytes);
        }
      });
    }
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
      onPointerDown: (e) {
        ref.read(editActivityProvider.notifier).begin();
        _speedTracker.onPointerDown(e.pointer, e.position);
        _reportPressure(e);
      },
      onPointerMove: (e) {
        final action = _speedTracker.onPointerMove(e.pointer, e.position);
        if (action != null) {
          _handleMacroAction(action);
        }
        _reportPressure(e);
      },
      onPointerUp: (e) {
        ref.read(editActivityProvider.notifier).end();
        _speedTracker.onPointerUp(e.pointer);
      },
      onPointerCancel: (e) {
        ref.read(editActivityProvider.notifier).end();
        _speedTracker.onPointerCancel(e.pointer);
      },
      child: ImageCanvas(
        imageBytes: widget.imageBytes,
        heroTag: widget.heroTag,
        editInterpreter: interpreter,
        onTap: () {
          final activeSection = ref.read(activeSectionProvider);
          if (activeSection != RecipeSection.masking &&
              activeSection != RecipeSection.retouch) {
            HapticFeedback.selectionClick();
            setState(() {
              _sheetSnap = _sheetSnap == _SheetSnap.hidden
                  ? _SheetSnap.half
                  : _SheetSnap.hidden;
            });
          }
        },
      ),
    );
  }

  /// Reports stylus pressure to [brushPressureProvider] for dynamic brush
  /// opacity/flow preview. Touch (non-stylus) events are ignored for palm
  /// rejection (issue #35).
  void _reportPressure(PointerEvent event) {
    final isStylus = event.kind == PointerDeviceKind.stylus ||
        event.kind == PointerDeviceKind.invertedStylus;
    if (!isStylus) return;
    ref.read(brushPressureProvider.notifier).setPressure(event.pressure);
  }

  @override
  Widget build(BuildContext context) {
    final kind = ref.watch(shellPreferenceProvider);
    final glassmorphic = ref.watch(glassmorphicUiProvider);
    final active = ref.watch(editActivityProvider);
    final nodeMode = ref.watch(nodeEditorProvider.select((s) => s.enabled));
    final activeSection = ref.watch(activeSectionProvider);
    final isRetouch = activeSection == RecipeSection.retouch;
    final scheme = Theme.of(context).colorScheme;
    // Only rebuild when the histogram's *presence* changes (not on every bake).
    final hasHistogram = ref.watch(histogramProvider.select((h) => h != null));

    final overlays = <Widget>[
      const _CompareHint(),
      _HistogramToggle(
        enabled: hasHistogram,
        selected: _showHistogram,
        onPressed: () => setState(() => _showHistogram = !_showHistogram),
      ),
    ];
    Widget shell;

    if (kind == AppShellKind.snapseed) {
      final hintSeen = ref.watch(gestureHintSeenProvider);
      shell = ColoredBox(
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
              if (isRetouch)
                const Positioned.fill(child: RetouchCanvasOverlay()),
              // Selective editing (issue #25): the node layer sits above the
              // canvas and absorbs every pointer until Done is tapped.
              if (nodeMode) const Positioned.fill(child: NodeOverlay()),
              SnapseedShell(
                tool: _active,
                category: _category,
                tools: gestureCategories[_category]!,
                gesturePhase: _gesturePhase,
                onCycleCategory: _cycleCategory,
                hasHistogram: hasHistogram,
                histogramOpen: _showHistogram && hasHistogram,
                onToggleHistogram: () =>
                    setState(() => _showHistogram = !_showHistogram),
                onPickTool: (t) {
                  _fsm.setTool(t);
                  setState(() => _active = t);
                },
                onSelectCategoryAndTool: (cat, t) {
                  final tools = gestureCategories[cat]!;
                  _fsm.setTools(tools, select: t);
                  setState(() {
                    _category = cat;
                    _active = t;
                  });
                },
              ),
              if (nodeMode)
                const Positioned(
                  top: Insets.md,
                  left: Insets.sm,
                  right: Insets.sm,
                  child: SafeArea(bottom: false, child: BrushToolbar()),
                ),
              if (isRetouch)
                const Positioned(
                  top: Insets.md,
                  left: Insets.sm,
                  right: Insets.sm,
                  child: SafeArea(
                    bottom: false,
                    child: Center(child: RetouchToolbar()),
                  ),
                ),
              const Positioned(
                top: Insets.lg + 16,
                left: Insets.md,
                right: Insets.md,
                child: SafeArea(
                  bottom: false,
                  child: _AiProgressFloatingPill(),
                ),
              ),
              if (widget.topHud != null)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _Fade(
                    active: active,
                    child: ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: glassmorphic ? 16 : 0,
                          sigmaY: glassmorphic ? 16 : 0,
                        ),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: glassmorphic
                                ? scheme.surface.withValues(alpha: 0.65)
                                : null,
                            gradient: glassmorphic
                                ? null
                                : LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      scheme.onSurface.withValues(alpha: 0.5),
                                      scheme.onSurface.withValues(alpha: 0.0),
                                    ],
                                  ),
                            border: glassmorphic
                                ? Border(
                                    bottom: BorderSide(
                                      color: scheme.outlineVariant.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  )
                                : null,
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
                  ),
                ),
              if (_showHistogram && hasHistogram) ...[
                Positioned(
                  left: 0,
                  right: 0,
                  top: 56,
                  child: _Fade(
                    active: active,
                    child: const SafeArea(
                      bottom: false,
                      child: _HistogramOverlay(),
                    ),
                  ),
                ),
              ],
              if (!hintSeen) const Positioned.fill(child: GhostHint()),
              // Compare affordance floating above the bottom dock (steps aside in node mode).
              if (!nodeMode)
                Positioned(
                  left: Insets.md,
                  bottom: 68,
                  child: _Fade(
                    active: active,
                    child: SafeArea(top: false, child: overlays[0]),
                  ),
                ),
              if (nodeMode)
                const Positioned(
                  left: Insets.sm,
                  right: Insets.sm,
                  bottom: 0,
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: Insets.lg),
                      child: NodeControls(),
                    ),
                  ),
                ),
              const Positioned.fill(child: MacroActionHud()),
            ],
          ),
        ),
      );
    } else {
      // Lightroom shell: adaptive layout (issue #34)
      shell = Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final widthClass = windowSizeClassFor(
                MediaQuery.sizeOf(context).width,
              );
              final wide =
                  widthClass != WindowSizeClass.compact;
              final canvas = Stack(
                children: [
                  Positioned.fill(child: _canvas()),
                  // Retouch overlay (Lightroom heal/clone pins directly on canvas)
                  if (isRetouch)
                    const Positioned.fill(child: RetouchCanvasOverlay()),
                  // Selective editing (issue #25) over the photo, with the
                  // adjust bar floating at its bottom edge.
                  if (nodeMode) const Positioned.fill(child: NodeOverlay()),
                  if (nodeMode)
                    const Positioned(
                      top: Insets.md,
                      left: Insets.sm,
                      right: Insets.sm,
                      child: SafeArea(
                        bottom: false,
                        child: BrushToolbar(),
                      ),
                    ),
                  if (isRetouch)
                    const Positioned(
                      top: Insets.md,
                      left: Insets.sm,
                      right: Insets.sm,
                      child: SafeArea(
                        bottom: false,
                        child: Center(child: RetouchToolbar()),
                      ),
                    ),
                  const Positioned(
                    top: Insets.lg + 16,
                    left: Insets.md,
                    right: Insets.md,
                    child: SafeArea(
                      bottom: false,
                      child: _AiProgressFloatingPill(),
                    ),
                  ),
                  if (nodeMode && (wide || kind == AppShellKind.snapseed))
                    const Positioned(
                      left: Insets.sm,
                      right: Insets.sm,
                      bottom: Insets.sm,
                      child: SafeArea(top: false, child: NodeControls()),
                    ),
                  if (!nodeMode && !isRetouch)
                    Positioned(
                      left: Insets.sm,
                      bottom: Insets.sm,
                      child: _Fade(
                        active: active,
                        child: SafeArea(top: false, child: overlays[0]),
                      ),
                    ),
                ],
              );

              if (wide) {
                final sidebarWidth = (constraints.maxWidth * 0.30)
                    .clamp(240.0, 480.0)
                    .clamp(200.0, constraints.maxWidth * 0.40);
                return Material(
                  color: scheme.surface,
                  child: Row(
                    children: [
                      Expanded(child: canvas),
                      // Notch/punch-hole protection on the trailing edge.
                      SafeArea(
                        left: false,
                        right: true,
                        child: SizedBox(
                          width: sidebarWidth,
                          child: ClipRect(
                            child: BackdropFilter(
                              filter: ImageFilter.blur(
                                sigmaX: glassmorphic ? 20 : 0,
                                sigmaY: glassmorphic ? 20 : 0,
                              ),
                              child: Material(
                                color: glassmorphic
                                    ? scheme.surface.withValues(alpha: 0.75)
                                    : scheme.surface,
                                child: Column(
                                  children: [
                                    _PanelHandle(
                                      collapsed: _panelCollapsed,
                                      onToggle: () => setState(
                                        () =>
                                            _panelCollapsed = !_panelCollapsed,
                                      ),
                                    ),
                                    if (!_panelCollapsed && hasHistogram)
                                      _HistogramDrawer(
                                        open: _histogramOpen,
                                        setOpen: (v) =>
                                            setState(() => _histogramOpen = v),
                                      ),
                                    if (!_panelCollapsed)
                                      const Expanded(child: LightroomShell()),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Docked Instrument Tray layout (Lightroom Mobile parity):
              // Viewport sanctity: the photo occupies 75–80% of portrait height, completely
              // unobstructed; tool controls live in a docked, compact bottom tray in the
              // thumb reach zone.
              return Material(
                color: scheme.surface,
                child: Column(
                  children: [
                    Expanded(child: canvas),
                    _LightroomSheet(
                      availableHeight: constraints.maxHeight,
                      snap: _sheetSnap,
                      onSnap: (s) => setState(() => _sheetSnap = s),
                      hasHistogram: hasHistogram,
                      histogramOpen: _histogramOpen,
                      setHistogramOpen: (v) =>
                          setState(() => _histogramOpen = v),
                    ),
                  ],
                ),
              );
            },
          ),
          const Positioned.fill(child: MacroActionHud()),
        ],
      );
    }

    return AnimatedSwitcher(
      duration: AppMotion.standardDuration,
      switchInCurve: AppMotion.standardCurve,
      switchOutCurve: AppMotion.standardCurve,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 0.05),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: shell,
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
      duration: AppMotion.fadeDuration,
      curve: AppMotion.fadeCurve,
      child: IgnorePointer(ignoring: active, child: child),
    );
  }
}

/// The grab-handle between the image and the Lightroom panel. Tapping it
/// collapses the tools so the photo can fill the screen.
class _PanelHandle extends ConsumerWidget {
  const _PanelHandle({
    required this.collapsed,
    required this.onToggle,
    this.onDoubleTap,
  });

  final bool collapsed;
  final VoidCallback onToggle;
  final VoidCallback? onDoubleTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final glassmorphic = ref.watch(glassmorphicUiProvider);
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: glassmorphic ? 16 : 0,
          sigmaY: glassmorphic ? 16 : 0,
        ),
        child: Material(
          color: glassmorphic
              ? scheme.surface.withValues(alpha: 0.65)
              : scheme.surface,
          child: InkWell(
            onTap: onToggle,
            onDoubleTap: onDoubleTap,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      collapsed
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 14,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      collapsed ? 'Show tools' : 'Hide tools',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Snap points for the floating Lightroom sheet (issue #32), as a fraction of
/// the available height: fully hidden, a small peek, half, and near-full.
enum _SheetSnap { hidden, peek, half, full }

// Raised from {0.20, 0.24, 0.38}: at 0.24 the docked tray only fit a single
// slider between the grab bar and the tabs (bug: "bottom-sheet height, only 1
// slider visible"). Half now fits ~3 sliders; full ~6. Tap the canvas /
// grab bar still collapses the tray for the full-height photo.
// Peek raised 0.20 → 0.28 plus a hard 236px floor (see _minPeekHeight) so
// short viewports still show ~2 content rows (issue: peek sheet buries the
// Lightroom panel).
const Map<_SheetSnap, double> _sheetFractions = {
  _SheetSnap.hidden: 0.0,
  _SheetSnap.peek: 0.28,
  _SheetSnap.half: 0.36,
  _SheetSnap.full: 0.62,
};

/// Minimum peek body height: grab bar handle (~30) + panel chrome (~114) +
/// ~2 content rows. Keeps controls usable on short devices.
const double _minPeekHeight = 236.0;

/// A draggable, floating bottom sheet holding the Lightroom tools over the
/// edge-to-edge photo. Drag the grab bar to move between snap points, or tap it
/// to collapse/restore (issue #32).
class _LightroomSheet extends ConsumerStatefulWidget {
  const _LightroomSheet({
    required this.availableHeight,
    required this.snap,
    required this.onSnap,
    required this.hasHistogram,
    required this.histogramOpen,
    required this.setHistogramOpen,
  });

  final double availableHeight;
  final _SheetSnap snap;
  final ValueChanged<_SheetSnap> onSnap;
  final bool hasHistogram;
  final bool histogramOpen;
  final ValueChanged<bool> setHistogramOpen;

  @override
  ConsumerState<_LightroomSheet> createState() => _LightroomSheetState();
}

class _LightroomSheetState extends ConsumerState<_LightroomSheet> {
  /// Upward drag accumulated since the gesture started (positive = taller).
  double _dragDy = 0;
  bool _dragging = false;

  double get _height {
    var base = _sheetFractions[widget.snap]! * widget.availableHeight;
    if (widget.snap == _SheetSnap.peek && base < _minPeekHeight) {
      base = _minPeekHeight;
    }
    final raw = base + _dragDy;
    return raw.clamp(0.0, widget.availableHeight).toDouble();
  }

  void _onDragStart(DragStartDetails _) {
    _dragging = true;
    _dragDy = 0;
  }

  void _onDragUpdate(DragUpdateDetails d) {
    setState(() => _dragDy -= d.delta.dy);
  }

  void _onDragEnd(DragEndDetails d) {
    final velocity = -(d.primaryVelocity ?? 0); // up positive
    const snaps = _SheetSnap.values;
    final current = snaps.indexOf(widget.snap);
    _SheetSnap target;
    if (velocity > 600 && current < snaps.length - 1) {
      target = snaps[current + 1];
    } else if (velocity < -600 && current > 0) {
      target = snaps[current - 1];
    } else {
      final measured = _height;
      target = snaps.reduce((a, b) {
        final da = (_sheetFractions[a]! * widget.availableHeight - measured)
            .abs();
        final db = (_sheetFractions[b]! * widget.availableHeight - measured)
            .abs();
        return da <= db ? a : b;
      });
    }
    setState(() {
      _dragging = false;
      _dragDy = 0;
    });
    widget.onSnap(target);
  }

  void _toggle() => widget.onSnap(
    widget.snap == _SheetSnap.hidden ? _SheetSnap.half : _SheetSnap.hidden,
  );

  void _onDoubleTap() {
    if (widget.snap == _SheetSnap.full) {
      widget.onSnap(_SheetSnap.half);
    } else {
      widget.onSnap(_SheetSnap.full);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final glassmorphic = ref.watch(glassmorphicUiProvider);
    final contentHeight = _height;
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragStart: _onDragStart,
            onVerticalDragUpdate: _onDragUpdate,
            onVerticalDragEnd: _onDragEnd,
            child: _PanelHandle(
              collapsed: widget.snap == _SheetSnap.hidden,
              onToggle: _toggle,
              onDoubleTap: _onDoubleTap,
            ),
          ),
          AnimatedContainer(
            key: const Key('lightroom-sheet-body'),
            duration: _dragging
                ? Duration.zero
                : AppMotion.sheetDuration,
            curve: AppMotion.sheetCurve,
            height: contentHeight,
            child: contentHeight <= 0.5
                ? const SizedBox.shrink()
                : ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(Radii.md),
                    ),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: glassmorphic ? 20 : 0,
                        sigmaY: glassmorphic ? 20 : 0,
                      ),
                      child: Material(
                        color: glassmorphic
                            ? scheme.surface.withValues(alpha: 0.72)
                            : scheme.surface,
                        shape: glassmorphic
                            ? Border(
                                top: BorderSide(
                                  color: scheme.outlineVariant.withValues(
                                    alpha: 0.35,
                                  ),
                                ),
                              )
                            : null,
                        child: OverflowBox(
                          minHeight: 0,
                          maxHeight: double.infinity,
                          alignment: Alignment.topCenter,
                          child: SizedBox(
                            height: math.max(
                              contentHeight,
                              widget.histogramOpen ? 260.0 : 190.0,
                            ),
                            child: Column(
                              children: [
                                if (widget.hasHistogram)
                                  _HistogramDrawer(
                                    open: widget.histogramOpen,
                                    setOpen: widget.setHistogramOpen,
                                  ),
                                const Expanded(child: LightroomShell()),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// The histogram as a pull-up drawer nested at the top of the bottom panel
/// (issue #28): tap the handle — or swipe/flick it up/down — to reveal/hide
/// it, so it never steals canvas space.
///
/// Open/close is decided on release (issue #45): velocity first (so a fast
/// flick shorter than the displacement threshold still works), then net
/// displacement with hysteresis (close needs a slightly larger drift than
/// open); anything below both thresholds snaps back to the previous state.
class _HistogramDrawer extends ConsumerStatefulWidget {
  const _HistogramDrawer({required this.open, required this.setOpen});

  final bool open;
  final ValueChanged<bool> setOpen;

  @override
  ConsumerState<_HistogramDrawer> createState() => _HistogramDrawerState();
}

class _HistogramDrawerState extends ConsumerState<_HistogramDrawer> {
  /// Flick threshold in logical px/s (a slow drag never reaches it).
  static const double _flickVelocity = 400;

  /// Net-displacement fallback, with hysteresis: opening is a lighter
  /// gesture than closing so a jittery hold can't toggle both ways.
  /// A tester.drag(±48) delivers ~±28px after kTouchSlop (~18) is eaten,
  /// so both thresholds must sit below that.
  static const double _openOffset = 24;
  static const double _closeOffset = 28;

  double _netDy = 0;

  void _onUpdate(DragUpdateDetails d) {
    _netDy += d.primaryDelta ?? 0;
  }

  void _onEnd(DragEndDetails d) {
    final dy = d.velocity.pixelsPerSecond.dy;
    if (dy <= -_flickVelocity) {
      widget.setOpen(true);
    } else if (dy >= _flickVelocity) {
      widget.setOpen(false);
    } else if (_netDy <= -_openOffset) {
      widget.setOpen(true);
    } else if (_netDy >= _closeOffset) {
      widget.setOpen(false);
    }
    // Below both thresholds: snap back — leave state untouched.
    _netDy = 0;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final glassmorphic = ref.watch(glassmorphicUiProvider);
    return Material(
      color: glassmorphic
          ? scheme.surface.withValues(alpha: 0.70)
          : scheme.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            key: const Key('histogram-drawer-handle'),
            onTap: () => widget.setOpen(!widget.open),
            onVerticalDragUpdate: _onUpdate,
            onVerticalDragEnd: _onEnd,
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
                    widget.open
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_up,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: Insets.sm),
                ],
              ),
            ),
          ClipRect(
            child: AnimatedSize(
              duration: AppMotion.standardDuration,
              curve: AppMotion.standardCurve,
              alignment: Alignment.topCenter,
              child: widget.open
                  ? const SizedBox(
                      height: 96,
                      width: double.infinity,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          Insets.md,
                          0,
                          Insets.md,
                          Insets.xs,
                        ),
                        child: InteractiveHistogram(height: 90),
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

/// A compact, interactive affordance on the image: hold to view the
/// unedited "before".
class _CompareHint extends ConsumerWidget {
  const _CompareHint();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final wiper = ref.watch(wiperCompareProvider);
    final assist = ref.watch(exposureAssistProvider);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: scheme.onSurface.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 4),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (_) =>
                    ref.read(compareHoldProvider.notifier).hold(),
                onPointerUp: (_) =>
                    ref.read(compareHoldProvider.notifier).release(),
                onPointerCancel: (_) =>
                    ref.read(compareHoldProvider.notifier).release(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.compare, size: 14, color: scheme.primary),
                    const SizedBox(width: Insets.xs),
                    Text(
                      'Hold to compare',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 1,
                height: 12,
                color: scheme.outlineVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  ref.read(wiperCompareProvider.notifier).toggle();
                  HapticFeedback.selectionClick();
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.splitscreen,
                      size: 14,
                      color: wiper.isActive
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: Insets.xs),
                    Text(
                      'Wiper',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: wiper.isActive
                            ? FontWeight.bold
                            : FontWeight.w600,
                        color: wiper.isActive
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 1,
                height: 12,
                color: scheme.outlineVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  ref.read(exposureAssistProvider.notifier).cycleMode();
                  HapticFeedback.selectionClick();
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.wb_iridescent_outlined,
                      size: 14,
                      color: assist.isActive
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: Insets.xs),
                    Text(
                      assist.mode == ExposureAssistMode.zebras
                          ? 'Zebras'
                          : (assist.mode == ExposureAssistMode.falseColor
                                ? 'IRE'
                                : 'Assist'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: assist.isActive
                            ? FontWeight.bold
                            : FontWeight.w600,
                        color: assist.isActive
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Floating glassmorphic HUD pill displayed over the viewport when an on-device
/// AI segmentation or re-inference operation is processing (#83, #89, #96).
class _AiProgressFloatingPill extends ConsumerWidget {
  const _AiProgressFloatingPill();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isInferring = ref.watch(aiMaskInferringProvider);
    final statusMsg =
        ref.watch(aiMaskStatusMessageProvider) ??
        'Processing with on-device AI… Please wait a moment';

    return AnimatedOpacity(
      opacity: isInferring ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: IgnorePointer(
        ignoring: !isInferring,
        child: isInferring
            ? Center(
                child: Container(
                  key: const Key('ai-floating-pill'),
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          statusMsg,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}
