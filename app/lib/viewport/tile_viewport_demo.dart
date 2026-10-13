import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../engine/engine.dart';
import 'tile_viewport.dart';

/// Demo host for the P1 tile viewport: generates a large synthetic image in
/// Rust, decodes it once to RGBA, and shows it in a zoomable tile viewport with
/// a live exposure slider to demonstrate per-tile grading.
class TileViewportDemo extends StatefulWidget {
  const TileViewportDemo({super.key});

  @override
  State<TileViewportDemo> createState() => _TileViewportDemoState();
}

class _TileViewportDemoState extends State<TileViewportDemo> {
  // ~12 MP: large enough to tile (8×6 at 512px) and prove no full-image
  // texture is ever materialised.
  static const int _demoWidth = 4000;
  static const int _demoHeight = 3000;

  ui.FragmentProgram? _program;
  Uint8List? _rgba;
  int _width = 0;
  int _height = 0;
  String? _error;
  double _exposure = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final program = await ui.FragmentProgram.fromAsset('shaders/grade.frag');
      final jpeg = await TesseraEngine.syntheticJpeg(
        width: _demoWidth,
        height: _demoHeight,
      );
      final image = await TesseraEngine.decodeJpegRgba(jpeg);
      if (!mounted) return;
      setState(() {
        _program = program;
        _rgba = image.rgba;
        _width = image.width;
        _height = image.height;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final program = _program;
    final rgba = _rgba;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('Tile viewport')),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            )
          : (program == null || rgba == null)
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: TileViewport(
                    rgba: rgba,
                    imageWidth: _width,
                    imageHeight: _height,
                    shaderProgram: program,
                    exposure: _exposure,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Text(
                        'Exposure',
                        style: TextStyle(color: Colors.white70),
                      ),
                      Expanded(
                        child: Slider(
                          value: _exposure,
                          min: -2,
                          max: 2,
                          onChanged: (v) => setState(() => _exposure = v),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
