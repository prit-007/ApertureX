import 'dart:typed_data';

import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/log/activity_log.dart';
import '../../core/log/log_providers.dart';
import '../../edit/parameter.dart';
import '../../edit/recipe.dart';
import '../../edit/recipe_controller.dart';
import '../../engine/engine.dart';
import '../../viewport/mask_peek.dart' show rubyPeeksEnabledProvider;
import '../../viewport/soft_proofing.dart';
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
import '../common/app_sheet.dart' show AppSheet, showAppSheet;
import 'looks_presets_panel.dart';
import 'lightroom_common.dart';
import 'master_tabs_bar.dart';
import 'plugins_panel_view.dart';
import 'action_bar.dart';
import 'sub_tabs.dart';

export 'lightroom_common.dart';
export 'looks_presets_panel.dart';
export 'plugins_panel_view.dart';
export 'master_tabs_bar.dart';
export 'action_bar.dart';
export 'sub_tabs.dart';

typedef _LightroomDirtyState = LightroomDirtyState;
const _masterTabLabel = masterTabLabel;

/// Function signature for the Auto Tone analyzer, overridable in tests.
typedef AutoToneFn = Future<Map<String, double>?> Function(Uint8List jpeg);

/// Riverpod provider for Auto Tone analysis, overridable in tests.
final autoToneProvider = Provider<AutoToneFn>((ref) => AxEngine.autoTone);

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
          _isCropGeometrySubTabModified(
            recipe,
            _CropGeometrySubTab.transform,
          ) ||
          _isCropGeometrySubTabModified(
            recipe,
            _CropGeometrySubTab.perspective,
          ),
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

  bool _isLightColorSubTabModified(
    EditRecipe recipe,
    _LightColorSubTab tab,
  ) => switch (tab) {
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

  bool _isEffectsDetailSubTabModified(
    EditRecipe recipe,
    _EffectsDetailSubTab tab,
  ) => switch (tab) {
    _EffectsDetailSubTab.effects => isSectionModified(
      recipe,
      RecipeSection.effects,
    ),
    _EffectsDetailSubTab.detail => isSectionModified(
      recipe,
      RecipeSection.detail,
    ),
    _EffectsDetailSubTab.blur => isSectionModified(recipe, RecipeSection.blur),
    _EffectsDetailSubTab.film => isSectionModified(recipe, RecipeSection.film),
  };

  bool _isCropGeometrySubTabModified(
    EditRecipe recipe,
    _CropGeometrySubTab tab,
  ) => switch (tab) {
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

  bool _isProToolsSubTabModified(
    EditRecipe recipe,
    _ProToolsSubTab tab,
  ) => switch (tab) {
    _ProToolsSubTab.retouch => isSectionModified(recipe, RecipeSection.retouch),
    _ProToolsSubTab.optics => isSectionModified(recipe, RecipeSection.optics),
    _ProToolsSubTab.shaderLab => isSectionModified(recipe, RecipeSection.lab),
  };

  int _computeMasterMask(EditRecipe recipe) {
    int mask = 0;
    for (int i = 0; i < _masterTabs.length; i++) {
      if (_isMasterTabModified(recipe, _masterTabs[i])) {
        mask |= (1 << i);
      }
    }
    return mask;
  }

  int _computeSubTabMask(EditRecipe recipe, MasterTab activeTab) {
    int mask = 0;
    switch (activeTab) {
      case MasterTab.lightColor:
        const tabs = _LightColorSubTab.values;
        for (int i = 0; i < tabs.length; i++) {
          if (_isLightColorSubTabModified(recipe, tabs[i])) mask |= (1 << i);
        }
        break;
      case MasterTab.effectsDetail:
        const tabs = _EffectsDetailSubTab.values;
        for (int i = 0; i < tabs.length; i++) {
          if (_isEffectsDetailSubTabModified(recipe, tabs[i])) mask |= (1 << i);
        }
        break;
      case MasterTab.cropGeometry:
        const tabs = _CropGeometrySubTab.values;
        for (int i = 0; i < tabs.length; i++) {
          if (_isCropGeometrySubTabModified(recipe, tabs[i])) mask |= (1 << i);
        }
        break;
      case MasterTab.proTools:
        const tabs = _ProToolsSubTab.values;
        for (int i = 0; i < tabs.length; i++) {
          if (_isProToolsSubTabModified(recipe, tabs[i])) mask |= (1 << i);
        }
        break;
      default:
        break;
    }
    return mask;
  }

  _LightroomDirtyState _computeDirtyState(
    EditRecipe recipe,
    EditRecipe? tabEntry,
    MasterTab activeTab,
  ) {
    final hasTabChanges = tabEntry != null && recipe != tabEntry;
    return _LightroomDirtyState(
      hasTabChanges: hasTabChanges,
      modifiedMasterMask: _computeMasterMask(recipe),
      modifiedSubTabMask: _computeSubTabMask(recipe, activeTab),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    _tabEntryRecipe ??= ref.read(recipeControllerProvider).recipe;
    final dirtyState = ref.watch(
      recipeControllerProvider.select(
        (s) => _computeDirtyState(s.recipe, _tabEntryRecipe, _activeTab),
      ),
    );
    final hasTabChanges = dirtyState.hasTabChanges;

    final controller = ref.read(recipeControllerProvider.notifier);

    return LayoutBuilder(
      builder: (context, constraints) {
        final content = Column(
          children: [
            // Master Tabs Bar (top): scrollable row of 6 consolidated Master Tabs
            MasterTabsBar(
              activeTab: _activeTab,
              tabEntryRecipe: _tabEntryRecipe,
              dirtyState: dirtyState,
              onTabChanged: (tab) {
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
                    ref.read(activeSectionProvider.notifier).select(
                      RecipeSection.geometry,
                    );
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
                    ref.read(activeSectionProvider.notifier).select(
                      RecipeSection.masking,
                    );
                    break;
                  case MasterTab.plugins:
                    break;
                }
              },
              scrollController: _tabScrollController,
            ),
            Divider(
              height: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.2),
            ),
            // Streamlined Action Bar: Cancel, TAT, Undo, Redo, History, Compare, Wiper, Apply
            LightroomActionBar(
              hasTabChanges: hasTabChanges,
              controller: controller,
              activeTab: _activeTab,
              onCancel: () {
                HapticFeedback.lightImpact();
                controller.loadRecipe(
                  _tabEntryRecipe!,
                  label:
                      'Discarded ${_masterTabLabel(_activeTab)} changes',
                );
                setState(() {});
              },
              onApply: () {
                HapticFeedback.lightImpact();
                controller.commit(
                    label: 'Applied ${_masterTabLabel(_activeTab)}');
                setState(() {
                  _tabEntryRecipe = ref.read(recipeControllerProvider).recipe;
                });
              },
              onSoftProofing: () {
                _showSoftProofingSheet(context);
                HapticFeedback.selectionClick();
              },
              onToolGuideSelect: _selectToolFromGuide,
            ),
            Divider(
              height: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.2),
            ),
            // Active Master Tab Controls
            Expanded(
              child: SafeArea(
                bottom: false,
                child: _sectionBody(dirtyState, hasTabChanges, controller),
              ),
            ),
          ],
        );

        if (constraints.maxHeight < 120) {
          return OverflowBox(
            minHeight: 0,
            maxHeight: double.infinity,
            alignment: Alignment.topCenter,
            child: SizedBox(height: 160, child: content),
          );
        }
        return content;
      },
    );
  }

  /// The body for the active Master Tab.
  Widget _sectionBody(
    _LightroomDirtyState dirtyState,
    bool hasTabChanges,
    RecipeController controller,
  ) {
    switch (_activeTab) {
      case MasterTab.lightColor:
        return Column(
          children: [
            SubTabs<_LightColorSubTab>(
              tabs: [
                (
                  'Light',
                  _LightColorSubTab.light,
                  'light',
                  (dirtyState.modifiedSubTabMask &
                          (1 << _LightColorSubTab.light.index)) !=
                      0,
                ),
                (
                  'Color',
                  _LightColorSubTab.color,
                  'color',
                  (dirtyState.modifiedSubTabMask &
                          (1 << _LightColorSubTab.color.index)) !=
                      0,
                ),
                (
                  'Curve',
                  _LightColorSubTab.curve,
                  'curve',
                  (dirtyState.modifiedSubTabMask &
                          (1 << _LightColorSubTab.curve.index)) !=
                      0,
                ),
                (
                  'Mix',
                  _LightColorSubTab.mix,
                  'mix',
                  (dirtyState.modifiedSubTabMask &
                          (1 << _LightColorSubTab.mix.index)) !=
                      0,
                ),
                (
                  'Grade',
                  _LightColorSubTab.grade,
                  'grade',
                  (dirtyState.modifiedSubTabMask &
                          (1 << _LightColorSubTab.grade.index)) !=
                      0,
                ),
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
                  ref
                      .read(activeSectionProvider.notifier)
                      .select(RecipeSection.light);
                } else if (val == _LightColorSubTab.color) {
                  ref
                      .read(activeSectionProvider.notifier)
                      .select(RecipeSection.color);
                }
              },
            ),
            Expanded(
              child: switch (_lightColorTab) {
                _LightColorSubTab.light => const ParameterPanel(
                  section: RecipeSection.light,
                ),
                _LightColorSubTab.color => const ParameterPanel(
                  section: RecipeSection.color,
                ),
                _LightColorSubTab.curve => const ToneCurveEditor(),
                _LightColorSubTab.mix => const SingleChildScrollView(
                  physics: BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  child: HslMixer(),
                ),
                _LightColorSubTab.grade => const SingleChildScrollView(
                  physics: BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  child: ColorGradingEditor(),
                ),
              },
            ),
          ],
        );

      case MasterTab.effectsDetail:
        return Column(
          children: [
            SubTabs<_EffectsDetailSubTab>(
              tabs: [
                (
                  'Effects',
                  _EffectsDetailSubTab.effects,
                  'effects',
                  (dirtyState.modifiedSubTabMask &
                          (1 << _EffectsDetailSubTab.effects.index)) !=
                      0,
                ),
                (
                  'Detail',
                  _EffectsDetailSubTab.detail,
                  'detail',
                  (dirtyState.modifiedSubTabMask &
                          (1 << _EffectsDetailSubTab.detail.index)) !=
                      0,
                ),
                (
                  'Blur',
                  _EffectsDetailSubTab.blur,
                  'blur',
                  (dirtyState.modifiedSubTabMask &
                          (1 << _EffectsDetailSubTab.blur.index)) !=
                      0,
                ),
                (
                  'Film',
                  _EffectsDetailSubTab.film,
                  'film',
                  (dirtyState.modifiedSubTabMask &
                          (1 << _EffectsDetailSubTab.film.index)) !=
                      0,
                ),
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
                  ref
                      .read(activeSectionProvider.notifier)
                      .select(RecipeSection.effects);
                } else if (val == _EffectsDetailSubTab.detail) {
                  ref
                      .read(activeSectionProvider.notifier)
                      .select(RecipeSection.detail);
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
                _EffectsDetailSubTab.effects => const ParameterPanel(
                  section: RecipeSection.effects,
                ),
                _EffectsDetailSubTab.detail => const ParameterPanel(
                  section: RecipeSection.detail,
                ),
                _EffectsDetailSubTab.blur => const BlurControls(),
                _EffectsDetailSubTab.film => const FilmControls(),
              },
            ),
          ],
        );

      case MasterTab.cropGeometry:
        return Column(
          children: [
            SubTabs<_CropGeometrySubTab>(
              tabs: [
                (
                  'Straighten',
                  _CropGeometrySubTab.straighten,
                  'straighten',
                  (dirtyState.modifiedSubTabMask &
                          (1 << _CropGeometrySubTab.straighten.index)) !=
                      0,
                ),
                (
                  'Transform',
                  _CropGeometrySubTab.transform,
                  'transform',
                  (dirtyState.modifiedSubTabMask &
                          (1 << _CropGeometrySubTab.transform.index)) !=
                      0,
                ),
                (
                  'Perspective',
                  _CropGeometrySubTab.perspective,
                  'perspective',
                  (dirtyState.modifiedSubTabMask &
                          (1 << _CropGeometrySubTab.perspective.index)) !=
                      0,
                ),
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
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                child: GeometryControls(
                  subTab: switch (_cropGeometryTab) {
                    _CropGeometrySubTab.straighten => GeometrySubTab.straighten,
                    _CropGeometrySubTab.transform => GeometrySubTab.transform,
                    _CropGeometrySubTab.perspective =>
                      GeometrySubTab.perspective,
                  },
                ),
              ),
            ),
          ],
        );

      case MasterTab.proTools:
        return Column(
          children: [
            SubTabs<_ProToolsSubTab>(
              tabs: [
                (
                  'Retouch',
                  _ProToolsSubTab.retouch,
                  'retouch',
                  (dirtyState.modifiedSubTabMask &
                          (1 << _ProToolsSubTab.retouch.index)) !=
                      0,
                ),
                (
                  'Optics',
                  _ProToolsSubTab.optics,
                  'optics',
                  (dirtyState.modifiedSubTabMask &
                          (1 << _ProToolsSubTab.optics.index)) !=
                      0,
                ),
                (
                  'Shader Lab',
                  _ProToolsSubTab.shaderLab,
                  'shaderLab',
                  (dirtyState.modifiedSubTabMask &
                          (1 << _ProToolsSubTab.shaderLab.index)) !=
                      0,
                ),
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
                  ref
                      .read(activeSectionProvider.notifier)
                      .select(RecipeSection.retouch);
                } else if (val == _ProToolsSubTab.optics) {
                  ref
                      .read(activeSectionProvider.notifier)
                      .select(RecipeSection.optics);
                } else {
                  ref
                      .read(activeSectionProvider.notifier)
                      .select(RecipeSection.lab);
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
        return const PluginsPanelView();
    }
  }

  void _selectToolFromGuide(String toolId) {
    setState(() {
      switch (toolId) {
        case 'exposure':
        case 'contrast':
        case 'highlights_shadows':
        case 'whites_blacks':
          _activeTab = MasterTab.lightColor;
          _lightColorTab = _LightColorSubTab.light;
          ref.read(activeSectionProvider.notifier).select(RecipeSection.light);
          break;
        case 'temperature_tint':
        case 'vibrance_saturation':
          _activeTab = MasterTab.lightColor;
          _lightColorTab = _LightColorSubTab.color;
          ref.read(activeSectionProvider.notifier).select(RecipeSection.color);
          break;
        case 'tone_curves':
          _activeTab = MasterTab.lightColor;
          _lightColorTab = _LightColorSubTab.curve;
          break;
        case 'hsl_mixer':
          _activeTab = MasterTab.lightColor;
          _lightColorTab = _LightColorSubTab.mix;
          break;
        case 'color_grading':
          _activeTab = MasterTab.lightColor;
          _lightColorTab = _LightColorSubTab.grade;
          break;
        case 'clarity_texture':
        case 'depth_bokeh':
          _activeTab = MasterTab.effectsDetail;
          _effectsDetailTab = _EffectsDetailSubTab.effects;
          ref
              .read(activeSectionProvider.notifier)
              .select(RecipeSection.effects);
          break;
        case 'ai_denoise':
        case 'sharpening':
          _activeTab = MasterTab.effectsDetail;
          _effectsDetailTab = _EffectsDetailSubTab.detail;
          ref.read(activeSectionProvider.notifier).select(RecipeSection.detail);
          break;
        case 'geometry_crop':
          _activeTab = MasterTab.cropGeometry;
          ref
              .read(activeSectionProvider.notifier)
              .select(RecipeSection.geometry);
          break;
        case 'ai_subject_mask':
        case 'stylus':
          _activeTab = MasterTab.masks;
          ref
              .read(activeSectionProvider.notifier)
              .select(RecipeSection.masking);
          break;
        case 'neural_plugins':
          _activeTab = MasterTab.plugins;
          break;
      }
    });
  }

  void _showSoftProofingSheet(BuildContext context) {
    showAppSheet(
      context,
      Consumer(
        builder: (context, ref, _) {
          final proof = ref.watch(softProofingProvider);
          final notifier = ref.read(softProofingProvider.notifier);
          final theme = Theme.of(context);

          return AppSheet(
            title: 'Soft Proofing',
            subtitle: 'Simulate printer ICC profiles and gamut clipping',
            scrollable: true,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Enabled',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Switch(
                    key: const Key('soft-proofing-toggle'),
                    value: proof.enabled,
                    onChanged: (val) => notifier.setEnabled(val),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Target Profile', style: theme.textTheme.labelMedium),
              DropdownButton<ProofProfile>(
                key: const Key('soft-proofing-profile-dropdown'),
                value: proof.profile,
                isExpanded: true,
                items: ProofProfile.values.map((p) {
                  return DropdownMenuItem(value: p, child: Text(p.displayName));
                }).toList(),
                onChanged: proof.enabled
                    ? (p) {
                        if (p != null) notifier.setProfile(p);
                      }
                    : null,
              ),
              const SizedBox(height: 12),
              Text('Rendering Intent', style: theme.textTheme.labelMedium),
              DropdownButton<ProofIntent>(
                key: const Key('soft-proofing-intent-dropdown'),
                value: proof.intent,
                isExpanded: true,
                items: ProofIntent.values.map((i) {
                  return DropdownMenuItem(value: i, child: Text(i.displayName));
                }).toList(),
                onChanged: proof.enabled
                    ? (i) {
                        if (i != null) notifier.setIntent(i);
                      }
                    : null,
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                key: const Key('soft-proofing-paper-ink'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Simulate Paper & Ink (DMax Black Floor)'),
                value: proof.simulatePaperAndInk,
                onChanged: proof.enabled
                    ? (_) => notifier.togglePaperAndInk()
                    : null,
              ),
              CheckboxListTile(
                key: const Key('soft-proofing-gamut-warning'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Highlight Out-of-Gamut Pixels'),
                value: proof.gamutWarning,
                onChanged: proof.enabled
                    ? (_) => notifier.toggleGamutWarning()
                    : null,
              ),
            ],
          );
        },
      ),
    );
  }
}
