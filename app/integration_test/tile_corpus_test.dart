import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:aperturex/engine/engine.dart';
import 'package:aperturex/viewport/roi_decoder.dart';
import 'package:aperturex/viewport/tile_source.dart';

/// On-device >100 MP tile-pyramid + seam + memory harness (#16 remainder).
///
/// Run on a pinned device profile:
///   flutter test integration_test/tile_corpus_test.dart -d `device-id`
///
/// Env:
///   CORPUS_MP=108     corpus megapixels (default 108 ≈ 12000×9000)
///   CORPUS_JPEG=path  use an existing corpus file instead of generating
///                     (see `cargo run --release --example gen_corpus`)
///   CORPUS_STRICT=1   enforce the RSS memory gate (default report-only)
///
/// What it proves, on the real platform region decoders (Android
/// `BitmapRegionDecoder`, iOS `CGImageSource`):
///  * adjacent tiles at every feasible pyramid level are **byte-exact**
///    across their seams (checked against an independent 2·factor-wide
///    oracle strip through the same decoder) — no tile-grid seams;
///  * deep-zoom-out requests clamp to the source's feasible level;
///  * the tile storm's resident set stays inside the 512 MB device budget
///    and nowhere near a full-frame RGBA (the whole point of #16).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(AxEngine.init);

  testWidgets('100 MP pyramid: seams byte-exact, memory in budget',
      (tester) async {
    final mp = int.tryParse(Platform.environment['CORPUS_MP'] ?? '') ?? 108;
    final strict = Platform.environment['CORPUS_STRICT'] == '1';
    const budgetBytes = 512 * 1024 * 1024;

    // 4:3 frame at ~mp megapixels (108 → 12000×9000).
    final height = math.sqrt(mp * 1e6 * 3 / 4).round();
    final width = (height * 4 / 3).round();
    final fullRgbaBytes = width * height * 4;
    int rss() => ProcessInfo.currentRss;

    final Uint8List jpeg;
    final int imageW, imageH;
    final corpusPath = Platform.environment['CORPUS_JPEG'];
    if (corpusPath != null) {
      jpeg = File(corpusPath).readAsBytesSync();
      final dims = await AxEngine.jpegDimensions(jpeg);
      imageW = dims.width;
      imageH = dims.height;
    } else {
      final genSw = Stopwatch()..start();
      jpeg = await AxEngine.syntheticJpeg(width: width, height: height);
      genSw.stop();
      imageW = width;
      imageH = height;
      // ignore: avoid_print — the report is the harness's primary output.
      print('corpus: ${imageW}x$imageH '
          '(${(imageW * imageH / 1e6).toStringAsFixed(1)} MP), '
          '${mb(jpeg.length)} jpeg, generated in ${genSw.elapsedMilliseconds} ms');
    }

    expect(imageW * imageH, greaterThan(100 * 1000 * 1000),
        reason: 'this harness exists for >100 MP sources');
    final baseline = rss();

    // The channel MUST be live on-device: without it RoiDecoder would fall
    // back to a full-frame Rust decode — 432 MB of RGBA, which is exactly
    // the failure mode this harness exists to prevent.
    await _expectRoiChannelLive();

    final source = JpegTileSource(
      jpeg: jpeg,
      imageWidth: imageW,
      imageHeight: imageH,
    );
    expect(source.maxFeasibleLevel, greaterThan(0),
        reason: 'a >100 MP frame must have at least one coarse level');

    final decoder = RoiDecoder();
    final latencies = <int>[];
    var maxRss = baseline;

    Future<DecodedTile> timedFetch(int level, int col, int row) async {
      final sw = Stopwatch()..start();
      final tile = await source.fetchTile(level, col, row);
      sw.stop();
      expect(tile, isNotNull,
          reason: 'tile l$level c$col r$row must decode on-device');
      latencies.add(sw.elapsedMilliseconds);
      maxRss = math.max(maxRss, rss());
      return tile!;
    }

    // Seam sweep across every feasible level: for a few tile pairs, the
    // edge columns/rows of both tiles must equal an oracle strip decoded
    // independently across the seam (same decoder ⇒ deterministic bytes).
    for (var level = 0; level <= source.maxFeasibleLevel; level++) {
      final factor = 1 << level;
      final size = source.pyramid.levelSize(level);
      final cols = (size.width / source.tileSize).ceil();
      final rows = (size.height / source.tileSize).ceil();
      final pitch = source.tileSize * factor; // seam pitch in source px

      for (final c in {0, cols ~/ 2, cols - 1}.toSet()) {
        if (c + 1 >= cols) continue;
        final left = await timedFetch(level, c, 0);
        final right = await timedFetch(level, c + 1, 0);
        final seamX = (c + 1) * pitch;
        final oracleBand = await decoder.decodeRect(
          bytes: jpeg,
          imageW: imageW,
          imageH: imageH,
          x: seamX - factor,
          y: 0, // both tiles are the top row of the level
          width: 2 * factor,
          height: math.min(left.height * factor, imageH),
        );
        expect(oracleBand, isNotNull);
        final oracle = _downsample(
          oracleBand!.rgba,
          oracleBand.width,
          oracleBand.height,
          factor,
        );
        for (var y = 0; y < left.height; y++) {
          final l = (y * left.width + left.width - 1) * 4;
          final r = (y * right.width) * 4;
          final oL = (y * oracle.width) * 4;
          final oR = (y * oracle.width + 1) * 4;
          expect(
            _px(left.rgba, l),
            _px(oracle.rgba, oL),
            reason: 'l$level vertical seam col $c|${c + 1} row $y (left)',
          );
          expect(
            _px(right.rgba, r),
            _px(oracle.rgba, oR),
            reason: 'l$level vertical seam col $c|${c + 1} row $y (right)',
          );
        }
      }

      for (final r in {0, rows - 1}.toSet()) {
        if (r + 1 >= rows) continue;
        final top = await timedFetch(level, 0, r);
        final bottom = await timedFetch(level, 0, r + 1);
        final seamY = (r + 1) * pitch;
        final oracleBand = await decoder.decodeRect(
          bytes: jpeg,
          imageW: imageW,
          imageH: imageH,
          x: 0,
          y: seamY - factor,
          width: math.min(top.width * factor, imageW),
          height: 2 * factor,
        );
        expect(oracleBand, isNotNull);
        final oracle = _downsample(
          oracleBand!.rgba,
          oracleBand.width,
          oracleBand.height,
          factor,
        );
        final topLastRow = (top.height - 1) * top.width * 4;
        const bottomRow = 0;
        for (var x = 0; x < top.width; x++) {
          final t = topLastRow + x * 4;
          final b = bottomRow + x * 4;
          final oT = x * 4;
          final oB = (oracle.width) * 4 + x * 4;
          expect(
            _px(top.rgba, t),
            _px(oracle.rgba, oT),
            reason: 'l$level horizontal seam row $r|${r + 1} col $x (top)',
          );
          expect(
            _px(bottom.rgba, b),
            _px(oracle.rgba, oB),
            reason: 'l$level horizontal seam row $r|${r + 1} col $x (bottom)',
          );
        }
      }
    }

    // Zoom-out walk: every level down to the floor delivers a sane tile at
    // or below the feasible level (the clamp contract).
    for (var level = 0; level < source.pyramid.levelCount; level++) {
      final tile = await source.fetchTile(
        level,
        source.pyramid.tilesAcross(level) ~/ 2,
        source.pyramid.tilesDown(level) ~/ 2,
      );
      expect(tile, isNotNull);
      expect(tile!.level, lessThanOrEqualTo(source.maxFeasibleLevel));
    }

    latencies.sort();
    final p95 = latencies[(latencies.length * 0.95).floor().clamp(
      0,
      latencies.length - 1,
    )];
    // ignore: avoid_print — the report is the harness's primary output.
    print('tiles: n=${latencies.length} '
        'min=${latencies.first}ms median=${latencies[latencies.length ~/ 2]}ms '
        'p95=${p95}ms | rss baseline=${mb(baseline)} peak=${mb(maxRss)} '
        'full-rgba=${mb(fullRgbaBytes)} budget=${mb(budgetBytes)}');

    // The tile storm must stay nowhere near a full-frame decode and inside
    // the device budget once the transient fetch buffers are gone.
    expect(maxRss - baseline, lessThan(fullRgbaBytes ~/ 4),
        reason: 'tile fetching approached full-frame memory — ROI decode '
            'is not actually engaged');
    final settled = rss();
    if (strict) {
      expect(settled, lessThan(budgetBytes),
          reason: 'settled RSS over the 512 MB device budget');
      expect(p95, lessThan(500),
          reason: 'p95 tile fetch over 500 ms on the pinned profile');
    }
  });
}

/// Probes the `aperturex/roi_decode` channel with a tiny rect so a host or
/// plugin-less run skips cleanly instead of full-decoding the corpus.
Future<void> _expectRoiChannelLive() async {
  const channel = MethodChannel('aperturex/roi_decode');
  try {
    await channel.invokeMethod<Map<Object?, Object?>>('decodeBand', {
      'jpeg': Uint8List(0), // handler must reject it as bad_args/decode_failed
      'x': 0,
      'y': 0,
      'width': 1,
      'height': 1,
    });
  } on MissingPluginException {
    fail('aperturex/roi_decode is not registered on this platform — run '
        'on an Android/iOS device (the Rust fallback full-decodes, which '
        'cannot hold a >100 MP frame)');
  } on PlatformException {
    // Expected: bad_args/decode_failed proves the native handler is live.
  }
}

/// Same block-average as `tile_source.downsampleBox`, duplicated here so the
/// oracle does not share the unit under test's filter call site.
({Uint8List rgba, int width, int height}) _downsample(
  Uint8List src,
  int w,
  int h,
  int factor,
) {
  final ow = (w / factor).ceil();
  final oh = (h / factor).ceil();
  final out = Uint8List(ow * oh * 4);
  for (var oy = 0; oy < oh; oy++) {
    final y0 = oy * factor;
    final y1 = math.min(y0 + factor, h);
    for (var ox = 0; ox < ow; ox++) {
      final x0 = ox * factor;
      final x1 = math.min(x0 + factor, w);
      var r = 0, g = 0, b = 0, a = 0;
      for (var y = y0; y < y1; y++) {
        var i = (y * w + x0) * 4;
        for (var x = x0; x < x1; x++) {
          r += src[i];
          g += src[i + 1];
          b += src[i + 2];
          a += src[i + 3];
          i += 4;
        }
      }
      final n = (x1 - x0) * (y1 - y0);
      final o = (oy * ow + ox) * 4;
      out[o] = (r / n).round();
      out[o + 1] = (g / n).round();
      out[o + 2] = (b / n).round();
      out[o + 3] = (a / n).round();
    }
  }
  return (rgba: out, width: ow, height: oh);
}

(int, int, int, int) _px(Uint8List buf, int i) =>
    (buf[i], buf[i + 1], buf[i + 2], buf[i + 3]);

String mb(int bytes) => '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
