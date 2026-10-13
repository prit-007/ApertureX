import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../edit/parameter.dart';
import '../edit/recipe_controller.dart';

/// The shared editing canvas, rendered by BOTH shells (ADR 0008 invariant:
/// switching shells must not change the image). Skeleton for now — a procedural
/// surface with hold-to-compare; the LUT grading path lands in full Slice D.
class ImageCanvas extends ConsumerStatefulWidget {
  const ImageCanvas({super.key});

  @override
  ConsumerState<ImageCanvas> createState() => _ImageCanvasState();
}

class _ImageCanvasState extends ConsumerState<ImageCanvas> {
  bool _comparing = false;

  @override
  Widget build(BuildContext context) {
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
