// Lens Blur and Optical Depth Presets for ApertureX.
//
// Supplies dedicated presets modeling classic optical lens characters with
// continuous depth-of-field falloff, aperture blade geometry, and specular bokeh boost:
// - Portrait 85/f1.8: Classic 85mm optical isolation with circular aperture blades
// - Street 35/f1.4: Fast 35mm environmental portrait with hexagonal blades
// - Anamorphic 50: Cinema anamorphic lens with cat's eye mechanical vignetting
// - Vintage Swirl: Classic Petzval optical formula with tangential swirl
// - Creamy Macro: Ultra-shallow macro depth of field with soap bubble caustic rims

import '../../color/blur_spec.dart';
import '../../edit/tool_definition.dart';
import 'preset_catalog.dart';

/// Predefined lens blur preset definitions with complete 3-way color grading wheels,
/// 8-band HSL mixes, and Depth Anything V2 optical parameters.
final List<ToolDefinition> lensBlurPresets = ToolLibrary.lensBlurLookTools();

/// Maps lens blur tools to categorized [PresetItem]s for [PresetCatalog].
List<PresetItem> lensBlurPresetItems() => [
      PresetItem(
        id: 'optics_portrait_85',
        name: 'Portrait 85/f1.8',
        category: PresetCategory.portrait,
        description: 'Classic 85mm f/1.8 optical portrait isolation with circular aperture blades',
        reference: 'Classic 85mm Prime',
        tool: lensBlurPresets.firstWhere((t) => t.name == 'Portrait 85/f1.8'),
        depthHint: 'Ideal for headshots and half-body portraits',
        blurAmount: 0.85,
        bokehShape: BokehShape.circle,
      ),
      PresetItem(
        id: 'optics_street_35',
        name: 'Street 35/f1.4',
        category: PresetCategory.urban,
        description: 'Fast 35mm f/1.4 environmental portrait look with gentle falloff',
        reference: 'Fast 35mm Prime',
        tool: lensBlurPresets.firstWhere((t) => t.name == 'Street 35/f1.4'),
        depthHint: 'Environmental portrait with subject separation',
        blurAmount: 0.65,
        bokehShape: BokehShape.hexagon,
      ),
      PresetItem(
        id: 'optics_anamorphic_50',
        name: 'Anamorphic 50',
        category: PresetCategory.cinema,
        description: 'Cinema anamorphic lens with cat\'s eye mechanical vignetting',
        reference: 'Anamorphic Cinema',
        tool: lensBlurPresets.firstWhere((t) => t.name == 'Anamorphic 50'),
        depthHint: 'Cinematic widescreen look with elliptical bokeh',
        blurAmount: 0.75,
        bokehShape: BokehShape.catsEye,
      ),
      PresetItem(
        id: 'optics_vintage_swirl',
        name: 'Vintage Swirl',
        category: PresetCategory.film,
        description: 'Classic Petzval optical formula with tangential swirl and spherical aberration',
        reference: 'Petzval 1840 Lens',
        tool: lensBlurPresets.firstWhere((t) => t.name == 'Vintage Swirl'),
        depthHint: 'Vintage portrait with dynamic vortex background',
        blurAmount: 0.90,
        bokehShape: BokehShape.swirl,
      ),
      PresetItem(
        id: 'optics_creamy_macro',
        name: 'Creamy Macro',
        category: PresetCategory.nature,
        description: 'Ultra-shallow macro depth of field with soap bubble caustic rims',
        reference: 'Trioplan 100mm f/2.8',
        tool: lensBlurPresets.firstWhere((t) => t.name == 'Creamy Macro'),
        depthHint: 'Extreme macro close-up with caustic bokeh bubbles',
        blurAmount: 1.0,
        bokehShape: BokehShape.soapBubble,
      ),
    ];
