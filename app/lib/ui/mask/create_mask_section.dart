import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/design_tokens.dart';
import '../../edit/adjustment_layer.dart';

/// Categorized creation section grouped into AI Masks, Manual Tools, and Range Masks.
class CreateMaskCategorizedSection extends StatelessWidget {
  const CreateMaskCategorizedSection({
    super.key,
    required this.context,
    required this.ref,
    required this.isInferring,
    required this.onAddMask,
    required this.onAddAiSubject,
    required this.onAddAiFace,
    required this.onAddAiSkin,
    required this.onAddAiHair,
    required this.onAddAiObject,
    required this.onAddSky,
    required this.onAddDepthMap,
    this.onToolTap,
  });

  final BuildContext context;
  final WidgetRef ref;
  final bool isInferring;
  final void Function(MaskKind kind, {bool inverted, double? exposure}) onAddMask;
  final void Function({required bool inverted}) onAddAiSubject;
  final VoidCallback onAddAiFace;
  final VoidCallback onAddAiSkin;
  final VoidCallback onAddAiHair;
  final VoidCallback onAddAiObject;
  final VoidCallback onAddSky;
  final VoidCallback onAddDepthMap;
  final VoidCallback? onToolTap;

  Widget _buildToolTile({
    Key? key,
    required BuildContext ctx,
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    bool isTonal = false,
  }) {
    final scheme = Theme.of(ctx).colorScheme;
    return OutlinedButton(
      key: key,
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        backgroundColor: isTonal ? scheme.primary.withValues(alpha: 0.08) : null,
        foregroundColor: isTonal ? scheme.primary : scheme.onSurface,
        side: BorderSide(
          color: isTonal ? scheme.primary.withValues(alpha: 0.35) : scheme.outlineVariant.withValues(alpha: 0.5),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: const RoundedRectangleBorder(borderRadius: Radii.smAll),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isTonal ? scheme.primary : scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext buildContext) {
    final scheme = Theme.of(buildContext).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. AI MASKS
        Container(
          margin: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 4),
          padding: const EdgeInsets.all(Insets.sm),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh.withValues(alpha: 0.45),
            borderRadius: Radii.mdAll,
            border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 4,
                children: [
                  Icon(Icons.auto_awesome, size: 14, color: scheme.primary),
                  Text(
                    'AI MASKS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'On-Device AI',
                      style: TextStyle(
                        fontSize: 12.0,
                        fontWeight: FontWeight.bold,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Insets.xs),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildToolTile(
                    key: const Key('mask-add-subject'),
                    ctx: buildContext,
                    icon: Icons.person,
                    label: 'Subject +',
                    isTonal: true,
                    onPressed: isInferring
                        ? null
                        : () {
                            onToolTap?.call();
                            onAddAiSubject(inverted: false);
                          },
                  ),
                  _buildToolTile(
                    key: const Key('mask-add-sky'),
                    ctx: buildContext,
                    icon: Icons.cloud_outlined,
                    label: 'Sky +',
                    isTonal: true,
                    onPressed: isInferring
                        ? null
                        : () {
                            onToolTap?.call();
                            onAddSky();
                          },
                  ),
                  _buildToolTile(
                    key: const Key('mask-add-background'),
                    ctx: buildContext,
                    icon: Icons.wallpaper,
                    label: 'Background +',
                    isTonal: true,
                    onPressed: isInferring
                        ? null
                        : () {
                            onToolTap?.call();
                            onAddAiSubject(inverted: true);
                            HapticFeedback.selectionClick();
                          },
                  ),
                  _buildToolTile(
                    key: const Key('mask-add-face'),
                    ctx: buildContext,
                    icon: Icons.face_retouching_natural,
                    label: 'Face +',
                    isTonal: true,
                    onPressed: isInferring
                        ? null
                        : () {
                            onToolTap?.call();
                            onAddAiFace();
                            HapticFeedback.selectionClick();
                          },
                  ),
                  _buildToolTile(
                    key: const Key('mask-add-skin'),
                    ctx: buildContext,
                    icon: Icons.face,
                    label: 'Skin +',
                    isTonal: true,
                    onPressed: isInferring
                        ? null
                        : () {
                            onToolTap?.call();
                            onAddAiSkin();
                            HapticFeedback.selectionClick();
                          },
                  ),
                  _buildToolTile(
                    key: const Key('mask-add-hair'),
                    ctx: buildContext,
                    icon: Icons.content_cut,
                    label: 'Hair +',
                    isTonal: true,
                    onPressed: isInferring
                        ? null
                        : () {
                            onToolTap?.call();
                            onAddAiHair();
                            HapticFeedback.selectionClick();
                          },
                  ),
                  _buildToolTile(
                    key: const Key('mask-add-object'),
                    ctx: buildContext,
                    icon: Icons.category,
                    label: 'Object +',
                    isTonal: true,
                    onPressed: isInferring
                        ? null
                        : () {
                            onToolTap?.call();
                            onAddAiObject();
                            HapticFeedback.selectionClick();
                          },
                  ),
                ],
              ),
            ],
          ),
        ),

        // 2. MANUAL TOOLS
        Container(
          margin: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 4),
          padding: const EdgeInsets.all(Insets.sm),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh.withValues(alpha: 0.35),
            borderRadius: Radii.mdAll,
            border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.gesture, size: 14, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    'MANUAL TOOLS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Insets.xs),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildToolTile(
                    key: const Key('mask-add-brush'),
                    ctx: buildContext,
                    icon: Icons.brush,
                    label: 'Brush +',
                    onPressed: () {
                      onToolTap?.call();
                      onAddMask(MaskKind.brush);
                    },
                  ),
                  _buildToolTile(
                    key: const Key('mask-add-autobrush'),
                    ctx: buildContext,
                    icon: Icons.auto_fix_normal,
                    label: 'Auto Brush +',
                    onPressed: () {
                      onToolTap?.call();
                      onAddMask(MaskKind.autoBrush);
                    },
                  ),
                  _buildToolTile(
                    key: const Key('mask-add-linear'),
                    ctx: buildContext,
                    icon: Icons.gradient,
                    label: 'Linear +',
                    onPressed: () {
                      onToolTap?.call();
                      onAddMask(MaskKind.linear);
                    },
                  ),
                  _buildToolTile(
                    key: const Key('mask-add-radial'),
                    ctx: buildContext,
                    icon: Icons.brightness_5,
                    label: 'Radial +',
                    onPressed: () {
                      onToolTap?.call();
                      onAddMask(MaskKind.radial);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),

        // 3. RANGE MASKS
        Container(
          margin: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 4),
          padding: const EdgeInsets.all(Insets.sm),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh.withValues(alpha: 0.35),
            borderRadius: Radii.mdAll,
            border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.tune, size: 14, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    'RANGE MASKS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Insets.xs),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildToolTile(
                    key: const Key('mask-add-color-range'),
                    ctx: buildContext,
                    icon: Icons.colorize,
                    label: 'Color Range +',
                    onPressed: () {
                      onToolTap?.call();
                      onAddMask(MaskKind.colorRange);
                    },
                  ),
                  _buildToolTile(
                    key: const Key('mask-add-luminance'),
                    ctx: buildContext,
                    icon: Icons.brightness_6,
                    label: 'Darks +',
                    onPressed: () {
                      onToolTap?.call();
                      onAddMask(MaskKind.luminance);
                    },
                  ),
                  _buildToolTile(
                    key: const Key('mask-add-depth-range'),
                    ctx: buildContext,
                    icon: Icons.layers_outlined,
                    label: 'Depth Range +',
                    onPressed: () {
                      onToolTap?.call();
                      onAddMask(MaskKind.depthRange);
                    },
                  ),
                  _buildToolTile(
                    key: const Key('mask-add-depth'),
                    ctx: buildContext,
                    icon: Icons.blur_on,
                    label: 'Depth +',
                    onPressed: isInferring
                        ? null
                        : () {
                            onToolTap?.call();
                            onAddDepthMap();
                          },
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
