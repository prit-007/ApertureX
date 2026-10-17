import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Orientation of the interactive comparison curtain wiper split.
enum WiperOrientation {
  /// Left-to-right curtain split (vertical divider).
  vertical,

  /// Top-to-bottom curtain split (horizontal divider).
  horizontal,
}

/// Immutable state for the interactive draggable Curtain Wiper A/B Compare (Issue #100).
class WiperCompareState {
  const WiperCompareState({
    this.isActive = false,
    this.position = 0.50,
    this.orientation = WiperOrientation.vertical,
  });

  /// True when the interactive curtain wiper comparison is active.
  final bool isActive;

  /// Normalized position along the active split axis (0.0 to 1.0, default 0.50).
  final double position;

  /// Split direction: vertical or horizontal.
  final WiperOrientation orientation;

  WiperCompareState copyWith({
    bool? isActive,
    double? position,
    WiperOrientation? orientation,
  }) {
    return WiperCompareState(
      isActive: isActive ?? this.isActive,
      position: position ?? this.position,
      orientation: orientation ?? this.orientation,
    );
  }
}

/// State notifier managing the interactive draggable curtain wiper comparison.
class WiperCompare extends Notifier<WiperCompareState> {
  @override
  WiperCompareState build() => const WiperCompareState();

  /// Toggles curtain wiper mode on/off.
  void toggle() {
    state = state.copyWith(isActive: !state.isActive);
  }

  /// Explicitly sets curtain wiper active state.
  void setActive(bool active) {
    if (state.isActive == active) return;
    state = state.copyWith(isActive: active);
  }

  /// Sets normalized wiper position (clamped to 0.0 .. 1.0).
  void setPosition(double pos) {
    final clamped = pos.clamp(0.0, 1.0);
    if ((state.position - clamped).abs() < 1e-4) return;
    state = state.copyWith(position: clamped);
  }

  /// Snaps wiper divider back to 50% (center).
  void resetPosition() {
    state = state.copyWith(position: 0.50);
  }

  /// Toggles between vertical and horizontal wiper curtain orientations.
  void toggleOrientation() {
    state = state.copyWith(
      orientation: state.orientation == WiperOrientation.vertical
          ? WiperOrientation.horizontal
          : WiperOrientation.vertical,
    );
  }
}

final wiperCompareProvider =
    NotifierProvider<WiperCompare, WiperCompareState>(WiperCompare.new);
