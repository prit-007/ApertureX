import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'tile_grid.dart';
import 'tile_lru.dart';
import 'viewport_transform.dart';

/// A zoomable, pannable viewport that composites a decoded RGBA image as tiles
/// through the grading shader.
///
/// Demonstrates the P1 tile viewport: a large image stays sharp at any zoom
/// because only the visible tiles are drawn — extracted from a single full
/// decode and cached in a byte-budgeted LRU (ARCHITECTURE §5). Navigation uses
/// a single scale gesture (pinch to zoom, drag to pan, anchored at the focal
/// point); grading uniforms are applied identically per tile so seams are
/// invisible.
class TileViewport extends StatefulWidget {
  const TileViewport({
    super.key,
    required this.rgba,
    required this.imageWidth,
    required this.imageHeight,
    required this.shaderProgram,
    this.exposure = 0,
    this.contrast = 0,
    this.saturation = 0,
    this.tileSize = 512,
    this.maxCacheBytes = 96 * 1024 * 1024,
    this.maxZoomFactor = 8,
  });

  /// Full decoded RGBA8 pixels (length `imageWidth * imageHeight * 4`).
  final Uint8List rgba;
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
  late final TileGrid _grid = TileGrid(
    imageWidth: widget.imageWidth,
    imageHeight: widget.imageHeight,
    tileSize: widget.tileSize,
  );

  late final ui.FragmentShader _shader = widget.shaderProgram.fragmentShader();

  late final TileLru<TileCoord, ui.Image> _cache = TileLru<TileCoord, ui.Image>(
    maxBytes: widget.maxCacheBytes,
    sizeOf: (img) => img.width * img.height * 4,
    onEvict: (_, img) => img.dispose(),
  );

  final Set<TileCoord> _inFlight = {};

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

  Future<void> _ensureTile(TileCoord coord) async {
    if (_cache.containsKey(coord) || _inFlight.contains(coord)) return;
    _inFlight.add(coord);
    try {
      final img = await _createTileImage(coord);
      if (!mounted) {
        img.dispose();
        return;
      }
      _cache.put(coord, img);
      setState(() {});
    } finally {
      _inFlight.remove(coord);
    }
  }

  Future<ui.Image> _createTileImage(TileCoord coord) async {
    final rect = _grid.tileRect(coord.col, coord.row);
    final w = rect.width.round();
    final h = rect.height.round();
    final x = rect.left.round();
    final y = rect.top.round();

    final bytes = Uint8List(w * h * 4);
    for (var row = 0; row < h; row++) {
      final src = ((y + row) * widget.imageWidth + x) * 4;
      final dst = row * w * 4;
      bytes.setRange(dst, dst + w * 4, widget.rgba, src);
    }

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

        final tiles = _grid.visibleTiles(_transform.visibleWorld(_viewportSize));
        for (final tile in tiles) {
          _ensureTile(tile.coord);
        }

        return GestureDetector(
          onScaleStart: _onScaleStart,
          onScaleUpdate: _onScaleUpdate,
          behavior: HitTestBehavior.opaque,
          child: ClipRect(
            child: CustomPaint(
              painter: _TilePainter(
                tiles: tiles,
                transform: _transform,
                cache: _cache,
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
    required this.transform,
    required this.cache,
    required this.shader,
    required this.exposure,
    required this.contrast,
    required this.saturation,
  });

  final List<VisibleTile> tiles;
  final ViewportTransform transform;
  final TileLru<TileCoord, ui.Image> cache;
  final ui.FragmentShader shader;
  final double exposure;
  final double contrast;
  final double saturation;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(const Color(0xFF101010), BlendMode.src);

    for (final tile in tiles) {
      final img = cache.get(tile.coord);
      if (img == null) continue; // still loading; repainted once decoded

      final topLeft = transform.worldToScreen(tile.worldRect.topLeft);
      final bottomRight = transform.worldToScreen(tile.worldRect.bottomRight);
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
      old.exposure != exposure ||
      old.contrast != contrast ||
      old.saturation != saturation;
}
