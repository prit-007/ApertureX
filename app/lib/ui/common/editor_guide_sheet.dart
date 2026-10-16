import 'package:material_ui/material_ui.dart';
import '../../core/theme/design_tokens.dart';

/// Interactive in-app guide sheet demonstrating editor gestures, pro tools,
/// stylus workflows, and shortcuts.
class EditorGuideSheet extends StatefulWidget {
  const EditorGuideSheet({super.key});

  /// Opens the guide as a modal bottom sheet.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const EditorGuideSheet(),
    );
  }

  @override
  State<EditorGuideSheet> createState() => _EditorGuideSheetState();
}

class _EditorGuideSheetState extends State<EditorGuideSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final size = MediaQuery.of(context).size;

    return Container(
      height: size.height * 0.78,
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: Radii.pillAll,
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.lg, vertical: Insets.xs),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(Insets.xs),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.auto_awesome,
                    size: 20,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ApertureX Pro Guide',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Master gestures, non-destructive editing & pro tools',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const Key('editor-guide-close'),
                  icon: const Icon(Icons.close),
                  tooltip: 'Close guide',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.xs),
          // Tab bar
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelPadding: const EdgeInsets.symmetric(horizontal: Insets.md),
            indicatorColor: scheme.primary,
            indicatorWeight: 3,
            labelColor: scheme.primary,
            unselectedLabelColor: scheme.onSurfaceVariant,
            labelStyle: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            tabs: const [
              Tab(text: 'Gestures'),
              Tab(text: 'Pro Tools'),
              Tab(text: 'Masking & Pen'),
              Tab(text: 'Panels & Keys'),
            ],
          ),
          Divider(height: 1, color: scheme.outlineVariant),
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _GesturesTab(scheme: scheme, theme: theme),
                _ProToolsTab(scheme: scheme, theme: theme),
                _MaskingTab(scheme: scheme, theme: theme),
                _PanelsTab(scheme: scheme, theme: theme),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GesturesTab extends StatelessWidget {
  const _GesturesTab({required this.scheme, required this.theme});

  final ColorScheme scheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(Insets.lg),
      children: [
        _GuideCard(
          icon: Icons.swap_vert,
          title: 'Vertical Drag',
          badge: '1 Finger ↕',
          description:
              'Drag vertically on the image to switch between parameters '
              '(Exposure, Contrast, Highlights, Shadows, Temperature, Saturation).',
          scheme: scheme,
          theme: theme,
        ),
        const SizedBox(height: Insets.sm),
        _GuideCard(
          icon: Icons.swap_horiz,
          title: 'Horizontal Scrub',
          badge: '1 Finger ↔',
          description:
              'Drag horizontally to smoothly dial parameter values up or down. '
              'Subtle haptic clicks fire as you cross zero or step through thresholds.',
          scheme: scheme,
          theme: theme,
        ),
        const SizedBox(height: Insets.sm),
        _GuideCard(
          icon: Icons.speed,
          title: 'Two-Finger Precision Gear',
          badge: '2 Fingers ✌️',
          description:
              'Touch with a second finger while scrubbing to engage the 10x '
              'precision gear ratio. Perfect for micro-contrast and delicate skin tone adjustments.',
          scheme: scheme,
          theme: theme,
        ),
        const SizedBox(height: Insets.sm),
        _GuideCard(
          icon: Icons.compare,
          title: 'Hold to Compare',
          badge: 'Long Press 👆',
          description:
              'Press and hold anywhere on the photo or tap the Compare button '
              'to instantly view the unedited original. Release to return to your edit.',
          scheme: scheme,
          theme: theme,
        ),
      ],
    );
  }
}

class _ProToolsTab extends StatelessWidget {
  const _ProToolsTab({required this.scheme, required this.theme});

  final ColorScheme scheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(Insets.lg),
      children: [
        _GuideCard(
          icon: Icons.colorize,
          title: 'Targeted Adjustment (TAT)',
          badge: 'Direct On-Image',
          description:
              'Tap the TAT pipette icon, then tap directly on any color in your '
              'photo and drag to shift Hue, Saturation, or Luminance of that specific shade.',
          scheme: scheme,
          theme: theme,
        ),
        const SizedBox(height: Insets.sm),
        _GuideCard(
          icon: Icons.add_location_alt,
          title: 'Selective Control Points',
          badge: 'Radial Pin',
          description:
              'Drop selective control points onto subjects or faces. Adjust exposure, '
              'contrast, and saturation locally with automatic edge-aware radial masking.',
          scheme: scheme,
          theme: theme,
        ),
        const SizedBox(height: Insets.sm),
        _GuideCard(
          icon: Icons.show_chart,
          title: 'Tone & RGB Curves',
          badge: 'Pro Spline',
          description:
              'Fine-tune tonal contrast with a 5-point cubic spline. Switch '
              'between Luminance and individual Red, Green, and Blue color channels.',
          scheme: scheme,
          theme: theme,
        ),
        const SizedBox(height: Insets.sm),
        _GuideCard(
          icon: Icons.crop_rotate,
          title: 'Precision Straighten & Rotate',
          badge: '0.06° Step',
          description:
              'Use the smooth rotation dial for ultra-fine sub-degree alignment, '
              'or tap Auto to level the horizon automatically via GPU perspective warp.',
          scheme: scheme,
          theme: theme,
        ),
      ],
    );
  }
}

class _MaskingTab extends StatelessWidget {
  const _MaskingTab({required this.scheme, required this.theme});

  final ColorScheme scheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(Insets.lg),
      children: [
        _GuideCard(
          icon: Icons.brush,
          title: 'Pressure-Sensitive Stylus',
          badge: 'S-Pen / Apple Pencil',
          description:
              'Draw local adjustment masks with natural pen pressure. Harder '
              'pressure yields higher opacity/flow, while light pressure blends softly.',
          scheme: scheme,
          theme: theme,
        ),
        const SizedBox(height: Insets.sm),
        _GuideCard(
          icon: Icons.auto_fix_normal,
          title: 'Inverted Stylus Eraser',
          badge: 'Dual-Tip',
          description:
              'Flip your stylus to use the physical eraser tip, or toggle Erase mode '
              'in the on-canvas Brush Toolbar to carve clean mask contours.',
          scheme: scheme,
          theme: theme,
        ),
        const SizedBox(height: Insets.sm),
        _GuideCard(
          icon: Icons.visibility,
          title: 'Mask Peek & Invert',
          badge: 'Rubylith Overlay',
          description:
              'Tap the Eye icon to view the red rubylith mask overlay. Use the Invert '
              'button to instantly flip the masked and protected regions.',
          scheme: scheme,
          theme: theme,
        ),
      ],
    );
  }
}

class _PanelsTab extends StatelessWidget {
  const _PanelsTab({required this.scheme, required this.theme});

  final ColorScheme scheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(Insets.lg),
      children: [
        _GuideCard(
          icon: Icons.view_sidebar,
          title: 'Dual-Shell Architecture',
          badge: 'Shared Recipe',
          description:
              'Switch between the gesture-first Snapseed shell and the deep '
              'Lightroom precision panel anytime in Settings. All edits share the same 100% non-destructive recipe.',
          scheme: scheme,
          theme: theme,
        ),
        const SizedBox(height: Insets.sm),
        _GuideCard(
          icon: Icons.keyboard,
          title: 'Keyboard Shortcuts',
          badge: 'Hardware Keys',
          description:
              '• Z / Shift+Z: Undo / Redo\n'
              '• \\ (Backslash): Toggle Before / After\n'
              '• C: Crop & Rotate\n'
              '• E: Export photo\n'
              '• 1–5: Star ratings',
          scheme: scheme,
          theme: theme,
        ),
      ],
    );
  }
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({
    required this.icon,
    required this.title,
    required this.badge,
    required this.description,
    required this.scheme,
    required this.theme,
  });

  final IconData icon;
  final String title;
  final String badge;
  final String description;
  final ColorScheme scheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(Insets.sm),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: scheme.primary, size: 22),
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Insets.xs + 2,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.secondaryContainer,
                        borderRadius: Radii.pillAll,
                      ),
                      child: Text(
                        badge,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSecondaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Insets.xs),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
