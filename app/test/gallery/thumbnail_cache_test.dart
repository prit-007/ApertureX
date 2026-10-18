import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/gallery/thumbnail_memory_cache.dart';

void main() {
  group('ThumbnailMemoryCache', () {
    test('stores and retrieves cached thumbnail bytes', () {
      final cache = ThumbnailMemoryCache(maxEntries: 3);
      final bytes1 = Uint8List.fromList([1, 2, 3]);
      final bytes2 = Uint8List.fromList([4, 5, 6]);

      cache.put('asset-1', bytes1);
      cache.put('asset-2', bytes2);

      expect(cache.get('asset-1'), equals(bytes1));
      expect(cache.get('asset-2'), equals(bytes2));
      expect(cache.get('asset-3'), isNull);
      expect(cache.length, 2);
    });

    test('evicts oldest LRU entry when capacity is reached', () {
      final cache = ThumbnailMemoryCache(maxEntries: 2);
      final bytes1 = Uint8List.fromList([1]);
      final bytes2 = Uint8List.fromList([2]);
      final bytes3 = Uint8List.fromList([3]);

      cache.put('a', bytes1);
      cache.put('b', bytes2);

      // Access 'a' to make it most recently used
      expect(cache.get('a'), equals(bytes1));

      // Put 'c' - should evict 'b' (oldest)
      cache.put('c', bytes3);

      expect(cache.get('a'), equals(bytes1));
      expect(cache.get('b'), isNull);
      expect(cache.get('c'), equals(bytes3));
      expect(cache.length, 2);
    });

    test('clear empties the cache', () {
      final cache = ThumbnailMemoryCache(maxEntries: 5);
      cache.put('x', Uint8List.fromList([10]));
      cache.put('y', Uint8List.fromList([20]));
      expect(cache.length, 2);

      cache.clear();
      expect(cache.length, 0);
      expect(cache.get('x'), isNull);
      expect(cache.get('y'), isNull);
    });
  });
}
