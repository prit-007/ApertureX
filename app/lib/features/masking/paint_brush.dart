import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Handles the accumulation of pressure-aware brush strokes into a mask.
/// A mask is a grayscale buffer where 0 = no effect, 1 = full effect.
class PaintBrush {

  PaintBrush({required this.width, required this.height});
  final int width;
  final int height;

  /// Paints a stroke from [start] to [end] with [pressure] (0..1).
  /// Returns the updated mask buffer.
  ///
  /// Sampling is distance-based (one stamp per quarter of the dynamic
  /// radius), the radius follows an exponential pressure curve, and stamp
  /// positions ride a Catmull-Rom spline through [previous]/[start]/
  /// [end]/[next] so fast strokes stay smooth. Missing neighbours are
  /// linearly extrapolated, which degenerates the spline to a straight line.
  Uint8List paintStroke(
    Uint8List currentMask,
    Offset start,
    Offset end, {
    double pressure = 1.0,
    double radius = 20.0,
    bool isEraser = false,
    Offset? previous,
    Offset? next,
  }) {
    final out = Uint8List.fromList(currentMask);
    // Gamma 1.5: light touches stay delicate, heavy ones fill faster.
    final dynamicRadius = radius * math.pow(pressure, 1.5);
    if (dynamicRadius <= 0.5) return out; // too small to mark a pixel

    final distance = (end - start).distance;
    final steps = math.max(1, (distance / (dynamicRadius * 0.25)).ceil());

    final p0 = previous ?? (start * 2 - end);
    final p3 = next ?? (end * 2 - start);
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final pos = _catmullRom(p0, start, end, p3, t);
      _drawCircle(out, pos, dynamicRadius, pressure, isEraser);
    }
    return out;
  }

  /// Catmull-Rom through (p1, p2) with p0/p3 shaping the tangents.
  static Offset _catmullRom(Offset p0, Offset p1, Offset p2, Offset p3, double t) {
    double component(double a, double b, double c, double d) {
      final t2 = t * t;
      final t3 = t2 * t;
      return 0.5 *
          ((2 * b) +
              (-a + c) * t +
              (2 * a - 5 * b + 4 * c - d) * t2 +
              (-a + 3 * b - 3 * c + d) * t3);
    }

    return Offset(
      component(p0.dx, p1.dx, p2.dx, p3.dx),
      component(p0.dy, p1.dy, p2.dy, p3.dy),
    );
  }

  void _drawCircle(Uint8List out, Offset center, double radius, double pressure, bool isEraser) {
    final r2 = radius * radius;
    final x0 = (center.dx - radius).clamp(0, width.toDouble()).toInt();
    final x1 = (center.dx + radius).clamp(0, width.toDouble()).toInt();
    final y0 = (center.dy - radius).clamp(0, height.toDouble()).toInt();
    final y1 = (center.dy + radius).clamp(0, height.toDouble()).toInt();

    for (int y = y0; y < y1; y++) {
      for (int x = x0; x < x1; x++) {
        final dx = x - center.dx;
        final dy = y - center.dy;
        final dist2 = dx * dx + dy * dy;
        if (dist2 < r2) {
          final dist = math.sqrt(dist2);
          final falloff = 1.0 - (dist / radius);
          final influence = falloff * pressure;
          final idx = y * width + x;
          
          if (isEraser) {
            out[idx] = (out[idx] - (influence * 255)).clamp(0, 255).toInt();
          } else {
            out[idx] = (out[idx] + (influence * 255)).clamp(0, 255).toInt();
          }
        }
      }
    }
  }
}
