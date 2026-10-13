import 'dart:ui' show Offset;

/// The adjustment tools available on the gesture carousel.
///
/// The seed ships only the three tools the color shader wires up (see
/// `shaders/grade.frag`); the full P2 tool set is larger.
enum GradeTool { exposure, contrast, saturation }

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
    this.onToolChanged,
    this.onValueChanged,
    this.onReset,
    this.onPhaseChanged,
  }) : assert(tools.isNotEmpty),
       assert(touchSlop > 0),
       assert(cycleStep > 0),
       assert(fullSwipeValue > 0);

  /// Ordered carousel of tools that vertical swipes cycle through.
  final List<GradeTool> tools;

  /// Screen-space distance a drag must cover before the axis locks, in logical
  /// pixels. Mirrors `kTouchSlop` by default.
  final double touchSlop;

  /// Vertical travel (logical px) required to advance one tool.
  final double cycleStep;

  /// Horizontal travel (logical px) that maps to a full `-1..1` value change.
  final double fullSwipeValue;

  void Function(GradeTool tool)? onToolChanged;
  void Function(GradeTool tool, double delta)? onValueChanged;
  void Function(GradeTool tool)? onReset;
  void Function(GesturePhase phase)? onPhaseChanged;

  int _toolIndex = 0;
  GesturePhase _phase = GesturePhase.idle;
  GestureAxis _axis = GestureAxis.undecided;
  Offset _accumulated = Offset.zero;
  double _cycleAccumulator = 0;

  int get toolIndex => _toolIndex;
  GradeTool get tool => tools[_toolIndex];
  GesturePhase get phase => _phase;
  GestureAxis get axis => _axis;

  void onPanStart(Offset localPosition) {
    _accumulated = Offset.zero;
    _cycleAccumulator = 0;
    _axis = GestureAxis.undecided;
    _setPhase(GesturePhase.scanning);
  }

  void onPanUpdate(Offset delta) {
    _accumulated += delta;

    switch (_phase) {
      case GesturePhase.scanning:
        if (_accumulated.distance < touchSlop) return;
        if (_accumulated.dx.abs() >= _accumulated.dy.abs()) {
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
    final normalized = delta.dx / fullSwipeValue;
    if (normalized != 0) onValueChanged?.call(tool, normalized);
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
