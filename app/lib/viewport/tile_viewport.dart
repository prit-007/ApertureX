import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'tile_grid.dart';
import 'tile_lru.dart';
import 'tile_pyramid.dart';
import 'tile_source.dart';
import 'viewport_transform.dart';

/// Cache key in source mode: a tile address is (level, col, row) — the same
/// (col,row) exists at every pyramid level with a different extent.
class _LevelTileKey {
  const _LevelTileKey(this.level, this.col, this.row);

  final int level;
  final int col;
  final int row;

  @override
  bool operator ==(Object other) =>
      other is _LevelTileKey &&
      other.level == level &&
      other.col == col &&
      other.row == row;

  @override
  int get hashCode => Object.hash(level, col, row);
}

/// A zoomable, pannable viewport that composites decoded RGBA tiles through
/// the grading shader (ARCHITECTURE §5).
///
/// Two sources, one painter:
///  * **[source]** (#16) — a [TileSource] decodes tiles on demand with the
///    multi-level [TilePyramid]: zoomed-out views sample a coarser level (so
///    a >100 MP frame is never decoded full-size), and while a fine tile is
///    in flight its coarse ancestor paints its exact world rect — no
///    blank-while-decode flashes. The source may deliver a coarser level
///    than requested when its byte budget forbids the footprint; the tile is
///    keyed and painted at the level it actually arrived at.
///  * **[rgba]** — a fully decoded in-memory frame sliced into tiles (the
///    original P1 demo path; fine for ≤ tens of MP, kept for tests/demos).
///
/// Grading uniforms are applied identically per tile so seams are invisible;
/// navigation is a single scale gesture (pinch to zoom, drag to pan, anchored
/// at the focal point).
class TileViewport extends StatefulWidget {
  const TileViewport({
    super.key,
    this.rgba,
    this.source,
    required this.imageWidth,
    required this.imageHeight,
    required this.shaderProgram,
    this.exposure = 0,
    this.contrast = 0,
    this.saturation = 0,
    this.tileSize = 512,
    this.maxCacheBytes = 96 * 1024 * 1024,
    this.maxZoomFactor = 8,
  }) : assert(
          rgba != null || source != null,
          'provide exactly one of rgba (in-memory) or source (on-demand)',
        );

  /// Full decoded RGBA8 pixels (length `imageWidth * imageHeight * 4`) —
  /// legacy in-memory path; mutually exclusive with [source].
  final Uint8List? rgba;

  /// On-demand pyramid tile source (#16); mutually exclusive with [rgba].
  final TileSource? source;

  final int imageWidth;
  final int imageHeight;
  final ui.FragmentProgram shaderProgram;
  final double exposure;
  final double contrast;
  final double saturation;
  final int tileSize;
  final int maxCacheBytes;
  final double maxZoomFactor;

  @override
  State<TileViewport> createState() => _TileViewportState();
}

class _TileViewportState extends State<TileViewport> {
  TileSource? get _source => widget.source;

  late final TileGrid _legacyGrid = TileGrid(
    imageWidth: widget.imageWidth,
    imageHeight: widget.imageHeight,
    tileSize: widget.tileSize,
  );

  late final TilePyramid? _pyramid = _source?.pyramid;

  late final ui.FragmentShader _shader = widget.shaderProgram.fragmentShader();

  late final TileLru<Object, ui.Image> _cache = TileLru<Object, ui.Image>(
    maxBytes: widget.maxCacheBytes,
    sizeOf: (img) => img.width * img.height * 4,
    onEvict: (_, img) => img.dispose(),
  );

  final Set<Object> _inFlight = {};
  final Set<Object> _failedKeys = {};

  ViewportTransform _transform = const ViewportTransform(
    scale: 1,
    offset: Offset.zero,
  );
  ViewportTransform _startTransform = const ViewportTransform(
    scale: 1,
    offset: Offset.zero,
  );
  double _startScale = 1;
  Size _viewportSize = Size.zero;
  bool _initialized = false;

  Size get _imageSize => Size(
    widget.imageWidth.toDouble(),
    widget.imageHeight.toDouble(),
  );

  double get _minScale =>
      ViewportTransform.fitScale(_imageSize, _viewportSize);
  double get _maxScale => _minScale * widget.maxZoomFactor;

  /// Display level in source mode: the zoom-matched pyramid level, clamped to
  /// what the source can actually decode within its byte budget.
  int get _level {
    final pyramid = _pyramid;
    if (pyramid == null) return 0;
    final matched = pyramid.levelForScale(_transform.scale);
    return matched.clamp(0, _source!.maxFeasibleLevel);
  }

  @override
  void dispose() {
    _cache.clear();
    super.dispose();
  }

  void _onScaleStart(ScaleStartDetails details) {
    _startTransform = _transform;
    _startScale = _transform.scale;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (_viewportSize == Size.zero) return;
    final next = _startTransform.zoomed(
      newScale: _startScale * details.scale,
      focalScreen: details.focalPoint,
      minScale: _minScale,
      maxScale: _maxScale,
    ).clampToImage(_imageSize, _viewportSize);
    if (next.scale != _transform.scale || next.offset != _transform.offset) {
      setState(() => _transform = next);
    }
  }

  Future<void> _ensureTile(Object key, Future<ui.Image> Function() create) async {
    if (_cache.containsKey(key) || _inFlight.contains(key)) return;
    _inFlight.add(key);
    try {
      final img = await create();
      if (!mounted) {
        img.dispose();
        return;
      }
      _cache.put(key, img);
      setState(() {});
    } finally {
      _inFlight.remove(key);
    }
  }

  Future<ui.Image> _createTileImage(TileCoord coord) async {
    final rect = _legacyGrid.tileRect(coord.col, coord.row);
    final w = rect.width.round();
    final h = rect.height.round();
    final x = rect.left.round();
    final y = rect.top.round();

    final bytes = Uint8List(w * h * 4);
    final rgba = widget.rgba!;
    for (var row = 0; row < h; row++) {
      final src = ((y + row) * widget.imageWidth + x) * 4;
      final dst = row * w * 4;
      bytes.setRange(dst, dst + w * 4, rgba, src);
    }
    return _decodeUiImage(bytes, w, h);
  }

  Future<ui.Image> _createSourceTile(int level, int col, int row) async {
    final tile = await _source!.fetchTile(level, col, row);
    if (tile == null) {
      // Out of range or decode failure: a transparent stand-in caches under
      // the key (via the failed set) so the painter stops re-requesting.
      _failedKeys.add(_LevelTileKey(level, col, row));
      return _decodeUiImage(Uint8List(4), 1, 1);
    }
    return _decodeUiImage(tile.rgba, tile.width, tile.height);
  }

  static Future<ui.Image> _decodeUiImage(Uint8List bytes, int w, int h) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      bytes,
      w,
      h,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }

  /// Exact cached tile for a level-0-space tile address, else the nearest
  /// cached coarse ancestor covering it — the pyramid's instant-paint path.
  ui.Image? _imageForLevelTile(int level, int col, int row) {
    final pyramid = _pyramid;
    if (pyramid == null) return null;
    final exactKey = _LevelTileKey(level, col, row);
    final exact = _cache.get(exactKey);
    if (exact != null && !_failedKeys.contains(exactKey)) return exact;
    for (final a in coarseAncestors(
      level: level,
      col: col,
      row: row,
      maxLevel: pyramid.levelCount - 1,
    )) {
      final key = _LevelTileKey(a.level, a.col, a.row);
      final img = _cache.get(key);
      if (img != null && !_failedKeys.contains(key)) return img;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewportSize = constraints.biggest;
        if (!_initialized && _viewportSize != Size.zero) {
          _initialized = true;
          _transform = ViewportTransform(
            scale: _minScale,
            offset: Offset.zero,
          ).clampToImage(_imageSize, _viewportSize);
        }

        final source = _source;
        final List<VisibleTile> tiles;
        final int level;
        if (source == null) {
          level = 0;
          tiles = _legacyGrid.visibleTiles(
            _transform.visibleWorld(_viewportSize),
          );
          for (final tile in tiles) {
            _ensureTile(
              tile.coord,
              () => _createTileImage(tile.coord),
            );
          }
        } else {
          level = _level;
          // Grid in level-k units; the painter scales worldRects back to
          // level-0 space by the level factor.
          final size = source.pyramid.levelSize(level);
          final grid = TileGrid(
            imageWidth: size.width.round(),
            imageHeight: size.height.round(),
            tileSize: source.tileSize,
          );
          final factor = 1 << level;
          final visible = _transform.visibleWorld(_viewportSize);
          tiles = grid.visibleTiles(
            Rect.fromLTRB(
              visible.left / factor,
              visible.top / factor,
              visible.right / factor,
              visible.bottom / factor,
            ),
          );
          for (final tile in tiles) {
            final key = _LevelTileKey(level, tile.coord.col, tile.coord.row);
            _ensureTile(
              key,
              () => _createSourceTile(level, tile.coord.col, tile.coord.row),
            );
          }
        }

        return GestureDetector(
          onScaleStart: _onScaleStart,
          onScaleUpdate: _onScaleUpdate,
          behavior: HitTestBehavior.opaque,
          child: ClipRect(
            child: CustomPaint(
              painter: _TilePainter(
                tiles: tiles,
                level: level,
                transform: _transform,
                cache: _cache,
                resolve: source == null
                    ? null
                    : (col, row) => _imageForLevelTile(level, col, row),
                shader: _shader,
                exposure: widget.exposure,
                contrast: widget.contrast,
                saturation: widget.saturation,
              ),
              size: _viewportSize,
            ),
          ),
        );
      },
    );
  }
}

/// Paints the visible tiles, each through the shared grading shader.
///
/// Uniform contract (must match `shaders/grade.frag`): floats 0,1 = drawn rect
/// size; 2 = exposure; 3 = contrast; 4 = saturation; sampler 0 = tile texture.
class _TilePainter extends CustomPainter {
  _TilePainter({
    required this.tiles,
    required this.level,
    required this.transform,
    required this.cache,
    required this.resolve,
    required this.shader,
    required this.exposure,
    required this.contrast,
    required this.saturation,
  });

  final List<VisibleTile> tiles;
  final int level;
  final ViewportTransform transform;
  final TileLru<Object, ui.Image> cache;

  /// Source mode: resolves a fine tile to its cached image or a coarse
  /// ancestor's (null path for the legacy in-memory mode).
  final ui.Image? Function(int col, int row)? resolve;
  final ui.FragmentShader shader;
  final double exposure;
  final double contrast;
  final double saturation;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(const Color(0xFF101010), BlendMode.src);

    final factor = (1 << level).toDouble();
    for (final tile in tiles) {
      final ui.Image? img;
      final r = resolve;
      if (r != null) {
        img = r(tile.coord.col, tile.coord.row);
      } else {
        img = cache.get(tile.coord);
      }
      if (img == null) continue; // still loading; repainted once decoded

      final topLeft = transform.worldToScreen(tile.worldRect.topLeft * factor);
      final bottomRight = transform.worldToScreen(
        tile.worldRect.bottomRight * factor,
      );
      final rect = Rect.fromPoints(topLeft, bottomRight);

      shader
        ..setFloat(0, rect.width)
        ..setFloat(1, rect.height)
        ..setFloat(2, exposure)
        ..setFloat(3, contrast)
        ..setFloat(4, saturation)
        ..setImageSampler(0, img);
      canvas.drawRect(rect, Paint()..shader = shader);
    }
  }

  @override
  bool shouldRepaint(_TilePainter old) =>
      old.transform.scale != transform.scale ||
      old.transform.offset != transform.offset ||
      old.tiles.length != tiles.length ||
      old.level != level ||
      old.exposure != exposure ||
      old.contrast != contrast ||
      old.saturation != saturation;
}
