import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/gallery/duplicate_detector.dart';

void main() {
  group('DuplicateDetector Tests', () {
    test('hammingDistance computes bitwise population count difference', () {
      expect(DuplicateDetector.hammingDistance(0, 0), 0);
      expect(DuplicateDetector.hammingDistance(0x1, 0x0), 1);
      expect(DuplicateDetector.hammingDistance(0x3, 0x0), 2);
      expect(DuplicateDetector.hammingDistance(0xFF, 0x00), 8);
      expect(DuplicateDetector.hammingDistance(0x12345678, 0x12345678), 0);
      expect(DuplicateDetector.hammingDistance(0x12345678, 0x12345679), 1);
    });

    test('computeDHash produces deterministic and scale-invariant hashes', () {
      // Create an alternating vertical stripes image (bright on even x, dark on odd x)
      const w1 = 18;
      const h1 = 16;
      final img1 = Uint8List(w1 * h1 * 4);
      for (var y = 0; y < h1; y++) {
        for (var x = 0; x < w1; x++) {
          final luma = (x % 4 < 2) ? 220 : 30;
          final idx = (y * w1 + x) * 4;
          img1[idx] = luma;
          img1[idx + 1] = luma;
          img1[idx + 2] = luma;
          img1[idx + 3] = 255;
        }
      }

      // Same pattern image at 2x resolution
      const w2 = 36;
      const h2 = 32;
      final img2 = Uint8List(w2 * h2 * 4);
      for (var y = 0; y < h2; y++) {
        for (var x = 0; x < w2; x++) {
          final luma = ((x ~/ 2) % 4 < 2) ? 220 : 30;
          final idx = (y * w2 + x) * 4;
          img2[idx] = luma;
          img2[idx + 1] = luma;
          img2[idx + 2] = luma;
          img2[idx + 3] = 255;
        }
      }

      final hash1 = DuplicateDetector.computeDHash(img1, w1, h1);
      final hash2 = DuplicateDetector.computeDHash(img2, w2, h2);

      expect(hash1, isNot(0));
      // Gradient left to right: left < right everywhere, so all bits are 0
      expect(hash1, hash2);
      expect(DuplicateDetector.hammingDistance(hash1, hash2), 0);
    });

    test('findDuplicates clusters near-duplicate hashes', () {
      const baseHash = 0xAAAAAAAAAAAAAAAA;
      final assetHashes = <String, int>{
        'photo1': baseHash,
        'photo1_copy': baseHash, // exact (dist 0)
        'photo1_burst': baseHash ^ 0x3, // near (dist 2)
        'photo2': 0x5555555555555555, // distinct
        'photo3': 0x0000000000000000, // distinct
      };

      final groups = DuplicateDetector.findDuplicates(assetHashes, maxDistance: 4);

      expect(groups.length, 1);
      final g = groups.first;
      expect(g.primaryAssetId, 'photo1');
      expect(g.duplicateAssetIds, containsAll(['photo1_copy', 'photo1_burst']));
      expect(g.duplicateAssetIds.contains('photo2'), isFalse);
      expect(g.duplicateAssetIds.contains('photo3'), isFalse);
      expect(g.distances['photo1_copy'], 0);
      expect(g.distances['photo1_burst'], 2);
    });
  });
}
