import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';

import 'exposure_assist.dart';
import 'soft_proofing.dart';
import 'split_compare.dart';
import 'wiper_compare.dart';

/// Chooses the preview delivery surface (spike B / issue #54 / Flaw 22).
///
/// When Rust is writing graded frames straight into a bound platform texture
/// (zero-copy), the widget tree mounts that [Texture]. If assist modes (zebras,
/// wiper compare, split compare, soft proofing) are active, they composite as
/// lightweight [CustomPaint] overlay layers directly on top of the texture,
/// rather than dropping the entire pipeline to the shader path.
class PreviewSurface extends StatelessWidget {
  const PreviewSurface({
    super.key,
    required this.textureId,
    required this.fallback,
    this.zebraActive = false,
    this.zebraMode = ExposureAssistMode.off,
    this.zebraTime = 0.0,
    this.zebraHigh = 0.98,
    this.zebraLow = 0.02,
    this.wiperActive = false,
    this.wiperPosition = 0.50,
    this.wiperOrientation = WiperOrientation.vertical,
    this.splitCompareActive = false,
    this.splitCompareOrientation = SplitOrientation.sideBySide,
    this.softProofActive = false,
    this.softProof = const SoftProofState(),
    this.zoneTargeting = false,
    this.compareSource,
  });

  /// Bound platform texture id, or `null` for the spike-A shader/atlas path.
  final int? textureId;

  /// The spike-A render (CustomPaint through `lut.frag`).
  final WidgetBuilder fallback;

  final bool zebraActive;
  final ExposureAssistMode zebraMode;
  final double zebraTime;
  final double zebraHigh;
  final double zebraLow;

  final bool wiperActive;
  final double wiperPosition;
  final WiperOrientation wiperOrientation;

  final bool splitCompareActive;
  final SplitOrientation splitCompareOrientation;

  final bool softProofActive;
  final SoftProofState softProof;

  final bool zoneTargeting;

  /// Source image for before/after comparison curtains.
  final ui.Image? compareSource;

  @override
  Widget build(BuildContext context) {
    final id = textureId;
    if (id == null) {
      return fallback(context);
    }

    final hasAssists = (zebraActive && zebraMode != ExposureAssistMode.off) ||
        (wiperActive && compareSource != null) ||
        (splitCompareActive && compareSource != null) ||
        (softProofActive && softProof.enabled);

    final baseTexture = Texture(textureId: id);

    if (!hasAssists) {
      return baseTexture;
    }

    return Stack(
      fit: StackFit.passthrough,
      children: [
        baseTexture,
        if (wiperActive && compareSource != null)
          Positioned.fill(
            child: CustomPaint(
              painter: WiperCurtainPainter(
                compareSource: compareSource!,
                position: wiperPosition,
                orientation: wiperOrientation,
              ),
            ),
          ),
        if (splitCompareActive && compareSource != null)
          Positioned.fill(
            child: CustomPaint(
              painter: SplitCurtainPainter(
                compareSource: compareSource!,
                orientation: splitCompareOrientation,
              ),
            ),
          ),
        if (zebraActive && zebraMode != ExposureAssistMode.off)
          Positioned.fill(
            child: CustomPaint(
              painter: ZebraOverlayPainter(
                mode: zebraMode,
                time: zebraTime,
                high: zebraHigh,
                low: zebraLow,
              ),
            ),
          ),
        if (softProofActive && softProof.enabled)
          Positioned.fill(
            child: CustomPaint(
              painter: SoftProofGamutPainter(softProof: softProof),
            ),
          ),
      ],
    );
  }
}

/// Helper that draws a high-contrast badge on [canvas].
void _drawBadge(Canvas canvas, String label, Offset pos) {
  final tp = TextPainter(
    text: TextSpan(
      text: label,
      style: const TextStyle(
        color: Color(0xFFFFFFFF),
        fontSize: 10,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.8,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  final bgRect = RRect.fromRectAndRadius(
    Rect.fromLTWH(pos.dx - 4, pos.dy - 2, tp.width + 8, tp.height + 4),
    const Radius.circular(4),
  );
  canvas.drawRRect(bgRect, Paint()..color = const Color(0xAA000000));
  tp.paint(canvas, pos);
}

/// Draws the wiper compare curtain over the base texture.
class WiperCurtainPainter extends CustomPainter {
  WiperCurtainPainter({
    required this.compareSource,
    required this.position,
    required this.orientation,
  });

  final ui.Image compareSource;
  final double position;
  final WiperOrientation orientation;

  @override
  void paint(Canvas canvas, Size size) {
    final dst = Offset.zero & size;
    if (orientation == WiperOrientation.vertical) {
      final splitX = dst.left + dst.width * position.clamp(0.0, 1.0);

      // 1. Unedited Source on Left side
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(dst.left, dst.top, splitX, dst.bottom));
      canvas.drawImageRect(
        compareSource,
        Rect.fromLTWH(0, 0, compareSource.width.toDouble(), compareSource.height.toDouble()),
        dst,
        Paint(),
      );
      canvas.restore();

      // 2. Glowing cyan divider line
      final glowPaint = Paint()
        ..color = const Color(0x6600E5FF)
        ..strokeWidth = 6.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
      canvas.drawLine(Offset(splitX, dst.top), Offset(splitX, dst.bottom), glowPaint);

      final linePaint = Paint()
        ..color = const Color(0xFF00E5FF)
        ..strokeWidth = 2.0;
      canvas.drawLine(Offset(splitX, dst.top), Offset(splitX, dst.bottom), linePaint);

      // 3. Thumb handle
      final handleCenter = Offset(splitX, dst.top + dst.height * 0.5);
      canvas.drawCircle(handleCenter, 18, Paint()..color = const Color(0xDD000000));
      canvas.drawCircle(
        handleCenter,
        18,
        Paint()
          ..color = const Color(0xFF00E5FF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
      final tp = TextPainter(
        text: const TextSpan(
          text: '◀ ▶',
          style: TextStyle(
            color: Color(0xFF00E5FF),
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, handleCenter - Offset(tp.width / 2, tp.height / 2));

      // 4. Badges
      if (splitX > dst.left + 50) {
        _drawBadge(canvas, 'BEFORE', Offset(dst.left + 12, dst.top + 12));
      }
      if (dst.right - splitX > 50) {
        _drawBadge(canvas, 'AFTER', Offset(dst.right - 62, dst.top + 12));
      }
    } else {
      final splitY = dst.top + dst.height * position.clamp(0.0, 1.0);

      // 1. Unedited Source on Top side
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(dst.left, dst.top, dst.right, splitY));
      canvas.drawImageRect(
        compareSource,
        Rect.fromLTWH(0, 0, compareSource.width.toDouble(), compareSource.height.toDouble()),
        dst,
        Paint(),
      );
      canvas.restore();

      // 2. Glowing cyan divider line
      final glowPaint = Paint()
        ..color = const Color(0x6600E5FF)
        ..strokeWidth = 6.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
      canvas.drawLine(Offset(dst.left, splitY), Offset(dst.right, splitY), glowPaint);

      final linePaint = Paint()
        ..color = const Color(0xFF00E5FF)
        ..strokeWidth = 2.0;
      canvas.drawLine(Offset(dst.left, splitY), Offset(dst.right, splitY), linePaint);

      // 3. Thumb handle
      final handleCenter = Offset(dst.left + dst.width * 0.5, splitY);
      canvas.drawCircle(handleCenter, 18, Paint()..color = const Color(0xDD000000));
      canvas.drawCircle(
        handleCenter,
        18,
        Paint()
          ..color = const Color(0xFF00E5FF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
      final tp = TextPainter(
        text: const TextSpan(
          text: '▲\n▼',
          style: TextStyle(
            color: Color(0xFF00E5FF),
            fontSize: 10,
            fontWeight: FontWeight.bold,
            height: 1.0,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();
      tp.paint(canvas, handleCenter - Offset(tp.width / 2, tp.height / 2));

      // 4. Badges
      if (splitY > dst.top + 35) {
        _drawBadge(canvas, 'BEFORE', Offset(dst.left + 12, dst.top + 12));
      }
      if (dst.bottom - splitY > 35) {
        _drawBadge(canvas, 'AFTER', Offset(dst.left + 12, dst.bottom - 32));
      }
    }
  }

  @override
  bool shouldRepaint(WiperCurtainPainter old) =>
      old.compareSource != compareSource ||
      old.position != position ||
      old.orientation != orientation;
}

/// Draws the split compare divider and unedited side over the base texture.
class SplitCurtainPainter extends CustomPainter {
  SplitCurtainPainter({
    required this.compareSource,
    required this.orientation,
  });

  final ui.Image compareSource;
  final SplitOrientation orientation;

  @override
  void paint(Canvas canvas, Size size) {
    final dst = Offset.zero & size;
    if (orientation == SplitOrientation.sideBySide) {
      final splitX = dst.left + dst.width * 0.5;

      canvas.save();
      canvas.clipRect(Rect.fromLTRB(dst.left, dst.top, splitX, dst.bottom));
      canvas.drawImageRect(
        compareSource,
        Rect.fromLTWH(0, 0, compareSource.width.toDouble(), compareSource.height.toDouble()),
        dst,
        Paint(),
      );
      canvas.restore();

      final linePaint = Paint()
        ..color = const Color(0xCCFFFFFF)
        ..strokeWidth = 2.0;
      canvas.drawLine(Offset(splitX, dst.top), Offset(splitX, dst.bottom), linePaint);

      _drawBadge(canvas, 'BEFORE', Offset(dst.left + 12, dst.top + 12));
      _drawBadge(canvas, 'AFTER', Offset(splitX + 12, dst.top + 12));
    } else {
      final splitY = dst.top + dst.height * 0.5;

      canvas.save();
      canvas.clipRect(Rect.fromLTRB(dst.left, dst.top, dst.right, splitY));
      canvas.drawImageRect(
        compareSource,
        Rect.fromLTWH(0, 0, compareSource.width.toDouble(), compareSource.height.toDouble()),
        dst,
        Paint(),
      );
      canvas.restore();

      final linePaint = Paint()
        ..color = const Color(0xCCFFFFFF)
        ..strokeWidth = 2.0;
      canvas.drawLine(Offset(dst.left, splitY), Offset(dst.right, splitY), linePaint);

      _drawBadge(canvas, 'BEFORE', Offset(dst.left + 12, dst.top + 12));
      _drawBadge(canvas, 'AFTER', Offset(dst.left + 12, splitY + 12));
    }
  }

  @override
  bool shouldRepaint(SplitCurtainPainter old) =>
      old.compareSource != compareSource || old.orientation != orientation;
}

/// Draws soft-proofing profile name and gamut warning badge over the base texture.
class SoftProofGamutPainter extends CustomPainter {
  SoftProofGamutPainter({required this.softProof});

  final SoftProofState softProof;

  @override
  void paint(Canvas canvas, Size size) {
    if (!softProof.enabled) return;
    final label = softProof.gamutWarning
        ? 'PROOF: ${softProof.profile.displayName} [GAMUT WARNING]'
        : 'PROOF: ${softProof.profile.displayName}';
    _drawBadge(canvas, label, const Offset(12, 12));
  }

  @override
  bool shouldRepaint(SoftProofGamutPainter old) => old.softProof != softProof;
}

/// Draws animated diagonal 45-degree zebra stripes over the base texture.
class ZebraOverlayPainter extends CustomPainter {
  ZebraOverlayPainter({
    required this.mode,
    required this.time,
    this.high = 0.98,
    this.low = 0.02,
  });

  final ExposureAssistMode mode;
  final double time;
  final double high;
  final double low;

  @override
  void paint(Canvas canvas, Size size) {
    if (mode == ExposureAssistMode.off) return;
    final rect = Offset.zero & size;
    canvas.save();
    canvas.clipRect(rect);
    final paint = Paint()
      ..color = const Color(0xFFFF1744).withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final offset = (time * 48.0) % 20.0;
    final diag = size.width + size.height;
    for (double d = -size.height + offset; d < diag; d += 20.0) {
      canvas.drawLine(
        Offset(d, 0),
        Offset(d + size.height, size.height),
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(ZebraOverlayPainter old) =>
      old.mode != mode ||
      old.time != time ||
      old.high != high ||
      old.low != low;
}

/// Whether the viewport must show the loading/error placeholder.
///
/// The zero-copy path ([useTexture] = true) never bakes `lut`/`base` images —
/// requiring them there is what pinned the preview to the placeholder (#54).
bool previewNeedsPlaceholder({
  required bool failed,
  required bool hasProgram,
  required bool hasShader,
  required bool hasSource,
  required bool hasLut,
  required bool useTexture,
}) =>
    failed ||
    !hasProgram ||
    !hasShader ||
    !hasSource ||
    (!hasLut && !useTexture);

/// Whether the preview delivers frames through the bound platform texture.
///
/// Yields to the shader/atlas path when an imported LUT is active (the Rust
/// render doesn't carry an external atlas), while a compare/mask-peek
/// crossfade runs — those fades are drawn by `lut.frag` (`blend`/`maskBlend`),
/// which the texture path doesn't carry — while a high-zoom overlay (band or
/// tiles) is drawing, and whenever recipe geometry is non-identity.
bool useTextureDelivery({
  required int? textureId,
  required bool hasImportedLut,
  required bool gestureActive,
  required bool roiActive,
  bool geometryActive = false,
}) =>
    textureId != null &&
    !hasImportedLut &&
    !gestureActive &&
    !roiActive &&
    !geometryActive;
