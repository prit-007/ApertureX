import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Exposure inspection modes for cinema camera monitoring.
enum ExposureAssistMode {
  /// Normal color grading output (no assist).
  off,

  /// Animated diagonal zebra stripes on overexposed and underexposed pixels.
  zebras,

  /// ARRI 16-zone IRE luminance false-color heatmap.
  falseColor,
}

/// State for real-time exposure assist inspection.
class ExposureAssistState {
  const ExposureAssistState({
    this.mode = ExposureAssistMode.off,
    this.zebraHigh = 0.98,
    this.zebraLow = 0.02,
  });

  /// The active exposure inspection mode.
  final ExposureAssistMode mode;

  /// Luminance threshold above which zebra stripes indicate highlight clipping (0.0..1.0).
  final double zebraHigh;

  /// Luminance threshold below which zebra stripes indicate shadow crush (0.0..1.0).
  final double zebraLow;

  /// Whether any inspection overlay is currently active.
  bool get isActive => mode != ExposureAssistMode.off;

  ExposureAssistState copyWith({
    ExposureAssistMode? mode,
    double? zebraHigh,
    double? zebraLow,
  }) {
    return ExposureAssistState(
      mode: mode ?? this.mode,
      zebraHigh: zebraHigh ?? this.zebraHigh,
      zebraLow: zebraLow ?? this.zebraLow,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExposureAssistState &&
          runtimeType == other.runtimeType &&
          mode == other.mode &&
          zebraHigh == other.zebraHigh &&
          zebraLow == other.zebraLow;

  @override
  int get hashCode => Object.hash(mode, zebraHigh, zebraLow);
}

/// Notifier controlling exposure assist modes and thresholds.
class ExposureAssist extends Notifier<ExposureAssistState> {
  @override
  ExposureAssistState build() => const ExposureAssistState();

  /// Sets the inspection mode directly.
  void setMode(ExposureAssistMode mode) {
    state = state.copyWith(mode: mode);
  }

  /// Cycles through: off -> zebras -> falseColor -> off.
  void cycleMode() {
    switch (state.mode) {
      case ExposureAssistMode.off:
        state = state.copyWith(mode: ExposureAssistMode.zebras);
        break;
      case ExposureAssistMode.zebras:
        state = state.copyWith(mode: ExposureAssistMode.falseColor);
        break;
      case ExposureAssistMode.falseColor:
        state = state.copyWith(mode: ExposureAssistMode.off);
        break;
    }
  }

  /// Sets custom highlight and shadow zebra thresholds.
  void setThresholds({double? high, double? low}) {
    state = state.copyWith(
      zebraHigh: high?.clamp(0.0, 1.0),
      zebraLow: low?.clamp(0.0, 1.0),
    );
  }

  /// Resets back to defaults (off, high=0.98, low=0.02).
  void reset() {
    state = const ExposureAssistState();
  }
}

/// Riverpod provider for real-time exposure assist inspection.
final exposureAssistProvider =
    NotifierProvider<ExposureAssist, ExposureAssistState>(ExposureAssist.new);
