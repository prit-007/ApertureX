import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';

/// Available gesture demonstration types for ApertureX Academy and Pro Guide.
enum GestureDemoType {
  /// Demonstrates vertical dragging across the image to cycle active parameters.
  verticalDrag,

  /// Demonstrates horizontal scrubbing to dial parameter values up/down with haptic ticks.
  horizontalScrub,

  /// Demonstrates dropping a second finger to engage the 10x precision gear ratio.
  twoFingerPrecisionGear,

  /// Demonstrates the split curtain wiper sweeping to compare before and after.
  splitWiper,
}

/// Smooth, lightweight animated looping visual mockups demonstrating ApertureX gestures.
///
/// Automatically plays in a smooth loop during runtime, and renders a stable preview
/// frame in test environments to allow tests to settle without timing out.
class GestureAnimationPlayer extends StatefulWidget {
  const GestureAnimationPlayer({
    super.key,
    required this.type,
    this.height = 130,
    this.isAnimating,
  });

  /// The gesture demo to render.
  final GestureDemoType type;

  /// Height of the mockup container.
  final double height;

  /// Optional override for animation playback. If null, automatically loops unless
  /// in a test environment.
  final bool? isAnimating;

  @override
  State<GestureAnimationPlayer> createState() => _GestureAnimationPlayerState();
}

class _GestureAnimationPlayerState extends State<GestureAnimationPlayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  bool get _isTestEnvironment =>
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  bool get _shouldAnimate => widget.isAnimating ?? !_isTestEnvironment;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _durationForType(widget.type),
    );

    if (_shouldAnimate) {
      _controller.repeat();
    } else {
      _controller.value = 0.5;
    }
  }

  @override
  void didUpdateWidget(GestureAnimationPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.type != widget.type) {
      _controller.duration = _durationForType(widget.type);
    }
    if (_shouldAnimate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!_shouldAnimate && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0.5;
    }
  }

  Duration _durationForType(GestureDemoType type) {
    switch (type) {
      case GestureDemoType.verticalDrag:
        return const Duration(milliseconds: 2800);
      case GestureDemoType.horizontalScrub:
        return const Duration(milliseconds: 2600);
      case GestureDemoType.twoFingerPrecisionGear:
        return const Duration(milliseconds: 3200);
      case GestureDemoType.splitWiper:
        return const Duration(milliseconds: 3000);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          switch (widget.type) {
            case GestureDemoType.verticalDrag:
              return _VerticalDragPlayer(
                progress: _controller.value,
                scheme: scheme,
                theme: theme,
              );
            case GestureDemoType.horizontalScrub:
              return _HorizontalScrubPlayer(
                progress: _controller.value,
                scheme: scheme,
                theme: theme,
              );
            case GestureDemoType.twoFingerPrecisionGear:
              return _TwoFingerPrecisionGearPlayer(
                progress: _controller.value,
                scheme: scheme,
                theme: theme,
              );
            case GestureDemoType.splitWiper:
              return _SplitWiperPlayer(
                progress: _controller.value,
                scheme: scheme,
                theme: theme,
              );
          }
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 1. Vertical Drag Demo
// ---------------------------------------------------------------------------

class _VerticalDragPlayer extends StatelessWidget {
  const _VerticalDragPlayer({
    required this.progress,
    required this.scheme,
    required this.theme,
  });

  final double progress;
  final ColorScheme scheme;
  final ThemeData theme;

  static const _labels = [
    (name: 'Exposure', icon: Icons.wb_sunny_outlined),
    (name: 'Contrast', icon: Icons.contrast),
    (name: 'Highlights', icon: Icons.brightness_high_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    // Oscillate progress 0.0 -> 1.0 -> 0.0 smoothly
    final t = (math.sin((progress * 2 * math.pi) - (math.pi / 2)) + 1) / 2;

    final int activeIndex;
    if (t < 0.33) {
      activeIndex = 0;
    } else if (t < 0.67) {
      activeIndex = 1;
    } else {
      activeIndex = 2;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.xs + 2),
      child: Row(
        children: [
          // Left side: Cycling parameter labels
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < _labels.length; i++) ...[
                  _ParameterPill(
                    label: _labels[i].name,
                    icon: _labels[i].icon,
                    isActive: i == activeIndex,
                    scheme: scheme,
                    theme: theme,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: Insets.md),

          // Right side: Vertical drag track and finger touch beacon
          SizedBox(
            width: 50,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final trackHeight = constraints.maxHeight - 24;
                final beaconY = 12 + (t * trackHeight);

                return Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    // Vertical guideline
                    Positioned.fill(
                      child: Center(
                        child: Container(
                          width: 2,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: scheme.outlineVariant.withValues(alpha: 0.5),
                            borderRadius: Radii.pillAll,
                          ),
                        ),
                      ),
                    ),
                    // Direction arrows
                    Positioned(
                      top: 0,
                      child: Icon(
                        Icons.arrow_drop_up,
                        size: 16,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      child: Icon(
                        Icons.arrow_drop_down,
                        size: 16,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    // Animated finger touch
                    Positioned(
                      top: beaconY - 15,
                      child: _TouchPoint(
                        scheme: scheme,
                        showRipple: true,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ParameterPill extends StatelessWidget {
  const _ParameterPill({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.scheme,
    required this.theme,
  });

  final String label;
  final IconData icon;
  final bool isActive;
  final ColorScheme scheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? scheme.primaryContainer
            : scheme.surface.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive
              ? scheme.primary
              : scheme.outlineVariant.withValues(alpha: 0.3),
          width: isActive ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 14,
            color: isActive ? scheme.primary : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: Insets.xs + 2),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
              ),
            ),
          ),
          if (isActive)
            Icon(
              Icons.check_circle,
              size: 13,
              color: scheme.primary,
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2. Horizontal Scrub Demo
// ---------------------------------------------------------------------------

class _HorizontalScrubPlayer extends StatelessWidget {
  const _HorizontalScrubPlayer({
    required this.progress,
    required this.scheme,
    required this.theme,
  });

  final double progress;
  final ColorScheme scheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    // Smooth oscillation between -1.0 and +1.0
    final scrubRatio = math.sin(progress * 2 * math.pi);
    // Value: ranges between -1.2 EV and +1.2 EV
    final evValue = scrubRatio * 1.2;
    final evString = '${evValue > 0 ? '+' : ''}${evValue.toStringAsFixed(1)} EV';
    // Expanding dial indicator scale
    final dialScale = 1.0 + (scrubRatio.abs() * 0.14);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final scrubX = (width / 2) + (scrubRatio * (width * 0.32));

        return Stack(
          alignment: Alignment.center,
          children: [
            // Top: Expanding numeric dial indicator badge (+1.2 EV)
            Positioned(
              top: Insets.sm,
              child: Transform.scale(
                scale: dialScale,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: Radii.pillAll,
                    border: Border.all(color: scheme.primary, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tune, size: 13, color: scheme.primary),
                      const SizedBox(width: Insets.xs),
                      Text(
                        evString,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: scheme.onPrimaryContainer,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Middle: Horizontal dial ruler track with ticks
            Positioned(
              top: height * 0.44,
              left: Insets.md,
              right: Insets.md,
              child: CustomPaint(
                size: Size(width - (Insets.md * 2), 24),
                painter: _RulerTrackPainter(
                  scheme: scheme,
                  scrubX: scrubX - Insets.md,
                ),
              ),
            ),

            // Animated finger touch and haptic visual ripples
            Positioned(
              top: (height * 0.44) - 2,
              left: scrubX - 16,
              child: _TouchPoint(
                scheme: scheme,
                showRipple: true,
                rippleProgress: (progress * 5) % 1.0,
              ),
            ),

            // Bottom caption
            Positioned(
              bottom: 6,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.swap_horiz, size: 13, color: scheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    'Scrub horizontally • Haptic ticks & dynamic dial',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RulerTrackPainter extends CustomPainter {
  const _RulerTrackPainter({
    required this.scheme,
    required this.scrubX,
  });

  final ColorScheme scheme;
  final double scrubX;

  @override
  void paint(Canvas canvas, Size size) {
    final baseLinePaint = Paint()
      ..color = scheme.outlineVariant.withValues(alpha: 0.4)
      ..strokeWidth = 1.0;

    final tickPaint = Paint()
      ..color = scheme.outlineVariant.withValues(alpha: 0.6)
      ..strokeWidth = 1.0;

    final activeTickPaint = Paint()
      ..color = scheme.primary
      ..strokeWidth = 2.0;

    final centerTickPaint = Paint()
      ..color = scheme.onSurface
      ..strokeWidth = 2.0;

    final midY = size.height / 2;
    canvas.drawLine(Offset(0, midY), Offset(size.width, midY), baseLinePaint);

    final centerX = size.width / 2;
    const step = 10.0;
    final tickCount = (size.width / step).floor();

    for (var i = 0; i <= tickCount; i++) {
      final x = i * step;
      final isCenter = (x - centerX).abs() < (step / 2);
      final isNearScrub = (x - scrubX).abs() < (step * 1.2);

      final double tickHeight;
      final Paint p;
      if (isCenter) {
        tickHeight = 14;
        p = centerTickPaint;
      } else if (isNearScrub) {
        tickHeight = 11;
        p = activeTickPaint;
      } else {
        tickHeight = (i % 5 == 0) ? 8 : 4;
        p = tickPaint;
      }

      canvas.drawLine(
        Offset(x, midY - (tickHeight / 2)),
        Offset(x, midY + (tickHeight / 2)),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(_RulerTrackPainter oldDelegate) =>
      oldDelegate.scrubX != scrubX || oldDelegate.scheme != scheme;
}

// ---------------------------------------------------------------------------
// 3. Two-Finger Precision Gear Demo
// ---------------------------------------------------------------------------

class _TwoFingerPrecisionGearPlayer extends StatelessWidget {
  const _TwoFingerPrecisionGearPlayer({
    required this.progress,
    required this.scheme,
    required this.theme,
  });

  final double progress;
  final ColorScheme scheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    // Phases:
    // 0.00 .. 0.25: Finger 1 scrubs; Finger 2 is up/invisible; gear inactive.
    // 0.25 .. 0.40: Finger 2 lands next to Finger 1.
    // 0.40 .. 0.85: Both fingers on screen -> Glowing 10x Gear badge active!
    // 0.85 .. 1.00: Finger 2 lifts and gear fades.
    final bool isGearActive = progress >= 0.38 && progress <= 0.88;
    final double finger2Opacity;
    final double finger2DropY;

    if (progress < 0.22) {
      finger2Opacity = 0.0;
      finger2DropY = -24.0;
    } else if (progress < 0.38) {
      final t = (progress - 0.22) / 0.16;
      finger2Opacity = t;
      finger2DropY = -24.0 * (1 - t);
    } else if (progress <= 0.85) {
      finger2Opacity = 1.0;
      finger2DropY = 0.0;
    } else {
      final t = (progress - 0.85) / 0.15;
      finger2Opacity = (1 - t).clamp(0.0, 1.0);
      finger2DropY = -24.0 * t;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final centerX = width / 2;

        return Stack(
          alignment: Alignment.center,
          children: [
            // Top: Glowing "10x Gear" badge
            Positioned(
              top: Insets.sm,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 160),
                opacity: isGearActive ? 1.0 : 0.2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: isGearActive
                        ? scheme.primaryContainer
                        : scheme.surfaceContainerHigh,
                    borderRadius: Radii.pillAll,
                    border: Border.all(
                      color: isGearActive ? scheme.primary : scheme.outlineVariant,
                      width: isGearActive ? 1.5 : 1.0,
                    ),
                    boxShadow: isGearActive
                        ? [
                            BoxShadow(
                              color: scheme.primary.withValues(alpha: 0.6),
                              blurRadius: 14,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.settings,
                        size: 14,
                        color: isGearActive ? scheme.primary : scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '10x Gear',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: isGearActive
                              ? scheme.onPrimaryContainer
                              : scheme.onSurfaceVariant,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '• 0.01 Micro-Precision',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 10,
                          color: isGearActive
                              ? scheme.onPrimaryContainer.withValues(alpha: 0.8)
                              : scheme.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Canvas touch connection beam when gear is active
            if (isGearActive)
              Positioned(
                top: (height * 0.52) - 1,
                left: centerX - 28,
                width: 56,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.6),
                    borderRadius: Radii.pillAll,
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.8),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),

            // Finger 1 (Primary contact)
            Positioned(
              top: (height * 0.52) - 15,
              left: centerX - 42,
              child: _TouchPoint(
                scheme: scheme,
                label: '1',
                showRipple: true,
              ),
            ),

            // Finger 2 (Precision contact meeting on canvas)
            Positioned(
              top: ((height * 0.52) - 15) + finger2DropY,
              left: centerX + 12,
              child: Opacity(
                opacity: finger2Opacity,
                child: _TouchPoint(
                  scheme: scheme,
                  label: '2',
                  showRipple: isGearActive,
                ),
              ),
            ),

            // Bottom caption
            Positioned(
              bottom: 6,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.speed, size: 13, color: scheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    'Touch 2nd finger while scrubbing for 10x gear ratio',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 4. Split Wiper Demo
// ---------------------------------------------------------------------------

class _SplitWiperPlayer extends StatelessWidget {
  const _SplitWiperPlayer({
    required this.progress,
    required this.scheme,
    required this.theme,
  });

  final double progress;
  final ColorScheme scheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    // Smooth oscillation across the canvas (0.22 to 0.78 width fraction)
    final fraction = 0.50 + (0.28 * math.sin(progress * 2 * math.pi));

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final wiperX = width * fraction;

        return Stack(
          children: [
            // Layer 1: Edited / Graded half (Right canvas)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      scheme.primaryContainer,
                      scheme.tertiaryContainer,
                      scheme.primary.withValues(alpha: 0.6),
                    ],
                  ),
                ),
                alignment: Alignment.topRight,
                padding: const EdgeInsets.only(top: 8, right: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: scheme.surface.withValues(alpha: 0.75),
                    borderRadius: Radii.pillAll,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, size: 10, color: scheme.primary),
                      const SizedBox(width: 3),
                      Text(
                        'EDITED',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Layer 2: Unedited / Original half (Left canvas, clipped to wiperX)
            Positioned.fill(
              child: ClipRect(
                clipper: _FractionClipper(fraction: fraction),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        scheme.surfaceContainerHighest,
                        scheme.outlineVariant.withValues(alpha: 0.4),
                        scheme.surfaceContainerHigh,
                      ],
                    ),
                  ),
                  alignment: Alignment.topLeft,
                  padding: const EdgeInsets.only(top: 8, left: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: scheme.surface.withValues(alpha: 0.75),
                      borderRadius: Radii.pillAll,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.image_outlined, size: 10, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 3),
                        Text(
                          'ORIGINAL',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Layer 3: Split curtain divider bar & wiper handle
            Positioned(
              left: wiperX - 1.5,
              top: 0,
              bottom: 0,
              child: Container(
                width: 3,
                decoration: BoxDecoration(
                  color: scheme.onSurface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),

            // Wiper Thumb Handle
            Positioned(
              left: wiperX - 15,
              top: (height / 2) - 15,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.surface,
                  border: Border.all(color: scheme.primary, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.compare_arrows,
                  size: 16,
                  color: scheme.primary,
                ),
              ),
            ),

            // Bottom caption
            Positioned(
              bottom: 6,
              left: Insets.sm,
              right: Insets.sm,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: scheme.surface.withValues(alpha: 0.8),
                    borderRadius: Radii.pillAll,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.compare, size: 12, color: scheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Split wiper sweeps across canvas to compare',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 10,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FractionClipper extends CustomClipper<Rect> {
  const _FractionClipper({required this.fraction});

  final double fraction;

  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(0, 0, size.width * fraction, size.height);
  }

  @override
  bool shouldReclip(_FractionClipper oldClipper) => oldClipper.fraction != fraction;
}

// ---------------------------------------------------------------------------
// Shared Reusable Touch Point Beacon
// ---------------------------------------------------------------------------

class _TouchPoint extends StatelessWidget {
  const _TouchPoint({
    required this.scheme,
    this.label,
    this.showRipple = false,
    this.rippleProgress,
  });

  final ColorScheme scheme;
  final String? label;
  final bool showRipple;
  final double? rippleProgress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (showRipple) ...[
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.primary.withValues(alpha: 0.18),
              ),
            ),
          ],
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.primary,
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.4),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Center(
              child: label != null
                  ? Text(
                      label!,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: scheme.onPrimary,
                      ),
                    )
                  : Icon(
                      Icons.touch_app,
                      size: 13,
                      color: scheme.onPrimary,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
