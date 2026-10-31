import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The rubylith overlay color used when visualizing an active brush mask.
enum RubyMaskColor {
  red,
  green,
  blue,
  white,
}

/// Interactive settings for the manual brush masking tool.
class BrushMaskSettings {
  const BrushMaskSettings({
    this.radius = 0.05,
    this.feather = 0.25,
    this.flow = 1.0,
    this.isEraser = false,
    this.showRubyMask = true,
    this.rubyColor = RubyMaskColor.red,
    this.rubyOpacity = 0.5,
  });

  /// Base brush radius in normalized canvas coordinates [0.005..0.3].
  final double radius;

  /// Edge softness [0.01..1.0].
  final double feather;

  /// Stroke flow / opacity multiplier [0.05..1.0].
  final double flow;

  /// True when erasing from the active mask.
  final bool isEraser;

  /// True when the semi-transparent rubylith mask overlay should be visible.
  final bool showRubyMask;

  /// Overlay tint color.
  final RubyMaskColor rubyColor;

  /// Overlay opacity [0.0..1.0].
  final double rubyOpacity;

  BrushMaskSettings copyWith({
    double? radius,
    double? feather,
    double? flow,
    bool? isEraser,
    bool? showRubyMask,
    RubyMaskColor? rubyColor,
    double? rubyOpacity,
  }) => BrushMaskSettings(
    radius: radius ?? this.radius,
    feather: feather ?? this.feather,
    flow: flow ?? this.flow,
    isEraser: isEraser ?? this.isEraser,
    showRubyMask: showRubyMask ?? this.showRubyMask,
    rubyColor: rubyColor ?? this.rubyColor,
    rubyOpacity: rubyOpacity ?? this.rubyOpacity,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrushMaskSettings &&
          other.radius == radius &&
          other.feather == feather &&
          other.flow == flow &&
          other.isEraser == isEraser &&
          other.showRubyMask == showRubyMask &&
          other.rubyColor == rubyColor &&
          other.rubyOpacity == rubyOpacity;

  @override
  int get hashCode => Object.hash(
    radius,
    feather,
    flow,
    isEraser,
    showRubyMask,
    rubyColor,
    rubyOpacity,
  );
}

class BrushMaskNotifier extends Notifier<BrushMaskSettings> {
  @override
  BrushMaskSettings build() => const BrushMaskSettings();

  void setRadius(double value) {
    state = state.copyWith(radius: value.clamp(0.005, 0.3));
  }

  void setFeather(double value) {
    state = state.copyWith(feather: value.clamp(0.01, 1.0));
  }

  void setFlow(double value) {
    state = state.copyWith(flow: value.clamp(0.05, 1.0));
  }

  void setEraser(bool value) {
    state = state.copyWith(isEraser: value);
  }

  void toggleEraser() {
    state = state.copyWith(isEraser: !state.isEraser);
  }

  void toggleRubyMask() {
    state = state.copyWith(showRubyMask: !state.showRubyMask);
  }

  void setRubyColor(RubyMaskColor color) {
    state = state.copyWith(rubyColor: color);
  }

  void setRubyOpacity(double value) {
    state = state.copyWith(rubyOpacity: value.clamp(0.0, 1.0));
  }
}

/// Global settings provider for brush masking.
final brushMaskProvider =
    NotifierProvider<BrushMaskNotifier, BrushMaskSettings>(
      BrushMaskNotifier.new,
    );
