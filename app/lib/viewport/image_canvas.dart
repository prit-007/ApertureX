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
import '../edit/parameter.dart';
import '../edit/recipe.dart';
import '../edit/recipe_controller.dart';
import '../engine/engine.dart';

/// The shared editing canvas, rendered by BOTH shells (ADR 0008 invariant:
/// switching shells must not change the image).
///
/// Performance model (this is a **60fps editor**):
///  * The source is decoded once at **proxy resolution** ([_maxPreviewDim]) —
///    small enough that every CPU pass is milliseconds, big enough to look
///    sharp on any phone. Export still runs full-resolution (see the editor).
///  * The expensive, neighbour-aware **base** pass (geometry → spatial → masks)
///    only re-runs when those settings change.
///  * The point-wise **grade** is baked into a small 3D LUT (preview size) and
///    only re-baked when a grade setting changes.
///  * The GPU shader then grades the (already-processed) base texture in one
///    texture fetch per pixel, so scrubbing a slider is just a cheap re-bake.
class ImageCanvas extends ConsumerStatefulWidget {
  const ImageCanvas({super.key, this.imageBytes});

  /// JPEG bytes of the photo being edited. When null the canvas falls back to
  /// the built-in sample (used by the sample-editor entry point).
  final Uint8List? imageBytes;

  @override
  ConsumerState<ImageCanvas> createState() => _ImageCanvasState();
}

class _ImageCanvasState extends ConsumerState<ImageCanvas>
    with SingleTickerProviderStateMixin {
  /// Longest side of the preview proxy. ~2MP for a 4:3 phone photo.
  static const int _maxPreviewDim = 1600;

  /// Preview LUT is small; export grades per-pixel exactly.
  static const int _previewLutSize = 33;

  ui.FragmentProgram? _program;
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
  int _bakeToken = 0;
  int? _lastBaseKey;
  int? _lastGradeKey;
  int _importedKey = 0;
  int? _tatBand;
  Timer? _debounce;
  late final AnimationController _compare;

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
      var proxy = await _decode(jpeg);
      // Safety: if a caller ever hands us something larger than the preview
      // budget, re-decode downscaled rather than process full-resolution.
      final longest = math.max(proxy.$3, proxy.$4);
      if (longest > _maxPreviewDim) {
        final scale = _maxPreviewDim / longest;
        proxy.$1.dispose();
        proxy = await _decode(
          jpeg,
          targetWidth: math.max(1, (proxy.$3 * scale).round()),
          targetHeight: math.max(1, (proxy.$4 * scale).round()),
        );
      }
      if (!mounted) {
        proxy.$1.dispose();
        return;
      }
      _program = program;
      _source = proxy.$1;
      _sourceRgba = proxy.$2;
      _sourceWidth = proxy.$3;
      _sourceHeight = proxy.$4;
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

  /// Decodes [jpeg] to an RGBA proxy. The bytes are wrapped in a length-known
  /// [ui.ImmutableBuffer] so Skia reads them directly instead of copying through
  /// a temp buffer; [targetWidth]/[targetHeight] let the platform codec
  /// downscale during decode (DCT-scaled) when needed.
  Future<(ui.Image, Uint8List, int, int)> _decode(
    Uint8List jpeg, {
    int? targetWidth,
    int? targetHeight,
  }) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(jpeg);
    final codec = await ui.instantiateImageCodecFromBuffer(
      buffer,
      targetWidth: targetWidth,
      targetHeight: targetHeight,
    );
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return (image, data!.buffer.asUint8List(), image.width, image.height);
  }

  Future<ui.Image> _imageFrom(Uint8List rgba, int w, int h) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      rgba,
      w,
      h,
      ui.PixelFormat.rgba8888,
      completer.complete,
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
    r.sharpen,
    r.denoiseLuma,
    r.denoiseChroma,
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
    if (baseChanged) await _rebuildBase(recipe, token);
    if (gradeChanged) await _rebuildLut(recipe, token);
    if (token != _bakeToken) return;
    await _rebuildHistogram(recipe, token);
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
      _baseImage?.dispose();
      _baseImage = image;
      _baseRgba = baseRgba;
      _baseW = geo.width;
      _baseH = geo.height;
      _lastBaseKey = _baseKey(recipe);
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
    _debounce?.cancel();
    _compare.dispose();
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
    final source = _baseImage ?? _source;
    final lut = _lut;
    if (_failed || program == null || source == null || lut == null) {
      return _placeholder();
    }

    final tat = ref.watch(tatModeProvider);
    final content = Size(source.width.toDouble(), source.height.toDouble());

    return LayoutBuilder(
      builder: (context, constraints) {
        final bounds = constraints.biggest;
        final dst = _containRect(content, bounds);
        return GestureDetector(
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
          onPanStart: tat ? (d) => _tatTouch(d.localPosition, dst) : null,
          onPanUpdate: tat ? (d) => _tatAdjust(d, dst) : null,
          onPanEnd: tat
              ? (_) => ref
                    .read(recipeControllerProvider.notifier)
                    .commit(label: 'TAT')
              : null,
          child: Stack(
            children: [
              AnimatedBuilder(
                animation: _compare,
                builder: (context, _) => CustomPaint(
                  size: Size.infinite,
                  painter: _CanvasPainter(
                    shader: program.fragmentShader(),
                    source: source,
                    lut: lut,
                    lutSize: _activeLutSize.toDouble(),
                    dst: dst,
                    blend: _compare.value,
                  ),
                ),
              ),
              if (tat && _tatBand != null)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xCC000000),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Target: ${_bandNames[_tatBand!]}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
              if (_comparing)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'BEFORE',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontSize: 12,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// The largest rect of aspect [content] that fits centred inside [bounds].
  static Rect _containRect(Size content, Size bounds) {
    if (content.isEmpty || bounds.isEmpty) return Offset.zero & bounds;
    final fit = applyBoxFit(BoxFit.contain, content, bounds);
    return Alignment.center.inscribe(fit.destination, Offset.zero & bounds);
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

  int? _bandAt(Offset local, Rect dst) {
    final rgba = _baseRgba;
    if (rgba == null || _baseW == 0 || dst.width == 0 || dst.height == 0) {
      return null;
    }
    final fx = ((local.dx - dst.left) / dst.width).clamp(0.0, 1.0);
    final fy = ((local.dy - dst.top) / dst.height).clamp(0.0, 1.0);
    final x = (fx * _baseW).clamp(0, _baseW - 1).toInt();
    final y = (fy * _baseH).clamp(0, _baseH - 1).toInt();
    final i = (y * _baseW + x) * 4;
    if (i + 2 >= rgba.length) return null;
    return nearestHslBand(hueOf(rgba[i], rgba[i + 1], rgba[i + 2]));
  }

  void _tatTouch(Offset local, Rect dst) {
    final band = _bandAt(local, dst);
    if (band != null && band != _tatBand) setState(() => _tatBand = band);
  }

  void _tatAdjust(DragUpdateDetails d, Rect dst) {
    final band = _bandAt(d.localPosition, dst) ?? _tatBand;
    if (band == null) return;
    if (band != _tatBand) setState(() => _tatBand = band);
    final notifier = ref.read(recipeControllerProvider.notifier);
    final saturation = ref.read(recipeControllerProvider).recipe.hsl[band * 3 + 1];
    notifier.setHsl(
      band,
      saturation: saturation + (d.delta.dx / dst.width) * 2,
    );
  }

  Widget _placeholder() {
    final exposure = valueOf(
      ref.watch(recipeControllerProvider).recipe,
      Parameter.exposure,
    );
    return GestureDetector(
      onLongPressStart: (_) => setState(() => _comparing = true),
      onLongPressEnd: (_) => setState(() => _comparing = false),
      onLongPressCancel: () => setState(() => _comparing = false),
      child: Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.image_outlined, color: Colors.white24, size: 64),
            const SizedBox(height: 8),
            Text(
              _comparing ? 'BEFORE' : 'AFTER',
              style: const TextStyle(color: Colors.white70, letterSpacing: 2),
            ),
            const SizedBox(height: 4),
            Text(
              'EV ${exposure >= 0 ? '+' : ''}${exposure.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
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
    canvas.drawColor(const Color(0xFF101010), BlendMode.src);

    shader
      ..setFloat(0, dst.width)
      ..setFloat(1, dst.height)
      ..setFloat(2, lutSize)
      ..setImageSampler(0, source)
      ..setImageSampler(1, lut);
    canvas.drawRect(dst, Paint()..shader = shader);

    // Crossfade to the unedited source on top while comparing.
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
