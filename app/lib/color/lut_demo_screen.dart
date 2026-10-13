import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../engine/engine.dart';
import 'lut_atlas.dart';
import 'lut_texture.dart';

/// Slice D spike demo: grades an image purely by sampling a **CPU-baked 3D LUT**
/// (packed as a 2D atlas) in `shaders/lut.frag` — no per-pixel colour math on
/// the GPU. Drag the sliders to re-bake the LUT in Rust and see it applied live.
class LutDemoScreen extends StatefulWidget {
  const LutDemoScreen({super.key});

  @override
  State<LutDemoScreen> createState() => _LutDemoScreenState();
}

class _LutDemoScreenState extends State<LutDemoScreen> {
  static const int _lutSize = 33;

  ui.FragmentProgram? _program;
  ui.Image? _source;
  ui.Image? _lut;
  String? _error;

  double _exposure = 0;
  double _contrast = 0;
  double _saturation = 0;
  bool _showOriginal = false;
  int _bakeToken = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final program = await ui.FragmentProgram.fromAsset('shaders/lut.frag');
      final jpeg = await TesseraEngine.syntheticJpeg(width: 768, height: 768);
      final decoded = await TesseraEngine.decodeJpegRgba(jpeg);
      final source = await _imageFromRgba(
        decoded.rgba,
        decoded.width,
        decoded.height,
      );
      if (!mounted) return;
      setState(() => _program = program);
      await _rebake();
      setState(() => _source = source);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _rebake() async {
    final token = ++_bakeToken;
    final data = await TesseraEngine.bakeLut3d(
      size: _lutSize,
      exposure: _exposure,
      contrast: _contrast,
      saturation: _saturation,
    );
    final image = await lutAtlasToImage(
      LutAtlas(size: data.size, rgba: data.rgba),
    );
    // Drop a stale bake if a newer one landed first.
    if (!mounted || token != _bakeToken) {
      image.dispose();
      return;
    }
    setState(() {
      _lut?.dispose();
      _lut = image;
    });
  }

  Future<ui.Image> _imageFromRgba(Uint8List rgba, int w, int h) {
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

  void _set(void Function() change) {
    setState(change);
    _rebake();
  }

  @override
  void dispose() {
    _source?.dispose();
    _lut?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final program = _program;
    final source = _source;
    final lut = _lut;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('3D LUT spike')),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            )
          : (program == null || source == null || lut == null)
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTapDown: (_) => setState(() => _showOriginal = true),
                    onTapUp: (_) => setState(() => _showOriginal = false),
                    onTapCancel: () => setState(() => _showOriginal = false),
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: _LutPainter(
                        shader: program.fragmentShader(),
                        source: source,
                        lut: lut,
                        lutSize: _lutSize.toDouble(),
                        bypass: _showOriginal,
                      ),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'hold image to compare · sliders re-bake the LUT in Rust',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ),
                _slider('Exposure', _exposure, -2, 2, (v) => _set(() => _exposure = v)),
                _slider('Contrast', _contrast, -1, 1, (v) => _set(() => _contrast = v)),
                _slider('Saturation', _saturation, -1, 1, (v) => _set(() => _saturation = v)),
                const SizedBox(height: 8),
              ],
            ),
    );
  }

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            child: Text(label, style: const TextStyle(color: Colors.white70)),
          ),
          Expanded(
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              value.toStringAsFixed(2),
              textAlign: TextAlign.end,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}

/// Draws the source through `lut.frag`, sampling the packed 3D LUT atlas.
class _LutPainter extends CustomPainter {
  _LutPainter({
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
      // Hold-to-compare: raw source, no LUT.
      canvas.drawImageRect(
        source,
        Rect.fromLTWH(0, 0, source.width.toDouble(), source.height.toDouble()),
        Offset.zero & size,
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

  @override
  bool shouldRepaint(_LutPainter old) =>
      old.source != source || old.lut != lut || old.bypass != bypass;
}
