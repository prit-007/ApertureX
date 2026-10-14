import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// A first-run "ghost hint" for the invisible gesture shell: a soft, glowing
/// thumb that animates an up/down swipe (with a fading motion trail) plus a
/// caption. It ignores touches, so the first real gesture passes straight
/// through to the canvas and dismisses it (see `AppShell`).
class GhostHint extends ConsumerStatefulWidget {
  const GhostHint({super.key});

  @override
  ConsumerState<GhostHint> createState() => _GhostHintState();
}

class _GhostHintState extends ConsumerState<GhostHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IgnorePointer(
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = Curves.easeInOut.transform(_controller.value);
            final dy = (t * 2 - 1) * 30;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.keyboard_arrow_up,
                  color: scheme.onSurface.withValues(alpha: 0.7),
                ),
                SizedBox(
                  height: 96,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Motion trail (older copies, faded).
                      for (final (lag, opacity) in const [
                        (0.0, 0.15),
                        (-14.0, 0.30),
                      ])
                        Transform.translate(
                          offset: Offset(0, dy - lag),
                          child: _Thumb(scheme: scheme, opacity: opacity),
                        ),
                      Transform.translate(
                        offset: Offset(0, dy),
                        child: _Thumb(scheme: scheme, opacity: 1),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down,
                  color: scheme.onSurface.withValues(alpha: 0.7),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Swipe up / down to pick a tool',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Swipe left / right to adjust  ·  tap to reset  ·  '
                        'long-press to compare',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.scheme, required this.opacity});

  final ColorScheme scheme;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: scheme.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: scheme.primary.withValues(alpha: 0.45),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Icon(Icons.touch_app, color: Colors.white),
      ),
    );
  }
}
