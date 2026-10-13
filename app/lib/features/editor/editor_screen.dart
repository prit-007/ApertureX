import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

import '../../color/grade_spec.dart';
import '../../color/lut_demo_screen.dart';
import '../../color/spatial_spec.dart';
import '../../edit/grade_mapping.dart';
import '../../edit/recipe.dart';
import '../../engine/engine.dart';
import '../../gesture/gesture_interpreter.dart';
import '../../viewport/tile_viewport_demo.dart';
import 'grade_painter.dart';

/// Seed editor screen: an invisible Snapseed-style gesture over a GPU-graded
/// image, now driven by a real [EditRecipe] — the single source of truth every
/// shell shares (ARCHITECTURE §16). Export grades on the CPU in Rust and writes
/// a JPEG.
class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late final GestureInterpreter _fsm;

  EditRecipe _recipe = EditRecipe.neutral;

  ui.FragmentShader? _shader;
  ui.Image? _texture;
  Uint8List? _rgba;
  int _imageWidth = 0;
  int _imageHeight = 0;

  GradeTool _active = GradeTool.exposure;
  bool _chromeVisible = false;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _fsm = GestureInterpreter(
      onToolChanged: (tool) => setState(() => _active = tool),
      onValueChanged: (tool, delta) => setState(() {
        _active = tool;
        _recipe = applyToolDelta(_recipe, tool, delta);
      }),
      onReset: (tool) => setState(() {
        _active = tool;
        _recipe = resetTool(_recipe, tool);
      }),
      onPhaseChanged: (phase) =>
          setState(() => _chromeVisible = phase != GesturePhase.idle),
    );
    _load();
  }

  Future<void> _load() async {
    final program = await ui.FragmentProgram.fromAsset('shaders/grade.frag');
    final jpeg = await TesseraEngine.syntheticJpeg(width: 1024, height: 1024);
    final decoded = await TesseraEngine.decodeJpegRgba(jpeg);
    final image = await _imageFromRgba(
      decoded.rgba,
      decoded.width,
      decoded.height,
    );
    if (!mounted) return;
    setState(() {
      _shader = program.fragmentShader();
      _texture = image;
      _rgba = decoded.rgba;
      _imageWidth = decoded.width;
      _imageHeight = decoded.height;
    });
  }

  Future<ui.Image> _imageFromRgba(Uint8List rgba, int width, int height) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      rgba,
      width,
      height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }

  double _toolValue(GradeTool tool) => switch (tool) {
    GradeTool.exposure => _recipe.exposure,
    GradeTool.contrast => _recipe.contrast,
    GradeTool.saturation => _recipe.saturation,
  };

  Future<void> _export() async {
    final rgba = _rgba;
    if (rgba == null) return;
    setState(() => _exporting = true);
    try {
      final jpeg = await TesseraEngine.exportJpeg(
        rgba: rgba,
        width: _imageWidth,
        height: _imageHeight,
        spec: GradeSpec.fromRecipe(_recipe),
        spatial: SpatialSpec.fromRecipe(_recipe),
      );
      final dir = await getApplicationDocumentsDirectory();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}/aperturex_$stamp.jpg');
      await file.writeAsBytes(jpeg, flush: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Exported ${file.path.split('/').last} (${jpeg.length} bytes)',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  void dispose() {
    _texture?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shader = _shader;
    final texture = _texture;
    final uniforms = GradeUniforms.fromRecipe(_recipe);

    return Scaffold(
      backgroundColor: Colors.black,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'lut-demo',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const LutDemoScreen()),
            ),
            child: const Icon(Icons.science),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'viewport-demo',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const TileViewportDemo()),
            ),
            child: const Icon(Icons.zoom_out_map),
          ),
        ],
      ),
      body: shader == null || texture == null
          ? const Center(child: CircularProgressIndicator())
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (d) => _fsm.onPanStart(d.localPosition),
              onPanUpdate: (d) => _fsm.onPanUpdate(d.delta),
              onPanEnd: (_) => _fsm.onPanEnd(),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(
                    painter: GradePainter(
                      shader: shader,
                      texture: texture,
                      exposure: uniforms.exposure,
                      contrast: uniforms.contrast,
                      saturation: uniforms.saturation,
                    ),
                  ),
                  _ToolChip(
                    active: _active,
                    value: _toolValue(_active),
                    visible: _chromeVisible,
                  ),
                  _ExportButton(onPressed: _export, busy: _exporting),
                  const _EngineBadge(),
                  const _Hint(),
                ],
              ),
            ),
    );
  }
}

/// Transient Material 3 chip showing the active tool and its value.
class _ToolChip extends StatelessWidget {
  const _ToolChip({
    required this.active,
    required this.value,
    required this.visible,
  });

  final GradeTool active;
  final double value;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = '${value >= 0 ? '+' : ''}${value.toStringAsFixed(2)}';

    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 150),
        child: Align(
          alignment: const Alignment(0, -0.4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(32),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _label(active),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  text,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.primary,
                    fontFeatures: const [ui.FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _label(GradeTool tool) => switch (tool) {
    GradeTool.exposure => 'Exposure',
    GradeTool.contrast => 'Contrast',
    GradeTool.saturation => 'Saturation',
  };
}

/// Top-right export action with a busy spinner.
class _ExportButton extends StatelessWidget {
  const _ExportButton({required this.onPressed, required this.busy});

  final VoidCallback onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: IconButton(
            onPressed: busy ? null : onPressed,
            icon: busy
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_alt, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

/// Shows the Rust engine version to prove the typed bridge call works on-device.
class _EngineBadge extends StatefulWidget {
  const _EngineBadge();

  @override
  State<_EngineBadge> createState() => _EngineBadgeState();
}

class _EngineBadgeState extends State<_EngineBadge> {
  late final Future<String> _version = TesseraEngine.version();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FutureBuilder<String>(
            future: _version,
            builder: (context, snapshot) => Text(
              snapshot.hasData ? 'engine v${snapshot.data}' : 'engine …',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment(0, 0.92),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          'Swipe up/down to pick a tool  ·  left/right to adjust  ·  tap to reset',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
      ),
    );
  }
}
