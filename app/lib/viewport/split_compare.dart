import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Orientation of the split-screen before/after comparison.
enum SplitOrientation {
  /// Side-by-side view (Left: Before, Right: After).
  sideBySide,

  /// Top-and-bottom view (Top: Before, Bottom: After).
  topBottom,
}

/// Immutable state for the split-screen Before/After toggle view.
class SplitCompareState {
  const SplitCompareState({
    this.isEnabled = false,
    this.orientation = SplitOrientation.sideBySide,
  });

  /// True when the split-screen before/after view is active.
  final bool isEnabled;

  /// Split layout direction: side-by-side or top-and-bottom.
  final SplitOrientation orientation;

  SplitCompareState copyWith({
    bool? isEnabled,
    SplitOrientation? orientation,
  }) {
    return SplitCompareState(
      isEnabled: isEnabled ?? this.isEnabled,
      orientation: orientation ?? this.orientation,
    );
  }
}

/// State notifier managing the split-screen before/after comparison.
class SplitCompare extends Notifier<SplitCompareState> {
  @override
  SplitCompareState build() => const SplitCompareState();

  /// Toggles split-screen before/after mode on or off.
  void toggle() {
    state = state.copyWith(isEnabled: !state.isEnabled);
  }

  /// Explicitly sets split-screen state.
  void setEnabled(bool enabled) {
    if (state.isEnabled == enabled) return;
    state = state.copyWith(isEnabled: enabled);
  }

  /// Toggles between side-by-side and top-and-bottom split orientations.
  void toggleOrientation() {
    state = state.copyWith(
      orientation: state.orientation == SplitOrientation.sideBySide
          ? SplitOrientation.topBottom
          : SplitOrientation.sideBySide,
    );
  }

  /// Explicitly sets the split orientation.
  void setOrientation(SplitOrientation orientation) {
    if (state.orientation == orientation) return;
    state = state.copyWith(orientation: orientation);
  }
}

final splitCompareProvider =
    NotifierProvider<SplitCompare, SplitCompareState>(SplitCompare.new);
