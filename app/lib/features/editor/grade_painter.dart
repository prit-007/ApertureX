import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

/// Paints the full-screen image through the grading [ui.FragmentShader].
///
/// Uniform contract (must match `shaders/grade.frag`):
///   floats 0,1 = surface size; 2 = exposure; 3 = contrast; 4 = saturation;
///   sampler 0 = image texture.
class GradePainter extends CustomPainter {
  GradePainter({
    required this.shader,
    required this.texture,
    required this.exposure,
    required this.contrast,
    required this.saturation,
  });

  final ui.FragmentShader shader;
  final ui.Image texture;
  final double exposure;
  final double contrast;
  final double saturation;

  @override
  void paint(Canvas canvas, Size size) {
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, exposure)
      ..setFloat(3, contrast)
      ..setFloat(4, saturation)
      ..setImageSampler(0, texture);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(GradePainter old) =>
      old.exposure != exposure ||
      old.contrast != contrast ||
      old.saturation != saturation ||
      old.texture != texture ||
      old.shader != shader;
}
