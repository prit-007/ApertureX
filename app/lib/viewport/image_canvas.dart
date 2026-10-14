import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../color/grade_spec.dart';
import '../color/histogram_view.dart';
import '../color/imported_lut.dart';
import '../color/lut_atlas.dart';
import '../color/lut_texture.dart';
import '../color/spatial_spec.dart';
import '../color/tat.dart';
import '../edit/geometry_spec.dart';
import '../edit/recipe.dart';
import '../edit/recipe_controller.dart';
import '../engine/engine.dart';
import '../gesture/gesture_interpreter.dart';

/// The shared editing canvas, rendered by BOTH shells (ADR 0008 invariant).
///
/// **Gesture routing** (the fix for the classic zoom-vs-edit conflict): a single
/// scale recognizer owns the surface and routes by finger count —
///  * **1 finger** → the edit model (Snapseed shell, via [editInterpreter]) or,
///    in the Lightroom shell, pan; the Target-Adjust tool uses it too;
///  * **2+ fingers** → zoom + pan (the transform is built here);
///  * **long-press** → before/after compare; **double-tap** → reset zoom.
///
/// **Rendering**: the image is drawn **width-fit** and edge-to-edge; all chrome
/// floats above it as a HUD. Processing runs at proxy resolution with split
/// base/grade bakes (see the field docs below).
class ImageCanvas extends ConsumerStatefulWidget {
  const ImageCanvas({
    super.key,
    this.imageBytes,
    this.editInterpreter,
  });

  /// JPEG bytes of the photo being edited (null → the built-in sample).
  final Uint8List? imageBytes;

  /// When non-null, 1-finger drags are routed to this Snapseed gesture model
  /// instead of panning (Lightroom).
  final GestureInterpreter? editInterpreter;

  @override
  ConsumerState<ImageCanvas> createState() => _ImageCanvasState();
}

class _ImageCanvasState extends ConsumerState<ImageCanvas>
    with SingleTickerProviderStateMixin {
  /// Longest side of the preview proxy. ~1.3MP for a 3:4 phone photo.
  static const int _maxPreviewDim = 1440;

  /// Preview LUT is small; export grades per-pixel exactly.
  static const int _previewLutSize = 33;

  ui.FragmentProgram? _program;
  ui.FragmentShader? _shader;
  ui.Image? _source; // proxy, unedited — for the before/after compare
  Uint8List? _sourceRgba;
  int _sourceWidth = 0;
  int _sourceHeight = 0;

  ui.Image? _baseImage; // geometry + spatial + masks applied
  Uint8List? _baseRgba;
  int _baseW = 0;
  int _baseH = 0;

  ui.Image? _lut;
  int _activeLutSize = _previewLutSize;

  bool _failed = false;
  bool _comparing = false;
  bool _needsReset = true;
  bool _disposed = false;
  int _bakeToken = 0;
  final ValueNotifier<bool> _busy = ValueNotifier(false);
  int? _lastBaseKey;
  int? _lastGradeKey;
  int _importedKey = 0;
  int? _tatBand;
  Timer? _debounce;
  late final AnimationController _compare;

  // Transform (own, so it never fights the edit gestures).
  double _scale = 1;
  Offset _offset = Offset.zero;
  double _minScale = 1;
  double _startScale = 1;
  Offset _startOffset = Offset.zero;
  Offset _startFocal = Offset.zero;
  bool _multi = false;

  @override
  void initState() {
    super.initState();
    _compare = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _load();
  }

  Future<void> _load() async {
    try {
      final program = await ui.FragmentProgram.fromAsset('shaders/lut.frag');
      final jpeg =
          widget.imageBytes ??
          await TesseraEngine.syntheticJpeg(width: 1024, height: 1024);
      final proxy = await _decode(jpeg, maxDim: _maxPreviewDim);
      if (!mounted) {
        proxy.$1.dispose();
        return;
      }
      _program = program;
      _shader = program.fragmentShader();
      _source = proxy.$1;
      _sourceRgba = proxy.$2;
      _sourceWidth = proxy.$3;
      _sourceHeight = proxy.$4;
      _needsReset = true;
      await _rebake(
        ref.read(recipeControllerProvider).recipe,
        baseChanged: true,
        gradeChanged: true,
      );
      if (mounted && _baseImage != null) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  /// Decodes [bytes] to RGBA in a **single** pass, capping the long side at
  /// [maxDim]. Reads the header via [ui.ImageDescriptor] (no pixel decode) so
  /// the one scaled decode is sized correctly — never decodes full-res then
  /// shrinks.
  Future<(ui.Image, Uint8List, int, int)> _decode(
    Uint8List bytes, {
    int? maxDim,
  }) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    var tw = descriptor.width;
    var th = descriptor.height;
    if (maxDim != null) {
      final longest = math.max(tw, th);
      if (longest > maxDim) {
        final scale = maxDim / longest;
        tw = math.max(1, (tw * scale).round());
        th = math.max(1, (th * scale).round());
      }
    }
    final codec = await ui.instantiateImageCodecFromBuffer(
      buffer,
      targetWidth: tw,
      targetHeight: th,
    );
    final frame = await codec.getNextFrame();
    codec.dispose();
    descriptor.dispose();
    final image = frame.image;
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    // Copy into a tightly-packed buffer with an explicit offset+length — never
    // rely on the ByteData's backing buffer being exactly w*h*4 at offset 0.
    final pixels = Uint8List.fromList(
      data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    return (image, pixels, image.width, image.height);
  }

  Future<ui.Image> _imageFrom(Uint8List rgba, int w, int h) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      rgba,
      w,
      h,
      ui.PixelFormat.rgba8888,
      completer.complete,
      rowBytes: w * 4,
    );
    return completer.future;
  }

  // --- change detection -----------------------------------------------------

  int _baseKey(EditRecipe r) => Object.hash(
    r.rotation,
    r.flipH,
    r.flipV,
    r.straighten,
    r.shadows,
    r.highlights,
    r.clarity,
    r.texture,
    r.dehaze,
    r.vignette,
    r.grain,
    r.sharpen,
    r.denoiseLuma,
    r.denoiseChroma,
    Object.hashAll(r.crop),
    Object.hashAll(r.layers),
  );

  int _gradeKey(EditRecipe r) => Object.hash(
    r.exposure,
    r.contrast,
    r.saturation,
    r.temperature,
    r.tint,
    r.vibrance,
    r.gradeShadowHue,
    r.gradeShadowSat,
    r.gradeMidHue,
    r.gradeMidSat,
    r.gradeHighlightHue,
    r.gradeHighlightSat,
    r.masterCurve,
    r.redCurve,
    r.greenCurve,
    r.blueCurve,
    Object.hashAll(r.hsl),
  );

  void _scheduleBake(EditRecipe recipe) {
    if (_program == null || _sourceRgba == null) return;
    final imported = ref.read(importedLutProvider)?.hashCode ?? 0;
    final baseChanged = _baseKey(recipe) != _lastBaseKey;
    final gradeChanged =
        _gradeKey(recipe) != _lastGradeKey || imported != _importedKey;
    if (!baseChanged && !gradeChanged) return;
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 16),
      () => _rebake(recipe, baseChanged: baseChanged, gradeChanged: gradeChanged),
    );
  }

  Future<void> _rebake(
    EditRecipe recipe, {
    required bool baseChanged,
    required bool gradeChanged,
  }) async {
    if (_program == null || _sourceRgba == null) return;
    final token = ++_bakeToken;
    try {
      if (baseChanged) {
        _setBusy(true);
        await _rebuildBase(recipe, token);
      }
      if (gradeChanged) await _rebuildLut(recipe, token);
      if (token != _bakeToken) return;
      await _rebuildHistogram(recipe, token);
    } finally {
      if (token == _bakeToken) _setBusy(false);
    }
  }

  void _setBusy(bool value) {
    if (!_disposed) _busy.value = value;
  }

  Future<void> _rebuildBase(EditRecipe recipe, int token) async {
    final raw = _sourceRgba!;
    final geometry = GeometrySpec.fromRecipe(recipe);
    final spatial = SpatialSpec.fromRecipe(recipe);

    final geo = await TesseraEngine.applyGeometry(
      raw,
      width: _sourceWidth,
      height: _sourceHeight,
      spec: geometry,
    );
    if (token != _bakeToken) return;
    final spatialized = await TesseraEngine.applySpatial(
      geo.rgba,
      width: geo.width,
      height: geo.height,
      spec: spatial,
    );
    if (token != _bakeToken) return;
    final baseRgba = await TesseraEngine.applyMasks(
      spatialized,
      width: geo.width,
      height: geo.height,
      layers: recipe.layers,
    );
    final image = await _imageFrom(baseRgba, geo.width, geo.height);
    if (!mounted || token != _bakeToken) {
      image.dispose();
      return;
    }
    setState(() {
      final dimsChanged = _baseW != geo.width || _baseH != geo.height;
      _baseImage?.dispose();
      _baseImage = image;
      _baseRgba = baseRgba;
      _baseW = geo.width;
      _baseH = geo.height;
      _lastBaseKey = _baseKey(recipe);
      if (dimsChanged) _needsReset = true;
    });
  }

  Future<void> _rebuildLut(EditRecipe recipe, int token) async {
    final spec = GradeSpec.fromRecipe(recipe);
    final imported = ref.read(importedLutProvider);
    final ui.Image lutImage;
    final int lutSize;
    if (imported != null) {
      lutImage = await lutAtlasToImage(imported);
      lutSize = imported.size;
    } else {
      final data = await TesseraEngine.bakeLut3d(
        spec,
        size: _previewLutSize,
      );
      if (token != _bakeToken) return;
      lutImage = await lutAtlasToImage(
        LutAtlas(size: data.size, rgba: data.rgba),
      );
      lutSize = data.size;
    }
    if (!mounted || token != _bakeToken) {
      lutImage.dispose();
      return;
    }
    setState(() {
      _lut?.dispose();
      _lut = lutImage;
      _activeLutSize = lutSize;
      _lastGradeKey = _gradeKey(recipe);
      _importedKey = imported?.hashCode ?? 0;
    });
  }

  Future<void> _rebuildHistogram(EditRecipe recipe, int token) async {
    final baseRgba = _baseRgba;
    if (baseRgba == null) return;
    final histogram = await TesseraEngine.histogramGraded(
      rgba: baseRgba,
      width: _baseW,
      height: _baseH,
      sampleDim: 256,
      spec: GradeSpec.fromRecipe(recipe),
    );
    if (token != _bakeToken) return;
    ref.read(histogramProvider.notifier).publish(histogram);
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    _compare.dispose();
    _busy.dispose();
    _shader?.dispose();
    _source?.dispose();
    _baseImage?.dispose();
    _lut?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(recipeControllerProvider, (previous, next) {
      if (previous?.recipe != next.recipe) _scheduleBake(next.recipe);
    });
    ref.listen(
      importedLutProvider,
      (_, _) => _scheduleBake(ref.read(recipeControllerProvider).recipe),
    );

    final program = _program;
    final shader = _shader;
    final source = _baseImage ?? _source;
    final lut = _lut;
    if (_failed || program == null || shader == null || source == null || lut == null) {
      return _placeholder();
    }

    final tat = ref.watch(tatModeProvider);
    final content = Size(source.width.toDouble(), source.height.toDouble());

    return LayoutBuilder(
      builder: (context, constraints) {
        final bounds = constraints.biggest;
        final fitted = _widthFit(content, bounds);
        if (_needsReset) {
          _needsReset = false;
          _minScale = math.min(1.0, bounds.height / fitted.height);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _resetView(fitted, bounds));
          });
        }

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onScaleStart: (d) => _onScaleStart(d, fitted, tat),
                onScaleUpdate: (d) => _onScaleUpdate(d, fitted, bounds, tat),
                onScaleEnd: (_) => _onScaleEnd(),
                onDoubleTap: () => _resetView(fitted, bounds),
                onLongPressStart: (_) {
                  setState(() => _comparing = true);
                  _compare.forward();
                },
                onLongPressEnd: (_) {
                  setState(() => _comparing = false);
                  _compare.reverse();
                },
                onLongPressCancel: () {
                  setState(() => _comparing = false);
                  _compare.reverse();
                },
                child: ClipRect(
                  child: Transform(
                    alignment: Alignment.topLeft,
                    transform: Matrix4.identity()
                      ..translateByDouble(_offset.dx, _offset.dy, 0, 1)
                      ..scaleByDouble(_scale, _scale, _scale, 1),
                    child: SizedBox(
                      width: fitted.width,
                      height: fitted.height,
                      child: AnimatedBuilder(
                        animation: _compare,
                        builder: (context, _) => CustomPaint(
                          size: fitted,
                          painter: _CanvasPainter(
                            shader: shader,
                            source: source,
                            lut: lut,
                            lutSize: _activeLutSize.toDouble(),
                            dst: Offset.zero & fitted,
                            blend: _compare.value,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (tat && _tatBand != null)
              Positioned(
                top: 8,
                left: 8,
                child: IgnorePointer(
                  child: _Chip(text: 'Target: ${_bandNames[_tatBand!]}'),
                ),
              ),
            if (_comparing)
              const Positioned(
                top: 8,
                right: 8,
                child: IgnorePointer(child: _Badge(text: 'BEFORE')),
              ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ValueListenableBuilder<bool>(
                valueListenable: _busy,
                builder: (context, busy, _) => busy
                    ? LinearProgressIndicator(
                        minHeight: 2,
                        backgroundColor: Colors.transparent,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        );
      },
    );
  }

  // --- gesture routing ------------------------------------------------------

  void _onScaleStart(ScaleStartDetails d, Size fitted, bool tat) {
    _startScale = _scale;
    _startOffset = _offset;
    _startFocal = d.localFocalPoint;
    _multi = d.pointerCount >= 2;
    if (_multi) return;
    if (widget.editInterpreter != null) {
      widget.editInterpreter!.onPanStart(d.localFocalPoint);
    } else if (tat) {
      _tatTouch(d.localFocalPoint, fitted);
    }
  }

  void _onScaleUpdate(
    ScaleUpdateDetails d,
    Size fitted,
    Size bounds,
    bool tat,
  ) {
    if (d.pointerCount >= 2 || _multi) {
      if (!_multi) {
        // Transition 1 -> 2 fingers: cancel the edit (no tap-reset) and
        // re-anchor so the pinch doesn't jump.
        widget.editInterpreter?.cancel();
        _multi = true;
        _startScale = _scale;
        _startOffset = _offset;
        _startFocal = d.localFocalPoint;
      }
      final scale = (_startScale * d.scale).clamp(_minScale, _maxScale);
      final scene = (_startFocal - _startOffset) / _startScale;
      final offset = d.localFocalPoint - scene * scale;
      setState(() {
        _scale = scale;
        _offset = _clampOffset(offset, scale, fitted, bounds);
      });
      return;
    }
    if (_multi) return;
    if (widget.editInterpreter != null) {
      widget.editInterpreter!.onPanUpdate(d.focalPointDelta);
    } else if (tat) {
      _tatAdjust(d.localFocalPoint, d.focalPointDelta, fitted);
    } else {
      setState(() {
        _offset = _clampOffset(
          _offset + d.focalPointDelta,
          _scale,
          fitted,
          bounds,
        );
      });
    }
  }

  void _onScaleEnd() {
    if (!_multi) widget.editInterpreter?.onPanEnd();
    _multi = false;
  }

  static const double _maxScale = 8;

  Offset _toScene(Offset viewport) => (viewport - _offset) / _scale;

  Offset _clampOffset(Offset o, double scale, Size fitted, Size bounds) {
    final cw = fitted.width * scale;
    final ch = fitted.height * scale;
    final cx = cw <= bounds.width
        ? (bounds.width - cw) / 2
        : o.dx.clamp(bounds.width - cw, 0.0);
    final cy = ch <= bounds.height
        ? (bounds.height - ch) / 2
        : o.dy.clamp(bounds.height - ch, 0.0);
    return Offset(cx, cy);
  }

  /// The width-fit display size of [content] within [bounds].
  static Size _widthFit(Size content, Size bounds) {
    if (content.width <= 0 || bounds.width <= 0) return bounds;
    return Size(bounds.width, bounds.width * content.height / content.width);
  }

  void _resetView(Size fitted, Size bounds) {
    _scale = 1;
    _offset = Offset(
      0,
      fitted.height < bounds.height ? (bounds.height - fitted.height) / 2 : 0,
    );
  }

  static const List<String> _bandNames = [
    'Red',
    'Orange',
    'Yellow',
    'Green',
    'Aqua',
    'Blue',
    'Purple',
    'Magenta',
  ];

  int? _bandAt(Offset viewportLocal, Size fitted) {
    final rgba = _baseRgba;
    if (rgba == null || _baseW == 0 || fitted.width == 0 || fitted.height == 0) {
      return null;
    }
    final scene = _toScene(viewportLocal);
    final fx = (scene.dx / fitted.width).clamp(0.0, 1.0);
    final fy = (scene.dy / fitted.height).clamp(0.0, 1.0);
    if (scene.dx < 0 || scene.dy < 0) return null;
    final x = (fx * _baseW).clamp(0, _baseW - 1).toInt();
    final y = (fy * _baseH).clamp(0, _baseH - 1).toInt();
    final i = (y * _baseW + x) * 4;
    if (i + 2 >= rgba.length) return null;
    return nearestHslBand(hueOf(rgba[i], rgba[i + 1], rgba[i + 2]));
  }

  void _tatTouch(Offset local, Size fitted) {
    final band = _bandAt(local, fitted);
    if (band != null && band != _tatBand) setState(() => _tatBand = band);
  }

  void _tatAdjust(Offset local, Offset delta, Size fitted) {
    final band = _bandAt(local, fitted) ?? _tatBand;
    if (band == null) return;
    if (band != _tatBand) setState(() => _tatBand = band);
    final notifier = ref.read(recipeControllerProvider.notifier);
    final saturation = ref.read(recipeControllerProvider).recipe.hsl[band * 3 + 1];
    notifier.setHsl(
      band,
      saturation: saturation + (delta.dx / fitted.width) * 2,
    );
  }

  Widget _placeholder() {
    final scheme = Theme.of(context).colorScheme;
    if (_failed) {
      return ColoredBox(
        color: scheme.surfaceContainerLowest,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.broken_image_outlined,
                color: scheme.onSurfaceVariant,
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                'Preview unavailable',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }
    return ColoredBox(
      color: scheme.surfaceContainerLowest,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading image…',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xCC000000),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: scheme.onPrimary,
          fontSize: 12,
          letterSpacing: 1.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Draws the base texture through `lut.frag` inside the aspect-correct [dst]
/// rect, sampling the packed 3D LUT atlas, and crossfades to the raw source
/// while comparing ([blend] 0..1).
class _CanvasPainter extends CustomPainter {
  _CanvasPainter({
    required this.shader,
    required this.source,
    required this.lut,
    required this.lutSize,
    required this.dst,
    required this.blend,
  });

  final ui.FragmentShader shader;
  final ui.Image source;
  final ui.Image lut;
  final double lutSize;
  final Rect dst;
  final double blend;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(const Color(0xFF000000), BlendMode.src);

    shader
      ..setFloat(0, dst.width)
      ..setFloat(1, dst.height)
      ..setFloat(2, lutSize)
      ..setImageSampler(0, source)
      ..setImageSampler(1, lut);
    canvas.drawRect(dst, Paint()..shader = shader);

    if (blend > 0) {
      canvas.drawImageRect(
        source,
        Rect.fromLTWH(0, 0, source.width.toDouble(), source.height.toDouble()),
        dst,
        Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: blend),
      );
    }
  }

  @override
  bool shouldRepaint(_CanvasPainter old) =>
      old.source != source || old.lut != lut || old.blend != blend || old.dst != dst;
}
