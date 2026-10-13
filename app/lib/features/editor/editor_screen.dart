import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../../gesture/gesture_interpreter.dart';
import 'grade_painter.dart';

/// Seed editor screen: an invisible Snapseed-style gesture over a GPU-graded
/// image. This is the first vertical slice of the Tessera editing experience;
/// the tile compositor and real recipe model arrive in later phases.
class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late final GestureInterpreter _fsm;
  final Map<GradeTool, double> _values = {
    for (final tool in GradeTool.values) tool: 0.0,
  };

  ui.FragmentShader? _shader;
  ui.Image? _texture;

  GradeTool _active = GradeTool.exposure;
  bool _chromeVisible = false;

  @override
  void initState() {
    super.initState();
    _fsm = GestureInterpreter(
      onToolChanged: (tool) => setState(() => _active = tool),
      onValueChanged: (tool, delta) => setState(() {
        _active = tool;
        _values[tool] = (_values[tool]! + delta).clamp(-1.0, 1.0);
      }),
      onReset: (tool) => setState(() {
        _active = tool;
        _values[tool] = 0.0;
      }),
      onPhaseChanged: (phase) =>
          setState(() => _chromeVisible = phase != GesturePhase.idle),
    );
    _load();
  }

  Future<void> _load() async {
    final program = await ui.FragmentProgram.fromAsset('shaders/grade.frag');
    final texture = _makeTestImage(1024, 1024);
    if (!mounted) return;
    setState(() {
      _shader = program.fragmentShader();
      _texture = texture;
    });
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

    return Scaffold(
      backgroundColor: Colors.black,
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
                      exposure: _values[GradeTool.exposure]! * 2.0,
                      contrast: _values[GradeTool.contrast]!,
                      saturation: _values[GradeTool.saturation]!,
                    ),
                  ),
                  _ToolChip(
                    active: _active,
                    value: _values[_active]!,
                    visible: _chromeVisible,
                  ),
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
    final pct = (value * 100).round();

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
                  '${pct > 0 ? '+' : ''}$pct',
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

/// Builds a colourful test texture procedurally so the seed needs no assets.
ui.Image _makeTestImage(int width, int height) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final rect = Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());

  canvas.drawRect(
    rect,
    Paint()
      ..shader = ui.Gradient.linear(
        rect.topLeft,
        rect.bottomRight,
        const [
          Color(0xFFB23A48),
          Color(0xFF4A3F8F),
          Color(0xFF2A9D8F),
          Color(0xFFE9C46A),
        ],
        const [0.0, 0.35, 0.7, 1.0],
      ),
  );

  final disc = Paint()..color = Colors.white.withValues(alpha: 0.15);
  for (var i = 0; i < 6; i++) {
    canvas.drawCircle(
      Offset(
        width * (0.2 + i * 0.14),
        height * (0.3 + (i.isEven ? 0.1 : -0.1)),
      ),
      width * 0.08,
      disc,
    );
  }

  canvas.drawRect(
    Rect.fromLTWH(0, height * 0.72, width.toDouble(), height * 0.28),
    Paint()..color = Colors.black.withValues(alpha: 0.35),
  );

  return recorder.endRecording().toImageSync(width, height);
}
