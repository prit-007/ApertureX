import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Handles the accumulation of pressure-aware brush strokes into a mask.
/// A mask is a grayscale buffer where 0 = no effect, 1 = full effect.
class PaintBrush {
  final int width;
  final int height;

  PaintBrush({required this.width, required this.height});

  /// Paints a stroke from [start] to [end] with [pressure] (0..1).
  /// Returns the updated mask buffer.
  Uint8List paintStroke(
    Uint8List currentMask,
    Offset start,
    Offset end, {
    double pressure = 1.0,
    double radius = 20.0,
    bool isEraser = false,
  }) {
    final out = Uint8List.fromList(currentMask);
    final steps = 100; // Fixed sampling for simplicity; should be distance-based.
    
    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      final pos = Offset.lerp(start, end, t)!;
      _drawCircle(out, pos, radius, pressure, isEraser);
    }
    return out;
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
