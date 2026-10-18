import 'dart:typed_data';

/// High-performance in-memory LRU cache for gallery thumbnails.
/// Eliminates redundant IPC and disk decoding when scrolling back and forth.
class ThumbnailMemoryCache {
  ThumbnailMemoryCache({this.maxEntries = 1000});

  final int maxEntries;
  final Map<String, Uint8List> _cache = {};

  Uint8List? get(String id) {
    final bytes = _cache.remove(id);
    if (bytes != null) {
      _cache[id] = bytes;
    }
    return bytes;
  }

  void put(String id, Uint8List bytes) {
    if (bytes.isEmpty) return;
    if (_cache.containsKey(id)) {
      // Refresh recency
      _cache.remove(id);
      _cache[id] = bytes;
      return;
    }
    if (_cache.length >= maxEntries) {
      _cache.remove(_cache.keys.first);
    }
    _cache[id] = bytes;
  }

  void remove(String id) => _cache.remove(id);

  void clear() => _cache.clear();

  int get length => _cache.length;
}

final thumbnailCache = ThumbnailMemoryCache();
