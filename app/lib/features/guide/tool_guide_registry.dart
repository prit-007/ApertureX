import 'package:flutter/material.dart';
import 'tool_guide_model.dart';

/// Central catalog of interactive guides and pro masterclasses for ApertureX.
class ToolGuideRegistry {
  ToolGuideRegistry._();

  static const List<ToolGuideModel> allGuides = [
    // --- LIGHT ---
    ToolGuideModel(
      id: 'exposure',
      title: 'Exposure & Dynamic Range',
      category: ToolCategory.light,
      summary: 'Adjust overall photo brightness with linear photometric precision.',
      description:
          'Exposure shifts the overall lightness or darkness of the image in photographic stops (EV). '
          'ApertureX handles exposure calculations in floating-point linear color space, avoiding harsh clipping '
          'and preserving shadow detail and highlight roll-off.',
      icon: Icons.wb_sunny_outlined,
      bestUsedFor: 'Correcting underexposed or overexposed shots before doing targeted tonal adjustments.',
      proTips: [
        'Double tap the slider thumb to instantly reset exposure to zero (neutral).',
        'In Snapseed gesture shell, drag vertically to select Exposure and scrub horizontally to adjust.',
        'Watch the live interactive histogram in the HUD to prevent highlight burnout.',
      ],
      shortcut: 'E (in Quick Edit)',
    ),
    ToolGuideModel(
      id: 'contrast',
      title: 'Contrast & Dynamic Tone',
      category: ToolCategory.light,
      summary: 'Stretch the tonal difference between bright highlights and dark shadows.',
      description:
          'Increases punch and dimension by expanding the gap between the darkest and brightest areas. '
          'Unlike simple gamma contrast, ApertureX uses an S-curve that anchors midtones around 18% gray.',
      icon: Icons.contrast,
      bestUsedFor: 'Adding punch to flat RAW photos or softening harsh noon-day sun captures.',
      proTips: [
        'For high-contrast scenes with harsh light, lower contrast slightly (-10 to -20) to recover midtone depth.',
        'Pair with Clarity for punchy micro-textures without clipping deep blacks.',
      ],
    ),
    ToolGuideModel(
      id: 'highlights_shadows',
      title: 'Highlights & Shadows Recovery',
      category: ToolCategory.light,
      summary: 'Surgically restore clipped sky details or lift dark, muddy shadow areas.',
      description:
          'Highlights recovery specifically targets values in the 75%-100% luminance zone without altering midtones. '
          'Shadows lifting rescues detail from 0%-25% dark tones while maintaining clean black point anchoring.',
      icon: Icons.wb_twilight,
      bestUsedFor: 'Backlit portraits, golden hour landscapes, and high-dynamic-range scenes.',
      proTips: [
        'Pull Highlights to -30 or -50 to bring dramatic cloud textures back into blown-out skies.',
        'Avoid lifting Shadows beyond +70 to prevent excessive sensor noise in low-light RAW frames.',
      ],
    ),
    ToolGuideModel(
      id: 'whites_blacks',
      title: 'Whites & Blacks Clipping Point',
      category: ToolCategory.light,
      summary: 'Set the absolute white ceiling and true black foundation of your photo.',
      description:
          'Whites sets the point where highlights become pure white (#FFFFFF), giving specular punch. '
          'Blacks defines the lowest shadow threshold where tones become true black (#000000).',
      icon: Icons.tonality,
      bestUsedFor: 'Establishing contrast boundaries and creating rich, filmic black levels.',
      proTips: [
        'Hold Alt/Option (or tap HUD clipping preview) while moving Whites/Blacks to see zebra clippings in real-time.',
        'Lift Blacks slightly (+10 to +25) for a trendy matte or vintage film aesthetic.',
      ],
    ),
    ToolGuideModel(
      id: 'curves',
      title: 'Tone Curves & RGB Channels',
      category: ToolCategory.light,
      summary: '5-point spline curve control over luminance and individual color channels.',
      description:
          'Tone Curves provide maximum tonal precision. Adjust the master RGB curve for contrast curves '
          'or dial into individual Red, Green, and Blue channels for cinematic split toning and cross-processing.',
      icon: Icons.show_chart,
      bestUsedFor: 'Fine art grading, matte shadows, cinematic color casts, and high-precision contrast.',
      proTips: [
        'Create a subtle "S-curve" (lift shadows, drop highlights) for iconic editorial punch.',
        'In the Blue channel, lift the bottom-left point slightly to inject subtle cyan-blue into the deep shadows.',
      ],
      shortcut: 'C (in Curve mode)',
    ),

    // --- COLOR ---
    ToolGuideModel(
      id: 'white_balance',
      title: 'White Balance (Temp & Tint)',
      category: ToolCategory.color,
      summary: 'Neutralize color casts or add creative warmth and coolness.',
      description:
          'Temperature adjusts Kelvin warmth (cool blue to warm amber), while Tint balances the green-to-magenta axis. '
          'On RAW captures, this operates directly on camera sensor multipliers before demosaicing.',
      icon: Icons.device_thermostat,
      bestUsedFor: 'Correcting tungsten indoor lighting casts, mixed fluorescent lighting, or sunset warmth.',
      proTips: [
        'Tap the EyeDropper icon on the image to sample a neutral gray or white wall for auto white balance.',
        'Warm up portraits slightly (+5 to +10 Temp) to flatter skin tones.',
      ],
    ),
    ToolGuideModel(
      id: 'vibrance_saturation',
      title: 'Vibrance vs. Saturation',
      category: ToolCategory.color,
      summary: 'Smart color boost with automatic skin-tone preservation.',
      description:
          'Saturation boosts every color channel equally, which can easily over-saturate skin tones. '
          'Vibrance intelligently targets muted, pastel tones while shielding already-saturated areas and human skin.',
      icon: Icons.color_lens_outlined,
      bestUsedFor: 'Boosting nature, sky, and foliage colors safely in photos with human subjects.',
      proTips: [
        'Prefer Vibrance (+20 to +30) over Saturation for portrait photography.',
        'Set Saturation to -100 for a pure, clean monochrome black-and-white base.',
      ],
    ),
    ToolGuideModel(
      id: 'tat',
      title: 'Targeted Adjustment Tool (TAT / HSL)',
      category: ToolCategory.color,
      summary: 'Direct on-image color manipulation for Hue, Saturation, and Luminance.',
      description:
          'ApertureX lets you tap directly on any color in your photograph and drag up or down to shift '
          'Hue, Saturation, or Luminance. The engine automatically blends across 8 chromatic channels '
          '(Red, Orange, Yellow, Green, Aqua, Blue, Purple, Magenta).',
      icon: Icons.colorize,
      bestUsedFor: 'Isolating skin tones (Orange channel), intensifying blue skies, or enhancing autumn foliage.',
      proTips: [
        'Select TAT Luminance, tap the sky, and drag down to darken the blue sky without affecting the landscape.',
        'Select TAT Hue, tap green grass, and drag toward yellow or emerald for seasonal color styling.',
      ],
    ),
    ToolGuideModel(
      id: 'color_grading',
      title: 'Color Grading (3-Way Wheels)',
      category: ToolCategory.color,
      summary: 'Hollywood 3-way color wheels for Shadows, Midtones, and Highlights.',
      description:
          'Industry-standard color grading matching cinema grading suites like DaVinci Resolve. '
          'Tint shadows, midtones, and highlights independently, with adjustable balance and blending sliders.',
      icon: Icons.pie_chart_outline,
      bestUsedFor: 'Stylized cinematic looks, teal & orange color palettes, and mood enhancement.',
      proTips: [
        'Classic Hollywood recipe: Tint Shadows toward Cyan/Teal (Hue ~210°), Highlights toward Warm Orange (Hue ~40°).',
        'Use the Balance slider to favor shadow tinting or highlight tinting across the image.',
      ],
    ),

    // --- EFFECTS ---
    ToolGuideModel(
      id: 'clarity_texture',
      title: 'Clarity, Texture & Dehaze',
      category: ToolCategory.effects,
      summary: 'Midtone micro-contrast, high-frequency texture, and atmospheric haze cutting.',
      description:
          'Texture focuses on fine high-frequency details like pores and fabric threads without affecting larger edges. '
          'Clarity boosts midtone contrast for dramatic presence. Dehaze cuts through atmospheric fog, mist, and glare.',
      icon: Icons.blur_linear,
      bestUsedFor: 'Landscape drama, street photography, architecture, and portrait skin smoothing.',
      proTips: [
        'Negative Texture (-15) smooths skin surfaces while preserving crisp eyelashes and lips.',
        'Clarity adds dramatic pop to clouds, water reflections, and rock textures.',
        'Use Dehaze gently (+10 to +20) on mountain vistas to bring back distant contrast.',
      ],
    ),
    ToolGuideModel(
      id: 'depth_bokeh',
      title: 'AI Depth Bokeh & Lens Blur',
      category: ToolCategory.effects,
      summary: 'Cinematic optical bokeh and shallow depth-of-field simulation.',
      description:
          'Uses neural monocular depth estimation to construct a 16-bit depth map of the scene. '
          'Renders realistic optical bokeh with customizable focal plane, aperture blade count, and cat-eye falloff.',
      icon: Icons.lens_blur,
      bestUsedFor: 'Turning standard smartphone photos into wide-aperture f/1.4 prime lens portraits.',
      proTips: [
        'Tap anywhere on the photo to set the focal focus plane directly.',
        'Select aperture blade shapes (Circular, 5-blade, 7-blade, or Anamorphic) to match classic vintage lenses.',
      ],
    ),

    // --- OPTICS ---
    ToolGuideModel(
      id: 'optics_lensfun',
      title: 'Lensfun Optics & Distortion Correction',
      category: ToolCategory.optics,
      summary: 'Automatic lens profile detection, barrel/pincushion correction, and vignetting compensation.',
      description:
          'ApertureX includes a built-in Lensfun optics database. It reads EXIF metadata to identify your camera '
          'and lens model, automatically rectifying optical barrel/pincushion geometric distortion, vignetting falloff, '
          'and lateral chromatic aberration.',
      icon: Icons.camera_outlined,
      bestUsedFor: 'Wide-angle lens distortion, architectural photography, and corner darkening removal.',
      proTips: [
        'Enable "Profile Lens Corrections" to straighten curved straight lines on ultra-wide architectural shots.',
        'Use the Manual Defringe slider with the purple/green eye-dropper to clean high-contrast tree branches.',
      ],
    ),

    // --- GEOMETRY ---
    ToolGuideModel(
      id: 'geometry_crop',
      title: 'Crop, Rotate & GPU Perspective Warp',
      category: ToolCategory.geometry,
      summary: 'Instant 120 FPS GPU-accelerated cropping, sub-degree leveling, and perspective keystoning.',
      description:
          'ApertureX offloads live geometric transformations directly to Flutter Impeller Matrix4 shaders. '
          'Rotate with ultra-fine 0.06° resolution, level horizons automatically, or correct keystoning with 4-point perspective warp.',
      icon: Icons.crop_rotate,
      bestUsedFor: 'Straightening tilted horizons, squaring building facades, and cropping for social platforms.',
      proTips: [
        'Tap "Auto Straighten" to automatically align horizon lines via gradient Hough transform.',
        'Choose standard aspect ratios: 1:1 (Square), 4:5 (Portrait), 16:9 (Cinema), or Original ratio.',
      ],
    ),

    // --- MASKING & STYLUS ---
    ToolGuideModel(
      id: 'stylus',
      title: 'Stylus Pen Masking & Palm Rejection',
      category: ToolCategory.masking,
      summary: 'Pressure-sensitive painting with S-Pen, Apple Pencil, and dual-tip physical eraser.',
      description:
          'Full native stylus engine supporting hardware pressure sensitivity (0.0 to 1.0) and palm rejection. '
          'Drawing with a stylus smoothly modulates brush radius and flow. Inverting the pen or pressing the barrel button '
          'automatically activates eraser mode.',
      icon: Icons.brush,
      bestUsedFor: 'Fine local retouching, teeth whitening, eye sharpening, and precise object dodging/burning.',
      proTips: [
        'Hardware palm rejection ensures your hand resting on tablet screens will never trigger stray strokes.',
        'Tap the Eye icon to view the translucent red Rubylith overlay to inspect mask boundaries.',
      ],
    ),
    ToolGuideModel(
      id: 'ai_subject_mask',
      title: 'AI One-Tap Subject & Background Mask',
      category: ToolCategory.masking,
      summary: 'Automatic subject segmentation and hair strand boundary matting.',
      description:
          'ApertureX runs on-device neural segmentation models (Saliency, RMBG, MobileSAM) to isolate humans, '
          'pets, and objects in milliseconds. The mask alpha channel is refined via guided-filter re-matting against image RGBA.',
      icon: Icons.person_pin_circle_outlined,
      bestUsedFor: 'Darkening backgrounds, brightening subjects, or changing sky saturation in one tap.',
      proTips: [
        'Tap "Invert Mask" to flip from Subject to Background effortlessly.',
        'Use the Mask Feather slider to seamlessly blend adjustments into tricky hair and edge boundaries.',
      ],
    ),

    // --- WORKFLOW ---
    ToolGuideModel(
      id: 'dual_shell',
      title: 'Dual-Shell UI (Snapseed vs Lightroom)',
      category: ToolCategory.workflow,
      summary: 'Choose between fluid gesture editing or deep precision parameter panels.',
      description:
          'ApertureX is the world’s first editor with dual interchangeable UI shells over a single shared recipe. '
          'Use the Snapseed gesture shell for fast on-canvas swipe gestures, or switch to the Lightroom precision panel '
          'for categorized slider sheets and numerical inputs.',
      icon: Icons.view_sidebar,
      bestUsedFor: 'Personalizing your editing workflow based on whether you prefer fast gestures or deep precision.',
      proTips: [
        'Switch shells anytime in Settings > Editing Shell. Your photo recipe and history are 100% preserved.',
        'Enable Glassmorphism in Settings for translucent HUD overlays that do not block your view.',
      ],
    ),
    ToolGuideModel(
      id: 'selective_recipe',
      title: 'Selective Settings Copy & Paste',
      category: ToolCategory.workflow,
      summary: 'Batch edit photos by copying exact chosen parameter subsets.',
      description:
          'Unlike basic "Copy All" tools, ApertureX opens a granular selector where you can pick and choose '
          'which adjustments to paste: Light, Color, Effects, Tone Curves, or Geometry.',
      icon: Icons.copy_all,
      bestUsedFor: 'Applying consistent color grading across a photoshoot while keeping individual crops intact.',
      proTips: [
        'Uncheck "Geometry / Crop" when copying settings to preserve unique framing on individual photos.',
        'Tap "Select None", then tap only "Color" for instantaneous batch color matching.',
      ],
    ),
    ToolGuideModel(
      id: 'lossless_dng',
      title: 'Lossless DNG & CFA RAW Export',
      category: ToolCategory.workflow,
      summary: 'Export pure CFA Bayer sensor raw with non-destructive XMP metadata.',
      description:
          'When editing RAW photos, ApertureX allows exporting a lossless Adobe DNG file containing the original '
          'uncompressed CFA Bayer sensor data alongside embedded XMP non-destructive development tags.',
      icon: Icons.raw_on,
      bestUsedFor: 'Archival preservation and round-tripping with desktop tools like Photoshop and Darktable.',
      proTips: [
        'In the Export Options sheet, choose DNG (Lossless RAW) for maximum dynamic range preservation.',
      ],
    ),
    ToolGuideModel(
      id: 'neural_plugins',
      title: 'ApertureX Neural Forge (BYOM Plugins)',
      category: ToolCategory.workflow,
      summary: 'Bring-Your-Own-Model AI plugins via declarative ONNX manifests and GitHub URLs.',
      description:
          'The first photo editor in history allowing users to install custom AI models via GitHub links. '
          'Plugins are 100% sandboxed ONNX tensor weights driven by dynamic JSON manifests, rendering native Flutter sliders.',
      icon: Icons.extension_outlined,
      bestUsedFor: 'Adding state-of-the-art community AI upscalers, depth estimators, and portrait matting models.',
      proTips: [
        'Open Settings > AI Neural Plugins > Community to install SOTA models with 1 tap.',
        'Paste any valid GitHub repository or HuggingFace link to install community-created plugins offline.',
      ],
    ),
  ];

  /// Look up a guide by its unique identifier.
  static ToolGuideModel? getById(String id) {
    for (final guide in allGuides) {
      if (guide.id == id) return guide;
    }
    return null;
  }

  /// Filter all guides belonging to a category.
  static List<ToolGuideModel> getByCategory(ToolCategory category) {
    return allGuides.where((g) => g.category == category).toList(growable: false);
  }

  /// Search guides across title, summary, description, and pro tips.
  static List<ToolGuideModel> search(String query) {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) return allGuides;

    return allGuides.where((g) {
      if (g.title.toLowerCase().contains(clean)) return true;
      if (g.summary.toLowerCase().contains(clean)) return true;
      if (g.description.toLowerCase().contains(clean)) return true;
      if (g.bestUsedFor.toLowerCase().contains(clean)) return true;
      if (g.proTips.any((tip) => tip.toLowerCase().contains(clean))) return true;
      return false;
    }).toList(growable: false);
  }
}
