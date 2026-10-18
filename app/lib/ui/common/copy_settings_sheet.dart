import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/log/activity_log.dart';
import '../../core/log/log_providers.dart';
import '../../core/theme/design_tokens.dart';
import '../../edit/parameter.dart';
import '../../edit/recipe.dart';
import '../../edit/recipe_controller.dart';
import '../../edit/selective_recipe.dart';
import '../../edit/settings_clipboard.dart';
import 'app_sheet.dart';

class CopySettingsSheet extends ConsumerStatefulWidget {
  const CopySettingsSheet({super.key});

  @override
  ConsumerState<CopySettingsSheet> createState() => _CopySettingsSheetState();
}

class _CopySettingsSheetState extends ConsumerState<CopySettingsSheet> {
  late Set<RecipeSection> _selected;
  late Set<RecipeSection> _modified;
  late EditRecipe _recipe;

  @override
  void initState() {
    super.initState();
    _recipe = ref.read(recipeControllerProvider).recipe;
    _modified = CopiedSettings.detectModifiedSections(_recipe);
    // Pre-select modified sections, or all if none modified
    _selected = _modified.isNotEmpty
        ? Set<RecipeSection>.from(_modified)
        : RecipeSection.values.toSet();
  }

  void _selectAll() => setState(() => _selected = RecipeSection.values.toSet());
  void _selectModified() => setState(() => _selected = Set<RecipeSection>.from(_modified));
  void _deselectAll() => setState(() => _selected = <RecipeSection>{});

  void _confirm() {
    if (_selected.isEmpty) {
      Navigator.of(context).maybePop();
      return;
    }
    ref.read(settingsClipboardProvider.notifier).copy(_recipe, _selected);
    axLog(
      LogDomain.editor,
      'Copied settings (${_selected.map((s) => s.name).join(', ')})',
    );
    Navigator.of(context).maybePop();
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text('Copied ${_selected.length} settings group(s) to clipboard'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: AppSheet(
        title: 'Copy Settings',
        children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            TextButton(
              onPressed: _selectAll,
              child: const Text('Select All'),
            ),
            TextButton(
              onPressed: _selectModified,
              child: const Text('Modified Only'),
            ),
            TextButton(
              onPressed: _deselectAll,
              child: const Text('Deselect All'),
            ),
          ],
        ),
        const Divider(),
        ...RecipeSection.values.map((section) {
          final isModified = _modified.contains(section);
          final isChecked = _selected.contains(section);
          return CheckboxListTile(
            dense: true,
            value: isChecked,
            title: Text(
              _sectionTitle(section),
              style: TextStyle(
                fontWeight: isModified ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            subtitle: Text(
              isModified
                  ? '${_sectionSubtitle(section)} • Edited'
                  : _sectionSubtitle(section),
              style: TextStyle(
                color: isModified
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
            onChanged: (val) {
              setState(() {
                if (val == true) {
                  _selected.add(section);
                } else {
                  _selected.remove(section);
                }
              });
            },
          );
        }),
        const SizedBox(height: Insets.lg),
        FilledButton(
          key: const Key('copy-settings-confirm-btn'),
          onPressed: _confirm,
          child: Text('Copy (${_selected.length} groups)'),
        ),
      ],
    ));
  }

  static String _sectionTitle(RecipeSection s) => switch (s) {
    RecipeSection.light => 'Light / Basic Tone',
    RecipeSection.color => 'Color & Grading',
    RecipeSection.tone => 'Tone Curves',
    RecipeSection.effects => 'Effects & Texture',
    RecipeSection.detail => 'Detail & Sharpness',
    RecipeSection.optics => 'Optics & Defringe',
    RecipeSection.geometry => 'Geometry & Crop',
    RecipeSection.blur => 'Lens Blur & Bokeh',
    RecipeSection.masking => 'Masking & Groups',
    RecipeSection.retouch => 'Retouch Patches',
    RecipeSection.film => 'Film Simulation',
    RecipeSection.lab => 'Shader Lab',
  };

  static String _sectionSubtitle(RecipeSection s) => switch (s) {
    RecipeSection.light => 'Exposure, Contrast, Highlights, Shadows, Whites, Blacks',
    RecipeSection.color => 'White balance, HSL mixer, 3-way color grading wheels',
    RecipeSection.tone => 'Master and RGB custom curves',
    RecipeSection.effects => 'Clarity, Texture, Dehaze, Vignette, Grain',
    RecipeSection.detail => 'Sharpening, Luminance/Chrominance Denoise',
    RecipeSection.optics => 'Chromatic Aberration, Lens Profile Corrections',
    RecipeSection.geometry => 'Straighten, Skew, Perspective, Rotation, Crop',
    RecipeSection.blur => 'Synthetic aperture blur, Depth estimation, Bokeh',
    RecipeSection.masking => 'Local adjustment layers and AI segmentation masks',
    RecipeSection.retouch => 'Blemish healing brush and clone stamp patches',
    RecipeSection.film => 'Halation, Bloom, Dust and Scratches physics',
    RecipeSection.lab => 'Procedural shaders and custom GLSL code',
  };
}
