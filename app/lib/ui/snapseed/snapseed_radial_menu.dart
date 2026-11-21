import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../gesture/gesture_interpreter.dart';

/// Index of the radial-menu item nearest [pointer], for a menu centred at
/// [center] with [count] items at [radius]. Item 0 sits at the top (−90°),
/// going clockwise. Pure — unit-tested.
int nearestRadialItem(Offset center, Offset pointer, int count, double radius) {
  var best = 0;
  var bestD = double.infinity;
  for (var i = 0; i < count; i++) {
    final angle = -math.pi / 2 + i * 2 * math.pi / count;
    final c = center + Offset(math.cos(angle) * radius, math.sin(angle) * radius);
    final d = (c - pointer).distanceSquared;
    if (d < bestD) {
      bestD = d;
      best = i;
    }
  }
  return best;
}

/// A tap-to-pick radial menu of every gesture tool.
class SnapseedRadialMenu extends StatelessWidget {
  const SnapseedRadialMenu({
    super.key,
    required this.active,
    required this.tools,
    required this.iconOf,
    required this.onDismiss,
    required this.onPick,
  });

  final GradeTool active;
  final List<GradeTool> tools;
  final IconData Function(GradeTool) iconOf;
  final VoidCallback onDismiss;
  final ValueChanged<GradeTool> onPick;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shortest = MediaQuery.sizeOf(context).shortestSide;
    final radius = shortest >= 600 ? 128.0 : 96.0;
    // Fixed hit-box (issue #46): each item paints a 56px circle + label but
    // gets a symmetric target around its ring point. The box is larger than
    // the painted circle so taps just outside the ring still hit the item
    // instead of the dismiss backdrop; Containers don't clip, so the label
    // painting past the box is fine.
    const hitW = 88.0;
    const hitH = 100.0;
    final half = radius + hitW / 2;
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onDismiss();
            },
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: ColoredBox(color: scheme.surface.withValues(alpha: 0.5)),
            ),
          ),
        ),
        // Recenter the ring inside the safe area so side cutouts (issue #47)
        // don't clip the outermost items; the dismiss backdrop stays full-bleed.
        SafeArea(
          child: Center(
            child: SizedBox(
              width: half * 2,
              height: half * 2,
              child: Stack(
                children: [
                  for (var i = 0; i < tools.length; i++)
                    Positioned(
                      left: half +
                          math.cos(-math.pi / 2 + i * 2 * math.pi / tools.length) *
                              radius -
                          hitW / 2,
                      top: half +
                          math.sin(-math.pi / 2 + i * 2 * math.pi / tools.length) *
                              radius -
                          hitH / 2,
                      child: Semantics(
                        button: true,
                        label: tools[i].name,
                        child: RadialItemButton(
                          key: Key('radial-${tools[i].name}'),
                          tool: tools[i],
                          icon: iconOf(tools[i]),
                          selected: tools[i] == active,
                          hitW: hitW,
                          hitH: hitH,
                          onTap: () {
                            onPick(tools[i]);
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class RadialItemButton extends StatefulWidget {
  const RadialItemButton({
    super.key,
    required this.tool,
    required this.icon,
    required this.selected,
    required this.hitW,
    required this.hitH,
    required this.onTap,
  });

  final GradeTool tool;
  final IconData icon;
  final bool selected;
  final double hitW;
  final double hitH;
  final VoidCallback onTap;

  @override
  State<RadialItemButton> createState() => _RadialItemButtonState();
}

class _RadialItemButtonState extends State<RadialItemButton> with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.90).animate(
      CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => _anim.forward(),
      onPointerUp: (_) => _anim.reverse(),
      onPointerCancel: (_) => _anim.reverse(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        child: Container(
          width: widget.hitW,
          height: widget.hitH,
          color: Colors.transparent,
          alignment: Alignment.topCenter,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.selected ? scheme.primary : scheme.surfaceContainerHighest,
                    boxShadow: widget.selected
                        ? [
                            BoxShadow(
                              color: scheme.primary.withValues(alpha: 0.45),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    widget.icon,
                    color: widget.selected ? scheme.onPrimary : scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.tool.name,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w400,
                    color: widget.selected ? scheme.primary : scheme.onSurfaceVariant,
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
