import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:aperturex/viewport/image_canvas.dart' show ImageCanvas;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../color/tat.dart';
import '../../core/theme/design_tokens.dart';
import '../../edit/node_editor.dart';
import '../../edit/parameter.dart';
import '../../edit/recipe_controller.dart';
import '../../edit/recipe_mapping.dart';
import '../../edit/tool_definition.dart';
import '../../gesture/gesture_interpreter.dart';
import '../../gesture/zone_mask.dart';
import '../common/blur_controls.dart';
import '../common/history_tree_sheet.dart';
import '../common/mask_controls.dart';
import '../common/precision_rotation_dial.dart';
import '../common/preset_preview_thumbnail.dart';
import 'edit_hud.dart';
import 'snapseed_gesture_hud.dart';
import 'snapseed_tools_sheet.dart';
import '../../l10n/app_strings.dart';
import '../../core/theme/window_size_class.dart';
import 'snapseed_dock_sidebar.dart';
import 'snapseed_hud_hosts.dart';
import 'snapseed_radial_menu.dart';

export 'snapseed_dock_sidebar.dart';
export 'snapseed_hud_hosts.dart';
export 'snapseed_radial_menu.dart';

/// The Snapseed shell is a pure **HUD**: it owns no gestures and no edit state.
/// The shared [ImageCanvas] owns the touch model (1-finger edit, 2-finger
/// zoom/pan), routes 1-finger drags to the interpreter, and this layer floats
/// the active tool + recent changes over an edge-to-edge image, plus the radial
/// tool menu.
class SnapseedShell extends ConsumerStatefulWidget {
  const SnapseedShell({
    super.key,
    required this.tool,
    required this.category,
    required this.tools,
    required this.onCycleCategory,
    required this.onPickTool,
    this.onSelectCategoryAndTool,
    this.histogramOpen = false,
    this.hasHistogram = false,
    this.onToggleHistogram,
    this.gesturePhase = GesturePhase.idle,
  });

  final GradeTool tool;
  final ToolCategory category;
  final List<GradeTool> tools;
  final VoidCallback onCycleCategory;
  final ValueChanged<GradeTool> onPickTool;
  final void Function(ToolCategory category, GradeTool tool)? onSelectCategoryAndTool;
  final bool histogramOpen;
  final bool hasHistogram;
  final VoidCallback? onToggleHistogram;
  final GesturePhase gesturePhase;

  @override
  ConsumerState<SnapseedShell> createState() => _SnapseedShellState();
}

String _categoryLabel(ToolCategory c, [AppStrings? strings]) => switch (c) {
  ToolCategory.light => strings?.light ?? 'Light',
  ToolCategory.color => strings?.color ?? 'Color',
  ToolCategory.effects => strings?.effects ?? 'Effects',
  ToolCategory.detail => strings?.detail ?? 'Detail',
};

class _SnapseedShellState extends ConsumerState<SnapseedShell> {
  bool _radialOpen = false;
  bool _straightenOpen = false;
  bool _looksOpen = false;
  ToolDefinition? _activePresetTool;
  double _activePresetAmount = 1.0;
  Timer? _scrubFadeTimer;
  bool _scrubVisible = false;

  @override
  void initState() {
    super.initState();
    if (widget.gesturePhase == GesturePhase.scrubbing) {
      _scrubVisible = true;
    }
  }

  @override
  void didUpdateWidget(SnapseedShell old) {
    super.didUpdateWidget(old);
    if (widget.gesturePhase == GesturePhase.scrubbing) {
      // Scrubbing started or continuing: cancel any pending fade-out and show
      // the HUD immediately.
      _scrubFadeTimer?.cancel();
      _scrubFadeTimer = null;
      if (!_scrubVisible) {
        setState(() => _scrubVisible = true);
      }
    } else if (old.gesturePhase == GesturePhase.scrubbing &&
        widget.gesturePhase != GesturePhase.scrubbing) {
      // Scrubbing ended: fade the HUD out over 600ms instead of snapping off.
      _scrubFadeTimer?.cancel();
      _scrubFadeTimer = Timer(const Duration(milliseconds: 600), () {
        if (mounted) setState(() => _scrubVisible = false);
      });
    }
  }

  @override
  void dispose() {
    _scrubFadeTimer?.cancel();
    super.dispose();
  }

  static IconData _icon(GradeTool tool) => switch (tool) {
    GradeTool.exposure => Icons.exposure,
    GradeTool.contrast => Icons.contrast,
    GradeTool.highlights => Icons.brightness_high,
    GradeTool.shadows => Icons.brightness_low,
    GradeTool.whites => Icons.brightness_7,
    GradeTool.blacks => Icons.brightness_4,
    GradeTool.temperature => Icons.thermostat,
    GradeTool.tint => Icons.color_lens,
    GradeTool.vibrance => Icons.auto_awesome,
    GradeTool.saturation => Icons.water_drop,
    GradeTool.clarity => Icons.blur_on,
    GradeTool.dehaze => Icons.filter_drama,
    GradeTool.vignette => Icons.vignette,
    GradeTool.grain => Icons.grain,
    GradeTool.sharpen => Icons.details,
    GradeTool.shadowsGrade => Icons.tonality,
    GradeTool.midtonesGrade => Icons.brightness_medium,
    GradeTool.highlightsGrade => Icons.wb_sunny,
  };

  BoxConstraints _sheetConstraints(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final widthClass = windowSizeClassFor(size.width);
    final maxW = switch (widthClass) {
      WindowSizeClass.compact => double.infinity,
      WindowSizeClass.medium => 600.0,
      WindowSizeClass.expanded || WindowSizeClass.large || WindowSizeClass.extraLarge =>
        math.min(size.width * 0.70, 840.0),
    };
    return BoxConstraints(maxWidth: maxW);
  }

  double _sheetHeight(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isCompact = windowSizeClassFor(size.width) == WindowSizeClass.compact;
    return isCompact ? size.height * 0.70 : math.min(size.height * 0.75, 620.0);
  }

  void _openToolsSheet(BuildContext context) {
    HapticFeedback.lightImpact();
    final sheetH = _sheetHeight(context);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Center(
        child: ConstrainedBox(
          constraints: _sheetConstraints(context),
          child: SizedBox(
            height: sheetH,
            child: SnapseedToolsSheet(
              onSelectCategoryAndTool: (cat, tool) {
                final onSelect = widget.onSelectCategoryAndTool;
                if (onSelect != null) {
                  onSelect(cat, tool);
                } else {
                  widget.onPickTool(tool);
                }
              },
              onOpenStraighten: () {
                setState(() => _straightenOpen = true);
              },
              onOpenCrop: () {
                setState(() => _straightenOpen = true);
              },
            ),
          ),
        ),
      ),
    );
  }

  void _openMasksSheet(BuildContext context) {
    HapticFeedback.lightImpact();
    final sheetH = _sheetHeight(context);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Center(
        child: ConstrainedBox(
          constraints: _sheetConstraints(context),
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.lg)),
            child: SizedBox(
              height: sheetH,
              child: const SafeArea(
                top: false,
                child: Column(
                  children: [
                    SizedBox(height: Insets.xs),
                    Center(
                      child: SizedBox(
                        width: 36,
                        height: 4,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.all(Radius.circular(2)),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.xs),
                      child: Row(
                        children: [
                          Icon(Icons.layers_outlined, size: 20),
                          SizedBox(width: Insets.sm),
                          Text(
                            'Masks & Layers',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1),
                    Expanded(child: MaskControls()),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openLensBlurSheet(BuildContext context) {
    HapticFeedback.lightImpact();
    final sheetH = _sheetHeight(context);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Center(
        child: ConstrainedBox(
          constraints: _sheetConstraints(context),
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.lg)),
            child: SizedBox(
              height: sheetH,
              child: const SafeArea(
                top: false,
                child: Column(
              children: [
                SizedBox(height: Insets.xs),
                Center(
                  child: SizedBox(
                    width: 36,
                    height: 4,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.all(Radius.circular(2)),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.xs),
                  child: Row(
                    children: [
                      Icon(Icons.blur_on, size: 20),
                      SizedBox(width: Insets.sm),
                      Text(
                        'Lens Blur & Bokeh',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1),
                Expanded(child: BlurControls()),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
);
  }

  @override
  Widget build(BuildContext context) {
    final parameter = primaryParameterForTool(widget.tool);
    final spec = specOf(parameter);
    final zoneMask = ref.watch(zoneMaskProvider);
    final scheme = Theme.of(context).colorScheme;
    // Node mode swaps the bottom chrome for the node adjust bar, so the
    // tool pill (and its Selective entry) steps aside until Done.
    final nodeMode = ref.watch(nodeEditorProvider.select((s) => s.enabled));

    return LayoutBuilder(
      builder: (context, constraints) {
        final widthClass = windowSizeClassFor(constraints.maxWidth);
        final isWide = widthClass != WindowSizeClass.compact;
        final isLargeScreen = widthClass == WindowSizeClass.large ||
            widthClass == WindowSizeClass.extraLarge;
        final dockButtonConstraints = isLargeScreen
            ? const BoxConstraints(minWidth: 52, minHeight: 52)
            : const BoxConstraints(minWidth: 48, minHeight: 48);
        final dockIconSize = isLargeScreen ? 19.0 : 17.0;

        return Stack(
          children: [
        // Recent-changes HUD: float below top bar (top: 56), or below histogram (top: 140)
        // so it never collides with the histogram or status bar.
        Positioned(
          top: widget.histogramOpen ? 140 : 56,
          right: isLargeScreen ? 280 : 0,
          child: const SafeArea(left: false, bottom: false, child: EditHud()),
        ),

        // Ansel Adams Haptic Zone Masking targeting overlay
        if (zoneMask.isTargeting)
          Positioned(
            top: 72,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: scheme.error.withValues(alpha: 0.8),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.blur_circular,
                      color: scheme.error,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Zone ${zoneMask.activeZone} (${(zoneMask.activeZone / 10.0 * 100).round()}%) · Luminosity Mask',
                      style: TextStyle(
                        color: scheme.onError,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Ansel Adams Haptic Zone Masking locked pill
        if (zoneMask.lockedLayerIndex != null && !nodeMode)
          Positioned(
            bottom: isLargeScreen ? 16 : 64,
            left: 0,
            right: isLargeScreen ? 280 : 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.only(left: 12, right: 4, top: 4, bottom: 4),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.6),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.onSurface.withValues(alpha: 0.16),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock, color: scheme.primary, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'Zone ${zoneMask.activeZone} Mask Locked · ${spec.label}',
                      style: themeStyle(context, FontWeight.w600).copyWith(
                        color: scheme.onSurface,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                      icon: const Icon(Icons.close, size: 15),
                      tooltip: 'Remove Zone Mask',
                      onPressed: () {
                        ref.read(zoneMaskProvider.notifier).removeLockedMask();
                        HapticFeedback.lightImpact();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Live Snapseed-style top scrubbing HUD pill
        Positioned(
          top: MediaQuery.paddingOf(context).top + 16,
          left: 16,
          right: 16,
          child: SnapseedScrubHudHost(
            tool: widget.tool,
            gesturePhase: widget.gesturePhase,
            scrubVisible: _scrubVisible,
            nodeMode: nodeMode,
          ),
        ),

        // Persistent gesture discovery affordance when idle
        if (widget.gesturePhase == GesturePhase.idle && !_scrubVisible && !nodeMode)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 16,
            left: 16,
            right: 16,
            child: Center(
              child: GestureDetector(
                key: const Key('snapseed-gesture-hint-pill'),
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _radialOpen = true);
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: scheme.outlineVariant.withValues(alpha: 0.35),
                        ),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(gradeToolIcon(widget.tool), size: 14, color: scheme.primary),
                            const SizedBox(width: 5),
                            Text(
                              gradeToolLabel(widget.tool),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurface,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '↕ Tool  ↔ Adjust',
                              style: TextStyle(
                                fontSize: 11,
                                color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

        // Live Snapseed-style vertical parameter selection carousel
        if (widget.gesturePhase == GesturePhase.cycling && !nodeMode)
          Positioned.fill(
            child: IgnorePointer(
              child: SnapseedCarouselHost(
                category: widget.category,
                tools: widget.tools,
                activeTool: widget.tool,
                visible: true,
              ),
            ),
          ),

        // Unified Material 3 bottom dock (zero-overlap, integrated actions, responsive wide alignment).
        // On large/extraLarge screens (tablets), render a dedicated right sidebar with full-width tool buttons (Flaw 15).
        if (!nodeMode)
          isLargeScreen
              ? Align(
                  alignment: Alignment.bottomRight,
                  child: SafeArea(
                    top: false,
                    right: true,
                    child: SnapseedDockSidebar(
                      key: const Key('snapseed-dock-sidebar'),
                      tool: widget.tool,
                      category: widget.category,
                      onCycleCategory: widget.onCycleCategory,
                      onOpenToolsSheet: () => _openToolsSheet(context),
                      onOpenStacks: () {
                        HapticFeedback.lightImpact();
                        HistoryTreeSheet.show(context);
                      },
                      onToggleLooks: () {
                        HapticFeedback.lightImpact();
                        setState(() => _looksOpen = !_looksOpen);
                      },
                      looksOpen: _looksOpen,
                      onOpenMasks: () => _openMasksSheet(context),
                      onOpenLensBlur: () => _openLensBlurSheet(context),
                      onToggleStraighten: () {
                        HapticFeedback.lightImpact();
                        setState(() => _straightenOpen = !_straightenOpen);
                      },
                      straightenOpen: _straightenOpen,
                      onOpenRadial: () {
                        HapticFeedback.lightImpact();
                        setState(() => _radialOpen = true);
                      },
                      onEnableSelective: () {
                        HapticFeedback.lightImpact();
                        ref.read(nodeEditorProvider.notifier).enable();
                      },
                      hasHistogram: widget.hasHistogram,
                      histogramOpen: widget.histogramOpen,
                      onToggleHistogram: widget.onToggleHistogram,
                    ),
                  ),
                )
              : Align(
                  alignment: isWide ? Alignment.bottomRight : Alignment.bottomCenter,
                  child: SafeArea(
                    top: false,
                    right: true,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(Insets.sm, 0, isWide ? Insets.xl : Insets.sm, Insets.sm),
                      child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: scheme.outlineVariant.withValues(alpha: 0.5),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: scheme.onSurface.withValues(alpha: 0.16),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {},
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                key: const Key('snapseed-tools-sheet-toggle'),
                                tooltip: 'All Tools',
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: dockButtonConstraints,
                                onPressed: () => _openToolsSheet(context),
                                icon: Icon(Icons.grid_view, size: dockIconSize),
                              ),
                              IconButton(
                                key: const Key('snapseed-stacks-toggle'),
                                tooltip: 'View Edits (Stacks)',
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: dockButtonConstraints,
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  HistoryTreeSheet.show(context);
                                },
                                icon: Icon(Icons.layers, size: dockIconSize),
                              ),
                              IconButton(
                                key: const Key('snapseed-looks-toggle'),
                                tooltip: 'Looks & Presets',
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: dockButtonConstraints,
                                isSelected: _looksOpen,
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  setState(() => _looksOpen = !_looksOpen);
                                },
                                icon: Icon(Icons.style_outlined, size: dockIconSize),
                                selectedIcon: Icon(Icons.style, size: dockIconSize, color: scheme.primary),
                              ),
                              IconButton(
                                key: const Key('snapseed-mask-toggle'),
                                tooltip: 'Masks & Layers',
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: dockButtonConstraints,
                                onPressed: () => _openMasksSheet(context),
                                icon: Icon(Icons.layers_outlined, size: dockIconSize),
                              ),
                              IconButton(
                                key: const Key('snapseed-lens-blur-toggle'),
                                tooltip: 'Lens Blur & Bokeh',
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: dockButtonConstraints,
                                onPressed: () => _openLensBlurSheet(context),
                                icon: Icon(Icons.blur_on, size: dockIconSize),
                              ),
                              IconButton(
                                key: const Key('snapseed-straighten-toggle'),
                                tooltip: 'Straighten & Rotate',
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: dockButtonConstraints,
                                isSelected: _straightenOpen,
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  setState(() => _straightenOpen = !_straightenOpen);
                                },
                                icon: Icon(Icons.crop_rotate, size: dockIconSize),
                                selectedIcon: Icon(Icons.crop_rotate, size: dockIconSize, color: scheme.primary),
                              ),
                              IconButton(
                                tooltip: 'Tools',
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: dockButtonConstraints,
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  setState(() => _radialOpen = true);
                                },
                                icon: Icon(Icons.radio_button_checked, size: dockIconSize),
                              ),
                              Container(
                                width: 1,
                                height: 18,
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                color: scheme.outlineVariant,
                              ),
                              InkWell(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  widget.onCycleCategory();
                                },
                                borderRadius: Radii.smAll,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _categoryLabel(widget.category, AppStrings.of(context)),
                                        style: themeStyle(context, FontWeight.w600)
                                            .copyWith(color: scheme.onSurfaceVariant, fontSize: 11),
                                      ),
                                      const Icon(Icons.unfold_more, size: 12),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  widget.tool.is2D
                                      ? switch (widget.tool) {
                                          GradeTool.shadowsGrade => 'Shadows Grade',
                                          GradeTool.midtonesGrade => 'Midtones Grade',
                                          GradeTool.highlightsGrade => 'Highlights Grade',
                                          _ => spec.label,
                                        }
                                      : spec.label,
                                  overflow: TextOverflow.ellipsis,
                                  style: themeStyle(context, FontWeight.w600).copyWith(fontSize: 11),
                                ),
                              ),
                              const SizedBox(width: 4),
                              if (widget.tool.is2D)
                                Snapseed2DColorIndicator(tool: widget.tool)
                              else
                                Snapseed1DValueIndicator(tool: widget.tool),
                              Container(
                                width: 1,
                                height: 18,
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                color: scheme.outlineVariant,
                              ),
                              IconButton(
                                tooltip: 'HSL target: tap a colour in the photo, then '
                                    'drag to adjust it',
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: dockButtonConstraints,
                                isSelected: ref.watch(tatModeProvider),
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  ref.read(tatModeProvider.notifier).toggle();
                                },
                                icon: Icon(Icons.colorize, size: dockIconSize),
                                selectedIcon: Icon(Icons.colorize, size: dockIconSize, color: scheme.primary),
                              ),
                              IconButton(
                                key: const Key('selective-toggle'),
                                tooltip: 'Selective',
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: dockButtonConstraints,
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  ref.read(nodeEditorProvider.notifier).enable();
                                },
                                icon: Icon(Icons.add_location_alt, size: dockIconSize),
                              ),
                              if (widget.hasHistogram)
                                IconButton(
                                  key: const Key('histogram-toggle'),
                                  tooltip: widget.histogramOpen ? 'Hide histogram' : 'Show histogram',
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: dockButtonConstraints,
                                  isSelected: widget.histogramOpen,
                                  onPressed: () {
                                    HapticFeedback.selectionClick();
                                    widget.onToggleHistogram?.call();
                                  },
                                  icon: Icon(Icons.bar_chart, size: dockIconSize),
                                  selectedIcon: Icon(Icons.bar_chart, size: dockIconSize, color: scheme.primary),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Live Photo Preset/Looks Carousel
        if (_looksOpen && !nodeMode)
          Align(
            alignment: isWide ? Alignment.bottomRight : Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              right: true,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: isLargeScreen ? 16 : 74,
                  left: 16,
                  right: isLargeScreen ? 300 : (isWide ? Insets.xl : 16),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      key: const Key('snapseed-looks-carousel'),
                      constraints: BoxConstraints(
                        maxWidth: math.min(500.0, MediaQuery.sizeOf(context).width - 24.0),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: scheme.outlineVariant.withValues(alpha: 0.5),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: scheme.onSurface.withValues(alpha: 0.16),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.auto_awesome, size: 16, color: scheme.primary),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Looks & Presets',
                                      style: themeStyle(context, FontWeight.bold).copyWith(
                                        fontSize: 13,
                                        color: scheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                  icon: const Icon(Icons.close, size: 16),
                                  tooltip: 'Close Presets',
                                  onPressed: () => setState(() => _looksOpen = false),
                                ),
                              ],
                            ),
                          ),
                          if (_activePresetTool case final activePreset?)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(Radii.sm),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      '${activePreset.name} · ${(_activePresetAmount * 100).round()}%',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: scheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: SliderTheme(
                                        data: SliderTheme.of(context).copyWith(
                                          trackHeight: 2,
                                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                                        ),
                                        child: Slider(
                                          key: const Key('snapseed-preset-strength-slider'),
                                          value: _activePresetAmount,
                                          min: 0.0,
                                          max: 2.0,
                                          divisions: 40,
                                          onChanged: (val) {
                                            setState(() => _activePresetAmount = val);
                                            ref.read(recipeControllerProvider.notifier).applyTool(activePreset, amount: val);
                                          },
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close, size: 14),
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => setState(() => _activePresetTool = null),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          const SizedBox(height: 6),
                          SizedBox(
                            height: 76,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: ToolLibrary.builtins.length,
                              separatorBuilder: (_, _) => const SizedBox(width: 10),
                              itemBuilder: (context, index) {
                                final tool = ToolLibrary.builtins[index];
                                return InkWell(
                                  key: Key('snapseed-preset-${tool.name}'),
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    setState(() {
                                      _activePresetTool = tool;
                                      _activePresetAmount = 1.0;
                                    });
                                    ref.read(recipeControllerProvider.notifier).applyTool(tool, amount: 1.0);
                                    ref.read(recipeControllerProvider.notifier).commit(label: tool.name);
                                  },
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      PresetThumbnail(
                                        params: tool.params,
                                        size: 46,
                                      ),
                                      const SizedBox(height: 4),
                                      SizedBox(
                                        width: 58,
                                        child: Text(
                                          tool.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                            color: scheme.onSurface,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

        // Floating straighten & rotation dial HUD
        if (_straightenOpen && !nodeMode)
          Align(
            alignment: isWide ? Alignment.bottomRight : Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              right: true,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: isLargeScreen ? 16 : 74,
                  right: isLargeScreen ? 300 : (isWide ? Insets.xl : 0),
                ),
                child: DecoratedBox(
                  key: const Key('snapseed-straighten-panel'),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(alpha: 0.95),
                    borderRadius: Radii.mdAll,
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 8, 8),
                    child: SizedBox(
                      width: math.min(330.0, MediaQuery.sizeOf(context).width - 32.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Straighten & Rotate',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: scheme.onSurface,
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                iconSize: 18,
                                icon: const Icon(Icons.close),
                                onPressed: () =>
                                    setState(() => _straightenOpen = false),
                              ),
                            ],
                          ),
                          const PrecisionRotationDial(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),


        // Radial tool menu.
        if (_radialOpen)
          Positioned.fill(
            child: SnapseedRadialMenu(
              active: widget.tool,
              tools: widget.tools,
              iconOf: _icon,
              onDismiss: () => setState(() => _radialOpen = false),
              onPick: (t) {
                setState(() => _radialOpen = false);
                widget.onPickTool(t);
              },
            ),
          ),
          ],
        );
      },
    );
  }
}
