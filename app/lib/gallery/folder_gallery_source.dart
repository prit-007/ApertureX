import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/image_format.dart';
import 'gallery_album.dart';
import 'gallery_asset.dart';
import 'gallery_source.dart';
import 'thumbnail_memory_cache.dart';

/// Prefs key holding the user-chosen desktop library root (#103).
const String folderRootPrefsKey = 'desktop_library_root';

/// Implicit album id for a folder-backed library — there is exactly one
/// album (the chosen root), so no per-folder bookkeeping is stored.
const String kFolderAlbumId = 'folder';

/// Extensions the folder scan accepts (#103): every raster format
/// package:image decodes for preview/thumbnail, plus the RAW containers the
/// Rust pipeline opens. HEIC/AVIF stay out — photo_manager transcodes them
/// on mobile, and no desktop decode path exists yet.
const Set<String> kFolderImageExtensions = {
  'jpg',
  'jpeg',
  'png',
  'webp',
  'gif',
  'bmp',
  'tif',
  'tiff',
  'dng',
  'cr2',
  'cr3',
  'nef',
  'arw',
  'orf',
  'rw2',
  'raf',
  'pef',
  'srw',
};

/// Signature of the native folder chooser, injectable so widget tests never
/// touch the real plugin channel.
typedef DirectoryPicker = Future<String?> Function();

/// A [GallerySource] backed by one user-chosen filesystem folder, for
/// Windows/Linux (and any desktop experiment). Asset ids are **bare file
/// names** resolved under the persisted root — stable across sibling roots
/// so catalog entries keep working after a move — and every load rejects
/// path separators/`..` so a crafted id can never escape the folder.
class FolderGallerySource implements GallerySource {
  FolderGallerySource({DirectoryPicker? pickDirectory})
    : _pickDirectory = pickDirectory ?? _pickSystemDirectory;

  final DirectoryPicker _pickDirectory;

  @override
  final ThumbnailMemoryCache thumbnailCache = ThumbnailMemoryCache();

  String? _rootPath;
  bool _rootRestored = false;

  /// The currently chosen folder, or null while the CTA is showing.
  String? get rootPath => _rootPath;

  static Future<String?> _pickSystemDirectory() =>
      FilePicker.getDirectoryPath(dialogTitle: 'Choose a photo folder');

  /// Restores the persisted root once per instance; a root that no longer
  /// exists on disk is dropped so the UI falls back to the CTA instead of
  /// silently showing an empty grid.
  Future<void> _ensureRoot() async {
    if (_rootRestored) return;
    _rootRestored = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(folderRootPrefsKey);
      if (stored != null && Directory(stored).existsSync()) {
        _rootPath = stored;
      }
    } catch (_) {
      _rootPath = null;
    }
  }

  /// Opens the native folder dialog. Returns false when cancelled — the
  /// previous root must stay untouched.
  Future<bool> pickRoot() async {
    await _ensureRoot();
    final path = await _pickDirectory();
    if (path == null) return false;
    return setRoot(path);
  }

  /// Points the library at [path] and persists it. Thumbnail entries are
  /// dropped because ids are bare names — old bytes could alias a
  /// same-named file under the new root.
  Future<bool> setRoot(String path) async {
    if (!Directory(path).existsSync()) return false;
    _rootPath = path;
    _rootRestored = true;
    thumbnailCache.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(folderRootPrefsKey, path);
    } catch (_) {
      // Best effort: the in-memory root still serves this session.
    }
    return true;
  }

  @override
  Future<GalleryPermission> requestPermission() async {
    await _ensureRoot();
    // Filesystem access needs no OS photo-library grant on desktop (#103).
    return GalleryPermission.granted;
  }

  @override
  Future<void> openAppSettings() async {} // nothing to grant on desktop

  @override
  Future<List<GalleryAlbum>> listAlbums() async {
    await _ensureRoot();
    final root = _rootPath;
    if (root == null) return const [];
    final assets = await _scan();
    return [
      GalleryAlbum(
        id: kFolderAlbumId,
        name: _basename(root),
        count: assets.length,
        coverAssetId: assets.isEmpty ? null : assets.first.id,
      ),
    ];
  }

  @override
  Future<List<GalleryAsset>> listImages({
    int limit = 500,
    String? albumId,
  }) async {
    await _ensureRoot();
    if (_rootPath == null) return const [];
    if (albumId != null && albumId != kFolderAlbumId) return const [];
    final assets = await _scan();
    return assets.length <= limit ? assets : assets.sublist(0, limit);
  }

  /// Flat scan (v1), newest-first by mtime. Rescans on every call so entering
  /// the screen reflects the disk and a re-pick needs no cache invalidation
  /// beyond the thumbnail LRU.
  Future<List<GalleryAsset>> _scan() async {
    final root = _rootPath;
    if (root == null) return const [];
    final assets = <GalleryAsset>[];
    try {
      await for (final entity in Directory(root).list(followLinks: false)) {
        if (entity is! File) continue;
        final name = _basename(entity.path);
        if (!_hasSupportedExtension(name)) continue;
        try {
          final stat = await entity.stat();
          assets.add(
            GalleryAsset(
              id: name,
              // 0×0 → grid falls back to square cells; real dimensions are
              // probed at decode time, never by reading every file upfront.
              width: 0,
              height: 0,
              created: stat.modified,
              modified: stat.modified,
            ),
          );
        } catch (_) {
          // Files vanishing mid-scan are normal on a live folder.
        }
      }
    } catch (_) {
      // Unreadable root → empty library; the UI shows the re-pick state.
      return const [];
    }
    assets.sort((a, b) {
      final ad = a.latestDate;
      final bd = b.latestDate;
      if (ad == null || bd == null) return 0;
      return bd.compareTo(ad);
    });
    return assets;
  }

  /// Ids are bare file names by contract; anything crafted to escape the
  /// root (separators, `..`, absolute paths) resolves to nothing.
  File? _resolveFile(String id) {
    final root = _rootPath;
    if (root == null || id.isEmpty) return null;
    if (id.contains('/') || id.contains('\\') || id.contains('..')) {
      return null;
    }
    return File('$root${Platform.pathSeparator}$id');
  }

  Future<Uint8List> _readOrEmpty(String id) async {
    await _ensureRoot();
    final file = _resolveFile(id);
    if (file == null) return Uint8List(0);
    try {
      if (!await file.exists()) return Uint8List(0);
      return await file.readAsBytes();
    } catch (_) {
      return Uint8List(0);
    }
  }

  /// Decodes [bytes] with package:image, scales the long side down to
  /// [maxDim] only when it exceeds the bound (never upscales), and
  /// re-encodes as JPEG — the editor's non-RAW path expects JPEG. Returns
  /// null when the bytes aren't Dart-decodable (caller decides fallback).
  Uint8List? _boundedJpeg(Uint8List bytes, int maxDim) {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;
      var out = decoded;
      if (math.max(decoded.width, decoded.height) > maxDim) {
        out = decoded.width >= decoded.height
            ? img.copyResize(decoded, width: maxDim)
            : img.copyResize(decoded, height: maxDim);
      }
      return Uint8List.fromList(img.encodeJpg(out, quality: 90));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Uint8List> loadImage(String id) => _readOrEmpty(id);

  @override
  Future<Uint8List> loadPreview(String id, {int maxDim = 1600}) async {
    final bytes = await _readOrEmpty(id);
    if (bytes.isEmpty) return bytes;
    if (detectImageFormat(bytes) == ImageFormat.raw) {
      // The editor sniffs RAW by magic bytes and Rust decodes the original
      // itself — pass through untouched, never resized/re-encoded here.
      return bytes;
    }
    // Non-decodable bytes fall back to the original so the editor surfaces
    // a real decode error instead of silently loading an empty buffer.
    return _boundedJpeg(bytes, maxDim) ?? bytes;
  }

  @override
  Future<Uint8List> loadThumbnail(String id, {int size = 256}) async {
    final bytes = await _readOrEmpty(id);
    if (bytes.isEmpty) return bytes;
    if (detectImageFormat(bytes) == ImageFormat.raw) {
      // v1: no Rust thumbnail encoder is exposed yet — RAW cells show the
      // placeholder row, exactly the trade-off issue #103 allows. Wiring
      // AxEngine.decodeAnalysisProxy here is a follow-up, not a blocker.
      return Uint8List(0);
    }
    return _boundedJpeg(bytes, size) ?? Uint8List(0);
  }

  static String _basename(String path) {
    final cut = math.max(path.lastIndexOf('/'), path.lastIndexOf('\\'));
    return cut < 0 ? path : path.substring(cut + 1);
  }

  static bool _hasSupportedExtension(String name) {
    final dot = name.lastIndexOf('.');
    if (dot <= 0) return false;
    return kFolderImageExtensions.contains(
      name.substring(dot + 1).toLowerCase(),
    );
  }
}
