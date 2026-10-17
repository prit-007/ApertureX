import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class MacroHudMessage {
  const MacroHudMessage({
    required this.message,
    required this.icon,
    required this.token,
  });

  final String message;
  final IconData icon;
  final int token;
}

class MacroHudNotifier extends Notifier<MacroHudMessage?> {
  Timer? _timer;
  int _counter = 0;

  @override
  MacroHudMessage? build() {
    ref.onDispose(() => _timer?.cancel());
    return null;
  }

  void show(String message, IconData icon) {
    _timer?.cancel();
    _counter++;
    state = MacroHudMessage(
      message: message,
      icon: icon,
      token: _counter,
    );
    _timer = Timer(const Duration(milliseconds: 1400), () {
      state = null;
    });
  }
}

final macroHudProvider =
    NotifierProvider<MacroHudNotifier, MacroHudMessage?>(MacroHudNotifier.new);

/// Floating HUD toast for Three-Finger Speed Editor gestures.
class MacroActionHud extends ConsumerWidget {
  const MacroActionHud({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final msg = ref.watch(macroHudProvider);
    final scheme = Theme.of(context).colorScheme;

    return IgnorePointer(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.9, end: 1.0).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
              ),
              child: child,
            ),
          );
        },
        child: msg == null
            ? const SizedBox.shrink()
            : Center(
                key: ValueKey(msg.token),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: scheme.primary.withValues(alpha: 0.6),
                      width: 1.5,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black45,
                        blurRadius: 16,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(msg.icon, color: scheme.primary, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        msg.message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
