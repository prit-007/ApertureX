import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/viewport/roi_decoder.dart';
import 'package:aperturex/viewport/tile_source.dart';
import 'package:aperturex/viewport/tile_pyramid.dart';

void main() {
  // Position-encoded pixels: any row/column misalignment changes bytes.
  Uint8List noise(int w, int h) {
    final v = Uint8List(w * h * 4);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = (y * w + x) * 4;
        v[i] = (x * 37 + y * 17) & 0xFF;
        v[i + 1] = (x * 11 + y * 53) & 0xFF;
        v[i + 2] = (x * 7 + y * 3) & 0xFF;
        v[i + 3] = 255;
      }
    }
    return v;
  }

  Uint8List crop(Uint8List src, int sw, int x, int y, int w, int h) {
    final out = Uint8List(w * h * 4);
    for (var row = 0; row < h; row++) {
      final from = ((y + row) * sw + x) * 4;
      out.setRange(row * w * 4, (row + 1) * w * 4, src, from);
    }
    return out;
  }

  group('footprintForTile', () {
    final pyramid = TilePyramid(imageWidth: 1000, imageHeight: 750);

    test('level-0 full tile is its exact rect, factor 1', () {
      final fp = footprintForTile(
        pyramid,
        tileSize: 256,
        level: 0,
        col: 1,
        row: 0,
      );
      expect((fp.srcX, fp.srcY, fp.srcW, fp.srcH), (256, 0, 256, 256));
      expect(fp.factor, 1);
      expect((fp.outW, fp.outH), (256, 256));
    });

    test('edge tiles clamp to the image', () {
      final fp = footprintForTile(
        pyramid,
        tileSize: 256,
        level: 0,
        col: 3, // 1000 - 768 = 232 wide
        row: 2, // 750 - 512 = 238 tall
      );
      expect((fp.srcX, fp.srcW), (768, 232));
      expect((fp.srcY, fp.srcH), (512, 238));
      expect((fp.outW, fp.outH), (232, 238));
    });

    test('deeper levels scale the footprint by the level factor', () {
      final fp = footprintForTile(
        pyramid,
        tileSize: 256,
        level: 1,
        col: 0,
        row: 0,
      );
      expect((fp.srcX, fp.srcY), (0, 0));
      expect((fp.srcW, fp.srcH), (512, 512));
      expect(fp.factor, 2);
      expect((fp.outW, fp.outH), (256, 256));
    });

    test('an odd source size clamps the last partial factor block', () {
      // 501 level-px wide → the last level-1 tile covers 250 level-px =
      // 500 source px of a possible 501·? — 1001 wide keeps a stray source
      // column past the last full block.
      final odd = TilePyramid(imageWidth: 1001, imageHeight: 751);
      final fp = footprintForTile(
        odd,
        tileSize: 256,
        level: 1,
        col: 1,
        row: 1,
      );
      expect(fp.srcX, 512);
      expect(fp.srcY, 512);
      expect(fp.srcX + fp.srcW, 1001);
      expect(fp.srcY + fp.srcH, 751);
      expect(fp.outW, (fp.srcW / fp.factor).ceil());
    });
  });

  group('downsampleBox', () {
    test('factor 1 returns the input buffer', () {
      final src = noise(8, 8);
      final out = downsampleBox(src, 8, 8, 1);
      expect(identical(out.rgba, src), isTrue);
      expect((out.width, out.height), (8, 8));
    });

    test('factor 2 averages each 2x2 block', () {
      // 2x2 block: channels 10,20,30,40 → mean 25.
      final src = Uint8List(2 * 2 * 4);
      final values = [10, 20, 30, 40];
      for (var p = 0; p < 4; p++) {
        src[p * 4] = values[p];
        src[p * 4 + 3] = 255;
      }
      final out = downsampleBox(src, 2, 2, 2);
      expect((out.width, out.height), (1, 1));
      expect(out.rgba[0], 25);
      expect(out.rgba[3], 255);
    });

    test('partial edge blocks average only existing pixels', () {
      final src = noise(3, 3);
      final out = downsampleBox(src, 3, 3, 2);
      expect((out.width, out.height), (2, 2));
      // Bottom-right block is a single pixel: (2,2) must pass through.
      final px = crop(src, 3, 2, 2, 1, 1);
      final i = (1 * 2 + 1) * 4;
      expect(
        (out.rgba[i], out.rgba[i + 1], out.rgba[i + 2], out.rgba[i + 3]),
        (px[0], px[1], px[2], px[3]),
      );
    });
  });

  group('coarseAncestors', () {
    test('steps by halving, nearest first', () {
      expect(
        coarseAncestors(level: 0, col: 5, row: 3, maxLevel: 2),
        const [AncestorTile(1, 2, 1), AncestorTile(2, 1, 0)],
      );
    });

    test('an ancestor’s world extent always covers its descendant', () {
      for (final dims in const [
        (1000, 750),
        (1001, 751),
        (12000, 9000),
        (513, 1),
      ]) {
        final pyramid = TilePyramid(imageWidth: dims.$1, imageHeight: dims.$2);
        for (var level = 0; level < pyramid.levelCount - 1; level++) {
          final size = pyramid.levelSize(level);
          final cols = (size.width / 256).ceil();
          final rows = (size.height / 256).ceil();
          for (var col = 0; col < cols; col++) {
            for (var row = 0; row < rows; row++) {
              final fp = footprintForTile(
                pyramid,
                tileSize: 256,
                level: level,
                col: col,
                row: row,
              );
              for (final a in coarseAncestors(
                level: level,
                col: col,
                row: row,
                maxLevel: pyramid.levelCount - 1,
              )) {
                final afp = footprintForTile(
                  pyramid,
                  tileSize: 256,
                  level: a.level,
                  col: a.col,
                  row: a.row,
                );
                expect(afp.srcX, lessThanOrEqualTo(fp.srcX), reason: '$dims l$level c$col → ${a.level}:${a.col}');
                expect(afp.srcY, lessThanOrEqualTo(fp.srcY), reason: '$dims l$level r$row → ${a.level}:${a.row}');
                expect(
                  afp.srcX + afp.srcW,
                  greaterThanOrEqualTo(fp.srcX + fp.srcW),
                  reason: '$dims l$level c$col → ${a.level}:${a.col}',
                );
                expect(
                  afp.srcY + afp.srcH,
                  greaterThanOrEqualTo(fp.srcY + fp.srcH),
                  reason: '$dims l$level r$row → ${a.level}:${a.row}',
                );
              }
            }
          }
        }
      }
    });
  });

  group('JpegTileSource (injected rect fetch)', () {
    const imageW = 1000, imageH = 750, tileSize = 256;
    final src = noise(imageW, imageH);

    late List<(int, int, int, int)> fetches;
    late JpegTileSource source;

    JpegTileSource make({int maxTileSourceBytes = 64 << 20}) {
      fetches = <(int, int, int, int)>[];
      return JpegTileSource(
        jpeg: Uint8List(8),
        imageWidth: imageW,
        imageHeight: imageH,
        tileSize: tileSize,
        maxTileSourceBytes: maxTileSourceBytes,
        fetchRect: ({
          required Uint8List bytes,
          required int imageW,
          required int imageH,
          required int x,
          required int y,
          required int width,
          required int height,
        }) async {
          fetches.add((x, y, width, height));
          return RoiBand(
            width: width,
            height: height,
            rgba: crop(src, imageW, x, y, width, height),
          );
        },
      );
    }

    setUp(() => source = make());

    test('level-0 tile is the exact source crop', () async {
      final tile = await source.fetchTile(0, 1, 0);
      expect(tile, isNotNull);
      expect((tile!.level, tile.width, tile.height), (0, 256, 256));
      expect(tile.rgba, crop(src, imageW, 256, 0, 256, 256));
      expect(fetches, [(256, 0, 256, 256)]);
    });

    test('edge tile decodes only its clamped footprint', () async {
      final tile = await source.fetchTile(0, 3, 2);
      expect(tile, isNotNull);
      expect((tile!.width, tile.height), (232, 238));
      expect(fetches.single, (768, 512, 232, 238));
    });

    test('horizontal seam: adjacent tiles are byte-contiguous', () async {
      final left = await source.fetchTile(0, 0, 0);
      final right = await source.fetchTile(0, 1, 0);
      // Left's last column is source x=255; right's first is x=256 — the
      // 2-px oracle strip across the seam must agree with both.
      final oracle = crop(src, imageW, 255, 0, 2, 256);
      for (var y = 0; y < 256; y++) {
        final l = (y * 256 + 255) * 4;
        final r = (y * 256 + 0) * 4;
        final o = y * 2 * 4;
        expect(
          (left!.rgba[l], left.rgba[l + 1], left.rgba[l + 2]),
          (oracle[o], oracle[o + 1], oracle[o + 2]),
          reason: 'left edge row $y',
        );
        expect(
          (right!.rgba[r], right.rgba[r + 1], right.rgba[r + 2]),
          (oracle[o + 4], oracle[o + 5], oracle[o + 6]),
          reason: 'right edge row $y',
        );
      }
    });

    test('vertical seam: stacked tiles are byte-contiguous', () async {
      final top = await source.fetchTile(0, 0, 0);
      final bottom = await source.fetchTile(0, 0, 1);
      final oracle = crop(src, imageW, 0, 255, 256, 2);
      for (var x = 0; x < 256; x++) {
        final t = (255 * 256 + x) * 4;
        final b = (0 * 256 + x) * 4;
        final o = x * 4;
        expect((top!.rgba[t], top.rgba[t + 1], top.rgba[t + 2]),
            (oracle[o], oracle[o + 1], oracle[o + 2]));
        expect(
          (bottom!.rgba[b], bottom.rgba[b + 1], bottom.rgba[b + 2]),
          (oracle[256 * 4 + o], oracle[256 * 4 + o + 1], oracle[256 * 4 + o + 2]),
        );
      }
    });

    test('level-1 tile equals the box downsample of its footprint', () async {
      final tile = await source.fetchTile(1, 0, 0);
      final fp = footprintForTile(
        source.pyramid,
        tileSize: tileSize,
        level: 1,
        col: 0,
        row: 0,
      );
      final expected = downsampleBox(
        crop(src, imageW, fp.srcX, fp.srcY, fp.srcW, fp.srcH),
        fp.srcW,
        fp.srcH,
        fp.factor,
      );
      expect(tile, isNotNull);
      expect((tile!.level, tile.width, tile.height), (1, 256, 256));
      expect(tile.rgba, expected.rgba);
    });

    test('level-1 seam: coarser tiles stay contiguous through the filter',
        () async {
      final left = await source.fetchTile(1, 0, 0);
      final right = await source.fetchTile(1, 1, 0);
      // Direct downsample of the union footprint (the full 1000×512 source
      // strip both tiles cover): the filter windows are block-aligned at
      // the seam, so the tiled result must match it.
      final union = downsampleBox(
        crop(src, imageW, 0, 0, imageW, 512),
        imageW,
        512,
        2,
      );
      expect(left!.width + right!.width, union.width);
      for (var y = 0; y < union.height; y++) {
        final lo = (y * union.width + left.width - 1) * 4;
        final ro = (y * union.width + left.width) * 4;
        final l = (y * left.width + left.width - 1) * 4;
        final r = (y * right.width) * 4;
        expect((left.rgba[l], left.rgba[l + 1], left.rgba[l + 2], left.rgba[l + 3]),
            (union.rgba[lo], union.rgba[lo + 1], union.rgba[lo + 2], union.rgba[lo + 3]),
            reason: 'left seam row $y');
        expect((right.rgba[r], right.rgba[r + 1], right.rgba[r + 2], right.rgba[r + 3]),
            (union.rgba[ro], union.rgba[ro + 1], union.rgba[ro + 2], union.rgba[ro + 3]),
            reason: 'right seam row $y');
      }
    });

    test('byte budget clamps delivery to the deepest feasible level', () {
      // Full-tile footprints: level 0 = 256²·4, level 1 = 512²·4,
      // level 2 = 1000×750·4 — a 2 MiB budget fits level 1 only.
      final tight = make(maxTileSourceBytes: 2 << 20);
      expect(tight.maxFeasibleLevel, 1);
    });

    test('over-budget requests are served at the feasible level, tagged',
        () async {
      final tight = make(maxTileSourceBytes: 2 << 20);
      final tile = await tight.fetchTile(4, 0, 0);
      expect(tile, isNotNull);
      expect(tile!.level, tight.maxFeasibleLevel);
      expect(tile.width, 256); // delivered at level-1 pitch
    });

    test('out-of-range tiles return null', () async {
      expect(await source.fetchTile(0, 4, 0), isNull);
      expect(await source.fetchTile(0, 0, 3), isNull);
      expect(await source.fetchTile(0, -1, 0), isNull);
      expect(fetches, isEmpty);
    });
  });

  group('RoiDecoder.decodeRect', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel('aperturex/roi_decode');
    late RoiDecoder decoder;
    late List<MethodCall> calls;

    setUp(() {
      calls = <MethodCall>[];
      decoder = RoiDecoder(
        rustFallback: ({
          required Uint8List bytes,
          required int x,
          required int y,
          required int width,
          required int height,
        }) async =>
            RoiBand(width: width, height: height, rgba: Uint8List(width * height * 4)),
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return <String, Object?>{
              'width': 16,
              'height': 8,
              'rgba': Uint8List(16 * 8 * 4),
            };
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('large frames pass the arbitrary rect to the platform verbatim',
        () async {
      // 6000×4000 (96 MiB RGBA) is above the native tier.
      final out = await decoder.decodeRect(
        bytes: Uint8List(4),
        imageW: 6000,
        imageH: 4000,
        x: 512,
        y: 1024,
        width: 256,
        height: 128,
      );
      expect(out, isNotNull);
      expect(calls.single.arguments, <String, Object?>{
        'jpeg': Uint8List(4),
        'x': 512,
        'y': 1024,
        'width': 256,
        'height': 128,
      });
    });

    test('rejects rects outside the image without decoding', () async {
      expect(
        await decoder.decodeRect(
          bytes: Uint8List(4),
          imageW: 100,
          imageH: 100,
          x: 90,
          y: 0,
          width: 20,
          height: 8,
        ),
        isNull,
      );
      expect(calls, isEmpty);
    });
  });
}
