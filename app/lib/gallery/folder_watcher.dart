import 'dart:async';
import 'dart:io';

/// Supported photo extensions for automatic import into the ApertureX library.
const Set<String> kSupportedAutoImportExtensions = {
  '.jpg',
  '.jpeg',
  '.png',
  '.heic',
  '.dng',
  '.cr2',
  '.cr3',
  '.nef',
  '.arw',
  '.rw2',
  '.orf',
  '.raf',
  '.tif',
  '.tiff',
};

/// Service that monitors a local directory and auto-imports newly dropped photos.
///
/// Designed for tethered shooting workflows, memory card ingestion, and desktop hot-folders.
class AutoImportFolderWatcher {
  AutoImportFolderWatcher({
    required this.directoryPath,
    required this.onPhotoDiscovered,
    this.debounceDuration = const Duration(milliseconds: 300),
  });

  final String directoryPath;
  final void Function(File file) onPhotoDiscovered;
  final Duration debounceDuration;

  StreamSubscription<FileSystemEvent>? _subscription;
  final Set<String> _processedPaths = {};
  final Map<String, Timer> _debounceTimers = {};
  bool _isWatching = false;

  bool get isWatching => _isWatching;

  /// Starts monitoring the folder for newly created or modified photo files.
  Future<void> start() async {
    final dir = Directory(directoryPath);
    if (!await dir.exists()) {
      return;
    }

    _isWatching = true;

    // Scan initial existing files to prevent duplicate notifications
    try {
      await for (final entity in dir.list(recursive: false, followLinks: false)) {
        if (entity is File && _isSupportedPhoto(entity.path)) {
          _processedPaths.add(entity.path);
        }
      }
    } catch (_) {
      // Ignore initial scan errors
    }

    try {
      _subscription = dir.watch(recursive: false).listen(_handleEvent);
    } catch (_) {
      // Platform may not support file watching; graceful degradation
    }
  }

  void _handleEvent(FileSystemEvent event) {
    if (event is! FileSystemCreateEvent && event is! FileSystemModifyEvent) {
      return;
    }

    final path = event.path;
    if (!_isSupportedPhoto(path) || _processedPaths.contains(path)) {
      return;
    }

    // Debounce to ensure file writing has concluded before ingestion
    _debounceTimers[path]?.cancel();
    _debounceTimers[path] = Timer(debounceDuration, () async {
      _debounceTimers.remove(path);
      final file = File(path);
      if (await file.exists()) {
        try {
          final length = await file.length();
          if (length > 0) {
            _processedPaths.add(path);
            onPhotoDiscovered(file);
          }
        } catch (_) {
          // File might still be locked by camera tether; ignore until next event
        }
      }
    });
  }

  bool _isSupportedPhoto(String path) {
    final dot = path.lastIndexOf('.');
    if (dot == -1) return false;
    final ext = path.substring(dot).toLowerCase();
    return kSupportedAutoImportExtensions.contains(ext);
  }

  /// Stops monitoring and cancels active timers.
  Future<void> stop() async {
    _isWatching = false;
    await _subscription?.cancel();
    _subscription = null;
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
  }

  /// Cleans up all watcher resources.
  void dispose() {
    stop();
  }
}
