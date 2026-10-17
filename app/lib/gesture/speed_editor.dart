import 'dart:ui';

/// Speed editor macro actions triggered by three-finger gestures.
enum SpeedMacroAction {
  copy,
  paste,
  nextPhoto,
  previousPhoto,
}

/// Pure Dart multi-touch tracker for three-finger Speed Editor gestures.
class SpeedEditorTracker {
  final Map<int, Offset> _pointers = <int, Offset>{};
  Offset? _initialFocal;
  bool _triggered = false;

  /// Travel thresholds in logical pixels.
  static const double verticalThreshold = 60.0;
  static const double horizontalThreshold = 80.0;

  bool get isTracking => _pointers.length == 3;

  void onPointerDown(int pointerId, Offset position) {
    _pointers[pointerId] = position;
    if (_pointers.length == 3) {
      _initialFocal = _computeFocal();
      _triggered = false;
    }
  }

  SpeedMacroAction? onPointerMove(int pointerId, Offset position) {
    _pointers[pointerId] = position;
    if (_pointers.length != 3 || _triggered || _initialFocal == null) {
      return null;
    }

    final currentFocal = _computeFocal();
    final delta = currentFocal - _initialFocal!;

    if (delta.dy.abs() >= delta.dx.abs()) {
      if (delta.dy <= -verticalThreshold) {
        _triggered = true;
        return SpeedMacroAction.copy;
      } else if (delta.dy >= verticalThreshold) {
        _triggered = true;
        return SpeedMacroAction.paste;
      }
    } else {
      if (delta.dx <= -horizontalThreshold) {
        _triggered = true;
        return SpeedMacroAction.nextPhoto;
      } else if (delta.dx >= horizontalThreshold) {
        _triggered = true;
        return SpeedMacroAction.previousPhoto;
      }
    }

    return null;
  }

  void onPointerUp(int pointerId) {
    _pointers.remove(pointerId);
    if (_pointers.isEmpty) {
      _initialFocal = null;
      _triggered = false;
    }
  }

  void onPointerCancel(int pointerId) {
    onPointerUp(pointerId);
  }

  Offset _computeFocal() {
    var sumX = 0.0;
    var sumY = 0.0;
    for (final p in _pointers.values) {
      sumX += p.dx;
      sumY += p.dy;
    }
    return Offset(sumX / _pointers.length, sumY / _pointers.length);
  }
}
