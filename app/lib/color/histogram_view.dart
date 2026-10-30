import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../engine/engine.dart';
import '../viewport/exposure_assist.dart';

/// The current graded histogram, published by the canvas after each bake.
class HistogramController extends Notifier<Histogram?> {
  @override
  Histogram? build() => null;

  void publish(Histogram? value) => state = value;
}

final histogramProvider = NotifierProvider<HistogramController, Histogram?>(
  HistogramController.new,
);

/// Draws an additive RGB histogram with a luma outline and Lightroom-style
/// highlight & shadow clipping warnings (Gap 14 Pro tool).
class HistogramView extends ConsumerWidget {
  const HistogramView({super.key, required this.histogram, this.height = 64});

  final Histogram histogram;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assist = ref.watch(exposureAssistProvider);
    final isZebrasActive = assist.mode == ExposureAssistMode.zebras;
    final hasShadowClip =
        histogram.luma.isNotEmpty && histogram.luma.first > 0;
    final hasHighlightClip =
        histogram.luma.isNotEmpty && histogram.luma.last > 0;

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _HistogramPainter(histogram)),
          ),
          // Shadow clipping indicator (top-left)
          Positioned(
            left: 4,
            top: 4,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.selectionClick();
                final n = ref.read(exposureAssistProvider.notifier);
                if (isZebrasActive) {
                  n.setMode(ExposureAssistMode.off);
                } else {
                  n.setMode(ExposureAssistMode.zebras);
                }
              },
              child: Tooltip(
                message: 'Shadow Clipping Warning (Blue)',
                child: Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isZebrasActive && hasShadowClip
                        ? const Color(0xFF0288D1).withValues(alpha: 0.85)
                        : Colors.black45,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: isZebrasActive
                          ? const Color(0xFF03A9F4)
                          : hasShadowClip
                              ? const Color(0xFF0288D1).withValues(alpha: 0.6)
                              : Colors.white24,
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.arrow_drop_down,
                    size: 16,
                    color: isZebrasActive || hasShadowClip
                        ? const Color(0xFF4FC3F7)
                        : Colors.white54,
                  ),
                ),
              ),
            ),
          ),
          // Highlight clipping indicator (top-right)
          Positioned(
            right: 4,
            top: 4,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.selectionClick();
                final n = ref.read(exposureAssistProvider.notifier);
                if (isZebrasActive) {
                  n.setMode(ExposureAssistMode.off);
                } else {
                  n.setMode(ExposureAssistMode.zebras);
                }
              },
              child: Tooltip(
                message: 'Highlight Clipping Warning (Red)',
                child: Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isZebrasActive && hasHighlightClip
                        ? const Color(0xFFD32F2F).withValues(alpha: 0.85)
                        : Colors.black45,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: isZebrasActive
                          ? const Color(0xFFF44336)
                          : hasHighlightClip
                              ? const Color(0xFFD32F2F).withValues(alpha: 0.6)
                              : Colors.white24,
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.arrow_drop_up,
                    size: 16,
                    color: isZebrasActive || hasHighlightClip
                        ? const Color(0xFFEF5350)
                        : Colors.white54,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistogramPainter extends CustomPainter {
  _HistogramPainter(this.histogram);

  final Histogram histogram;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF0A0A0A),
    );

    final n = histogram.luma.length;
    // Normalise by the tallest interior bin (the extreme bins are often huge
    // clipping piles and would flatten the curve).
    var maxBin = 1;
    for (final channel in [histogram.r, histogram.g, histogram.b]) {
      for (var i = 1; i < n - 1; i++) {
        if (channel[i] > maxBin) maxBin = channel[i];
      }
    }

    void channelFill(Uint32List channel, Color color) {
      final path = Path()..moveTo(0, size.height);
      for (var i = 0; i < n; i++) {
        final x = i / (n - 1) * size.width;
        final h = (channel[i] / maxBin).clamp(0.0, 1.0) * size.height;
        path.lineTo(x, size.height - h);
      }
      path
        ..lineTo(size.width, size.height)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..blendMode = BlendMode.plus,
      );
    }

    channelFill(histogram.r, const Color(0x40FF4D4D));
    channelFill(histogram.g, const Color(0x4040FF6E));
    channelFill(histogram.b, const Color(0x404D8DFF));

    // Luma outline.
    final outline = Path();
    for (var i = 0; i < n; i++) {
      final x = i / (n - 1) * size.width;
      final h = (histogram.luma[i] / maxBin).clamp(0.0, 1.0) * size.height;
      if (i == 0) {
        outline.moveTo(x, size.height - h);
      } else {
        outline.lineTo(x, size.height - h);
      }
    }
    canvas.drawPath(
      outline,
      Paint()
        ..color = const Color(0xAAFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_HistogramPainter old) => old.histogram != histogram;
}
