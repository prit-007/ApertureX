import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../color/tat.dart';
import '../../edit/parameter.dart';
import '../../edit/recipe_controller.dart';
import '../../viewport/compare_hold.dart';
import '../common/color_grading_editor.dart';
import '../common/geometry_controls.dart';
import '../common/hsl_mixer.dart';
import '../common/mask_controls.dart';
import '../common/optics_controls.dart';
import '../common/parameter_panel.dart';
import '../common/retouch_controls.dart';
import '../common/tone_curve_editor.dart';

enum _Tab { panel, curve, mix, grade }

String _sectionLabel(RecipeSection section) => switch (section) {
  RecipeSection.light => 'Light',
  RecipeSection.color => 'Color',
  RecipeSection.tone => 'Tone',
  RecipeSection.retouch => 'Retouch',
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
  /// Sections rendered as chips. `tone` is intentionally absent: its
  /// Curve/Mix views live inside Color (issue #44) and it carries no sliders
  /// of its own, so its panel used to render empty; `optics` stays out until
  /// lens-correction parameters exist (issue #66) — an empty panel reads as a
  /// broken tool.
  static const List<RecipeSection> _sections = [
    RecipeSection.light,
    RecipeSection.color,
    RecipeSection.retouch,
    RecipeSection.effects,
    RecipeSection.detail,
    RecipeSection.optics,
    RecipeSection.geometry,
    RecipeSection.masking,
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
        // Full-width chip strip: on a phone the trailing icon cluster used to
        // squeeze the scrollable chips to ~2 visible sections, so the rest of
        // the tools (Effects/Detail/Geometry/Masking) were undiscoverable.
        // The chips get their own row; actions sit below them.
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
            ],
          ),
        ),
        Divider(height: 1, color: scheme.outlineVariant),
        SizedBox(
          height: 48,
          child: Row(
            children: [
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
          child: SafeArea(bottom: true, child: _sectionBody()),
        ),
      ],
    );
  }

  /// The body for the selected top-level section. Color exposes the
  /// tone-curve and HSL-mixer as secondary tabs (issue #44) — they are views
  /// of colour data, not peer sections of the top chip row.
  Widget _sectionBody() {
    switch (_section) {
      case RecipeSection.color:
        return Column(
          children: [
            _subTabs(),
            Expanded(
              child: switch (_tab) {
                _Tab.curve => const ToneCurveEditor(),
                _Tab.mix => const SingleChildScrollView(child: HslMixer()),
                _Tab.grade =>
                  const SingleChildScrollView(child: ColorGradingEditor()),
                _Tab.panel => ParameterPanel(section: _section),
              },
            ),
          ],
        );
      case RecipeSection.geometry:
        return const SingleChildScrollView(child: GeometryControls());
      case RecipeSection.retouch:
        return const RetouchControls();
      case RecipeSection.masking:
        return const MaskControls();
      case RecipeSection.optics:
        return const OpticsControls();
      default:
        return ParameterPanel(section: _section);
    }
  }

  Widget _subTabs() {
    Widget tab(String label, _Tab value) => TextButton(
      onPressed: () => setState(() => _tab = value),
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        foregroundColor: _tab == value
            ? Theme.of(context).colorScheme.primary
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: _tab == value ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );

    return Row(
      children: [
        tab('Sliders', _Tab.panel),
        tab('Curve', _Tab.curve),
        tab('Mix', _Tab.mix),
        tab('Grade', _Tab.grade),
      ],
    );
  }
}
