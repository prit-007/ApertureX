import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Resolves the destination path for a desktop save: shows the native save
/// dialog and returns the chosen absolute path, or `null` when the user
/// cancelled.
///
/// The seam carries [bytes] because `file_picker`'s save API *requires* the
/// payload up front — there is no path-only save dialog in the package — and
/// its Linux (xdg portal) and Windows implementations write those bytes
/// themselves. [saveBytesDesktop] writes again through its one testable path,
/// which is an idempotent byte-identical overwrite of what the dialog just
/// wrote: cheaper to pay twice than to special-case "the dialog already wrote
/// it" outside any test's reach.
typedef SavePathDialog =
    Future<String?> Function(Uint8List bytes, String suggestedName);

/// The real dialog: `file_picker`'s save picker. Returns `null` on cancel;
/// a non-`file` Uri (content:// on exotic backends) counts as "no path" so a
/// backend that can't be addressed as a filesystem path never reaches the
/// byte writer.
Future<String?> filePickerSavePath(Uint8List bytes, String suggestedName) async {
  final uri = await FilePicker.saveFile(
    fileName: suggestedName,
    bytes: bytes,
  );
  if (uri == null) return null;
  if (uri.scheme != 'file') return null;
  return uri.toFilePath();
}

/// Injection point for [filePickerSavePath] so widget tests (and any future
/// non-file_picker surface — a share sheet, a cloud backend) swap the dialog
/// without touching platform channels.
final savePathDialogProvider = Provider<SavePathDialog>((ref) => filePickerSavePath);

/// Resolves a destination *folder* (no bytes involved — `file_picker` does
/// have a path-only directory API, unlike the save dialog). `null` = the user
/// cancelled the picker.
typedef DirectoryPickDialog = Future<String?> Function();

/// The real folder picker for desktop batch export (#104): the batch asks
/// once, every item writes `aperturex_<id>.jpg` into the result.
Future<String?> filePickerDirectoryPath() => FilePicker.getDirectoryPath();

/// Injection point for [filePickerDirectoryPath] (batch destination tests).
final pickDirectoryProvider = Provider<DirectoryPickDialog>(
  (ref) => filePickerDirectoryPath,
);

/// `~/Pictures/ApertureX/` — the fallback container when no dialog can be
/// shown (headless, test harness, plugin missing). Windows resolves its
/// USERPROFILE root; both are created on demand.
String defaultDesktopSaveDirectory() {
  final home =
      Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
  if (home == null || home.isEmpty) {
    // No HOME at all (bare CI container): stay relative rather than writing
    // an absolute '/Pictures' the run probably can't create.
    return 'Pictures${Platform.pathSeparator}ApertureX';
  }
  return '$home${Platform.pathSeparator}Pictures${Platform.pathSeparator}ApertureX';
}

/// Saves [bytes] to a user-chosen desktop path (#104).
///
/// - dialog resolves a path → the file is written there (byte-identical) and
///   returned;
/// - dialog cancels → `null`, nothing written, no error (issue #104 contract);
/// - dialog unavailable (`MissingPluginException` / `UnimplementedError`) →
///   write into [defaultDirectory] ?? `~/Pictures/ApertureX/`, created on
///   demand, so a headless run still exports.
///
/// [dialog] defaults to [filePickerSavePath]; tests inject a seam function.
Future<File?> saveBytesDesktop(
  Uint8List bytes, {
  required String suggestedName,
  String? defaultDirectory,
  SavePathDialog? dialog,
}) async {
  String? path;
  var dialogUnavailable = false;
  try {
    path = await (dialog ?? filePickerSavePath)(bytes, suggestedName);
  } on MissingPluginException {
    dialogUnavailable = true;
  } on UnimplementedError {
    dialogUnavailable = true;
  }

  if (path == null) {
    // A cancel must abort even when a fallback directory is available —
    // writing somewhere the user didn't confirm breaks the cancel contract.
    if (!dialogUnavailable) return null;
    final dirPath = defaultDirectory ?? defaultDesktopSaveDirectory();
    await Directory(dirPath).create(recursive: true);
    path = '$dirPath${Platform.pathSeparator}$suggestedName';
  }

  final file = File(path);
  // The dialog's own parent directory exists (it was just picked); the
  // fallback's was created above — so a plain write is always safe.
  await file.writeAsBytes(bytes, flush: true);
  return file;
}
