import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Live geometry warp (issues #34/#36): perspective, skew, and straighten are
/// applied on the GPU through a single [Matrix4] during editing. Rust bakes
/// the same parameters into pixels only at export.
Matrix4 calculateLiveGeometry({
  required double straightenAngle, // degrees
  required double perspectiveX, // -1..1
  required double perspectiveY,
  required double skewX,
  required double skewY,
}) {
  final m = Matrix4.identity();
  if (straightenAngle == 0 &&
      perspectiveX == 0 &&
      perspectiveY == 0 &&
      skewX == 0 &&
      skewY == 0) {
    return m;
  }
  // Homogeneous w-row: the divide that produces the keystone.
  m.setEntry(3, 2, 0.001);
  m.rotateY(perspectiveX * (math.pi / 4)); // ±45° max
  m.rotateX(perspectiveY * (math.pi / 4));
  final shear = Matrix4.identity()
    ..setEntry(0, 1, skewX)
    ..setEntry(1, 0, skewY);
  m.multiply(shear);
  if (straightenAngle != 0) {
    m.rotateZ(straightenAngle * math.pi / 180);
  }
  return m;
}

/// Scale that hides the empty corners a rotation pulls into frame, so the
/// rotated image still fills its original bounds.
double calculateAutoCropScale(double angleRad, double width, double height) {
  if (angleRad == 0 || width <= 0 || height <= 0) return 1;
  final a = angleRad.abs();
  final sinA = math.sin(a);
  final cosA = math.cos(a);
  final aspect = width / height;
  final scaleX = cosA + (1 / aspect) * sinA;
  final scaleY = cosA + aspect * sinA;
  return math.max(scaleX, scaleY);
}
