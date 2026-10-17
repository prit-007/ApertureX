/// Lensfun-aligned Lens Profile Database and optical calibration matcher (#66, #67).
///
/// Encapsulates optical characteristics for camera and lens combinations,
/// providing automatic lens identification from EXIF tags and recommending
/// distortion, transverse chromatic aberration (TCA), and vignetting profiles.
class LensProfileData {
  const LensProfileData({
    required this.maker,
    required this.model,
    required this.mount,
    required this.minFocal,
    required this.maxFocal,
    required this.maxAperture,
    this.cropFactor = 1.0,
    this.distortionCorrection = 0.0,
    this.vignetteCorrection = 0.0,
    this.hasCaProfile = true,
    this.description = '',
  });

  /// Manufacturer name (e.g., "Sony", "Canon", "Nikon", "Apple").
  final String maker;

  /// Lens model name (e.g., "FE 24-70mm F2.8 GM II").
  final String model;

  /// Camera bayonet/mount (e.g., "Sony E", "Canon RF", "Nikon Z").
  final String mount;

  /// Minimum focal length in mm.
  final double minFocal;

  /// Maximum focal length in mm.
  final double maxFocal;

  /// Maximum relative aperture (f-number, e.g. 2.8).
  final double maxAperture;

  /// Sensor crop factor relative to 35mm full frame (1.0 = FF, 1.5 = APS-C, 2.0 = MFT).
  final double cropFactor;

  /// Recommended default geometric distortion correction amount (-100 to 100).
  final double distortionCorrection;

  /// Recommended default vignette compensation amount (0 to 100).
  final double vignetteCorrection;

  /// Whether transverse chromatic aberration correction parameters are profiled.
  final bool hasCaProfile;

  /// Optional description or notes.
  final String description;

  /// Formatted display name, e.g., "Sony FE 24-70mm F2.8 GM II".
  String get displayName => model.startsWith(maker) ? model : '$maker $model';

  /// Formatted focal range string, e.g. "24-70mm f/2.8" or "50mm f/1.4".
  String get focalRangeLabel {
    final focalStr = minFocal == maxFocal
        ? '${minFocal.round()}mm'
        : '${minFocal.round()}-${maxFocal.round()}mm';
    return '$focalStr f/$maxAperture';
  }
}

/// Curated Lensfun database providing optical profile lookup and matching.
class LensDatabase {
  LensDatabase._();

  static const List<LensProfileData> lenses = [
    // --- Sony E-Mount ---
    LensProfileData(
      maker: 'Sony',
      model: 'FE 24-70mm F2.8 GM II',
      mount: 'Sony E',
      minFocal: 24.0,
      maxFocal: 70.0,
      maxAperture: 2.8,
      distortionCorrection: 32.0,
      vignetteCorrection: 45.0,
      description: 'Pro standard zoom for full-frame Sony Alpha bodies',
    ),
    LensProfileData(
      maker: 'Sony',
      model: 'FE 16-35mm F2.8 GM II',
      mount: 'Sony E',
      minFocal: 16.0,
      maxFocal: 35.0,
      maxAperture: 2.8,
      distortionCorrection: 40.0,
      vignetteCorrection: 50.0,
      description: 'Ultra-wide angle zoom for landscape and architecture',
    ),
    LensProfileData(
      maker: 'Sony',
      model: 'FE 70-200mm F2.8 GM OSS II',
      mount: 'Sony E',
      minFocal: 70.0,
      maxFocal: 200.0,
      maxAperture: 2.8,
      distortionCorrection: 18.0,
      vignetteCorrection: 30.0,
      description: 'Telephoto pro zoom with internal stabilization',
    ),
    LensProfileData(
      maker: 'Sony',
      model: 'FE 50mm F1.2 GM',
      mount: 'Sony E',
      minFocal: 50.0,
      maxFocal: 50.0,
      maxAperture: 1.2,
      distortionCorrection: 12.0,
      vignetteCorrection: 40.0,
      description: 'Ultra-fast standard prime',
    ),
    LensProfileData(
      maker: 'Sony',
      model: 'FE 85mm F1.4 GM',
      mount: 'Sony E',
      minFocal: 85.0,
      maxFocal: 85.0,
      maxAperture: 1.4,
      distortionCorrection: 10.0,
      vignetteCorrection: 35.0,
      description: 'Portrait telephoto prime',
    ),
    LensProfileData(
      maker: 'Sony',
      model: 'E 16-55mm F2.8 G',
      mount: 'Sony E',
      minFocal: 16.0,
      maxFocal: 55.0,
      maxAperture: 2.8,
      cropFactor: 1.5,
      distortionCorrection: 35.0,
      vignetteCorrection: 40.0,
      description: 'APS-C flagship standard zoom',
    ),

    // --- Canon RF / EF ---
    LensProfileData(
      maker: 'Canon',
      model: 'RF 24-70mm F2.8 L IS USM',
      mount: 'Canon RF',
      minFocal: 24.0,
      maxFocal: 70.0,
      maxAperture: 2.8,
      distortionCorrection: 30.0,
      vignetteCorrection: 42.0,
      description: 'L-series standard pro zoom for EOS R system',
    ),
    LensProfileData(
      maker: 'Canon',
      model: 'RF 15-35mm F2.8 L IS USM',
      mount: 'Canon RF',
      minFocal: 15.0,
      maxFocal: 35.0,
      maxAperture: 2.8,
      distortionCorrection: 38.0,
      vignetteCorrection: 48.0,
      description: 'L-series ultra-wide zoom for EOS R system',
    ),
    LensProfileData(
      maker: 'Canon',
      model: 'RF 50mm F1.2 L USM',
      mount: 'Canon RF',
      minFocal: 50.0,
      maxFocal: 50.0,
      maxAperture: 1.2,
      distortionCorrection: 15.0,
      vignetteCorrection: 38.0,
      description: 'Reference 50mm prime',
    ),
    LensProfileData(
      maker: 'Canon',
      model: 'EF 24-105mm f/4L IS USM',
      mount: 'Canon EF',
      minFocal: 24.0,
      maxFocal: 105.0,
      maxAperture: 4.0,
      distortionCorrection: 35.0,
      vignetteCorrection: 45.0,
      description: 'Workhorse travel zoom for Canon DSLRs and adapted EOS R',
    ),

    // --- Nikon Z ---
    LensProfileData(
      maker: 'Nikon',
      model: 'NIKKOR Z 24-70mm f/2.8 S',
      mount: 'Nikon Z',
      minFocal: 24.0,
      maxFocal: 70.0,
      maxAperture: 2.8,
      distortionCorrection: 28.0,
      vignetteCorrection: 40.0,
      description: 'S-Line standard pro zoom for Nikon Z series',
    ),
    LensProfileData(
      maker: 'Nikon',
      model: 'NIKKOR Z 50mm f/1.8 S',
      mount: 'Nikon Z',
      minFocal: 50.0,
      maxFocal: 50.0,
      maxAperture: 1.8,
      distortionCorrection: 8.0,
      vignetteCorrection: 25.0,
      description: 'High-resolving compact standard prime',
    ),

    // --- Fujifilm X ---
    LensProfileData(
      maker: 'Fujifilm',
      model: 'XF 16-55mm f/2.8 R LM WR',
      mount: 'Fujifilm X',
      minFocal: 16.0,
      maxFocal: 55.0,
      maxAperture: 2.8,
      cropFactor: 1.5,
      distortionCorrection: 30.0,
      vignetteCorrection: 35.0,
      description: 'Flagship standard zoom for X-Trans APS-C sensors',
    ),
    LensProfileData(
      maker: 'Fujifilm',
      model: 'XF 35mm f/1.4 R',
      mount: 'Fujifilm X',
      minFocal: 35.0,
      maxFocal: 35.0,
      maxAperture: 1.4,
      cropFactor: 1.5,
      distortionCorrection: 14.0,
      vignetteCorrection: 30.0,
      description: 'Classic character prime for street and portrait photography',
    ),

    // --- Sigma (Art / Contemporary) ---
    LensProfileData(
      maker: 'Sigma',
      model: '24-70mm F2.8 DG DN Art',
      mount: 'Multi-mount',
      minFocal: 24.0,
      maxFocal: 70.0,
      maxAperture: 2.8,
      distortionCorrection: 32.0,
      vignetteCorrection: 44.0,
      description: 'Art line high-performance zoom for Sony E / L-Mount',
    ),
    LensProfileData(
      maker: 'Sigma',
      model: '85mm F1.4 DG DN Art',
      mount: 'Multi-mount',
      minFocal: 85.0,
      maxFocal: 85.0,
      maxAperture: 1.4,
      distortionCorrection: 10.0,
      vignetteCorrection: 32.0,
      description: 'Compact portrait prime for mirrorless',
    ),

    // --- Apple iPhone Computational Lenses ---
    LensProfileData(
      maker: 'Apple',
      model: 'iPhone 15 Pro Main Camera (24mm)',
      mount: 'Apple Computational',
      minFocal: 6.86,
      maxFocal: 6.86,
      maxAperture: 1.78,
      cropFactor: 3.5,
      distortionCorrection: 22.0,
      vignetteCorrection: 25.0,
      description: 'Quad-pixel 48MP main computational camera module',
    ),
    LensProfileData(
      maker: 'Apple',
      model: 'iPhone 15 Pro Ultra Wide (13mm)',
      mount: 'Apple Computational',
      minFocal: 2.22,
      maxFocal: 2.22,
      maxAperture: 2.2,
      cropFactor: 5.8,
      distortionCorrection: 45.0,
      vignetteCorrection: 35.0,
      description: 'Ultra wide 120-degree field of view module',
    ),

    // --- Google Pixel Computational Lenses ---
    LensProfileData(
      maker: 'Google',
      model: 'Pixel 8 Pro Main Camera (25mm)',
      mount: 'Google Computational',
      minFocal: 6.9,
      maxFocal: 6.9,
      maxAperture: 1.68,
      cropFactor: 3.6,
      distortionCorrection: 20.0,
      vignetteCorrection: 22.0,
      description: '50MP Octa PD main sensor module',
    ),
  ];

  /// Finds the best matching lens from EXIF metadata.
  static LensProfileData? findBestMatch({
    String? lensModel,
    String? lensMake,
    String? cameraMake,
    String? cameraModel,
    double? focalLength,
  }) {
    // 1. Direct model string match
    if (lensModel != null && lensModel.isNotEmpty) {
      final query = _normalize(lensModel);
      for (final lens in lenses) {
        final target = _normalize(lens.model);
        if (query.contains(target) || target.contains(query)) {
          return lens;
        }
      }

      // Fuzzy keywords match
      for (final lens in lenses) {
        if (_matchesKeywords(query, lens.model)) {
          return lens;
        }
      }
    }

    // 2. Camera maker + focal length match
    if (cameraMake != null && cameraMake.isNotEmpty && focalLength != null) {
      final makeNorm = _normalize(cameraMake);
      final candidates = lenses.where((l) => _normalize(l.maker) == makeNorm || makeNorm.contains(_normalize(l.maker)));
      for (final candidate in candidates) {
        if (focalLength >= candidate.minFocal - 0.5 &&
            focalLength <= candidate.maxFocal + 0.5) {
          return candidate;
        }
      }
    }

    // 3. Fallback to camera manufacturer default lens if present
    if (cameraMake != null && cameraMake.isNotEmpty) {
      final makeNorm = _normalize(cameraMake);
      final match = lenses.where((l) => _normalize(l.maker) == makeNorm || makeNorm.contains(_normalize(l.maker))).firstOrNull;
      if (match != null) return match;
    }

    return null;
  }

  /// Lists all distinct lens makers in the database.
  static List<String> getMakers() {
    return lenses.map((l) => l.maker).toSet().toList()..sort();
  }

  /// Lists all lenses for a given manufacturer.
  static List<LensProfileData> getLensesForMaker(String maker) {
    return lenses.where((l) => l.maker.toLowerCase() == maker.toLowerCase()).toList();
  }

  static String _normalize(String input) {
    return input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  static bool _matchesKeywords(String query, String model) {
    final modelNorm = _normalize(model);
    final keywords = modelNorm.split(RegExp(r'\s+'));
    int matchCount = 0;
    for (final kw in keywords) {
      if (kw.length >= 3 && query.contains(kw)) {
        matchCount++;
      }
    }
    return matchCount >= 2;
  }
}
