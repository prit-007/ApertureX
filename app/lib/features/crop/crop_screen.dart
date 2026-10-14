import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/design_tokens.dart';
import '../../edit/crop_math.dart';
import '../../edit/geometry_spec.dart';
import '../../edit/recipe.dart';
import '../../edit/recipe_controller.dart';
import '../../engine/engine.dart';

/// Aspect presets for the crop tool (`null` = free).
const List<(String, double?)> kCropAspects = [
  ('Free', null),
  ('Original', -1),
  ('1:1', 1),
  ('4:5', 4 / 5),
  ('5:4', 5 / 4),
  ('16:9', 16 / 9),
  ('9:16', 9 / 16),
];

/// A full-screen, non-destructive crop tool: drag handles over the image, pick
/// an aspect ratio, rotate/flip, then Apply. Writes a normalized crop into the
/// shared recipe (the export path crops at full resolution).
class CropScreen extends ConsumerStatefulWidget {
  const CropScreen({super.key, required this.imageBytes});

  final Uint8List imageBytes;

  @override
  ConsumerState<CropScreen> createState() => _CropScreenState();
}

enum _Corner { topLeft, topRight, bottomLeft, bottomRight, move }

class _CropScreenState extends ConsumerState<CropScreen> {
  ui.Image? _image;
  bool _loading = true;

  Uint8List? _sourceRgba;
  Size _sourceSize = Size.zero;
  Size _imageSize = Size.zero;

  Rect _crop = const Rect.fromLTRB(0, 0, 1, 1);
  int _aspectIndex = 0;
  late int _rotation;
  late bool _flipH;
  double _straighten = 0;
  int _buildToken = 0;

  @override
  void initState() {
    super.initState();
    final recipe = ref.read(recipeControllerProvider).recipe;
    _rotation = recipe.rotation;
    _flipH = recipe.flipH;
    _straighten = recipe.straighten;
    _crop = clampNormalized(listToRect(recipe.crop));
    _init();
  }

  double? get _aspect {
    final raw = kCropAspects[_aspectIndex].$2;
    if (raw == null) return null;
    if (raw == -1) {
      return _imageSize.height == 0
          ? null
          : _imageSize.width / _imageSize.height;
    }
    return raw;
  }

  Future<void> _init() async {
    try {
      final decoded = await TesseraEngine.decodeJpegRgba(widget.imageBytes);
      _sourceRgba = decoded.rgba;
      _sourceSize = Size(decoded.width.toDouble(), decoded.height.toDouble());
      await _rebuildGeometry();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _rebuildGeometry() async {
    final rgba = _sourceRgba;
    if (rgba == null) return;
    final token = ++_buildToken;
    final geo = await TesseraEngine.applyGeometry(
      rgba,
      width: _sourceSize.width.toInt(),
      height: _sourceSize.height.toInt(),
      spec: GeometrySpec(
        rotation: _rotation,
        flipH: _flipH,
        straighten: _straighten,
        crop: fullCrop, // show the full transformed frame while cropping
      ),
    );
    final image = await _imageFrom(geo.rgba, geo.width, geo.height);
    if (!mounted || token != _buildToken) {
      image.dispose();
      return;
    }
    setState(() {
      _image?.dispose();
      _image = image;
      _imageSize = Size(geo.width.toDouble(), geo.height.toDouble());
      _crop = clampNormalized(_withAspect(_crop));
      _loading = false;
    });
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

  Rect _withAspect(Rect r) {
    final a = _aspect;
    if (a == null || _imageSize.isEmpty) return r;
    return clampNormalized(fitAspectWithin(r, a, _imageSize));
  }

  void _pickAspect(int index) {
    setState(() {
      _aspectIndex = index;
      _crop = _withAspect(_crop.isEmpty ? const Rect.fromLTRB(0, 0, 1, 1) : _crop);
    });
  }

  void _rotate(int dir) {
    setState(() {
      _rotation = ((_rotation + dir) % 4 + 4) % 4;
    });
    _rebuildGeometry();
  }

  void _flip() {
    setState(() => _flipH = !_flipH);
    _rebuildGeometry();
  }

  void _dragCorner(_Corner corner, Offset deltaNorm) {
    final d = Offset(deltaNorm.dx, deltaNorm.dy);
    var r = _crop;
    switch (corner) {
      case _Corner.topLeft:
        r = Rect.fromLTRB(r.left + d.dx, r.top + d.dy, r.right, r.bottom);
      case _Corner.topRight:
        r = Rect.fromLTRB(r.left, r.top + d.dy, r.right + d.dx, r.bottom);
      case _Corner.bottomLeft:
        r = Rect.fromLTRB(r.left + d.dx, r.top, r.right, r.bottom + d.dy);
      case _Corner.bottomRight:
        r = Rect.fromLTRB(r.left, r.top, r.right + d.dx, r.bottom + d.dy);
      case _Corner.move:
        final w = r.width, h = r.height;
        final l = (r.left + d.dx).clamp(0.0, 1.0 - w);
        final t = (r.top + d.dy).clamp(0.0, 1.0 - h);
        r = Rect.fromLTWH(l, t, w, h);
    }
    r = clampNormalized(r);
    if (corner != _Corner.move) r = _withAspect(r);
    setState(() => _crop = r);
  }

  void _apply() {
    ref
        .read(recipeControllerProvider.notifier)
        .applyCrop(
          crop: rectToList(_crop),
          rotation: _rotation,
          flipH: _flipH,
        );
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          tooltip: 'Cancel',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.close),
        ),
        title: const Text('Crop'),
        actions: [
          TextButton(
            onPressed: _loading ? null : _apply,
            child: const Text('Apply'),
          ),
        ],
      ),
      body: _loading || _image == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(child: _canvas(scheme)),
                _controls(scheme),
              ],
            ),
    );
  }

  Widget _canvas(ColorScheme scheme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bounds = constraints.biggest;
        final dst = _contain(_imageSize, bounds);
        return Stack(
          children: [
            Positioned.fromRect(
              rect: dst,
              child: RawImage(image: _image, fit: BoxFit.fill),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: _CropPainter(crop: _crop, dst: dst),
              ),
            ),
            // Movable interior.
            _handle(
              rect: Rect.fromLTRB(
                dst.left + _crop.left * dst.width,
                dst.top + _crop.top * dst.height,
                dst.left + _crop.right * dst.width,
                dst.top + _crop.bottom * dst.height,
              ),
              dst: dst,
              corner: _Corner.move,
            ),
            for (final corner in const [
              _Corner.topLeft,
              _Corner.topRight,
              _Corner.bottomLeft,
              _Corner.bottomRight,
            ])
              _cornerHandle(corner, dst),
          ],
        );
      },
    );
  }

  Widget _cornerHandle(_Corner corner, Rect dst) {
    final p = _cornerPoint(corner);
    final x = dst.left + p.dx * dst.width;
    final y = dst.top + p.dy * dst.height;
    const size = 44.0;
    return Positioned(
      left: x - size / 2,
      top: y - size / 2,
      width: size,
      height: size,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (d) => _dragCorner(
          corner,
          Offset(d.delta.dx / dst.width, d.delta.dy / dst.height),
        ),
        child: const Center(
          child: _HandleDot(),
        ),      ),
    );
  }

  Offset _cornerPoint(_Corner corner) => switch (corner) {
    _Corner.topLeft => _crop.topLeft,
    _Corner.topRight => _crop.topRight,
    _Corner.bottomLeft => _crop.bottomLeft,
    _Corner.bottomRight => _crop.bottomRight,
    _Corner.move => _crop.center,
  };

  Widget _handle({
    required Rect rect,
    required Rect dst,
    required _Corner corner,
  }) {
    return Positioned.fromRect(
      rect: rect,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanUpdate: (d) => _dragCorner(
          corner,
          Offset(d.delta.dx / dst.width, d.delta.dy / dst.height),
        ),
      ),
    );
  }

  Widget _controls(ColorScheme scheme) {
    return SafeArea(
      top: false,
      child: ColoredBox(
        color: scheme.surface,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
                children: [
                  for (var i = 0; i < kCropAspects.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(kCropAspects[i].$1),
                        selected: _aspectIndex == i,
                        showCheckmark: false,
                        onSelected: (_) => _pickAspect(i),
                      ),
                    ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  tooltip: 'Rotate left',
                  onPressed: () => _rotate(-1),
                  icon: const Icon(Icons.rotate_90_degrees_ccw),
                ),
                IconButton(
                  tooltip: 'Rotate right',
                  onPressed: () => _rotate(1),
                  icon: const Icon(Icons.rotate_90_degrees_cw),
                ),
                IconButton(
                  tooltip: 'Flip',
                  onPressed: _flip,
                  icon: const Icon(Icons.flip),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Rect _contain(Size content, Size bounds) {
    if (content.isEmpty || bounds.isEmpty) return Offset.zero & bounds;
    final fit = applyBoxFit(BoxFit.contain, content, bounds);
    return Alignment.center.inscribe(fit.destination, Offset.zero & bounds);
  }
}

class _HandleDot extends StatelessWidget {
  const _HandleDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black26),
      ),
    );
  }
}

/// Dims everything outside the crop, draws the border + rule-of-thirds grid.
class _CropPainter extends CustomPainter {
  _CropPainter({required this.crop, required this.dst});

  final Rect crop;
  final Rect dst;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTRB(
      dst.left + crop.left * dst.width,
      dst.top + crop.top * dst.height,
      dst.left + crop.right * dst.width,
      dst.top + crop.bottom * dst.height,
    );

    final dim = Paint()..color = const Color(0x99000000);
    // Four bands around the crop.
    canvas
      ..drawRect(Rect.fromLTRB(0, 0, size.width, rect.top), dim)
      ..drawRect(Rect.fromLTRB(0, rect.bottom, size.width, size.height), dim)
      ..drawRect(Rect.fromLTRB(0, rect.top, rect.left, rect.bottom), dim)
      ..drawRect(Rect.fromLTRB(rect.right, rect.top, size.width, rect.bottom), dim);

    canvas.drawRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white,
    );

    final grid = Paint()
      ..color = Colors.white38
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      final x = rect.left + rect.width * i / 3;
      final y = rect.top + rect.height * i / 3;
      canvas
        ..drawLine(Offset(x, rect.top), Offset(x, rect.bottom), grid)
        ..drawLine(Offset(rect.left, y), Offset(rect.right, y), grid);
    }
  }

  @override
  bool shouldRepaint(_CropPainter old) =>
      old.crop != crop || old.dst != dst;
}
