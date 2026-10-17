import 'dart:ui' show Offset;

/// The adjustment tools available on the gesture carousel. Mirrors the
/// Lightroom panel's reach so the Ghost UI has the same arsenal.
enum GradeTool {
  exposure,
  contrast,
  highlights,
  shadows,
  whites,
  blacks,
  temperature,
  tint,
  vibrance,
  saturation,
  clarity,
  dehaze,
  vignette,
  grain,
  sharpen,
  shadowsGrade,
  midtonesGrade,
  highlightsGrade,
}

extension GradeToolExt on GradeTool {
  bool get is2D =>
      this == GradeTool.shadowsGrade ||
      this == GradeTool.midtonesGrade ||
      this == GradeTool.highlightsGrade;
}

/// Tool categories, mirroring the Lightroom sections. The gesture shell cycles
/// the *active category's* tools with a vertical swipe, so all ~12 tools stay
/// reachable without an endlessly long list.
enum ToolCategory { light, color, effects, detail }

const Map<ToolCategory, List<GradeTool>> gestureCategories = {
  ToolCategory.light: [
    GradeTool.exposure,
    GradeTool.contrast,
    GradeTool.highlights,
    GradeTool.shadows,
    GradeTool.whites,
    GradeTool.blacks,
  ],
  ToolCategory.color: [
    GradeTool.temperature,
    GradeTool.tint,
    GradeTool.vibrance,
    GradeTool.saturation,
    GradeTool.shadowsGrade,
    GradeTool.midtonesGrade,
    GradeTool.highlightsGrade,
  ],
  ToolCategory.effects: [
    GradeTool.clarity,
    GradeTool.dehaze,
    GradeTool.vignette,
    GradeTool.grain,
  ],
  ToolCategory.detail: [GradeTool.sharpen],
};

/// High-level phase of the invisible, Snapseed-style gesture model.
enum GesturePhase { idle, scanning, cycling, scrubbing }

/// The axis a gesture locked onto once it passed touch slop.
enum GestureAxis { undecided, vertical, horizontal }

/// A pure-Dart state machine that turns a single pan gesture into tool cycling
/// (vertical) and value scrubbing (horizontal), like Snapseed's invisible
/// editing model.
///
/// It has **no Flutter dependency** and is therefore exhaustively
/// unit-testable. The widget layer only forwards [onPanStart], [onPanUpdate]
/// and [onPanEnd].
///
/// Behaviour:
/// * touch-down enters [GesturePhase.scanning];
/// * a release before touch slop is a **tap** -> resets the active tool;
/// * once total travel exceeds [touchSlop] the **dominant axis locks**:
///   * vertical   -> [GesturePhase.cycling] (step to next/previous tool),
///   * horizontal -> [GesturePhase.scrubbing] (change the active value);
/// * the axis stays locked for the rest of the gesture.
class GestureInterpreter {
  GestureInterpreter({
    this.tools = GradeTool.values,
    this.touchSlop = 18.0,
    this.cycleStep = 48.0,
    this.fullSwipeValue = 600.0,
    this.edgeMargin = 44.0,
    this.onToolChanged,
    this.onValueChanged,
    this.onValue2DChanged,
    this.onReset,
    this.onPhaseChanged,
  }) : assert(tools.isNotEmpty),
       assert(touchSlop > 0),
       assert(cycleStep > 0),
       assert(fullSwipeValue > 0);

  /// Ordered carousel of tools that vertical swipes cycle through. Replaced
  /// when the active [ToolCategory] changes (see [setTools]).
  List<GradeTool> tools;

  /// Screen-space distance a drag must cover before the axis locks, in logical
  /// pixels. Mirrors `kTouchSlop` by default.
  final double touchSlop;

  /// Vertical travel (logical px) required to advance one tool.
  final double cycleStep;

  /// Horizontal travel (logical px) that maps to a full `-1..1` value change.
  final double fullSwipeValue;

  /// Inset from screen left/right within which vertical swipes still cycle tools
  /// even when a 2D trackball tool is active.
  final double edgeMargin;

  void Function(GradeTool tool)? onToolChanged;
  void Function(GradeTool tool, double delta)? onValueChanged;
  void Function(GradeTool tool, double deltaX, double deltaY)? onValue2DChanged;
  void Function(GradeTool tool)? onReset;
  void Function(GesturePhase phase)? onPhaseChanged;

  int _toolIndex = 0;
  GesturePhase _phase = GesturePhase.idle;
  GestureAxis _axis = GestureAxis.undecided;
  Offset _accumulated = Offset.zero;
  double _cycleAccumulator = 0;
  bool _isEdge = false;

  int get toolIndex => _toolIndex;
  GradeTool get tool => tools[_toolIndex];
  GesturePhase get phase => _phase;
  GestureAxis get axis => _axis;

  /// Selects [tool] directly (e.g. picked from the radial menu) so subsequent
  /// swipes scrub that tool — not the previously-active one.
  void setTool(GradeTool tool) {
    final index = tools.indexOf(tool);
    if (index < 0 || index == _toolIndex) return;
    _toolIndex = index;
    onToolChanged?.call(tool);
  }

  /// Replaces the carousel (e.g. on a category switch) and selects [select]
  /// (or the first tool).
  void setTools(List<GradeTool> tools, {GradeTool? select}) {
    assert(tools.isNotEmpty);
    this.tools = tools;
    final index = select == null ? 0 : tools.indexOf(select);
    _toolIndex = index < 0 ? 0 : index;
    onToolChanged?.call(this.tools[_toolIndex]);
  }

  void onPanStart(Offset localPosition, {double? screenWidth}) {
    _accumulated = Offset.zero;
    _cycleAccumulator = 0;
    _axis = GestureAxis.undecided;
    _isEdge = localPosition.dx < edgeMargin ||
        (screenWidth != null && screenWidth > 0 && localPosition.dx > screenWidth - edgeMargin);
    _setPhase(GesturePhase.scanning);
  }

  void onPanUpdate(Offset delta) {
    _accumulated += delta;

    switch (_phase) {
      case GesturePhase.scanning:
        if (_accumulated.distance < touchSlop) return;
        if (tool.is2D && !_isEdge) {
          // 2D Trackball: anywhere away from edges enters 2D scrubbing!
          _axis = GestureAxis.horizontal;
          _setPhase(GesturePhase.scrubbing);
        } else if (_accumulated.dx.abs() >= _accumulated.dy.abs()) {
          _axis = GestureAxis.horizontal;
          _setPhase(GesturePhase.scrubbing);
        } else {
          _axis = GestureAxis.vertical;
          _setPhase(GesturePhase.cycling);
        }
        _apply(delta);
      case GesturePhase.cycling:
        _applyVertical(delta);
      case GesturePhase.scrubbing:
        _applyHorizontal(delta);
      case GesturePhase.idle:
        break;
    }
  }

  void onPanEnd() {
    if (_phase == GesturePhase.scanning) {
      onReset?.call(tool);
    }
    _setPhase(GesturePhase.idle);
    _axis = GestureAxis.undecided;
    _accumulated = Offset.zero;
    _cycleAccumulator = 0;
    _isEdge = false;
  }

  /// Aborts the in-progress gesture **without** firing the tap-reset — used when
  /// a gesture turns into a multi-finger zoom (placing a second finger must not
  /// reset the active parameter).
  void cancel() {
    _setPhase(GesturePhase.idle);
    _axis = GestureAxis.undecided;
    _accumulated = Offset.zero;
    _cycleAccumulator = 0;
    _isEdge = false;
  }

  void _apply(Offset delta) {
    switch (_axis) {
      case GestureAxis.horizontal:
        _applyHorizontal(delta);
      case GestureAxis.vertical:
        _applyVertical(delta);
      case GestureAxis.undecided:
        break;
    }
  }

  void _applyHorizontal(Offset delta) {
    if (tool.is2D) {
      final normalizedX = delta.dx / fullSwipeValue;
      final normalizedY = -delta.dy / fullSwipeValue;
      if (normalizedX != 0 || normalizedY != 0) {
        onValue2DChanged?.call(tool, normalizedX, normalizedY);
      }
    } else {
      final normalized = delta.dx / fullSwipeValue;
      if (normalized != 0) onValueChanged?.call(tool, normalized);
    }
  }

  void _applyVertical(Offset delta) {
    _cycleAccumulator += delta.dy;
    while (_cycleAccumulator <= -cycleStep) {
      _cycleAccumulator += cycleStep;
      _stepTool(1); // swipe up -> next tool
    }
    while (_cycleAccumulator >= cycleStep) {
      _cycleAccumulator -= cycleStep;
      _stepTool(-1); // swipe down -> previous tool
    }
  }

  void _stepTool(int direction) {
    final count = tools.length;
    _toolIndex = ((_toolIndex + direction) % count + count) % count;
    onToolChanged?.call(tool);
  }

  void _setPhase(GesturePhase next) {
    if (_phase == next) return;
    _phase = next;
    onPhaseChanged?.call(next);
  }
}
