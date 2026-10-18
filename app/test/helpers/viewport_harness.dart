import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sets up a deterministic test viewport with the given logical [size] (at
/// devicePixelRatio 1) and platform text scale, resetting on teardown.
void setViewport(WidgetTester tester, Size size, double textScale) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}
