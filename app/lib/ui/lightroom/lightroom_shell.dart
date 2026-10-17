import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/log/activity_log.dart';
import '../../core/log/log_providers.dart';
import '../../color/tat.dart';
import '../../edit/parameter.dart';
import '../../edit/recipe.dart';
import '../../edit/recipe_controller.dart';
import '../../viewport/compare_hold.dart';
import '../common/blur_controls.dart';
import '../common/color_grading_editor.dart';
import '../common/film_controls.dart';
import '../common/geometry_controls.dart';
import '../common/hsl_mixer.dart';
import '../common/lab_controls.dart';
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
  RecipeSection.blur => 'Blur',
  RecipeSection.effects => 'Effects',
  RecipeSection.detail => 'Detail',
  RecipeSection.optics => 'Optics',
  RecipeSection.geometry => 'Geometry',
  RecipeSection.masking => 'Masking',
  RecipeSection.film => 'Film',
  RecipeSection.lab => 'Lab',
};

class ActiveSectionNotifier extends Notifier<RecipeSection> {
  @override
  RecipeSection build() => RecipeSection.light;
  void select(RecipeSection section) {
    state = section;
    axLog(LogDomain.editor, 'Switched tool tab to ${_sectionLabel(section)}');
  }
}

final activeSectionProvider =
    NotifierProvider<ActiveSectionNotifier, RecipeSection>(
  ActiveSectionNotifier.new,
);

/// Lightroom shell: a scrollable row of tool tabs over the shared recipe. The
/// histogram is no longer a permanent strip here — it lives as a collapsible
/// overlay on the image (see `AppShell`), so the tools get the whole area.
class LightroomShell extends ConsumerStatefulWidget {
  const LightroomShell({super.key});

  @override
  ConsumerState<LightroomShell> createState() => _LightroomShellState();
}

class _LightroomShellState extends ConsumerState<LightroomShell> {
  /// Sections rendered as chips.
  static const List<RecipeSection> _sections = [
    RecipeSection.light,
    RecipeSection.color,
    RecipeSection.retouch,
    RecipeSection.blur,
    RecipeSection.effects,
    RecipeSection.detail,
    RecipeSection.optics,
    RecipeSection.geometry,
    RecipeSection.masking,
    RecipeSection.film,
    RecipeSection.lab,
  ];

  RecipeSection _section = RecipeSection.light;
  _Tab _tab = _Tab.panel;
  late final ScrollController _tabScrollController;
  EditRecipe? _sessionStartRecipe;


  @override
  void initState() {
    super.initState();
    _tabScrollController = ScrollController();
  }

  @override
  void dispose() {
    _tabScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final currentRecipe = ref.watch(recipeControllerProvider).recipe;
    _sessionStartRecipe ??= currentRecipe;
    final hasChanges = currentRecipe != _sessionStartRecipe;

    final canUndo = ref.watch(
      recipeControllerProvider.select((s) => s.index > 0),
    );
    final canRedo = ref.watch(
      recipeControllerProvider.select((s) => s.index < s.history.length - 1),
    );
    final controller = ref.read(recipeControllerProvider.notifier);

    Widget chip(RecipeSection section, bool selected, bool isModified, VoidCallback onTap) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_sectionLabel(section)),
            if (isModified) ...[
              const SizedBox(width: 4),
              Container(
                key: Key('applied-dot-${section.name}'),
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? scheme.primary : scheme.primary.withValues(alpha: 0.85),
                ),
              ),
            ],
          ],
        ),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        side: BorderSide(
          color: selected
              ? scheme.primary
              : isModified
                  ? scheme.primary.withValues(alpha: 0.45)
                  : scheme.outlineVariant.withValues(alpha: 0.5),
        ),
        selectedColor: scheme.primaryContainer,
        backgroundColor: scheme.surfaceContainerHigh,
        labelStyle: TextStyle(
          fontSize: 12,
          letterSpacing: 0.4,
          color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final content = Column(
          children: [
            // Category Chips Bar (top): scrollable row of tool categories
            SizedBox(
              height: 40,
              child: ListView(
                controller: _tabScrollController,
                physics: const BouncingScrollPhysics(),
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                children: [
                  for (final section in _sections)
                    chip(
                      section,
                      _tab == _Tab.panel && section == _section,
                      isSectionModified(currentRecipe, section),
                      () {
                        HapticFeedback.selectionClick();
                        if (hasChanges) {
                          controller.commit(label: 'Applied ${_sectionLabel(_section)}');
                        }
                        setState(() {
                          _section = section;
                          _tab = _Tab.panel;
                          _sessionStartRecipe = ref.read(recipeControllerProvider).recipe;
                        });
                        ref.read(activeSectionProvider.notifier).select(section);
                        final idx = _sections.indexOf(section);
                        if (_tabScrollController.hasClients) {
                          final target = (idx * 84.0 - 40.0).clamp(
                            0.0,
                            _tabScrollController.position.maxScrollExtent,
                          );
                          _tabScrollController.animateTo(
                            target,
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOut,
                          );
                        }
                      },
                    ),
                ],
              ),
            ),
            Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.2)),
            // Streamlined Action Bar: Cancel, TAT, Undo, Redo, Compare, Apply
            SizedBox(
              height: 38,
              child: Row(
                children: [
                  IconButton(
                    key: const Key('tray-cancel'),
                    tooltip: 'Discard changes',
                    visualDensity: VisualDensity.compact,
                    onPressed: hasChanges
                        ? () {
                            HapticFeedback.lightImpact();
                            controller.loadRecipe(
                              _sessionStartRecipe!,
                              label: 'Discarded ${_sectionLabel(_section)} changes',
                            );
                            setState(() {});
                          }
                        : null,
                    icon: Icon(
                      Icons.close,
                      size: 20,
                      color: hasChanges
                          ? scheme.error
                          : scheme.onSurfaceVariant.withValues(alpha: 0.38),
                    ),
                  ),
                  if (ref.watch(tatModeProvider)) ...[
                    TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      onPressed: () =>
                          ref.read(tatComponentProvider.notifier).cycle(),
                      child: Text(
                        tatComponentLabels[ref.watch(tatComponentProvider)],
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  IconButton(
                    tooltip: 'Target Adjustment: drag the image to target the HSL '
                        'colour under your finger',
                    visualDensity: VisualDensity.compact,
                    isSelected: ref.watch(tatModeProvider),
                    onPressed: () => ref.read(tatModeProvider.notifier).toggle(),
                    icon: const Icon(Icons.colorize),
                    selectedIcon: Icon(Icons.colorize, color: scheme.primary),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Undo',
                    visualDensity: VisualDensity.compact,
                    onPressed: canUndo ? controller.undo : null,
                    icon: const Icon(Icons.undo),
                  ),
                  IconButton(
                    tooltip: 'Redo',
                    visualDensity: VisualDensity.compact,
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
                      visualDensity: VisualDensity.compact,
                      onPressed: () {},
                      icon: const Icon(Icons.compare),
                    ),
                  ),
                  IconButton(
                    key: const Key('tray-apply'),
                    tooltip: 'Apply changes',
                    visualDensity: VisualDensity.compact,
                    onPressed: hasChanges
                        ? () {
                            HapticFeedback.lightImpact();
                            controller.commit(label: 'Applied ${_sectionLabel(_section)}');
                            setState(() {
                              _sessionStartRecipe = ref.read(recipeControllerProvider).recipe;
                            });
                          }
                        : null,
                    icon: Icon(
                      Icons.check,
                      size: 20,
                      color: hasChanges
                          ? scheme.primary
                          : scheme.onSurfaceVariant.withValues(alpha: 0.38),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.2)),
            // Active Tool Controls (Sliders, Curves, Mixers, etc.)
            Expanded(
              child: SafeArea(bottom: false, child: _sectionBody()),
            ),
          ],
        );

        if (constraints.maxHeight < 120) {
          return OverflowBox(
            minHeight: 0,
            maxHeight: double.infinity,
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: 160,
              child: content,
            ),
          );
        }
        return content;
      },
    );
  }

  /// The body for the selected top-level section.
  Widget _sectionBody() {
    switch (_section) {
      case RecipeSection.color:
        return Column(
          children: [
            _subTabs(),
            Expanded(
              child: switch (_tab) {
                _Tab.curve => const ToneCurveEditor(),
                _Tab.mix => const SingleChildScrollView(
                    physics: BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                    child: HslMixer(),
                  ),
                _Tab.grade => const SingleChildScrollView(
                    physics: BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                    child: ColorGradingEditor(),
                  ),
                _Tab.panel => ParameterPanel(section: _section),
              },
            ),
          ],
        );
      case RecipeSection.geometry:
        return const SingleChildScrollView(
          physics: BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          child: GeometryControls(),
        );
      case RecipeSection.retouch:
        return const RetouchControls();
      case RecipeSection.blur:
        return const BlurControls();
      case RecipeSection.masking:
        return const MaskControls();
      case RecipeSection.optics:
        return const OpticsControls();
      case RecipeSection.film:
        return const FilmControls();
      case RecipeSection.lab:
        return const LabControls();
      default:
        return ParameterPanel(section: _section);
    }
  }

  Widget _subTabs() {
    Widget tab(String label, _Tab value) => TextButton(
      onPressed: () {
        HapticFeedback.selectionClick();
        setState(() => _tab = value);
      },
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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

    return SizedBox(
      height: 32,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          tab('Sliders', _Tab.panel),
          tab('Curve', _Tab.curve),
          tab('Mix', _Tab.mix),
          tab('Grade', _Tab.grade),
        ],
      ),
    );
  }
}

