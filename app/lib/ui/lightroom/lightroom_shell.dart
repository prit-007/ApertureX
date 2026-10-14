import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../color/tat.dart';
import '../../edit/parameter.dart';
import '../../edit/recipe_controller.dart';
import '../../viewport/compare_hold.dart';
import '../common/geometry_controls.dart';
import '../common/hsl_mixer.dart';
import '../common/mask_controls.dart';
import '../common/parameter_panel.dart';
import '../common/tone_curve_editor.dart';

enum _Tab { panel, curve, mix, geometry, mask }

String _sectionLabel(RecipeSection section) => switch (section) {
  RecipeSection.light => 'Light',
  RecipeSection.color => 'Color',
  RecipeSection.tone => 'Tone',
  RecipeSection.effects => 'Effects',
  RecipeSection.detail => 'Detail',
  RecipeSection.optics => 'Optics',
  RecipeSection.geometry => 'Geometry',
  RecipeSection.masking => 'Masking',
};

/// Lightroom shell: a scrollable row of tool tabs over the shared recipe. The
/// histogram is no longer a permanent strip here — it lives as a collapsible
/// overlay on the image (see `AppShell`), so the tools get the whole area.
class LightroomShell extends ConsumerStatefulWidget {
  const LightroomShell({super.key});

  @override
  ConsumerState<LightroomShell> createState() => _LightroomShellState();
}

class _LightroomShellState extends ConsumerState<LightroomShell> {
  static const List<RecipeSection> _sections = [
    RecipeSection.light,
    RecipeSection.color,
    RecipeSection.effects,
    RecipeSection.detail,
  ];

  RecipeSection _section = RecipeSection.light;
  _Tab _tab = _Tab.panel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canUndo = ref.watch(
      recipeControllerProvider.select((s) => s.index > 0),
    );
    final canRedo = ref.watch(
      recipeControllerProvider.select((s) => s.index < s.history.length - 1),
    );
    final controller = ref.read(recipeControllerProvider.notifier);

    Widget chip(String label, bool selected, VoidCallback onTap) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
        labelStyle: TextStyle(
          fontSize: 12,
          letterSpacing: 0.4,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );

    return Column(
      children: [
        SizedBox(
          height: 52,
          child: Row(
            children: [
              Expanded(
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  children: [
                    for (final section in _sections)
                      chip(
                        _sectionLabel(section),
                        _tab == _Tab.panel && section == _section,
                        () => setState(() {
                          _section = section;
                          _tab = _Tab.panel;
                        }),
                      ),
                    chip('Curve', _tab == _Tab.curve, () => setState(() => _tab = _Tab.curve)),
                    chip('Mix', _tab == _Tab.mix, () => setState(() => _tab = _Tab.mix)),
                    chip('Geometry', _tab == _Tab.geometry, () => setState(() => _tab = _Tab.geometry)),
                    chip('Mask', _tab == _Tab.mask, () => setState(() => _tab = _Tab.mask)),
                  ],
                ),
              ),
              if (ref.watch(tatModeProvider))
                TextButton(
                  onPressed: () =>
                      ref.read(tatComponentProvider.notifier).cycle(),
                  child: Text(
                    tatComponentLabels[ref.watch(tatComponentProvider)],
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              IconButton(
                tooltip: 'Target Adjustment: drag the image to target the HSL '
                    'colour under your finger',
                isSelected: ref.watch(tatModeProvider),
                onPressed: () => ref.read(tatModeProvider.notifier).toggle(),
                icon: const Icon(Icons.colorize),
                selectedIcon: Icon(Icons.colorize, color: scheme.primary),
              ),
              // History + compare live at the bottom, in the thumb zone
              // (issue #28) — the app bar keeps only crop/more/export.
              IconButton(
                tooltip: 'Undo',
                onPressed: canUndo ? controller.undo : null,
                icon: const Icon(Icons.undo),
              ),
              IconButton(
                tooltip: 'Redo',
                onPressed: canRedo ? controller.redo : null,
                icon: const Icon(Icons.redo),
              ),
              Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (_) =>
                    ref.read(compareHoldProvider.notifier).hold(),
                onPointerUp: (_) =>
                    ref.read(compareHoldProvider.notifier).release(),
                onPointerCancel: (_) =>
                    ref.read(compareHoldProvider.notifier).release(),
                child: IconButton(
                  tooltip: 'Hold to compare',
                  // The Listener above drives the compare; the button only
                  // provides the affordance and the ripple.
                  onPressed: () {},
                  icon: const Icon(Icons.compare),
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: scheme.outlineVariant),
        Expanded(
          child: switch (_tab) {
            _Tab.panel => SafeArea(bottom: true, child: ParameterPanel(section: _section)),
            _Tab.curve => const ToneCurveEditor(),
            _Tab.mix => const SingleChildScrollView(child: HslMixer()),
            _Tab.geometry => const SingleChildScrollView(child: GeometryControls()),
            _Tab.mask => const MaskControls(),
          },
        ),
      ],
    );
  }
}
