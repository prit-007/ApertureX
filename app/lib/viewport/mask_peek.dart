import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../edit/parameter.dart';

/// Parameters whose adjustment auto-peeks the mask view (issue #27): while one
/// of these is being dragged the preview crossfades to a high-contrast
/// edge/detail view so the user sees exactly what is being sharpened or
/// denoised, then crossfades back on release.
const Set<Parameter> maskPeekParameters = {
  Parameter.sharpen,
  Parameter.sharpenRadius,
  Parameter.sharpenDetail,
  Parameter.sharpenMasking,
  Parameter.denoiseLuma,
  Parameter.denoiseChroma,
  Parameter.clarity,
  Parameter.texture,
  Parameter.dehaze,
};

/// True while the mask peek should be shown; the canvas crossfades the shader
/// toward it and back.
class MaskPeek extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) {
    if (state == value) return;
    state = value;
  }
}

final maskPeekProvider = NotifierProvider<MaskPeek, bool>(MaskPeek.new);

/// True when "Stylus-only mode" is active — touch input is routed to zoom/pan
/// while only the stylus drives painting/eraser mask strokes.
class StylusOnlyMode extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) {
    if (state == value) return;
    state = value;
  }
}

final stylusOnlyModeProvider = NotifierProvider<StylusOnlyMode, bool>(StylusOnlyMode.new);
