import 'dart:typed_data';

import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/log/activity_log.dart';
import '../../core/log/log_providers.dart';
import '../../core/theme/design_tokens.dart';
import '../../color/tat.dart';
import '../../edit/active_image.dart' show activeImageBytesProvider;
import '../../edit/parameter.dart';
import '../../edit/recipe.dart';
import '../../edit/recipe_controller.dart';
import '../../engine/engine.dart';
import '../../features/ai_plugins/ai_plugin_store.dart';
import '../../features/ai_plugins/ai_plugins_screen.dart';
import '../../viewport/compare_hold.dart';
import '../../viewport/exposure_assist.dart';
import '../../viewport/mask_peek.dart' show rubyPeeksEnabledProvider;
import '../../viewport/wiper_compare.dart';
import '../common/blur_controls.dart';
import '../common/color_grading_editor.dart';
import '../common/film_controls.dart';
import '../common/geometry_controls.dart';
import '../common/history_tree_sheet.dart';
import '../common/hsl_mixer.dart';
import '../common/lab_controls.dart';
import '../common/mask_controls.dart';
import '../common/optics_controls.dart';
import '../common/parameter_panel.dart';
import '../common/retouch_controls.dart';
import '../common/tone_curve_editor.dart';
import '../common/looks_sheet.dart';
import '../common/app_primitives.dart';
import '../common/app_sheet.dart' show showAppSheet;
import '../../edit/tool_definition.dart';

/// Function signature for the Auto Tone analyzer, overridable in tests.
typedef AutoToneFn = Future<Map<String, double>?> Function(Uint8List jpeg);

/// Riverpod provider for Auto Tone analysis, overridable in tests.
final autoToneProvider = Provider<AutoToneFn>((ref) => AxEngine.autoTone);

enum MasterTab {
  lightColor,
  effectsDetail,
  cropGeometry,
  proTools,
  looksPresets,
  masks,
  plugins,
}

String _masterTabLabel(MasterTab tab) => switch (tab) {
  MasterTab.lightColor => 'Light & Color',
  MasterTab.effectsDetail => 'Effects & Detail',
  MasterTab.cropGeometry => 'Crop & Geometry',
  MasterTab.proTools => 'Pro Tools',
  MasterTab.looksPresets => 'Looks & Presets',
  MasterTab.masks => 'Masks',
  MasterTab.plugins => 'Plugins',
};

enum _LightColorSubTab { light, color, curve, mix, grade }
enum _EffectsDetailSubTab { effects, detail, blur, film }
enum _CropGeometrySubTab { straighten, transform, perspective }
enum _ProToolsSubTab { retouch, optics, shaderLab }

class ActiveSectionNotifier extends Notifier<RecipeSection> {
  @override
  RecipeSection build() => RecipeSection.light;
  void select(RecipeSection section) {
    state = section;
    axLog(LogDomain.editor, 'Switched tool tab to ${section.name}');
  }
}

final activeSectionProvider =
    NotifierProvider<ActiveSectionNotifier, RecipeSection>(
  ActiveSectionNotifier.new,
);

/// Lightroom shell: a streamlined 6 Master Tabs tray over the shared recipe.
class LightroomShell extends ConsumerStatefulWidget {
  const LightroomShell({super.key});

  @override
  ConsumerState<LightroomShell> createState() => _LightroomShellState();
}

class _LightroomShellState extends ConsumerState<LightroomShell> {
  static const List<MasterTab> _masterTabs = [
    MasterTab.lightColor,
    MasterTab.effectsDetail,
    MasterTab.cropGeometry,
    MasterTab.proTools,
    MasterTab.looksPresets,
    MasterTab.masks,
    MasterTab.plugins,
  ];

  MasterTab _activeTab = MasterTab.lightColor;
  _LightColorSubTab _lightColorTab = _LightColorSubTab.light;
  _EffectsDetailSubTab _effectsDetailTab = _EffectsDetailSubTab.effects;
  _CropGeometrySubTab _cropGeometryTab = _CropGeometrySubTab.straighten;
  _ProToolsSubTab _proToolsTab = _ProToolsSubTab.retouch;

  late final ScrollController _tabScrollController;
  EditRecipe? _tabEntryRecipe;

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

  bool _isMasterTabModified(EditRecipe recipe, MasterTab tab) => switch (tab) {
    MasterTab.lightColor =>
      _isLightColorSubTabModified(recipe, _LightColorSubTab.light) ||
      _isLightColorSubTabModified(recipe, _LightColorSubTab.color) ||
      _isLightColorSubTabModified(recipe, _LightColorSubTab.curve) ||
      _isLightColorSubTabModified(recipe, _LightColorSubTab.mix) ||
      _isLightColorSubTabModified(recipe, _LightColorSubTab.grade),
    MasterTab.effectsDetail =>
      _isEffectsDetailSubTabModified(recipe, _EffectsDetailSubTab.effects) ||
      _isEffectsDetailSubTabModified(recipe, _EffectsDetailSubTab.detail) ||
      _isEffectsDetailSubTabModified(recipe, _EffectsDetailSubTab.blur) ||
      _isEffectsDetailSubTabModified(recipe, _EffectsDetailSubTab.film),
    MasterTab.cropGeometry =>
      _isCropGeometrySubTabModified(recipe, _CropGeometrySubTab.straighten) ||
      _isCropGeometrySubTabModified(recipe, _CropGeometrySubTab.transform) ||
      _isCropGeometrySubTabModified(recipe, _CropGeometrySubTab.perspective),
    MasterTab.proTools =>
      _isProToolsSubTabModified(recipe, _ProToolsSubTab.retouch) ||
      _isProToolsSubTabModified(recipe, _ProToolsSubTab.optics) ||
      _isProToolsSubTabModified(recipe, _ProToolsSubTab.shaderLab),
    MasterTab.looksPresets =>
        isSectionModified(recipe, RecipeSection.color) ||
        isSectionModified(recipe, RecipeSection.effects) ||
        isSectionModified(recipe, RecipeSection.detail),
    MasterTab.masks => isSectionModified(recipe, RecipeSection.masking),
    MasterTab.plugins => false,
  };

  bool _isLightColorSubTabModified(EditRecipe recipe, _LightColorSubTab tab) => switch (tab) {
    _LightColorSubTab.light => isSectionModified(recipe, RecipeSection.light),
    _LightColorSubTab.color =>
      recipe.temperature != 0 ||
      recipe.tint != 0 ||
      recipe.vibrance != 0 ||
      recipe.saturation != 0,
    _LightColorSubTab.curve => isSectionModified(recipe, RecipeSection.tone),
    _LightColorSubTab.mix => recipe.hsl != neutralHsl,
    _LightColorSubTab.grade =>
      recipe.gradeShadowHue != 0 ||
      recipe.gradeShadowSat != 0 ||
      recipe.gradeShadowLum != 0 ||
      recipe.gradeMidHue != 0 ||
      recipe.gradeMidSat != 0 ||
      recipe.gradeMidLum != 0 ||
      recipe.gradeHighlightHue != 0 ||
      recipe.gradeHighlightSat != 0 ||
      recipe.gradeHighlightLum != 0 ||
      recipe.gradeBlending != 0.5 ||
      recipe.gradeBalance != 0,
  };

  bool _isEffectsDetailSubTabModified(EditRecipe recipe, _EffectsDetailSubTab tab) => switch (tab) {
    _EffectsDetailSubTab.effects => isSectionModified(recipe, RecipeSection.effects),
    _EffectsDetailSubTab.detail => isSectionModified(recipe, RecipeSection.detail),
    _EffectsDetailSubTab.blur => isSectionModified(recipe, RecipeSection.blur),
    _EffectsDetailSubTab.film => isSectionModified(recipe, RecipeSection.film),
  };

  bool _isCropGeometrySubTabModified(EditRecipe recipe, _CropGeometrySubTab tab) => switch (tab) {
    _CropGeometrySubTab.straighten => recipe.straighten != 0,
    _CropGeometrySubTab.transform =>
      recipe.rotation != 0 ||
      recipe.flipH ||
      recipe.flipV ||
      recipe.crop != fullCrop,
    _CropGeometrySubTab.perspective =>
      recipe.perspectiveX != 0 ||
      recipe.perspectiveY != 0 ||
      recipe.skewX != 0 ||
      recipe.skewY != 0,
  };

  bool _isProToolsSubTabModified(EditRecipe recipe, _ProToolsSubTab tab) => switch (tab) {
    _ProToolsSubTab.retouch => isSectionModified(recipe, RecipeSection.retouch),
    _ProToolsSubTab.optics => isSectionModified(recipe, RecipeSection.optics),
    _ProToolsSubTab.shaderLab => isSectionModified(recipe, RecipeSection.lab),
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final currentRecipe = ref.watch(recipeControllerProvider).recipe;
    // Capture the tab-entry baseline when switching into a tab. This is the
    // reference point for dirty detection and modal apply/discard.
    _tabEntryRecipe ??= currentRecipe;
    final hasTabChanges = _tabEntryRecipe != null && currentRecipe != _tabEntryRecipe;

    final canUndo = ref.watch(
      recipeControllerProvider.select((s) => s.index > 0),
    );
    final canRedo = ref.watch(
      recipeControllerProvider.select((s) => s.index < s.history.length - 1),
    );
    final controller = ref.read(recipeControllerProvider.notifier);

    Widget chip(MasterTab tab, bool selected, bool isModified, VoidCallback onTap) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_masterTabLabel(tab)),
            if (isModified) ...[
              const SizedBox(width: 4),
              Container(
                key: Key('applied-dot-${tab.name}'),
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

    /// Shows Apply / Discard / Cancel when switching master tabs with uncommitted changes.
    Future<void> showUncommittedChangesDialog({
      required BuildContext dialogContext,
      required RecipeController notifier,
      required String tabLabel,
      required VoidCallback onApply,
      required VoidCallback onDiscard,
    }) async {
      final result = await showDialog<String>(
        context: dialogContext,
        builder: (ctx) => AlertDialog(
          title: Text('Uncommitted changes in $tabLabel'),
          content: const Text(
            'You have uncommitted changes. Apply them, discard, or cancel?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('discard'),
              child: const Text('Discard'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('cancel'),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop('apply'),
              child: const Text('Apply'),
            ),
          ],
        ),
      );
      if (result == 'apply') {
        onApply();
      } else if (result == 'discard') {
        onDiscard();
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final content = Column(
          children: [
            // Master Tabs Bar (top): scrollable row of 6 consolidated Master Tabs
            SizedBox(
              height: 40,
              child: ListView(
                key: const Key('lightroom-master-tabs-bar'),
                controller: _tabScrollController,
                physics: const BouncingScrollPhysics(),
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                children: [
                  for (final tab in _masterTabs)
                    chip(
                      tab,
                      tab == _activeTab,
                      _isMasterTabModified(currentRecipe, tab),
                      () {
                        HapticFeedback.selectionClick();
                        // Modal guard: block switching tabs while the current
                        // tab has uncommitted changes. Offer Apply / Discard /
                        // Cancel so the user is never stuck.
                        if (hasTabChanges && tab != _activeTab) {
                          HapticFeedback.heavyImpact();
                          showUncommittedChangesDialog(
                            dialogContext: context,
                            notifier: controller,
                            tabLabel: _masterTabLabel(_activeTab),
                            onApply: () {
                              controller.commit(
                                  label: 'Applied ${_masterTabLabel(_activeTab)}');
                              setState(() {
                                _activeTab = tab;
                                _tabEntryRecipe =
                                    ref.read(recipeControllerProvider).recipe;
                              });
                              final idx = _masterTabs.indexOf(tab);
                              if (_tabScrollController.hasClients) {
                                final target = (idx * 110.0 - 40.0).clamp(
                                  0.0,
                                  _tabScrollController.position.maxScrollExtent,
                                );
                                _tabScrollController.animateTo(
                                  target,
                                  duration: AppMotion.shortDuration,
                                  curve: AppMotion.standardCurve,
                                );
                              }
                            },
                            onDiscard: () {
                              controller.loadRecipe(
                                _tabEntryRecipe!,
                                label:
                                    'Discarded ${_masterTabLabel(_activeTab)} changes',
                              );
                              setState(() {
                                _activeTab = tab;
                                _tabEntryRecipe =
                                    ref.read(recipeControllerProvider).recipe;
                              });
                              final idx = _masterTabs.indexOf(tab);
                              if (_tabScrollController.hasClients) {
                                final target = (idx * 110.0 - 40.0).clamp(
                                  0.0,
                                  _tabScrollController.position.maxScrollExtent,
                                );
                                _tabScrollController.animateTo(
                                  target,
                                  duration: AppMotion.shortDuration,
                                  curve: AppMotion.standardCurve,
                                );
                              }
                            },
                          );
                          return;
                        }
                        // Commit any changes in the current tab before leaving.
                        if (hasTabChanges) {
                          controller.commit(label: 'Applied ${_masterTabLabel(_activeTab)}');
                        }
                        setState(() {
                          _activeTab = tab;
                          _tabEntryRecipe = ref.read(recipeControllerProvider).recipe;
                        });
                        // Update activeSectionProvider for canvas overlays
                        switch (tab) {
                          case MasterTab.lightColor:
                            ref.read(activeSectionProvider.notifier).select(
                              _lightColorTab == _LightColorSubTab.color
                                  ? RecipeSection.color
                                  : RecipeSection.light,
                            );
                            break;
                          case MasterTab.effectsDetail:
                            ref.read(activeSectionProvider.notifier).select(
                              _effectsDetailTab == _EffectsDetailSubTab.detail
                                  ? RecipeSection.detail
                                  : RecipeSection.effects,
                            );
                            break;
                          case MasterTab.cropGeometry:
                            ref.read(activeSectionProvider.notifier).select(RecipeSection.geometry);
                            break;
                          case MasterTab.proTools:
                            ref.read(activeSectionProvider.notifier).select(
                              _proToolsTab == _ProToolsSubTab.retouch
                                  ? RecipeSection.retouch
                                  : _proToolsTab == _ProToolsSubTab.optics
                                      ? RecipeSection.optics
                                      : RecipeSection.lab,
                            );
                            break;
                          case MasterTab.looksPresets:
                            ref.read(activeSectionProvider.notifier).select(
                              RecipeSection.color,
                            );
                            break;
                          case MasterTab.masks:
                            ref.read(activeSectionProvider.notifier).select(RecipeSection.masking);
                            break;
                          case MasterTab.plugins:
                            break;
                        }

                        final idx = _masterTabs.indexOf(tab);
                        if (_tabScrollController.hasClients) {
                          final target = (idx * 110.0 - 40.0).clamp(
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
            // Streamlined Action Bar: Cancel, TAT, Undo, Redo, History, Compare, Wiper, Apply
            SizedBox(
              height: 38,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: Row(
                    children: [
                  IconButton(
                    key: const Key('tray-cancel'),
                    tooltip: 'Discard changes',
                    visualDensity: VisualDensity.compact,
                    onPressed: hasTabChanges
                        ? () {
                            HapticFeedback.lightImpact();
                            controller.loadRecipe(
                              _tabEntryRecipe!,
                              label: 'Discarded ${_masterTabLabel(_activeTab)} changes',
                            );
                            setState(() {});
                          }
                        : null,
                    icon: Icon(
                      Icons.close,
                      size: 20,
                      color: hasTabChanges
                          ? scheme.error
                          : scheme.onSurfaceVariant.withValues(alpha: 0.38),
                    ),
                  ),
                  VerticalDivider(
                    width: 12,
                    indent: 8,
                    endIndent: 8,
                    color: scheme.outlineVariant.withValues(alpha: 0.2),
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
                  if (_activeTab == MasterTab.lightColor &&
                      _lightColorTab == _LightColorSubTab.light)
                    IconButton(
                      tooltip: 'Auto Tone: analyze image and apply balanced adjustments',
                      visualDensity: VisualDensity.compact,
                      onPressed: () async {
                        final bytes = ref.read(activeImageBytesProvider);
                        if (bytes == null) return;
                        final notifier =
                            ref.read(recipeControllerProvider.notifier);
                        final auto = await ref.read(autoToneProvider)(bytes);
                        if (auto == null) return;
                        notifier.update(
                            Parameter.exposure, auto['exposure'] as double);
                        notifier.update(
                            Parameter.contrast, auto['contrast'] as double);
                        notifier.update(
                            Parameter.highlights, auto['highlights'] as double);
                        notifier.update(
                            Parameter.shadows, auto['shadows'] as double);
                        notifier.update(
                            Parameter.whites, auto['whites'] as double);
                        notifier.update(
                            Parameter.blacks, auto['blacks'] as double);
                        notifier.update(
                            Parameter.temperature, auto['temperature'] as double);
                        notifier.update(
                            Parameter.tint, auto['tint'] as double);
                        notifier.commit(label: 'Auto Tone');
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Auto-tone applied')),
                          );
                        }
                      },
                      icon: const Icon(Icons.auto_awesome, size: 18),
                    ),
                  const SizedBox(width: Insets.sm),
                  IconButton(
                    tooltip: 'Target Adjustment: drag the image to target the HSL '
                        'colour under your finger',
                    visualDensity: VisualDensity.compact,
                    isSelected: ref.watch(tatModeProvider),
                    onPressed: () => ref.read(tatModeProvider.notifier).toggle(),
                    icon: const Icon(Icons.colorize),
                    selectedIcon: Icon(Icons.colorize, color: scheme.primary),
                  ),
                  VerticalDivider(
                    width: 12,
                    indent: 8,
                    endIndent: 8,
                    color: scheme.outlineVariant.withValues(alpha: 0.2),
                  ),
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
                  IconButton(
                    tooltip: 'Edit History & Branches (Git-style)',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => HistoryTreeSheet.show(context),
                    icon: const Icon(Icons.alt_route),
                  ),
                  VerticalDivider(
                    width: 12,
                    indent: 8,
                    endIndent: 8,
                    color: scheme.outlineVariant.withValues(alpha: 0.2),
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
                    tooltip: 'Split Curtain Wiper Compare (120 FPS)',
                    visualDensity: VisualDensity.compact,
                    isSelected: ref.watch(wiperCompareProvider).isActive,
                    onPressed: () {
                      ref.read(wiperCompareProvider.notifier).toggle();
                      HapticFeedback.selectionClick();
                    },
                    icon: const Icon(Icons.splitscreen),
                    selectedIcon: Icon(Icons.splitscreen, color: scheme.primary),
                  ),
                  IconButton(
                    tooltip: 'Exposure Assist: Zebras & False Color Heatmap (ARRI IRE)',
                    visualDensity: VisualDensity.compact,
                    isSelected: ref.watch(exposureAssistProvider).isActive,
                    onPressed: () {
                      ref.read(exposureAssistProvider.notifier).cycleMode();
                      HapticFeedback.selectionClick();
                    },
                    icon: const Icon(Icons.wb_iridescent_outlined),
                    selectedIcon: Icon(Icons.wb_iridescent, color: scheme.primary),
                  ),
                  VerticalDivider(
                    width: 12,
                    indent: 8,
                    endIndent: 8,
                    color: scheme.outlineVariant.withValues(alpha: 0.2),
                  ),
                  IconButton(
                    key: const Key('tray-apply'),
                    tooltip: 'Apply changes',
                    visualDensity: VisualDensity.compact,
                    onPressed: hasTabChanges
                        ? () {
                            HapticFeedback.lightImpact();
                            controller.commit(label: 'Applied ${_masterTabLabel(_activeTab)}');
                            setState(() {
                              _tabEntryRecipe = ref.read(recipeControllerProvider).recipe;
                            });
                          }
                        : null,
                    icon: Icon(
                      Icons.check,
                      size: 20,
                      color: hasTabChanges
                          ? scheme.primary
                          : scheme.onSurfaceVariant.withValues(alpha: 0.38),
                    ),
                  ),
                ],
                  ),
                ),
              ),
            ),
            Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.2)),
            // Active Master Tab Controls
            Expanded(
              child: SafeArea(
                bottom: false,
                child: _sectionBody(currentRecipe, hasTabChanges, controller),
              ),
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

  /// The body for the active Master Tab.
  Widget _sectionBody(
    EditRecipe currentRecipe,
    bool hasTabChanges,
    RecipeController controller,
  ) {
    switch (_activeTab) {
      case MasterTab.lightColor:
        return Column(
          children: [
            _subTabs(
              tabs: [
                ('Light', _LightColorSubTab.light, 'light', _isLightColorSubTabModified(currentRecipe, _LightColorSubTab.light)),
                ('Color', _LightColorSubTab.color, 'color', _isLightColorSubTabModified(currentRecipe, _LightColorSubTab.color)),
                ('Curve', _LightColorSubTab.curve, 'curve', _isLightColorSubTabModified(currentRecipe, _LightColorSubTab.curve)),
                ('Mix', _LightColorSubTab.mix, 'mix', _isLightColorSubTabModified(currentRecipe, _LightColorSubTab.mix)),
                ('Grade', _LightColorSubTab.grade, 'grade', _isLightColorSubTabModified(currentRecipe, _LightColorSubTab.grade)),
              ],
              current: _lightColorTab,
              hasTabChanges: hasTabChanges,
              onCancel: () {
                HapticFeedback.lightImpact();
                controller.loadRecipe(
                  _tabEntryRecipe!,
                  label: 'Discarded Light & Color changes',
                );
                setState(() {});
              },
              onApply: () {
                HapticFeedback.lightImpact();
                controller.commit(label: 'Applied Light & Color');
                setState(() {
                  _tabEntryRecipe = ref.read(recipeControllerProvider).recipe;
                });
              },
              onSelect: (val) {
                setState(() => _lightColorTab = val);
                if (val == _LightColorSubTab.light) {
                  ref.read(activeSectionProvider.notifier).select(RecipeSection.light);
                } else if (val == _LightColorSubTab.color) {
                  ref.read(activeSectionProvider.notifier).select(RecipeSection.color);
                }
              },
            ),
            Expanded(
              child: switch (_lightColorTab) {
                _LightColorSubTab.light => const ParameterPanel(
                  section: RecipeSection.light,
                ),
                _LightColorSubTab.color => const ParameterPanel(section: RecipeSection.color),
                _LightColorSubTab.curve => const ToneCurveEditor(),
                _LightColorSubTab.mix => const SingleChildScrollView(
                    physics: BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                    child: HslMixer(),
                  ),
                _LightColorSubTab.grade => const SingleChildScrollView(
                    physics: BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                    child: ColorGradingEditor(),
                  ),
              },
            ),
          ],
        );

      case MasterTab.effectsDetail:
        return Column(
          children: [
            _subTabs(
              tabs: [
                ('Effects', _EffectsDetailSubTab.effects, 'effects', _isEffectsDetailSubTabModified(currentRecipe, _EffectsDetailSubTab.effects)),
                ('Detail', _EffectsDetailSubTab.detail, 'detail', _isEffectsDetailSubTabModified(currentRecipe, _EffectsDetailSubTab.detail)),
                ('Blur', _EffectsDetailSubTab.blur, 'blur', _isEffectsDetailSubTabModified(currentRecipe, _EffectsDetailSubTab.blur)),
                ('Film', _EffectsDetailSubTab.film, 'film', _isEffectsDetailSubTabModified(currentRecipe, _EffectsDetailSubTab.film)),
              ],
              current: _effectsDetailTab,
              hasTabChanges: hasTabChanges,
              onCancel: () {
                HapticFeedback.lightImpact();
                controller.loadRecipe(
                  _tabEntryRecipe!,
                  label: 'Discarded Effects & Detail changes',
                );
                setState(() {});
              },
              onApply: () {
                HapticFeedback.lightImpact();
                controller.commit(label: 'Applied Effects & Detail');
                setState(() {
                  _tabEntryRecipe = ref.read(recipeControllerProvider).recipe;
                });
              },
              onSelect: (val) {
                setState(() => _effectsDetailTab = val);
                if (val == _EffectsDetailSubTab.effects) {
                  ref.read(activeSectionProvider.notifier).select(RecipeSection.effects);
                } else if (val == _EffectsDetailSubTab.detail) {
                  ref.read(activeSectionProvider.notifier).select(RecipeSection.detail);
                }
              },
            ),
            // Ruby Peeks toggle: compact inline toggle; dragging detail/peek
            // parameters crossfades to high-contrast detail view. Default off.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.visibility_off_outlined, size: 14),
                  const SizedBox(width: 6),
                  const Text('Ruby Peeks', style: TextStyle(fontSize: 11)),
                  const Spacer(),
                  Switch.adaptive(
                    value: ref.watch(rubyPeeksEnabledProvider),
                    onChanged: (v) =>
                        ref.read(rubyPeeksEnabledProvider.notifier).set(v),
                  ),
                ],
              ),
            ),
            Expanded(
              child: switch (_effectsDetailTab) {
                _EffectsDetailSubTab.effects => const ParameterPanel(section: RecipeSection.effects),
                _EffectsDetailSubTab.detail => const ParameterPanel(section: RecipeSection.detail),
                _EffectsDetailSubTab.blur => const BlurControls(),
                _EffectsDetailSubTab.film => const FilmControls(),
              },
            ),
          ],
        );

      case MasterTab.cropGeometry:
        return Column(
          children: [
            _subTabs(
              tabs: [
                ('Straighten', _CropGeometrySubTab.straighten, 'straighten', _isCropGeometrySubTabModified(currentRecipe, _CropGeometrySubTab.straighten)),
                ('Transform', _CropGeometrySubTab.transform, 'transform', _isCropGeometrySubTabModified(currentRecipe, _CropGeometrySubTab.transform)),
                ('Perspective', _CropGeometrySubTab.perspective, 'perspective', _isCropGeometrySubTabModified(currentRecipe, _CropGeometrySubTab.perspective)),
              ],
              current: _cropGeometryTab,
              hasTabChanges: hasTabChanges,
              onCancel: () {
                HapticFeedback.lightImpact();
                controller.loadRecipe(
                  _tabEntryRecipe!,
                  label: 'Discarded Crop & Geometry changes',
                );
                setState(() {});
              },
              onApply: () {
                HapticFeedback.lightImpact();
                controller.commit(label: 'Applied Crop & Geometry');
                setState(() {
                  _tabEntryRecipe = ref.read(recipeControllerProvider).recipe;
                });
              },
              onSelect: (val) => setState(() => _cropGeometryTab = val),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                child: GeometryControls(
                  subTab: switch (_cropGeometryTab) {
                    _CropGeometrySubTab.straighten => GeometrySubTab.straighten,
                    _CropGeometrySubTab.transform => GeometrySubTab.transform,
                    _CropGeometrySubTab.perspective => GeometrySubTab.perspective,
                  },
                ),
              ),
            ),
          ],
        );

      case MasterTab.proTools:
        return Column(
          children: [
            _subTabs(
              tabs: [
                ('Retouch', _ProToolsSubTab.retouch, 'retouch', _isProToolsSubTabModified(currentRecipe, _ProToolsSubTab.retouch)),
                ('Optics', _ProToolsSubTab.optics, 'optics', _isProToolsSubTabModified(currentRecipe, _ProToolsSubTab.optics)),
                ('Shader Lab', _ProToolsSubTab.shaderLab, 'shaderLab', _isProToolsSubTabModified(currentRecipe, _ProToolsSubTab.shaderLab)),
              ],
              current: _proToolsTab,
              hasTabChanges: hasTabChanges,
              onCancel: () {
                HapticFeedback.lightImpact();
                controller.loadRecipe(
                  _tabEntryRecipe!,
                  label: 'Discarded Pro Tools changes',
                );
                setState(() {});
              },
              onApply: () {
                HapticFeedback.lightImpact();
                controller.commit(label: 'Applied Pro Tools');
                setState(() {
                  _tabEntryRecipe = ref.read(recipeControllerProvider).recipe;
                });
              },
              onSelect: (val) {
                setState(() => _proToolsTab = val);
                if (val == _ProToolsSubTab.retouch) {
                  ref.read(activeSectionProvider.notifier).select(RecipeSection.retouch);
                } else if (val == _ProToolsSubTab.optics) {
                  ref.read(activeSectionProvider.notifier).select(RecipeSection.optics);
                } else {
                  ref.read(activeSectionProvider.notifier).select(RecipeSection.lab);
                }
              },
            ),
            Expanded(
              child: switch (_proToolsTab) {
                _ProToolsSubTab.retouch => const RetouchControls(),
                _ProToolsSubTab.optics => const OpticsControls(),
                _ProToolsSubTab.shaderLab => const LabControls(),
              },
            ),
          ],
        );

      case MasterTab.looksPresets:
        return const LooksPresetsPanel();

      case MasterTab.masks:
        return const MaskControls();

      case MasterTab.plugins:
        return const _PluginsPanelView();
    }
  }

  Widget _subTabs<T>({
    required List<(String label, T value, String keyName, bool isModified)> tabs,
    required T current,
    required ValueChanged<T> onSelect,
    required bool hasTabChanges,
    required VoidCallback onCancel,
    required VoidCallback onApply,
  }) {
    final scheme = Theme.of(context).colorScheme;

    // Same pill styling as the master tab chips above, so sub-tabs read as a
    // family instead of a row of boxy text buttons.
    Widget tab(String label, T value, String keyName, bool isModified) {
      final selected = current == value;
      return Padding(
        // Tighter chip padding: 8px horizontal, 0 vertical
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        child: ChoiceChip(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label),
              if (isModified) ...[
                const SizedBox(width: 4),
                Container(
                  key: Key('applied-dot-$keyName'),
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
          onSelected: (_) {
            HapticFeedback.selectionClick();
            if (hasTabChanges) {
              onApply();
            }
            onSelect(value);
          },
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
    }

    return SizedBox(
      height: 34,
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final item in tabs)
                    tab(item.$1, item.$2, item.$3, item.$4),
                ],
              ),
            ),
          ),
          if (hasTabChanges) ...[
            VerticalDivider(
              width: 1,
              indent: 8,
              endIndent: 8,
              color: scheme.outlineVariant.withValues(alpha: 0.3),
            ),
            IconButton(
              key: const Key('subtab-cancel'),
              tooltip: 'Discard changes',
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(),
              onPressed: onCancel,
              icon: Icon(Icons.close, color: scheme.error, size: 18),
            ),
            const SizedBox(width: 4),
            IconButton(
              key: const Key('subtab-apply'),
              tooltip: 'Apply changes',
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(),
              onPressed: onApply,
              icon: Icon(Icons.check, color: scheme.primary, size: 18),
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

class _PluginsPanelView extends ConsumerWidget {
  const _PluginsPanelView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(aiPluginProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final installed = state.installedPlugins;

    return ListView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: const EdgeInsets.all(Insets.md),
      children: [
        Card.outlined(
          child: Padding(
            padding: const EdgeInsets.all(Insets.md),
            child: Row(
              children: [
                Icon(Icons.offline_bolt_rounded, color: scheme.primary, size: 28),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Neural Forge On-Device AI',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Zero cloud inference. Local zero-copy tensors.',
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                FilledButton.tonal(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const AiPluginsScreen()),
                    );
                  },
                  child: const Text('Manage'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Insets.sm),
        for (final p in installed)
          ListTile(
            dense: true,
            leading: Icon(
              p.isBuiltIn ? Icons.verified_rounded : Icons.extension_rounded,
              color: scheme.primary,
            ),
            title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(p.description, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                p.task.label,
                style: TextStyle(
                  color: scheme.onPrimaryContainer,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Panel for applying built-in looks and presets to the current image.
class LooksPresetsPanel extends ConsumerWidget {
  const LooksPresetsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final recipe = ref.watch(recipeControllerProvider).recipe;
    final notifier = ref.read(recipeControllerProvider.notifier);

    return ListView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: const EdgeInsets.all(Insets.md),
      children: [
        const SectionHeader('Built-in Looks'),
        Text(
          'Tap a look to apply it to the current image. '
          'Applied looks create a new history entry so you can undo.',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Insets.md),
        ...ToolLibrary.builtins.map((tool) {
          final isApplied = _looksMatch(tool, recipe);
          return Card(
            margin: const EdgeInsets.only(bottom: Insets.xs),
            child: ListTile(
              leading: Icon(
                Icons.style,
                color: isApplied ? scheme.primary : scheme.onSurfaceVariant,
              ),
              title: Text(
                tool.name,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isApplied ? scheme.primary : null,
                ),
              ),
              subtitle: Text(
                tool.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11),
              ),
              trailing: isApplied
                  ? Icon(Icons.check_circle, color: scheme.primary, size: 20)
                  : Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
              onTap: () {
                HapticFeedback.lightImpact();
                notifier.applyTool(tool);
                notifier.commit(label: 'Applied ${tool.name}');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Applied look: ${tool.name}'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
            ),
          );
        }),
        const SizedBox(height: Insets.lg),
        const SectionHeader('Import Look'),
        Text(
          'Paste a look JSON or apx:// QR code to import a custom preset.',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Insets.sm),
        TextField(
          decoration: const InputDecoration(
            hintText: 'Paste look JSON or apx:// URL',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          onSubmitted: (json) {
            try {
              final tool = ToolDefinition.decode(json);
              HapticFeedback.lightImpact();
              notifier.applyTool(tool);
              notifier.commit(label: 'Imported ${tool.name}');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Imported look: ${tool.name}'),
                  duration: const Duration(seconds: 1),
                ),
              );
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Invalid look format'),
                  duration: Duration(seconds: 1),
                ),
              );
            }
          },
        ),
        const SizedBox(height: Insets.md),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () {
                showAppSheet(context, const LooksSheet());
              },
              icon: const Icon(Icons.qr_code_scanner, size: 18),
              label: const Text('Scan QR Look'),
            ),
          ],
        ),
      ],
    );
  }

  bool _looksMatch(ToolDefinition tool, EditRecipe recipe) {
    for (final entry in tool.params.entries) {
      final param = _parameterByName(entry.key);
      if (param == null) continue;
      final current = valueOf(recipe, param);
      if ((current - entry.value).abs() > 0.01) return false;
    }
    return true;
  }

  Parameter? _parameterByName(String name) {
    for (final p in Parameter.values) {
      if (p.name == name) return p;
    }
    return null;
  }
}
