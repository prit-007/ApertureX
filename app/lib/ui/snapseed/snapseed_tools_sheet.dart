import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/design_tokens.dart';
import '../../edit/adjustment_layer.dart';
import '../../edit/node_editor.dart';
import '../../edit/parameter.dart';
import '../../edit/recipe.dart';
import '../../edit/recipe_controller.dart';
import '../../gesture/gesture_interpreter.dart';
import '../common/blur_controls.dart';
import '../common/editor_guide_sheet.dart';
import '../common/film_controls.dart';
import '../common/lab_controls.dart';
import '../common/optics_controls.dart';
import '../common/retouch_controls.dart';
import '../common/tone_curve_editor.dart';

enum SnapseedToolType {
  tuneImage,
  details,
  curves,
  whiteBalance,
  cropRotate,
  straighten,
  selective,
  brush,
  healing,
  lensBlur,
  vignette,
  film,
  optics,
  shaderLab,
}

class SnapseedToolDef {
  const SnapseedToolDef({
    required this.id,
    required this.label,
    required this.icon,
    this.category,
    this.tool,
  });

  final SnapseedToolType id;
  final String label;
  final IconData icon;
  final ToolCategory? category;
  final GradeTool? tool;
}

const List<SnapseedToolDef> snapseedToolsList = [
  SnapseedToolDef(
    id: SnapseedToolType.tuneImage,
    label: 'Tune Image',
    icon: Icons.tune,
    category: ToolCategory.light,
    tool: GradeTool.exposure,
  ),
  SnapseedToolDef(
    id: SnapseedToolType.details,
    label: 'Details',
    icon: Icons.details,
    category: ToolCategory.detail,
    tool: GradeTool.sharpen,
  ),
  SnapseedToolDef(
    id: SnapseedToolType.curves,
    label: 'Curves',
    icon: Icons.show_chart,
  ),
  SnapseedToolDef(
    id: SnapseedToolType.whiteBalance,
    label: 'White Balance',
    icon: Icons.thermostat,
    category: ToolCategory.color,
    tool: GradeTool.temperature,
  ),
  SnapseedToolDef(
    id: SnapseedToolType.cropRotate,
    label: 'Crop & Rotate',
    icon: Icons.crop_rotate,
  ),
  SnapseedToolDef(
    id: SnapseedToolType.straighten,
    label: 'Straighten',
    icon: Icons.rotate_90_degrees_cw,
  ),
  SnapseedToolDef(
    id: SnapseedToolType.selective,
    label: 'Selective',
    icon: Icons.add_location_alt,
  ),
  SnapseedToolDef(
    id: SnapseedToolType.brush,
    label: 'Brush',
    icon: Icons.brush,
  ),
  SnapseedToolDef(
    id: SnapseedToolType.healing,
    label: 'Healing',
    icon: Icons.auto_fix_high,
  ),
  SnapseedToolDef(
    id: SnapseedToolType.lensBlur,
    label: 'Lens Blur',
    icon: Icons.blur_on,
  ),
  SnapseedToolDef(
    id: SnapseedToolType.vignette,
    label: 'Vignette',
    icon: Icons.vignette,
    category: ToolCategory.effects,
    tool: GradeTool.vignette,
  ),
  SnapseedToolDef(
    id: SnapseedToolType.film,
    label: 'Film & Grain',
    icon: Icons.movie_filter,
  ),
  SnapseedToolDef(
    id: SnapseedToolType.optics,
    label: 'Optics',
    icon: Icons.camera,
  ),
  SnapseedToolDef(
    id: SnapseedToolType.shaderLab,
    label: 'Shader Lab',
    icon: Icons.science,
  ),
];

/// A Snapseed-style comprehensive tools bottom sheet displaying an organized
/// grid of all 14 creative editing tools with iconic circular buttons.
class SnapseedToolsSheet extends ConsumerWidget {
  const SnapseedToolsSheet({
    super.key,
    required this.onSelectCategoryAndTool,
    this.onOpenStraighten,
    this.onOpenCrop,
  });

  final void Function(ToolCategory category, GradeTool tool) onSelectCategoryAndTool;
  final VoidCallback? onOpenStraighten;
  final VoidCallback? onOpenCrop;

  void _handleToolTap(BuildContext context, WidgetRef ref, SnapseedToolDef tool) {
    Navigator.of(context).pop();

    switch (tool.id) {
      case SnapseedToolType.selective:
        ref.read(nodeEditorProvider.notifier).enable();
      case SnapseedToolType.brush:
        final idx = ref.read(recipeControllerProvider).recipe.layers.length;
        ref.read(recipeControllerProvider.notifier).addLayer(
              const AdjustmentLayer(
                maskKind: MaskKind.brush,
                maskParams: [0.06, 0.25, 0],
                exposure: 0.6,
              ),
            );
        ref.read(nodeEditorProvider.notifier).enable();
        ref.read(nodeEditorProvider.notifier).select(idx);
      case SnapseedToolType.straighten:
        onOpenStraighten?.call();
      case SnapseedToolType.cropRotate:
        onOpenCrop?.call();
      case SnapseedToolType.curves:
        _showToolPanel(context, 'Curves', const ToneCurveEditor());
      case SnapseedToolType.lensBlur:
        _showToolPanel(context, 'Lens Blur', const BlurControls());
      case SnapseedToolType.film:
        _showToolPanel(context, 'Film & Grain', const FilmControls());
      case SnapseedToolType.optics:
        _showToolPanel(context, 'Optics', const OpticsControls());
      case SnapseedToolType.shaderLab:
        _showToolPanel(context, 'Shader Lab', const LabControls());
      case SnapseedToolType.healing:
        _showToolPanel(context, 'Healing', const RetouchControls());
      default:
        if (tool.category != null && tool.tool != null) {
          onSelectCategoryAndTool(tool.category!, tool.tool!);
        }
    }
  }

  void _showToolPanel(BuildContext context, String title, Widget body) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.lg)),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.65,
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                const SizedBox(height: Insets.xs),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.xs),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title.toUpperCase(),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.check, size: 20),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(child: body),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final recipe = ref.watch(recipeControllerProvider).recipe;

    return Material(
      color: scheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.lg)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Insets.md, Insets.sm, Insets.md, Insets.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Grab handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: Insets.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TOOLS',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Guide & Gestures',
                        icon: const Icon(Icons.help_outline, size: 20),
                        onPressed: () => EditorGuideSheet.show(context),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: Insets.xs),
              Expanded(
                child: GridView.builder(
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: Insets.md,
                    crossAxisSpacing: Insets.sm,
                    childAspectRatio: 0.82,
                  ),
                  itemCount: snapseedToolsList.length,
                  itemBuilder: (context, index) {
                    final tool = snapseedToolsList[index];
                    final isModified = isSnapseedToolModified(recipe, tool.id);
                    return InkWell(
                      borderRadius: Radii.mdAll,
                      onTap: () => _handleToolTap(context, ref, tool),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Badge(
                            isLabelVisible: isModified,
                            smallSize: 7,
                            backgroundColor: scheme.primary,
                            alignment: const AlignmentDirectional(0.85, -0.85),
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isModified
                                    ? scheme.primaryContainer.withValues(alpha: 0.45)
                                    : scheme.surfaceContainerHighest,
                              ),
                              child: Icon(
                                tool.icon,
                                size: 24,
                                color: isModified ? scheme.primary : scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            tool.label,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isModified ? FontWeight.w700 : FontWeight.w500,
                              color: isModified ? scheme.primary : scheme.onSurface,
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
    );
  }
}

/// Returns true if [id] has active adjustments in [recipe].
bool isSnapseedToolModified(EditRecipe recipe, SnapseedToolType id) => switch (id) {
  SnapseedToolType.tuneImage => isSectionModified(recipe, RecipeSection.light),
  SnapseedToolType.details => isSectionModified(recipe, RecipeSection.detail),
  SnapseedToolType.curves => isSectionModified(recipe, RecipeSection.tone),
  SnapseedToolType.whiteBalance => recipe.temperature != 0 || recipe.tint != 0,
  SnapseedToolType.cropRotate =>
    recipe.rotation != 0 || recipe.flipH || recipe.flipV || recipe.crop != fullCrop,
  SnapseedToolType.straighten => recipe.straighten != 0,
  SnapseedToolType.selective => recipe.layers.isNotEmpty,
  SnapseedToolType.brush => recipe.layers.any((l) => l.maskKind == MaskKind.brush),
  SnapseedToolType.healing => recipe.retouchPatches.isNotEmpty,
  SnapseedToolType.lensBlur => isSectionModified(recipe, RecipeSection.blur),
  SnapseedToolType.vignette => recipe.vignette != 0,
  SnapseedToolType.film => isSectionModified(recipe, RecipeSection.film),
  SnapseedToolType.optics => isSectionModified(recipe, RecipeSection.optics),
  SnapseedToolType.shaderLab => isSectionModified(recipe, RecipeSection.lab),
};

