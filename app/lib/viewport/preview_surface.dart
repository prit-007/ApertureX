import 'package:flutter/widgets.dart';

/// Chooses the preview delivery surface (spike B / issue #54).
///
/// When Rust is writing graded frames straight into a bound platform texture
/// (zero-copy), the widget tree must actually mount that [Texture]; otherwise
/// the viewport sits on the placeholder forever because the texture path never
/// builds the shader path's LUT/base images.
class PreviewSurface extends StatelessWidget {
  const PreviewSurface({super.key, required this.textureId, required this.fallback});

  /// Bound platform texture id, or `null` for the spike-A shader/atlas path.
  final int? textureId;

  /// The spike-A render (CustomPaint through `lut.frag`).
  final WidgetBuilder fallback;

  @override
  Widget build(BuildContext context) {
    final id = textureId;
    if (id != null) return Texture(textureId: id);
    return fallback(context);
  }
}

/// Whether the viewport must show the loading/error placeholder.
///
/// The zero-copy path ([useTexture] = true) never bakes `lut`/`base` images —
/// requiring them there is what pinned the preview to the placeholder (#54).
bool previewNeedsPlaceholder({
  required bool failed,
  required bool hasProgram,
  required bool hasShader,
  required bool hasSource,
  required bool hasLut,
  required bool useTexture,
}) =>
    failed ||
    !hasProgram ||
    !hasShader ||
    !hasSource ||
    (!hasLut && !useTexture);

/// Whether the preview delivers frames through the bound platform texture.
///
/// Yields to the shader/atlas path when an imported LUT is active (the Rust
/// render doesn't carry an external atlas) or while a compare/mask-peek
/// crossfade runs — those fades are drawn by `lut.frag` (`blend`/`maskBlend`),
/// which the texture path doesn't carry.
bool useTextureDelivery({
  required int? textureId,
  required bool hasImportedLut,
  required bool gestureActive,
}) =>
    textureId != null && !hasImportedLut && !gestureActive;
