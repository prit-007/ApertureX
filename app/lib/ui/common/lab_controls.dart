import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../edit/parameter.dart';
import '../../edit/recipe_controller.dart';
import 'app_primitives.dart';
import 'parameter_control.dart';

/// Supported community/pro shader lab presets.
enum ShaderLabPreset {
  none(0, 'None'),
  vhs(1, 'VHS Retro'),
  prism(2, 'Prism Dispersion'),
  crt(3, 'CRT Scanlines'),
  pixelate(4, 'Pixelate');

  const ShaderLabPreset(this.id, this.label);
  final int id;
  final String label;

  static ShaderLabPreset fromId(int id) {
    return ShaderLabPreset.values.firstWhere(
      (p) => p.id == id,
      orElse: () => ShaderLabPreset.none,
    );
  }
}

/// Shader Lab: analog VHS glitches, chromatic prism dispersion,
/// retro CRT scanlines, and pixelation shaders.
class LabControls extends ConsumerWidget {
  const LabControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipe = ref.watch(recipeControllerProvider).recipe;
    final notifier = ref.read(recipeControllerProvider.notifier);
    final activePreset = ShaderLabPreset.fromId(recipe.shaderLabPreset);

    return ListView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        const SectionHeader('Community Shaders & Glitches'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final preset in ShaderLabPreset.values)
                ChoiceChip(
                  label: Text(preset.label),
                  selected: preset == activePreset,
                  onSelected: (selected) {
                    if (selected) {
                      notifier.setShaderLabPreset(preset.id);
                    }
                  },
                ),
            ],
          ),
        ),
        if (activePreset != ShaderLabPreset.none) ...[
          const SectionHeader('Shader Parameters'),
          const ParameterControl(parameter: Parameter.shaderParam1),
          const ParameterControl(parameter: Parameter.shaderParam2),
          const ParameterControl(parameter: Parameter.shaderParam3),
        ],
      ],
    );
  }
}
