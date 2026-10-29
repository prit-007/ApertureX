import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

import 'file_saver.dart';

/// gal's Photos/DCIM bridge behind an interface (#104): gal declares
/// android/ios/macos/windows only — a Linux desktop has no implementation —
/// so tests inject a recording fake and fail the run if a desktop save ever
/// reaches this seam. Mobile production is a straight-through gal call.
abstract class GallerySink {
  Future<bool> hasAccess();

  Future<bool> requestAccess();

  /// Saves [bytes] under [name] — gal's contract: name without extension.
  Future<void> putImageBytes(Uint8List bytes, {required String name});

  /// Saves the file at [path] (temp-staged payloads like DNG/TIFF).
  Future<void> putImage(String path);
}

/// Production sink: the gal calls that used to sit inline in the editor.
class RealGalSink implements GallerySink {
  const RealGalSink();

  @override
  Future<bool> hasAccess() => Gal.hasAccess();

  @override
  Future<bool> requestAccess() => Gal.requestAccess();

  @override
  Future<void> putImageBytes(Uint8List bytes, {required String name}) =>
      Gal.putImageBytes(bytes, name: name);

  @override
  Future<void> putImage(String path) => Gal.putImage(path);
}

final gallerySinkProvider = Provider<GallerySink>((ref) => const RealGalSink());

/// True on Linux/Windows/macOS: #104's agreed decision is one filesystem save
/// path for *every* desktop (uniform, sidesteps gal's patchy desktop support);
/// mobile keeps gal. Tests override this instead of faking dart:io platforms.
///
/// Note this is wider than `gallery_source_factory`'s `defaultGallerySource`,
/// which keeps photo_manager for the macOS *library* — save destination and
/// library backend are independent choices.
final isDesktopPlatformProvider = Provider<bool>(
  (ref) => Platform.isLinux || Platform.isWindows || Platform.isMacOS,
);

/// Where a [PhotoSaver] save landed. A `null` result means the user cancelled
/// the desktop dialog — abort quietly, no error, nothing written (#104).
sealed class PhotoSaveOutcome {
  const PhotoSaveOutcome();
}

/// Mobile: the bytes reached the gallery via gal.
class SavedToGallery extends PhotoSaveOutcome {
  const SavedToGallery();
}

/// Desktop: the bytes were written to [file] in the user-chosen location.
class SavedToFile extends PhotoSaveOutcome {
  const SavedToFile(this.file);

  final File file;
}

/// Routes one export save to the desktop dialog or the mobile gallery (#104).
///
/// Both entry points take the *payload bytes* plus the export's base name:
/// the desktop branch writes `name.<extension>` through saveBytesDesktop,
/// the mobile branch either hands bytes to gal (JPEG) or stages a temp file
/// for gal's path-based API (DNG/TIFF) — exactly the pre-#104 flows.
class PhotoSaver {
  const PhotoSaver({
    required this.isDesktop,
    required this.dialog,
    required this.sink,
  });

  final bool isDesktop;
  final SavePathDialog dialog;
  final GallerySink sink;

  /// Byte payload whose format gal infers itself (JPEG export).
  ///
  /// [name] is what mobile hands gal (keep historical names byte-exact —
  /// preset cards pass `<title>_card.png` *with* the extension). The desktop
  /// dialog opens with [desktopFileName] ?? `<name>.jpg`.
  Future<PhotoSaveOutcome?> saveBytes(
    Uint8List bytes, {
    required String name,
    String? desktopFileName,
  }) => _save(
        bytes,
        name: name,
        suggestedFileName: desktopFileName ?? '$name.jpg',
        viaTemp: false,
      );

  /// File-container payload gal must receive as a path (DNG / TIFF16);
  /// [extension] without the dot.
  Future<PhotoSaveOutcome?> saveFile(
    Uint8List bytes, {
    required String name,
    required String extension,
  }) => _save(
        bytes,
        name: name,
        suggestedFileName: '$name.$extension',
        viaTemp: true,
      );

  Future<PhotoSaveOutcome?> _save(
    Uint8List bytes, {
    required String name,
    required String suggestedFileName,
    required bool viaTemp,
  }) async {
    if (isDesktop) {
      final file = await saveBytesDesktop(
        bytes,
        suggestedName: suggestedFileName,
        dialog: dialog,
      );
      return file == null ? null : SavedToFile(file);
    }

    if (!await sink.hasAccess()) await sink.requestAccess();
    if (viaTemp) {
      final dir = await getTemporaryDirectory();
      final tempFile = File('${dir.path}/$suggestedFileName');
      await tempFile.writeAsBytes(bytes, flush: true);
      await sink.putImage(tempFile.path);
    } else {
      await sink.putImageBytes(bytes, name: name);
    }
    return const SavedToGallery();
  }
}

/// Provider seam wired from the platform branches ([isDesktopPlatformProvider]
/// + [savePathDialogProvider] + [gallerySinkProvider]); tests override those
/// three and exercise the real composition.
final photoSaverProvider = Provider<PhotoSaver>(
  (ref) => PhotoSaver(
    isDesktop: ref.watch(isDesktopPlatformProvider),
    dialog: ref.watch(savePathDialogProvider),
    sink: ref.watch(gallerySinkProvider),
  ),
);
