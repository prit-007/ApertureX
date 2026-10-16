import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../core/log/activity_log.dart';
import '../core/log/log_providers.dart';
import 'recipe.dart';
import 'xmp_writer.dart';

/// The `.xmp` sidecar for an exported photo (#77).
///
/// Naming follows Adobe's documented convention — "the same base name and an
/// .xmp extension" (`IMG_1234.NEF` → `IMG_1234.xmp`) — so Lightroom,
/// Capture One and darktable pick the sidecar up next to the file it
/// describes. Path-hostile characters (possible in platform asset ids) are
/// sanitised because the sidecar must always be a single legal file name.
class XmpSidecar {
  const XmpSidecar._();

  static const String extension = '.xmp';

  static final RegExp _illegal = RegExp(r'[\\/:*?"<>|]');

  /// Sidecar file name for an image called [imageName].
  static String fileNameFor(String imageName) {
    final safe = imageName.replaceAll(_illegal, '_');
    final dot = safe.lastIndexOf('.');
    final base = dot <= 0 ? safe : safe.substring(0, dot);
    return '$base$extension';
  }
}

/// Where an export's sidecar goes. Abstract so tests (and future surfaces —
/// share sheets, SAF folders) can swap the destination.
abstract class XmpSidecarSink {
  /// Writes [recipe] as an `.xmp` file associated with [imageName].
  Future<void> write(String imageName, EditRecipe recipe);
}

/// Writes `<base>.xmp` files into the directory [resolveDir] produces,
/// creating it on first use. The directory is resolved lazily so the sink can
/// be constructed before `path_provider` is callable (tests inject a temp
/// directory; production resolves the app documents folder on first write).
class DirectoryXmpSidecarSink implements XmpSidecarSink {
  const DirectoryXmpSidecarSink(this.resolveDir);

  final Future<Directory> Function() resolveDir;

  @override
  Future<void> write(String imageName, EditRecipe recipe) async {
    final dir = await resolveDir();
    await dir.create(recursive: true);
    final file = File('${dir.path}/${XmpSidecar.fileNameFor(imageName)}');
    await file.writeAsString(writeXmp(recipe), flush: true);
  }
}

/// Best-effort sidecar emission for a finished export: the rendered photo has
/// already reached the gallery, so a sidecar failure is recorded in the
/// activity log instead of failing the export (#77 — the photo is the
/// deliverable; the sidecar rides along).
Future<void> emitXmpSidecar(
  XmpSidecarSink? sink,
  String imageName,
  EditRecipe recipe,
) async {
  if (sink == null) return;
  try {
    await sink.write(imageName, recipe);
  } catch (e, stack) {
    axLog(
      LogDomain.export,
      'XMP sidecar write failed for $imageName',
      level: LogLevel.error,
      error: '$e',
      stack: '$stack',
    );
  }
}

/// Sidecars for JPEG/RAW exports land in `<app documents>/exports/`, co-named
/// with the image they describe (`aperturex_<id>.xmp` next to
/// `aperturex_<id>.jpg` in the gallery).
final exportSidecarSinkProvider = Provider<XmpSidecarSink>((ref) {
  return DirectoryXmpSidecarSink(() async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory('${docs.path}/exports');
  });
});
