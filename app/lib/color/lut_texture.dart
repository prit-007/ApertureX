import 'dart:async';
import 'dart:ui' as ui;

import 'lut_atlas.dart';

/// Uploads a [LutAtlas] to a GPU texture for the LUT-sampling shader.
///
/// The shader samples it at texel centres and does manual trilinear
/// interpolation, so the upload's filter mode does not affect correctness.
Future<ui.Image> lutAtlasToImage(LutAtlas atlas) {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    atlas.rgba,
    atlas.width,
    atlas.height,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  return completer.future;
}
