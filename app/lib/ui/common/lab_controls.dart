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
  pixelate(4, 'Pixelate'),
  custom(5, 'Custom GLSL');

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

/// Shader Lab: community GLSL shaders, analog VHS glitches, chromatic prism dispersion,
/// retro CRT scanlines, pixelation, and live customizable GLSL fragment shaders.
class LabControls extends ConsumerWidget {
  const LabControls({super.key});

  void _showGlslEditor(BuildContext context, WidgetRef ref, String initialCode) {
    final controller = TextEditingController(text: initialCode);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Custom GLSL Shader'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Paste custom fragment shader code or uniforms.\nu_param1, u_param2, u_param3 are available as float uniforms.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 10,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '// Paste GLSL fragment shader code here...',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref
                  .read(recipeControllerProvider.notifier)
                  .setCustomGlslCode(controller.text);
              Navigator.of(ctx).pop();
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipe = ref.watch(recipeControllerProvider).recipe;
    final notifier = ref.read(recipeControllerProvider.notifier);
    final activePreset = ShaderLabPreset.fromId(recipe.shaderLabPreset);

    return ListView(
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
          if (activePreset == ShaderLabPreset.custom) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.code),
                label: const Text('Edit Custom GLSL'),
                onPressed: () => _showGlslEditor(context, ref, recipe.customGlslCode),
              ),
            ),
          ],
          const SectionHeader('Shader Parameters'),
          const ParameterControl(parameter: Parameter.shaderParam1),
          const ParameterControl(parameter: Parameter.shaderParam2),
          const ParameterControl(parameter: Parameter.shaderParam3),
        ],
      ],
    );
  }
}
