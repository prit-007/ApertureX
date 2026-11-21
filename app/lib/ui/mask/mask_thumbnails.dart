import 'package:material_ui/material_ui.dart';

import '../../core/theme/design_tokens.dart';
import '../../edit/adjustment_layer.dart';

/// High-contrast miniature thumbnail for individual mask layer cards.
class MaskThumbnail extends StatelessWidget {
  const MaskThumbnail({
    super.key,
    required this.kind,
    required this.isSelected,
    this.inverted = false,
  });

  final MaskKind kind;
  final bool isSelected;
  final bool inverted;

  IconData _iconForKind(MaskKind k) {
    return switch (k) {
      MaskKind.radial => Icons.brightness_5,
      MaskKind.linear => Icons.gradient,
      MaskKind.luminance => Icons.brightness_6,
      MaskKind.brush => Icons.brush,
      MaskKind.autoBrush => Icons.auto_fix_normal,
      MaskKind.subject => Icons.person,
      MaskKind.sky => Icons.cloud_outlined,
      MaskKind.bitmap => Icons.grain,
      MaskKind.colorRange => Icons.colorize,
      MaskKind.depthRange => Icons.layers_outlined,
      MaskKind.background => Icons.wallpaper,
      MaskKind.personFace => Icons.face,
      MaskKind.personSkin => Icons.face_retouching_natural,
      MaskKind.personHair => Icons.content_cut,
      MaskKind.object => Icons.category,
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: Radii.smAll,
        border: Border.all(
          color: isSelected ? scheme.primary : scheme.outlineVariant.withValues(alpha: 0.4),
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.primary.withValues(alpha: inverted ? 0.08 : 0.18),
            ),
          ),
          Icon(
            _iconForKind(kind),
            size: 18,
            color: isSelected ? scheme.primary : scheme.onSurface,
          ),
          if (inverted)
            Positioned(
              right: 2,
              bottom: 2,
              child: Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.orange,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// High-contrast miniature thumbnail for mask group cards.
class GroupThumbnail extends StatelessWidget {
  const GroupThumbnail({super.key, required this.group});

  final MaskGroup group;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: Radii.smAll,
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.4),
          width: 1.0,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.layers,
          size: 18,
          color: group.amount > 0 ? scheme.primary : scheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}
