import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'exposure_assist.dart';
import 'soft_proofing.dart';
import 'split_compare.dart';
import 'wiper_compare.dart';

/// A baked high-zoom tile (#16) and its draw rect in fitted/content space.
class CanvasTile {
  const CanvasTile({required this.image, required this.dst});

  final ui.Image image;
  final Rect dst;
}

/// Draws the base texture through `lut.frag` inside the aspect-correct [dst]
/// rect, sampling the packed 3D LUT atlas, and crossfades to the raw source
/// while comparing ([blend] 0..1).
class CanvasPainter extends CustomPainter {
  CanvasPainter({
    required this.shader,
    required this.source,
    required this.compareSource,
    required this.lut,
    required this.lutSize,
    required this.dst,
    required this.blend,
    required this.maskBlend,
    this.zoneLo = -1.0,
    this.zoneHi = -1.0,
    this.wiperActive = false,
    this.wiperPosition = 0.50,
    this.wiperOrientation = WiperOrientation.vertical,
    this.splitCompareActive = false,
    this.splitCompareOrientation = SplitOrientation.sideBySide,
    this.zebraMode = ExposureAssistMode.off,
    this.time = 0.0,
    this.zebraHigh = 0.98,
    this.zebraLow = 0.02,
    this.softProof = const SoftProofState(),
    this.tiles = const [],
  });

  final ui.FragmentShader shader;
  final ui.Image source;
  final ui.Image compareSource;
  final ui.Image lut;
  final double lutSize;
  final Rect dst;
  final double blend;
  final double maskBlend;
  final double zoneLo;
  final double zoneHi;
  final bool wiperActive;
  final double wiperPosition;
  final WiperOrientation wiperOrientation;
  final bool splitCompareActive;
  final SplitOrientation splitCompareOrientation;
  final ExposureAssistMode zebraMode;
  final double time;
  final double zebraHigh;
  final double zebraLow;
  final SoftProofState softProof;

  /// High-zoom tiles (#16): baked level-0 tiles of the original frame, drawn
  /// through the same uniforms over the proxy at their fitted-space rects.
  /// Empty while the overlay is inactive or tiles are still loading.
  final List<CanvasTile> tiles;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(const Color(0xFF000000), BlendMode.src);

    final zebraVal = zebraMode == ExposureAssistMode.zebras
        ? 1.0
        : (zebraMode == ExposureAssistMode.falseColor ? 2.0 : 0.0);

    shader
      ..setFloat(0, dst.width)
      ..setFloat(1, dst.height)
      ..setFloat(2, lutSize)
      ..setFloat(3, maskBlend)
      ..setFloat(4, source.width.toDouble())
      ..setFloat(5, source.height.toDouble())
      ..setFloat(6, zoneLo)
      ..setFloat(7, zoneHi)
      ..setFloat(8, zebraVal)
      ..setFloat(9, time)
      ..setFloat(10, zebraHigh)
      ..setFloat(11, zebraLow)
      ..setImageSampler(0, source)
      ..setImageSampler(1, lut);

    if (wiperActive) {
      if (wiperOrientation == WiperOrientation.vertical) {
        final splitX = dst.left + dst.width * wiperPosition.clamp(0.0, 1.0);

        // 1. Unedited Source on Left side
        canvas.save();
        canvas.clipRect(Rect.fromLTRB(dst.left, dst.top, splitX, dst.bottom));
        canvas.drawImageRect(
          compareSource,
          Rect.fromLTWH(
            0,
            0,
            compareSource.width.toDouble(),
            compareSource.height.toDouble(),
          ),
          dst,
          Paint(),
        );
        canvas.restore();

        // 2. Graded result on Right side
        canvas.save();
        canvas.clipRect(Rect.fromLTRB(splitX, dst.top, dst.right, dst.bottom));
        canvas.drawRect(dst, Paint()..shader = shader);
        if (tiles.isNotEmpty) {
          for (final tile in tiles) {
            canvas.save();
            canvas.translate(tile.dst.left, tile.dst.top);
            shader
              ..setFloat(0, tile.dst.width)
              ..setFloat(1, tile.dst.height)
              ..setFloat(2, lutSize)
              ..setFloat(3, maskBlend)
              ..setFloat(4, tile.image.width.toDouble())
              ..setFloat(5, tile.image.height.toDouble())
              ..setFloat(6, zoneLo)
              ..setFloat(7, zoneHi)
              ..setFloat(8, zebraVal)
              ..setFloat(9, time)
              ..setFloat(10, zebraHigh)
              ..setFloat(11, zebraLow)
              ..setImageSampler(0, tile.image)
              ..setImageSampler(1, lut);
            canvas.drawRect(
              Rect.fromLTWH(0, 0, tile.dst.width, tile.dst.height),
              Paint()..shader = shader,
            );
            canvas.restore();
          }
        }
        canvas.restore();

        // 3. Glowing cyan divider line
        final glowPaint = Paint()
          ..color = const Color(0x6600E5FF)
          ..strokeWidth = 6.0
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
        canvas.drawLine(
          Offset(splitX, dst.top),
          Offset(splitX, dst.bottom),
          glowPaint,
        );

        final linePaint = Paint()
          ..color = const Color(0xFF00E5FF)
          ..strokeWidth = 2.0;
        canvas.drawLine(
          Offset(splitX, dst.top),
          Offset(splitX, dst.bottom),
          linePaint,
        );

        // 4. Circular thumb handle at center
        final handleCenter = Offset(splitX, dst.top + dst.height * 0.5);
        canvas.drawCircle(
          handleCenter,
          18,
          Paint()..color = const Color(0xDD000000),
        );
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

        // 5. Before / After label badges
        if (splitX > dst.left + 50) {
          _drawCompareBadge(
            canvas,
            'BEFORE',
            Offset(dst.left + 12, dst.top + 12),
          );
        }
        if (dst.right - splitX > 50) {
          _drawCompareBadge(
            canvas,
            'AFTER',
            Offset(dst.right - 62, dst.top + 12),
          );
        }
      } else {
        // Horizontal split
        final splitY = dst.top + dst.height * wiperPosition.clamp(0.0, 1.0);

        // 1. Unedited Source on Top side
        canvas.save();
        canvas.clipRect(Rect.fromLTRB(dst.left, dst.top, dst.right, splitY));
        canvas.drawImageRect(
          compareSource,
          Rect.fromLTWH(
            0,
            0,
            compareSource.width.toDouble(),
            compareSource.height.toDouble(),
          ),
          dst,
          Paint(),
        );
        canvas.restore();

        // 2. Graded result on Bottom side
        canvas.save();
        canvas.clipRect(Rect.fromLTRB(dst.left, splitY, dst.right, dst.bottom));
        canvas.drawRect(dst, Paint()..shader = shader);
        if (tiles.isNotEmpty) {
          for (final tile in tiles) {
            canvas.save();
            canvas.translate(tile.dst.left, tile.dst.top);
            shader
              ..setFloat(0, tile.dst.width)
              ..setFloat(1, tile.dst.height)
              ..setFloat(2, lutSize)
              ..setFloat(3, maskBlend)
              ..setFloat(4, tile.image.width.toDouble())
              ..setFloat(5, tile.image.height.toDouble())
              ..setFloat(6, zoneLo)
              ..setFloat(7, zoneHi)
              ..setFloat(8, zebraVal)
              ..setFloat(9, time)
              ..setFloat(10, zebraHigh)
              ..setFloat(11, zebraLow)
              ..setImageSampler(0, tile.image)
              ..setImageSampler(1, lut);
            canvas.drawRect(
              Rect.fromLTWH(0, 0, tile.dst.width, tile.dst.height),
              Paint()..shader = shader,
            );
            canvas.restore();
          }
        }
        canvas.restore();

        // 3. Glowing cyan divider line
        final glowPaint = Paint()
          ..color = const Color(0x6600E5FF)
          ..strokeWidth = 6.0
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
        canvas.drawLine(
          Offset(dst.left, splitY),
          Offset(dst.right, splitY),
          glowPaint,
        );

        final linePaint = Paint()
          ..color = const Color(0xFF00E5FF)
          ..strokeWidth = 2.0;
        canvas.drawLine(
          Offset(dst.left, splitY),
          Offset(dst.right, splitY),
          linePaint,
        );

        // 4. Circular thumb handle at center
        final handleCenter = Offset(dst.left + dst.width * 0.5, splitY);
        canvas.drawCircle(
          handleCenter,
          18,
          Paint()..color = const Color(0xDD000000),
        );
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

        // 5. Before / After label badges
        if (splitY > dst.top + 35) {
          _drawCompareBadge(
            canvas,
            'BEFORE',
            Offset(dst.left + 12, dst.top + 12),
          );
        }
        if (dst.bottom - splitY > 35) {
          _drawCompareBadge(
            canvas,
            'AFTER',
            Offset(dst.left + 12, dst.bottom - 32),
          );
        }
      }
      return;
    }

    if (splitCompareActive) {
      if (splitCompareOrientation == SplitOrientation.sideBySide) {
        final splitX = dst.left + dst.width * 0.5;

        // 1. Unedited Source on Left side
        canvas.save();
        canvas.clipRect(Rect.fromLTRB(dst.left, dst.top, splitX, dst.bottom));
        canvas.drawImageRect(
          compareSource,
          Rect.fromLTWH(
            0,
            0,
            compareSource.width.toDouble(),
            compareSource.height.toDouble(),
          ),
          dst,
          Paint(),
        );
        canvas.restore();

        // 2. Graded result on Right side
        canvas.save();
        canvas.clipRect(Rect.fromLTRB(splitX, dst.top, dst.right, dst.bottom));
        canvas.drawRect(dst, Paint()..shader = shader);
        if (tiles.isNotEmpty) {
          for (final tile in tiles) {
            canvas.save();
            canvas.translate(tile.dst.left, tile.dst.top);
            shader
              ..setFloat(0, tile.dst.width)
              ..setFloat(1, tile.dst.height)
              ..setFloat(2, lutSize)
              ..setFloat(3, maskBlend)
              ..setFloat(4, tile.image.width.toDouble())
              ..setFloat(5, tile.image.height.toDouble())
              ..setFloat(6, zoneLo)
              ..setFloat(7, zoneHi)
              ..setFloat(8, zebraVal)
              ..setFloat(9, time)
              ..setFloat(10, zebraHigh)
              ..setFloat(11, zebraLow)
              ..setImageSampler(0, tile.image)
              ..setImageSampler(1, lut);
            canvas.drawRect(
              Rect.fromLTWH(0, 0, tile.dst.width, tile.dst.height),
              Paint()..shader = shader,
            );
            canvas.restore();
          }
        }
        canvas.restore();

        // 3. Crisp vertical divider line
        final linePaint = Paint()
          ..color = const Color(0xCCFFFFFF)
          ..strokeWidth = 2.0;
        canvas.drawLine(
          Offset(splitX, dst.top),
          Offset(splitX, dst.bottom),
          linePaint,
        );

        // 4. Before / After label badges
        _drawCompareBadge(
          canvas,
          'BEFORE',
          Offset(dst.left + 12, dst.top + 12),
        );
        _drawCompareBadge(canvas, 'AFTER', Offset(splitX + 12, dst.top + 12));
      } else {
        final splitY = dst.top + dst.height * 0.5;

        // 1. Unedited Source on Top side
        canvas.save();
        canvas.clipRect(Rect.fromLTRB(dst.left, dst.top, dst.right, splitY));
        canvas.drawImageRect(
          compareSource,
          Rect.fromLTWH(
            0,
            0,
            compareSource.width.toDouble(),
            compareSource.height.toDouble(),
          ),
          dst,
          Paint(),
        );
        canvas.restore();

        // 2. Graded result on Bottom side
        canvas.save();
        canvas.clipRect(Rect.fromLTRB(dst.left, splitY, dst.right, dst.bottom));
        canvas.drawRect(dst, Paint()..shader = shader);
        if (tiles.isNotEmpty) {
          for (final tile in tiles) {
            canvas.save();
            canvas.translate(tile.dst.left, tile.dst.top);
            shader
              ..setFloat(0, tile.dst.width)
              ..setFloat(1, tile.dst.height)
              ..setFloat(2, lutSize)
              ..setFloat(3, maskBlend)
              ..setFloat(4, tile.image.width.toDouble())
              ..setFloat(5, tile.image.height.toDouble())
              ..setFloat(6, zoneLo)
              ..setFloat(7, zoneHi)
              ..setFloat(8, zebraVal)
              ..setFloat(9, time)
              ..setFloat(10, zebraHigh)
              ..setFloat(11, zebraLow)
              ..setImageSampler(0, tile.image)
              ..setImageSampler(1, lut);
            canvas.drawRect(
              Rect.fromLTWH(0, 0, tile.dst.width, tile.dst.height),
              Paint()..shader = shader,
            );
            canvas.restore();
          }
        }
        canvas.restore();

        // 3. Crisp horizontal divider line
        final linePaint = Paint()
          ..color = const Color(0xCCFFFFFF)
          ..strokeWidth = 2.0;
        canvas.drawLine(
          Offset(dst.left, splitY),
          Offset(dst.right, splitY),
          linePaint,
        );

        // 4. Before / After label badges
        _drawCompareBadge(
          canvas,
          'BEFORE',
          Offset(dst.left + 12, dst.top + 12),
        );
        _drawCompareBadge(canvas, 'AFTER', Offset(dst.left + 12, splitY + 12));
      }
      return;
    }

    // Default: full graded result
    canvas.drawRect(dst, Paint()..shader = shader);
    if (tiles.isNotEmpty) {
      for (final tile in tiles) {
        canvas.save();
        canvas.translate(tile.dst.left, tile.dst.top);
        shader
          ..setFloat(0, tile.dst.width)
          ..setFloat(1, tile.dst.height)
          ..setFloat(2, lutSize)
          ..setFloat(3, maskBlend)
          ..setFloat(4, tile.image.width.toDouble())
          ..setFloat(5, tile.image.height.toDouble())
          ..setFloat(6, zoneLo)
          ..setFloat(7, zoneHi)
          ..setFloat(8, zebraVal)
          ..setFloat(9, time)
          ..setFloat(10, zebraHigh)
          ..setFloat(11, zebraLow)
          ..setImageSampler(0, tile.image)
          ..setImageSampler(1, lut);
        canvas.drawRect(
          Rect.fromLTWH(0, 0, tile.dst.width, tile.dst.height),
          Paint()..shader = shader,
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(CanvasPainter old) {
    if (old.shader != shader ||
        old.source != source ||
        old.compareSource != compareSource ||
        old.lut != lut ||
        old.lutSize != lutSize ||
        old.dst != dst ||
        old.blend != blend ||
        old.maskBlend != maskBlend ||
        old.zoneLo != zoneLo ||
        old.zoneHi != zoneHi ||
        old.wiperActive != wiperActive ||
        old.wiperPosition != wiperPosition ||
        old.wiperOrientation != wiperOrientation ||
        old.splitCompareActive != splitCompareActive ||
        old.splitCompareOrientation != splitCompareOrientation ||
        old.zebraMode != zebraMode ||
        old.time != time ||
        old.zebraHigh != zebraHigh ||
        old.zebraLow != zebraLow ||
        old.softProof != softProof ||
        old.tiles.length != tiles.length) {
      return true;
    }
    for (var i = 0; i < tiles.length; i++) {
      if (tiles[i].image != old.tiles[i].image ||
          tiles[i].dst != old.tiles[i].dst) {
        return true;
      }
    }
    return false;
  }

  void _drawCompareBadge(Canvas canvas, String label, Offset pos) {
    drawCompareBadge(canvas, label, pos);
  }
}

void drawCompareBadge(Canvas canvas, String label, Offset pos) {
  final tp = TextPainter(
    text: TextSpan(
      text: label,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  final badgeRect = RRect.fromRectAndRadius(
    Rect.fromLTWH(pos.dx, pos.dy, tp.width + 12, tp.height + 6),
    const Radius.circular(4),
  );

  canvas.drawRRect(badgeRect, Paint()..color = const Color(0x99000000));
  tp.paint(canvas, Offset(pos.dx + 6, pos.dy + 3));
}

class CanvasChip extends StatelessWidget {
  const CanvasChip({super.key, required this.text, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xCC000000),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: Colors.white70),
            const SizedBox(width: 4),
          ],
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }
}

class CanvasBadge extends StatelessWidget {
  const CanvasBadge({super.key, required this.text});

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
