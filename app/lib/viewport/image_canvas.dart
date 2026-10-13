import 'dart:async';
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
import '../edit/geometry_spec.dart';
import '../edit/parameter.dart';
import '../edit/recipe.dart';
import '../edit/recipe_controller.dart';
import '../engine/engine.dart';

/// The shared editing canvas, rendered by BOTH shells (ADR 0008 invariant:
/// switching shells must not change the image).
///
/// Grades the image by sampling a **CPU-baked 3D LUT** (packed as a 2D atlas)
/// in `shaders/lut.frag` — the recipe drives the bake, so preview matches the
/// Rust export path. Falls back to a neutral placeholder if the engine or
/// shader is unavailable (e.g. widget tests).
class ImageCanvas extends ConsumerStatefulWidget {
  const ImageCanvas({super.key});

  @override
  ConsumerState<ImageCanvas> createState() => _ImageCanvasState();
}

class _ImageCanvasState extends ConsumerState<ImageCanvas>
    with SingleTickerProviderStateMixin {
  static const int _lutSize = 33;

  ui.FragmentProgram? _program;
  ui.Image? _source;
  ui.Image? _baseImage;
  ui.Image? _lut;
  Uint8List? _sourceRgba;
  int _sourceWidth = 0;
  int _sourceHeight = 0;
  bool _failed = false;
  bool _comparing = false;
  int _bakeToken = 0;
  int _activeLutSize = _lutSize;
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
      final jpeg = await TesseraEngine.syntheticJpeg(width: 1024, height: 1024);
      final decoded = await TesseraEngine.decodeJpegRgba(jpeg);
      final source = await _imageFrom(
        decoded.rgba,
        decoded.width,
        decoded.height,
      );
      if (!mounted) {
        source.dispose();
        return;
      }
      _program = program;
      _source = source;
      _sourceRgba = decoded.rgba;
      _sourceWidth = decoded.width;
      _sourceHeight = decoded.height;
      await _rebake(ref.read(recipeControllerProvider).recipe);
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
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

  Future<void> _rebake(EditRecipe recipe) async {
    final raw = _sourceRgba;
    if (_program == null || raw == null) return;
    final token = ++_bakeToken;
    final spec = GradeSpec.fromRecipe(recipe);
    final spatial = SpatialSpec.fromRecipe(recipe);
    final geometry = GeometrySpec.fromRecipe(recipe);

    // Geometry (flip/rotate/straighten) then the spatial pass, then LUT grading
    // — matching the export order. Geometry may change the pixel dimensions.
    final geo = await TesseraEngine.applyGeometry(
      raw,
      width: _sourceWidth,
      height: _sourceHeight,
      spec: geometry,
    );
    final baseRgba = await TesseraEngine.applySpatial(
      geo.rgba,
      width: geo.width,
      height: geo.height,
      spec: spatial,
    );
    final baseImage = await _imageFrom(baseRgba, geo.width, geo.height);

    // Prefer an imported preset LUT while one is active; otherwise bake the
    // recipe grade into the LUT atlas.
    final imported = ref.read(importedLutProvider);
    final ui.Image lutImage;
    final int lutSize;
    if (imported != null) {
      lutImage = await lutAtlasToImage(imported);
      lutSize = imported.size;
    } else {
      final data = await TesseraEngine.bakeLut3d(spec, size: _lutSize);
      lutImage = await lutAtlasToImage(
        LutAtlas(size: data.size, rgba: data.rgba),
      );
      lutSize = data.size;
    }
    final histogram = await TesseraEngine.histogramGraded(
      rgba: baseRgba,
      width: geo.width,
      height: geo.height,
      sampleDim: 256,
      spec: spec,
    );

    if (!mounted || token != _bakeToken) {
      baseImage.dispose();
      lutImage.dispose();
      return;
    }
    setState(() {
      _baseImage?.dispose();
      _baseImage = baseImage;
      _lut?.dispose();
      _lut = lutImage;
      _activeLutSize = lutSize;
    });
    ref.read(histogramProvider.notifier).publish(histogram);
  }

  void _scheduleBake(EditRecipe recipe) {
    if (_program == null) return; // not ready (or no engine, e.g. tests)
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 40), () => _rebake(recipe));
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
      child: AnimatedBuilder(
        animation: _compare,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _CanvasPainter(
            shader: program.fragmentShader(),
            source: source,
            lut: lut,
            lutSize: _activeLutSize.toDouble(),
            blend: _compare.value,
          ),
        ),
      ),
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

/// Draws the source through `lut.frag`, sampling the packed 3D LUT atlas, and
/// crossfades to the raw source while comparing ([blend] 0..1).
class _CanvasPainter extends CustomPainter {
  _CanvasPainter({
    required this.shader,
    required this.source,
    required this.lut,
    required this.lutSize,
    required this.blend,
  });

  final ui.FragmentShader shader;
  final ui.Image source;
  final ui.Image lut;
  final double lutSize;
  final double blend;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(const Color(0xFF101010), BlendMode.src);

    final rect = Offset.zero & size;

    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, lutSize)
      ..setImageSampler(0, source)
      ..setImageSampler(1, lut);
    canvas.drawRect(rect, Paint()..shader = shader);

    // Crossfade to the unedited source on top while comparing.
    if (blend > 0) {
      canvas.drawImageRect(
        source,
        Rect.fromLTWH(0, 0, source.width.toDouble(), source.height.toDouble()),
        rect,
        Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: blend),
      );
    }
  }

  @override
  bool shouldRepaint(_CanvasPainter old) =>
      old.source != source || old.lut != lut || old.blend != blend;
}
