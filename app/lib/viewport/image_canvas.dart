import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../color/lut_atlas.dart';
import '../color/lut_texture.dart';
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

class _ImageCanvasState extends ConsumerState<ImageCanvas> {
  static const int _lutSize = 33;

  ui.FragmentProgram? _program;
  ui.Image? _source;
  ui.Image? _lut;
  bool _failed = false;
  bool _comparing = false;
  int _bakeToken = 0;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
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
    if (_program == null) return;
    final token = ++_bakeToken;
    final data = await TesseraEngine.bakeLut3d(
      size: _lutSize,
      exposure: recipe.exposure,
      contrast: recipe.contrast,
      saturation: recipe.saturation,
      temperature: recipe.temperature,
      tint: recipe.tint,
      vibrance: recipe.vibrance,
    );
    final image = await lutAtlasToImage(
      LutAtlas(size: data.size, rgba: data.rgba),
    );
    if (!mounted || token != _bakeToken) {
      image.dispose();
      return;
    }
    setState(() {
      _lut?.dispose();
      _lut = image;
    });
  }

  void _scheduleBake(EditRecipe recipe) {
    if (_program == null) return; // not ready (or no engine, e.g. tests)
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 40), () => _rebake(recipe));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _source?.dispose();
    _lut?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(recipeControllerProvider, (previous, next) {
      if (previous?.recipe != next.recipe) _scheduleBake(next.recipe);
    });

    final program = _program;
    final source = _source;
    final lut = _lut;
    if (_failed || program == null || source == null || lut == null) {
      return _placeholder();
    }

    return GestureDetector(
      onLongPressStart: (_) => setState(() => _comparing = true),
      onLongPressEnd: (_) => setState(() => _comparing = false),
      onLongPressCancel: () => setState(() => _comparing = false),
      child: CustomPaint(
        size: Size.infinite,
        painter: _CanvasPainter(
          shader: program.fragmentShader(),
          source: source,
          lut: lut,
          lutSize: _lutSize.toDouble(),
          bypass: _comparing,
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

/// Draws the source through `lut.frag`, sampling the packed 3D LUT atlas.
class _CanvasPainter extends CustomPainter {
  _CanvasPainter({
    required this.shader,
    required this.source,
    required this.lut,
    required this.lutSize,
    required this.bypass,
  });

  final ui.FragmentShader shader;
  final ui.Image source;
  final ui.Image lut;
  final double lutSize;
  final bool bypass;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(const Color(0xFF101010), BlendMode.src);

    if (bypass) {
      canvas.drawImageRect(
        source,
        Rect.fromLTWH(0, 0, source.width.toDouble(), source.height.toDouble()),
        _coverRect(size, source),
        Paint(),
      );
      return;
    }

    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, lutSize)
      ..setImageSampler(0, source)
      ..setImageSampler(1, lut);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  static Rect _coverRect(Size size, ui.Image image) => Offset.zero & size;

  @override
  bool shouldRepaint(_CanvasPainter old) =>
      old.source != source || old.lut != lut || old.bypass != bypass;
}
