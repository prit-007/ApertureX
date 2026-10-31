import 'dart:typed_data';

/// A cluster of duplicate or near-duplicate assets.
class DuplicateGroup {
  const DuplicateGroup({
    required this.primaryAssetId,
    required this.duplicateAssetIds,
    required this.distances,
  });

  /// The first or primary asset in this duplicate cluster.
  final String primaryAssetId;

  /// IDs of other assets matching [primaryAssetId].
  final List<String> duplicateAssetIds;

  /// Hamming distance of each duplicate asset to the primary asset.
  final Map<String, int> distances;

  /// Total number of photos in this cluster.
  int get totalCount => 1 + duplicateAssetIds.length;
}

/// Computes 64-bit perceptual difference hashes (dHash) and clusters duplicates.
class DuplicateDetector {
  const DuplicateDetector();

  /// Computes a 64-bit difference hash (dHash) from RGBA pixel data.
  ///
  /// Resizes image down to a 9×8 grayscale matrix, then compares adjacent
  /// horizontal pixels (`pixel[x] > pixel[x+1]`). This produces 8×8 = 64 bits.
  /// Invariant to scaling, aspect ratio, and moderate brightness/contrast changes.
  static int computeDHash(Uint8List rgba, int width, int height) {
    if (width < 2 || height < 1 || rgba.length < width * height * 4) {
      return 0;
    }

    // 1. Resample to 9 columns x 8 rows grayscale using box sampling
    const targetW = 9;
    const targetH = 8;
    final grid = List<int>.filled(targetW * targetH, 0);

    final cellW = width / targetW;
    final cellH = height / targetH;

    for (var gy = 0; gy < targetH; gy++) {
      final y0 = (gy * cellH).floor();
      final y1 = ((gy + 1) * cellH).ceil().clamp(y0 + 1, height);

      for (var gx = 0; gx < targetW; gx++) {
        final x0 = (gx * cellW).floor();
        final x1 = ((gx + 1) * cellW).ceil().clamp(x0 + 1, width);

        var lumaSum = 0;
        var pixelCount = 0;

        for (var y = y0; y < y1; y++) {
          final rowOffset = y * width * 4;
          for (var x = x0; x < x1; x++) {
            final idx = rowOffset + x * 4;
            final r = rgba[idx];
            final g = rgba[idx + 1];
            final b = rgba[idx + 2];
            // Fast integer luminance: (299*R + 587*G + 114*B) / 1000
            final luma = (299 * r + 587 * g + 114 * b) ~/ 1000;
            lumaSum += luma;
            pixelCount++;
          }
        }

        grid[gy * targetW + gx] = pixelCount > 0 ? lumaSum ~/ pixelCount : 0;
      }
    }

    // 2. Compute 64-bit difference hash: compare adjacent horizontal pixels
    var hash = 0;
    for (var gy = 0; gy < targetH; gy++) {
      for (var gx = 0; gx < 8; gx++) {
        final left = grid[gy * targetW + gx];
        final right = grid[gy * targetW + (gx + 1)];
        hash = (hash << 1) | (left > right ? 1 : 0);
      }
    }

    return hash;
  }

  /// Calculates the Hamming distance (number of differing bits) between two 64-bit hashes.
  static int hammingDistance(int hashA, int hashB) {
    var xor = hashA ^ hashB;
    var dist = 0;
    while (xor != 0) {
      dist += xor & 1;
      // 64-bit unsigned right shift
      xor = (xor >> 1) & 0x7FFFFFFFFFFFFFFF;
    }
    return dist;
  }

  /// Groups assets into duplicate clusters based on a maximum Hamming distance threshold.
  ///
  /// Distance thresholds:
  /// - `0`: Exact perceptual duplicates.
  /// - `1..6`: Near-duplicates (burst shots, slight crops, minor recompression).
  /// - `> 10`: Visually distinct photos.
  static List<DuplicateGroup> findDuplicates(
    Map<String, int> assetHashes, {
    int maxDistance = 6,
  }) {
    final visited = <String>{};
    final groups = <DuplicateGroup>[];
    final entries = assetHashes.entries.toList();

    for (var i = 0; i < entries.length; i++) {
      final primaryId = entries[i].key;
      if (visited.contains(primaryId)) continue;

      final primaryHash = entries[i].value;
      final duplicateIds = <String>[];
      final distances = <String, int>{};

      for (var j = i + 1; j < entries.length; j++) {
        final candidateId = entries[j].key;
        if (visited.contains(candidateId)) continue;

        final candidateHash = entries[j].value;
        final dist = hammingDistance(primaryHash, candidateHash);

        if (dist <= maxDistance) {
          duplicateIds.add(candidateId);
          distances[candidateId] = dist;
          visited.add(candidateId);
        }
      }

      if (duplicateIds.isNotEmpty) {
        visited.add(primaryId);
        groups.add(
          DuplicateGroup(
            primaryAssetId: primaryId,
            duplicateAssetIds: duplicateIds,
            distances: distances,
          ),
        );
      }
    }

    return groups;
  }
}
