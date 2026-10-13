import 'dart:collection';

/// A least-recently-used cache bounded by a total byte budget.
///
/// [sizeOf] reports each value's cost in bytes; the cache evicts the
/// least-recently-used entries (starting with the eldest) whenever the total
/// exceeds [maxBytes]. Used for the decoded-tile cache (ARCHITECTURE §5.2).
class TileLru<K, V> {
  TileLru({required this.maxBytes, required this.sizeOf}) : assert(maxBytes > 0);

  final int maxBytes;
  final int Function(V value) sizeOf;

  final LinkedHashMap<K, V> _map = LinkedHashMap<K, V>();
  int _totalBytes = 0;

  int get totalBytes => _totalBytes;
  int get length => _map.length;
  bool containsKey(K key) => _map.containsKey(key);

  /// Returns the value for [key] and marks it most-recently-used, or `null`.
  V? get(K key) {
    final value = _map.remove(key);
    if (value != null) _map[key] = value;
    return value;
  }

  /// Inserts or replaces [key], then evicts least-recently-used entries until
  /// the budget is met. A value larger than [maxBytes] is not retained.
  void put(K key, V value) {
    final existing = _map.remove(key);
    if (existing != null) _totalBytes -= sizeOf(existing);
    _map[key] = value;
    _totalBytes += sizeOf(value);
    _evictIfNeeded();
  }

  V? remove(K key) {
    final value = _map.remove(key);
    if (value != null) _totalBytes -= sizeOf(value);
    return value;
  }

  void clear() {
    _map.clear();
    _totalBytes = 0;
  }

  void _evictIfNeeded() {
    while (_totalBytes > maxBytes && _map.isNotEmpty) {
      final eldestKey = _map.keys.first;
      final removed = _map.remove(eldestKey);
      if (removed != null) _totalBytes -= sizeOf(removed);
    }
  }
}
