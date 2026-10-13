import 'package:flutter_test/flutter_test.dart';
import 'package:tessera/viewport/tile_lru.dart';

void main() {
  group('TileLru', () {
    int sizeOf(String v) => v.length;

    test('stores within budget without eviction', () {
      final lru = TileLru<int, String>(maxBytes: 10, sizeOf: sizeOf);
      lru.put(1, 'aaaa');
      lru.put(2, 'bbbb');
      expect(lru.length, 2);
      expect(lru.totalBytes, 8);
      expect(lru.get(1), 'aaaa');
    });

    test('evicts eldest when over budget', () {
      final lru = TileLru<int, String>(maxBytes: 8, sizeOf: sizeOf);
      lru.put(1, 'aaaa');
      lru.put(2, 'bbbb');
      lru.put(3, 'cccc');
      expect(lru.containsKey(1), isFalse);
      expect(lru.containsKey(2), isTrue);
      expect(lru.containsKey(3), isTrue);
      expect(lru.totalBytes, 8);
    });

    test('get refreshes recency so it is not evicted first', () {
      final lru = TileLru<int, String>(maxBytes: 8, sizeOf: sizeOf);
      lru.put(1, 'aaaa');
      lru.put(2, 'bbbb');
      lru.get(1);
      lru.put(3, 'cccc');
      expect(lru.containsKey(1), isTrue);
      expect(lru.containsKey(2), isFalse);
    });

    test('updating a key adjusts its byte cost', () {
      final lru = TileLru<int, String>(maxBytes: 10, sizeOf: sizeOf);
      lru.put(1, 'aaaa');
      lru.put(1, 'aaaaaa');
      expect(lru.length, 1);
      expect(lru.totalBytes, 6);
    });

    test('remove decrements bytes', () {
      final lru = TileLru<int, String>(maxBytes: 10, sizeOf: sizeOf);
      lru.put(1, 'aaaa');
      lru.remove(1);
      expect(lru.length, 0);
      expect(lru.totalBytes, 0);
    });

    test('clear empties cache and resets bytes', () {
      final lru = TileLru<int, String>(maxBytes: 10, sizeOf: sizeOf);
      lru.put(1, 'aaaa');
      lru.put(2, 'bbbb');
      lru.clear();
      expect(lru.length, 0);
      expect(lru.totalBytes, 0);
    });

    test('a single oversized value is not retained', () {
      final lru = TileLru<int, String>(maxBytes: 4, sizeOf: sizeOf);
      lru.put(1, 'aaaaaaaa');
      expect(lru.length, 0);
      expect(lru.totalBytes, 0);
    });

    test('evicts multiple eldest entries to fit a larger insert', () {
      final lru = TileLru<int, String>(maxBytes: 9, sizeOf: sizeOf);
      lru.put(1, 'aaa');
      lru.put(2, 'bbb');
      lru.put(3, 'ccc');
      lru.put(4, 'dddd');
      expect(lru.containsKey(1), isFalse);
      expect(lru.containsKey(2), isFalse);
      expect(lru.containsKey(3), isTrue);
      expect(lru.containsKey(4), isTrue);
      expect(lru.totalBytes, 7);
    });
  });
}
