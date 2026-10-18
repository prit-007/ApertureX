import 'dart:math' as math;
import 'dart:typed_data';

import 'image_format.dart';
import '../color/blur_spec.dart';
import '../color/grade_spec.dart';
import '../color/optics_spec.dart';
import '../color/spatial_spec.dart';
import '../edit/adjustment_layer.dart';
import '../edit/geometry_spec.dart';
import '../src/rust/api/color.dart' as rust_color;
import '../src/rust/api/decode.dart' show ImageDims, RgbaImage;
import '../src/rust/api/decode.dart' as rust_decode;
import '../src/rust/api/engine.dart' as rust_engine;
import '../src/rust/api/exif.dart' as rust_exif;
import '../src/rust/exif.dart' show ImageMetadata;
import '../src/rust/api/export.dart' as rust_export;
import '../src/rust/api/geometry.dart' as rust_geometry;
import '../src/rust/api/histogram.dart' as rust_hist;
import '../src/rust/api/icc.dart' as rust_icc;
import '../src/rust/api/logging.dart' as rust_logging;
import '../src/rust/api/mask.dart' as rust_mask;
import '../src/rust/api/preview.dart' as rust_preview;
import '../src/rust/api/preview.dart' show PreviewBaseSpec;
import '../src/rust/api/raw.dart' as rust_raw;
import '../src/rust/api/roi.dart' as rust_roi;
import '../src/rust/api/spatial.dart' as rust_spatial;
import '../src/rust/frb_generated.dart';

export '../src/rust/api/color.dart' show LutData;
export '../src/rust/api/decode.dart' show ImageDims, RgbaImage;
export '../src/rust/api/histogram.dart' show Histogram;
export '../src/rust/api/preview.dart' show PreviewBaseSpec;
export '../src/rust/api/exif.dart' show EmbeddedDepthResult;
export '../src/rust/exif.dart' show ImageMetadata;
export '../src/rust/api/mask.dart' show DetectedSky, DetectedSubject;
export '../src/rust/frb_generated.dart' show RustLib;

/// Thin, app-facing facade over the generated `flutter_rust_bridge` bindings.
///
/// Keeping the generated `src/rust/` package behind this wrapper means the rest
/// of the app depends on our own names, not on codegen symbols.
class AxEngine {
  const AxEngine._();

  /// Initialises the Rust library. Must be awaited before any engine call.
  static Future<void> init() => RustLib.init();

  /// Installs the Rust panic hook once (ADR 0012 §7): a panic appends payload
  /// + location to `<dir>/rust_panic.log` **before** unwinding to the Dart
  /// boundary, where it is logged and surfaced like any other fatal error.
  static Future<void> initPanicHook({required String dir}) =>
      rust_logging.initPanicHook(dir: dir);

  // --- engine introspection -------------------------------------------------

  static Future<String> version() => rust_engine.engineVersion();

  static Future<Uint8List> syntheticJpeg({
    required int width,
    required int height,
  }) => rust_engine.syntheticJpeg(width: width, height: height);

  static Future<Uint8List> brighten(Uint8List rgba, int amount) =>
      rust_engine.brightenRgba(rgba: rgba, amount: amount);

  // --- JPEG decode (P1) -----------------------------------------------------

  static Future<ImageDims> jpegDimensions(Uint8List jpeg) =>
      rust_decode.jpegDimensions(jpeg: jpeg);

  static Future<RgbaImage> decodeJpegRgba(Uint8List jpeg) =>
      rust_decode.decodeJpegRgba(jpeg: jpeg);

  static Future<RgbaImage> decodeJpegRoi(
    Uint8List jpeg, {
    required int x,
    required int y,
    required int width,
    required int height,
  }) => rust_decode.decodeJpegRoi(
    jpeg: jpeg,
    x: x,
    y: y,
    width: width,
    height: height,
  );

  // --- RAW/DNG decode (P3) --------------------------------------------------

  /// Reads RAW/DNG dimensions without demosaicing (ADR 0005, rawler-first).
  static Future<ImageDims> rawDimensions(Uint8List raw) =>
      rust_raw.rawDimensions(raw: raw);

  /// Decodes a RAW/DNG to a full sRGB RGBA8 buffer (demosaic + camera colour).
  static Future<RgbaImage> decodeRawRgba(Uint8List raw) =>
      rust_raw.decodeRawRgba(raw: raw);

  /// Decodes only the RGBA pixels inside the region of interest (tile path).
  static Future<RgbaImage> decodeRawRoi(
    Uint8List raw, {
    required int x,
    required int y,
    required int width,
    required int height,
  }) => rust_raw.decodeRawRoi(
    raw: raw,
    x: x,
    y: y,
    width: width,
    height: height,
  );

  /// Decodes an image into a bounded proxy buffer (<= [maxDim], ~2 MP) for AI / mask /
  /// geometry analysis to prevent out-of-memory errors on large mobile photos.
  static Future<RgbaImage> decodeAnalysisProxy(
    Uint8List bytes, {
    int maxDim = 1920,
  }) async {
    final decoded = isRawImage(bytes)
        ? await decodeRawRgba(bytes)
        : await decodeJpegRgba(bytes);
    if (maxDim > 0 && math.max(decoded.width, decoded.height) > maxDim) {
      final d = await downscale(
        decoded.rgba,
        width: decoded.width,
        height: decoded.height,
        maxDim: maxDim,
      );
      return RgbaImage(
        rgba: d.rgba,
        width: d.width,
        height: d.height,
      );
    }
    return decoded;
  }

  // --- colour / 3D LUT (P2 Slice D) -----------------------------------------

  /// Normalizes a color-grading hue value (either in degrees `0..360` from the UI
  /// or already normalized `0..1` from presets) into the canonical `[0.0, 1.0)`
  /// range expected by the Rust grading engine (`color.rs`).
  static double normalizeHue(double h) {
    if (h > 1.0 || h < 0.0) {
      final deg = ((h % 360.0) + 360.0) % 360.0;
      return (deg / 360.0).clamp(0.0, 1.0);
    }
    return h.clamp(0.0, 1.0);
  }

  static rust_color.ColorParams _colorParams(GradeSpec s) =>
      rust_color.ColorParams(
        exposure: s.exposure,
        contrast: s.contrast,
        highlights: 0,
        shadows: 0,
        whites: s.whites,
        blacks: s.blacks,
        saturation: s.saturation,
        temperature: s.temperature,
        tint: s.tint,
        vibrance: s.vibrance,
        gradeShadowHue: normalizeHue(s.gradeShadowHue),
        gradeShadowSat: s.gradeShadowSat,
        gradeShadowLum: s.gradeShadowLum,
        gradeMidHue: normalizeHue(s.gradeMidHue),
        gradeMidSat: s.gradeMidSat,
        gradeMidLum: s.gradeMidLum,
        gradeHighlightHue: normalizeHue(s.gradeHighlightHue),
        gradeHighlightSat: s.gradeHighlightSat,
        gradeHighlightLum: s.gradeHighlightLum,
        gradeBlending: s.gradeBlending,
        gradeBalance: s.gradeBalance,
      );


  static rust_color.CurveParams _curveParams(GradeSpec s) =>
      rust_color.CurveParams(
        master: Float32List.fromList(s.masterCurve),
        red: Float32List.fromList(s.redCurve),
        green: Float32List.fromList(s.greenCurve),
        blue: Float32List.fromList(s.blueCurve),
      );

  /// Bakes the grade (and tone curves) into a 2D-packed 3D LUT atlas — the
  /// preview path. Rust owns the colour math; the result feeds `lut.frag`.
  static Future<rust_color.LutData> bakeLut3d(
    GradeSpec spec, {
    int size = 33,
  }) => rust_color.bakeLut3D(
    size: size,
    params: _colorParams(spec),
    curves: _curveParams(spec),
    hsl: spec.hsl,
  );

  /// Applies the same pipeline per-pixel over RGBA (the export twin of the LUT).
  static Future<Uint8List> gradeRgba(Uint8List rgba, GradeSpec spec) =>
      rust_color.gradeRgba(
        rgba: rgba,
        params: _colorParams(spec),
        curves: _curveParams(spec),
        hsl: spec.hsl,
      );

  /// Exports the grade (and tone curves / color wheels) as a DaVinci Resolve / Premiere compliant `.cube` string.
  static Future<String> exportCubeLut(
    GradeSpec spec, {
    int size = 33,
    String? title,
  }) => rust_color.exportCubeLut(
    size: size,
    params: _colorParams(spec),
    curves: _curveParams(spec),
    hsl: spec.hsl,
    title: title,
  );

  // --- histogram (P2) -------------------------------------------------------

  /// Downsamples + grades + bins [rgba] into a 256-bin RGB/luma histogram.
  static Future<rust_hist.Histogram> histogramGraded({
    required Uint8List rgba,
    required int width,
    required int height,
    required GradeSpec spec,
    int sampleDim = 256,
  }) => rust_hist.histogramGraded(
    rgba: rgba,
    width: width,
    height: height,
    sampleDim: sampleDim,
    params: _colorParams(spec),
    curves: _curveParams(spec),
    hsl: spec.hsl,
  );

  // --- wide-gamut input (P2 #15) --------------------------------------------

  /// Detects the JPEG colour space: 0 unknown, 1 sRGB, 2 Display P3.
  static Future<int> detectColorspace(Uint8List jpeg) =>
      rust_icc.detectColorspace(jpeg: jpeg);

  /// Converts Display-P3-encoded RGBA pixels to sRGB.
  static Future<Uint8List> p3ToSrgb(
    Uint8List rgba, {
    required int width,
    required int height,
  }) => rust_icc.p3ToSrgb(rgba: rgba, width: width, height: height);

  // --- spatial (P2) ---------------------------------------------------------

  /// Applies the full spatial pass (shadows/highlights → clarity → texture →
  /// sharpen). A neutral [spec] returns the input unchanged.
  static Future<Uint8List> applySpatial(
    Uint8List rgba, {
    required int width,
    required int height,
    required SpatialSpec spec,
  }) => rust_spatial.spatialApply(
    rgba: rgba,
    width: width,
    height: height,
    shadows: spec.shadows,
    highlights: spec.highlights,
    clarity: spec.clarity,
    texture: spec.texture,
    sharpen: spec.sharpen,
    sharpenRadius: spec.sharpenRadius,
    sharpenDetail: spec.sharpenDetail,
    sharpenMasking: spec.sharpenMasking,
    denoiseLuma: spec.denoiseLuma,
    denoiseChroma: spec.denoiseChroma,
    dehaze: spec.dehaze,
    vignette: spec.vignette,
    vignetteMidpoint: spec.vignetteMidpoint,
    vignetteFeather: spec.vignetteFeather,
    vignetteRoundness: spec.vignetteRoundness,
    vignetteHighlights: spec.vignetteHighlights,
    grain: spec.grain,
    grainSize: spec.grainSize,
    grainRoughness: spec.grainRoughness,
  );

  /// Generates a black-and-white preview of the edge mask (for Alt/Option hold on Masking slider).
  static Future<Uint8List> spatialSharpenEdgeMask(
    Uint8List rgba, {
    required int width,
    required int height,
    required double masking,
  }) => rust_spatial.spatialSharpenEdgeMask(
    rgba: rgba,
    width: width,
    height: height,
    masking: masking,
  );

  /// Texture (fine-detail) boost on an RGBA buffer.
  static Future<Uint8List> spatialTexture(
    Uint8List rgba, {
    required int width,
    required int height,
    double amount = 0,
  }) => rust_spatial.spatialTexture(
    rgba: rgba,
    width: width,
    height: height,
    amount: amount,
  );

  /// Clarity (mid-frequency local contrast).
  static Future<Uint8List> spatialClarity(
    Uint8List rgba, {
    required int width,
    required int height,
    double amount = 0,
  }) => rust_spatial.spatialClarity(
    rgba: rgba,
    width: width,
    height: height,
    amount: amount,
  );

  /// Unsharp sharpening.
  static Future<Uint8List> spatialSharpen(
    Uint8List rgba, {
    required int width,
    required int height,
    double amount = 0,
    int radius = 1,
  }) => rust_spatial.spatialSharpen(
    rgba: rgba,
    width: width,
    height: height,
    amount: amount,
    radius: radius,
  );

  /// Edge-aware shadows/highlights.
  static Future<Uint8List> spatialShadowHighlight(
    Uint8List rgba, {
    required int width,
    required int height,
    double shadows = 0,
    double highlights = 0,
  }) => rust_spatial.spatialShadowHighlight(
    rgba: rgba,
    width: width,
    height: height,
    shadows: shadows,
    highlights: highlights,
  );

  // --- geometry (P2) --------------------------------------------------------

  /// Bilinear downscale so the longest side is at most [maxDim] (0 = no-op).
  static Future<rust_geometry.GeometryResult> downscale(
    Uint8List rgba, {
    required int width,
    required int height,
    int maxDim = 0,
  }) => rust_geometry.geometryDownscale(
    rgba: rgba,
    width: width,
    height: height,
    maxDim: maxDim,
  );

  /// Applies the geometry chain (flip → rotate → straighten); the result has
  /// new dimensions.
  static Future<rust_geometry.GeometryResult> applyGeometry(
    Uint8List rgba, {
    required int width,
    required int height,
    required GeometrySpec spec,
  }) => rust_geometry.geometryApply(
    rgba: rgba,
    width: width,
    height: height,
    flipH: spec.flipH,
    flipV: spec.flipV,
    turns: spec.rotation,
    angle: spec.straighten,
    cropL: spec.crop[0],
    cropT: spec.crop[1],
    cropR: spec.crop[2],
    cropB: spec.crop[3],
    perspectiveX: spec.perspectiveX,
    perspectiveY: spec.perspectiveY,
    skewX: spec.skewX,
    skewY: spec.skewY,
  );

  /// Automatically detects the horizon/straighten correction angle in degrees.
  static Future<double> detectStraightenAngle(
    Uint8List rgba, {
    required int width,
    required int height,
  }) => rust_geometry.geometryDetectStraightenAngle(
    rgba: rgba,
    width: width,
    height: height,
  );

  /// Automatically detects sky horizon, transition feather, and blue chromaticity weight from [rgba] pixels.
  static Future<rust_mask.DetectedSky?> detectSky(
    Uint8List rgba, {
    required int width,
    required int height,
  }) => rust_mask.detectSky(
    rgba: rgba,
    width: width,
    height: height,
  );

  /// Automatically detects dominant subject center, radii, and feather from [rgba] pixels.
  static Future<rust_mask.DetectedSubject?> detectSubject(
    Uint8List rgba, {
    required int width,
    required int height,
  }) => rust_mask.detectSubject(
    rgba: rgba,
    width: width,
    height: height,
  );

  /// Segments dominant subject into an alpha plane of dimensions [targetWidth] x [targetHeight] from [rgba] pixels.
  static Future<Float32List> segmentSubject(
    Uint8List rgba, {
    required int width,
    required int height,
    required int targetWidth,
    required int targetHeight,
  }) => rust_mask.segmentSubject(
    rgba: rgba,
    width: width,
    height: height,
    targetWidth: targetWidth,
    targetHeight: targetHeight,
  );

  /// Refines a mask alpha channel using guided-filter re-matting against image [rgba].
  static Future<Float32List> refineMask({
    required Uint8List rgba,
    required int width,
    required int height,
    required int maskKind,
    required List<double> maskParams,
    List<double> strokePoints = const [],
    double brushRadius = 0.05,
    int filterRadius = 8,
    double eps = 0.005,
  }) =>
      rust_mask.refineMask(
        rgba: rgba,
        width: width,
        height: height,
        kind: maskKind,
        params: Float32List.fromList(maskParams),
        strokePoints: Float32List.fromList(strokePoints),
        brushRadius: brushRadius,
        filterRadius: filterRadius,
        eps: eps,
      );

  /// Attempts to extract an embedded portrait depth map from JPEG container metadata.
  static Future<rust_exif.EmbeddedDepthResult?> extractEmbeddedDepth(Uint8List jpeg) =>
      rust_exif.extractEmbeddedDepth(jpeg: jpeg);

  // --- masking / local adjustments (P2.5) -----------------------------------

  static rust_color.ColorParams _localParams(AdjustmentLayer l) =>
      rust_color.ColorParams(
        exposure: l.exposure,
        contrast: l.contrast,
        highlights: l.highlights,
        shadows: l.shadows,
        whites: 0,
        blacks: 0,
        saturation: l.saturation,
        temperature: l.temperature,
        tint: l.tint,
        vibrance: 0,
        gradeShadowHue: normalizeHue(l.gradeShadowHue),
        gradeShadowSat: l.gradeShadowSat,
        gradeShadowLum: l.gradeShadowLum,
        gradeMidHue: normalizeHue(l.gradeMidHue),
        gradeMidSat: l.gradeMidSat,
        gradeMidLum: l.gradeMidLum,
        gradeHighlightHue: normalizeHue(l.gradeHighlightHue),
        gradeHighlightSat: l.gradeHighlightSat,
        gradeHighlightLum: l.gradeHighlightLum,
        gradeBlending: l.gradeBlending,
        gradeBalance: l.gradeBalance,
      );

  static rust_color.ColorParams _groupParams(MaskGroup g) =>
      rust_color.ColorParams(
        exposure: g.exposure,
        contrast: g.contrast,
        highlights: g.highlights,
        shadows: g.shadows,
        whites: 0,
        blacks: 0,
        saturation: g.saturation,
        temperature: g.temperature,
        tint: g.tint,
        vibrance: 0,
        gradeShadowHue: normalizeHue(g.gradeShadowHue),
        gradeShadowSat: g.gradeShadowSat,
        gradeShadowLum: g.gradeShadowLum,
        gradeMidHue: normalizeHue(g.gradeMidHue),
        gradeMidSat: g.gradeMidSat,
        gradeMidLum: g.gradeMidLum,
        gradeHighlightHue: normalizeHue(g.gradeHighlightHue),
        gradeHighlightSat: g.gradeHighlightSat,
        gradeHighlightLum: g.gradeHighlightLum,
        gradeBlending: g.gradeBlending,
        gradeBalance: g.gradeBalance,
      );


  static rust_mask.MaskLayer _maskLayer(
    AdjustmentLayer l, {
    MaskGroup? group,
  }) =>
      rust_mask.MaskLayer(
        kind: l.maskKind.index,
        mask: l.toBridgeMaskParams(),
        params: group != null ? _groupParams(group) : _localParams(l),
        inverted: l.inverted,
        amount: l.amount,
        groupId: l.groupId,
        joinOp: l.joinOp.index,
        groupInverted: group?.inverted ?? false,
        groupAmount: group?.amount ?? 1.0,
      );

  static List<rust_mask.MaskLayer> _mapLayers(
    List<AdjustmentLayer> layers, [
    List<MaskGroup> maskGroups = const [],
  ]) {
    final groupMap = {for (final g in maskGroups) g.id: g};
    return layers
        .map((l) => _maskLayer(l, group: l.groupId != null ? groupMap[l.groupId] : null))
        .toList();
  }

  /// Composites local adjustment [layers] over [rgba] (masks + sub-grades).
  static Future<Uint8List> applyMasks(
    Uint8List rgba, {
    required int width,
    required int height,
    required List<AdjustmentLayer> layers,
    List<MaskGroup> maskGroups = const [],
  }) {
    if (layers.isEmpty) return Future.value(rgba);
    return rust_mask.applyMasks(
      rgba: rgba,
      width: width,
      height: height,
      layers: _mapLayers(layers, maskGroups),
    );
  }

  // --- Rust-resident preview (#37 spike A) -----------------------------------

  /// Uploads decoded proxy pixels into the Rust-resident store and returns an
  /// opaque handle. This is the only bridge crossing for source pixels —
  /// every later bake references the handle instead.
  static Future<int> previewOpen({
    required Uint8List rgba,
    required int width,
    required int height,
  }) async =>
      (
        await rust_preview.previewOpen(
          rgba: rgba,
          width: width,
          height: height,
        )
      ).toInt();

  static Future<int> previewOpenJpeg({
    required Uint8List jpegBytes,
    int maxDim = 1440,
  }) async =>
      (
        await rust_preview.previewOpenJpeg(
          jpegBytes: jpegBytes,
          maxDim: maxDim,
        )
      ).toInt();

  /// Drops the resident image for [handle]. Unknown and double closes are
  /// safe, so widget teardown can call it unconditionally.
  static Future<void> previewClose(int handle) =>
      rust_preview.previewClose(handle: BigInt.from(handle));

  /// Fused geometry → spatial → masks bake on the resident source in **one**
  /// round trip (spike A). Straighten/perspective/skew stay GPU-warped live
  /// (issues #36/#52), so [PreviewBaseSpec] deliberately omits them; export
  /// keeps its own full-parity path via [exportJpeg].
  static Future<RgbaImage> previewBase(
    int handle, {
    required PreviewBaseSpec spec,
    required List<AdjustmentLayer> layers,
    List<MaskGroup> maskGroups = const [],
  }) => rust_preview.previewBase(
    handle: BigInt.from(handle),
    spec: spec,
    layers: _mapLayers(layers, maskGroups),
    retouchPatches: [],
  );

  /// Halo rows of context ([spatial margin]) the high-zoom ROI overlay (#55)
  /// must decode above and below its output band so [bakeRoiBand] sees true
  /// neighbours. Geometry never affects the halo.
  static Future<int> roiHalo({
    required PreviewBaseSpec spec,
    required int fullWidth,
    required int fullHeight,
  }) => rust_roi.roiHalo(
    spec: spec,
    fullWidth: fullWidth,
    fullHeight: fullHeight,
  );

  /// Bakes the spatial + mask chain of [previewBase] onto a decoded
  /// full-width band of the **original** frame — byte-parity with the rows the
  /// proxy shows, so the overlay stitches without a seam (#55/#16).
  ///
  /// [band] holds rows [decodeTop].. of the source, with [roiHalo] context
  /// around [outTop]..[outTop + outRows). The spec's geometry must be
  /// identity (the viewport gates on crop/rotate/flip); the grade stays
  /// shader-side, as in preview.
  static Future<RgbaImage> bakeRoiBand(
    Uint8List band, {
    required int decodeTop,
    required int outTop,
    required int outRows,
    required int fullWidth,
    required int fullHeight,
    required PreviewBaseSpec spec,
    required List<AdjustmentLayer> layers,
    List<MaskGroup> maskGroups = const [],
  }) => rust_roi.bakeRoiBand(
    band: band,
    decodeTop: decodeTop,
    outTop: outTop,
    outRows: outRows,
    fullWidth: fullWidth,
    fullHeight: fullHeight,
    spec: spec,
    layers: _mapLayers(layers, maskGroups),
  );

  /// Bakes the spatial + mask chain of [previewBase] onto a decoded **rect
  /// (tile)** of the **original** frame — the 2D sibling of [bakeRoiBand],
  /// used by the tiled viewport (#16).
  ///
  /// [rect] holds the pixels `(decodeX, decodeY, decodeW, decodeH)` of the
  /// source, with [roiHalo] context on **all four** sides around
  /// `(outX, outY, outW, outH)` (except at the image edges). The spec's
  /// geometry must be identity; the grade stays shader-side.
  static Future<RgbaImage> bakeRoiRect(
    Uint8List rect, {
    required int decodeX,
    required int decodeY,
    required int decodeW,
    required int decodeH,
    required int outX,
    required int outY,
    required int outW,
    required int outH,
    required int fullWidth,
    required int fullHeight,
    required PreviewBaseSpec spec,
    required List<AdjustmentLayer> layers,
    List<MaskGroup> maskGroups = const [],
  }) => rust_roi.bakeRoiRect(
    rect: rect,
    decodeX: decodeX,
    decodeY: decodeY,
    decodeW: decodeW,
    decodeH: decodeH,
    outX: outX,
    outY: outY,
    outW: outW,
    outH: outH,
    fullWidth: fullWidth,
    fullHeight: fullHeight,
    spec: spec,
    layers: _mapLayers(layers, maskGroups),
  );

  /// Histogram binned from the **cached** base inside Rust — zero pixels
  /// cross the bridge (spike A). Errors if [previewBase] hasn't run yet.
  static Future<rust_hist.Histogram> previewHistogram(
    int handle, {
    required GradeSpec spec,
    int sampleDim = 256,
  }) => rust_preview.previewHistogram(
    handle: BigInt.from(handle),
    params: _colorParams(spec),
    sampleDim: sampleDim,
    curves: _curveParams(spec),
    hsl: spec.hsl,
  );

  /// Spike B: fuses base + [spec] grade and writes the frame straight into the
  /// platform texture bound for [handle]. **Zero pixels cross the bridge** —
  /// only the rendered size comes back. [baseChanged] lets Rust reuse its
  /// cached base on grade-only ticks. Errors when no texture is bound, which
  /// callers treat as "fall back to [previewBase]".
  static Future<rust_preview.RenderedSize> previewRender(
    int handle, {
    required PreviewBaseSpec spec,
    required List<AdjustmentLayer> layers,
    List<MaskGroup> maskGroups = const [],
    required GradeSpec grade,
    required bool baseChanged,
  }) => rust_preview.previewRender(
    handle: BigInt.from(handle),
    spec: spec,
    layers: _mapLayers(layers, maskGroups),
    retouchPatches: [],
    params: _colorParams(grade),
    curves: _curveParams(grade),
    hsl: grade.hsl,
    baseChanged: baseChanged,
  );

  // --- export ---------------------------------------------------------------

  /// Encodes already-graded RGBA as a JPEG (alpha dropped). [exif] is the
  /// source's APP1/Exif segment (from [extractExif]); it is injected verbatim so
  /// GPS/DateTaken/ISO/camera metadata survives export.
  static Future<Uint8List> encodeJpegRgba({
    required Uint8List rgba,
    required int width,
    required int height,
    int quality = 90,
    List<int> exif = const <int>[],
  }) => rust_export.encodeJpegRgba(
    rgba: rgba,
    width: width,
    height: height,
    quality: quality,
    exif: exif,
  );

  /// Extracts the source JPEG's APP1/Exif segment (empty if none).
  static Future<Uint8List> extractExif(Uint8List jpeg) =>
      rust_exif.extractExif(jpeg: jpeg);

  /// Parses comprehensive image format, dimensions, camera, lens, exposure, and GPS metadata.
  static Future<ImageMetadata> getImageMetadata(Uint8List bytes) =>
      rust_exif.getImageMetadata(bytes: bytes);

  /// Runs the whole export recipe — geometry → banded spatial → masks → grade →
  /// optional downscale → JPEG — inside Rust in a **single** call (P4), so a
  /// full-resolution export crosses the bridge once and never holds several
  /// full-size buffers at once.
  ///
  /// Pass a [cancelToken] from [exportCancelNew] to abort mid-run: returns
  /// `null` when the token fired before the JPEG was produced. The default
  /// token (0) never cancels.
  static Future<Uint8List?> exportJpegFull({
    required Uint8List rgba,
    required int width,
    required int height,
    required GradeSpec spec,
    SpatialSpec spatial = const SpatialSpec(),
    OpticsSpec optics = const OpticsSpec(),
    GeometrySpec geometry = const GeometrySpec(),
    LensBlurSpec blur = const LensBlurSpec(),
    List<AdjustmentLayer> layers = const <AdjustmentLayer>[],
    List<MaskGroup> maskGroups = const <MaskGroup>[],
    List<int> exif = const <int>[],
    rust_export.ExportBrandingSpec? branding,
    rust_export.C2paExportSpec? c2pa,
    int quality = 90,
    int? maxDim,
    int cancelToken = 0,
    int colorSpace = 0,
    bool ultraHdr = false,
    double hdrHeadroom = 2.0,
  }) async {
    final exportSpec = rust_export.ExportSpec(
      flipH: geometry.flipH,
      flipV: geometry.flipV,
      turns: geometry.rotation,
      angle: geometry.straighten,
      cropL: geometry.crop[0],
      cropT: geometry.crop[1],
      cropR: geometry.crop[2],
      cropB: geometry.crop[3],
      perspectiveX: geometry.perspectiveX,
      perspectiveY: geometry.perspectiveY,
      skewX: geometry.skewX,
      skewY: geometry.skewY,
      shadows: spatial.shadows,
      highlights: spatial.highlights,
      clarity: spatial.clarity,
      texture: spatial.texture,
      sharpen: spatial.sharpen,
      sharpenRadius: spatial.sharpenRadius,
      sharpenDetail: spatial.sharpenDetail,
      sharpenMasking: spatial.sharpenMasking,
      denoiseLuma: spatial.denoiseLuma,
      denoiseChroma: spatial.denoiseChroma,
      dehaze: spatial.dehaze,
      vignette: spatial.vignette,
      vignetteMidpoint: spatial.vignetteMidpoint,
      vignetteFeather: spatial.vignetteFeather,
      vignetteRoundness: spatial.vignetteRoundness,
      vignetteHighlights: spatial.vignetteHighlights,
      grain: spatial.grain,
      grainSize: spatial.grainSize,
      grainRoughness: spatial.grainRoughness,
      removeChromaticAberration: optics.removeChromaticAberration,
      defringePurpleAmount: optics.defringePurpleAmount,
      defringePurpleHueMin: optics.defringePurpleHueMin,
      defringePurpleHueMax: optics.defringePurpleHueMax,
      defringeGreenAmount: optics.defringeGreenAmount,
      defringeGreenHueMin: optics.defringeGreenHueMin,
      defringeGreenHueMax: optics.defringeGreenHueMax,
      profileCorrections: optics.profileCorrections,
      profileDistortion: optics.profileDistortion,
      profileVignetting: optics.profileVignetting,
      filmBloom: 0.0,
      filmBloomRadius: 0.0,
      filmBloomThreshold: 0.0,
      filmDust: 0.0,
      filmHalation: 0.0,
      filmHalationRadius: 0.0,
      filmHalationThreshold: 0.0,
      filmScratches: 0.0,
      shaderLabPreset: 0,
      shaderParam1: 0.0,
      shaderParam2: 0.0,
      shaderParam3: 0.0,
      blurEnabled: blur.enabled,
      blurAmount: blur.amount,
      blurFocalPoint: blur.focalPoint,
      blurFocalRange: blur.focalRange,
      blurBokehShape: blur.bokehShape.index,
      blurBokehBoost: blur.bokehBoost,
      quality: quality,
      maxDim: maxDim ?? 0,
      bandRows: 256,
      cancelToken: BigInt.from(cancelToken),
      colorSpace: colorSpace,
      ultraHdr: ultraHdr,
      hdrHeadroom: hdrHeadroom,
    );


    final mappedLayers = _mapLayers(layers, maskGroups);
    final colorP = _colorParams(spec);
    final curveP = _curveParams(spec);

    final result = (branding != null || c2pa != null)
        ? await rust_export.exportFullWithBranding(
            rgba: rgba,
            width: width,
            height: height,
            spec: exportSpec,
            layers: mappedLayers,
            params: colorP,
            curves: curveP,
            hsl: spec.hsl,
            exif: exif,
            branding: branding ??
                rust_export.ExportBrandingSpec(
                  enableMuseumFrame: false,
                  frameTheme: 0,
                  exifLine1: '',
                  exifLine2: '',
                  enableSignature: false,
                  signatureText: '',
                  signatureAnchor: 8,
                  signatureOpacity: 0.8,
                  signatureSizePct: 2.5,
                  enableLogo: false,
                  logoBytes: Uint8List(0),
                  logoAnchor: 8,
                  logoOpacity: 0.8,
                  logoScalePct: 10.0,
                  enableFossBadge: false,
                ),
            c2Pa: c2pa ??
                rust_export.C2paExportSpec(
                  enableC2Pa: false,
                  devicePrivateKey: Uint8List(0),
                  recipeJson: '',
                  exifSummary: '',
                ),
            retouchPatches: [],
          )
        : await rust_export.exportFull(
            rgba: rgba,
            width: width,
            height: height,
            spec: exportSpec,
            layers: mappedLayers,
            params: colorP,
            curves: curveP,
            hsl: spec.hsl,
            exif: exif,
            retouchPatches: [],
          );
    return result.cancelled ? null : result.jpeg;
  }

  /// Non-cancellable [exportJpegFull] for callers (and the reference tests)
  /// that just want the bytes. Routes through the same single-call pipeline, so
  /// preview == export by construction.
  static Future<Uint8List> exportJpeg({
    required Uint8List rgba,
    required int width,
    required int height,
    required GradeSpec spec,
    SpatialSpec spatial = const SpatialSpec(),
    OpticsSpec optics = const OpticsSpec(),
    GeometrySpec geometry = const GeometrySpec(),
    LensBlurSpec blur = const LensBlurSpec(),
    List<AdjustmentLayer> layers = const <AdjustmentLayer>[],
    List<MaskGroup> maskGroups = const <MaskGroup>[],
    List<int> exif = const <int>[],
    int quality = 90,
    int? maxDim,
    int colorSpace = 0,
    bool ultraHdr = false,
    double hdrHeadroom = 2.0,
  }) async {
    final jpeg = await exportJpegFull(
      rgba: rgba,
      width: width,
      height: height,
      spec: spec,
      spatial: spatial,
      optics: optics,
      geometry: geometry,
      blur: blur,
      layers: layers,
      maskGroups: maskGroups,
      exif: exif,
      quality: quality,
      maxDim: maxDim,
      colorSpace: colorSpace,
      ultraHdr: ultraHdr,
      hdrHeadroom: hdrHeadroom,
    );
    // Token 0 never cancels, so this is always non-null.
    return jpeg!;
  }

  /// Exports raw camera CFA samples into a lossless DNG format with injected
  /// XMP sidecar (#79).
  ///
  /// Preserves the original CFA stream verbatim via lossless compression
  /// (LJPEG-92) without demosaic or bit-depth degradation (shape (a)). Injects
  /// the non-destructive edit recipe into the TIFF ApplicationNotes tag (0x02BC).
  static Future<Uint8List> exportDng({
    required List<int> rawBytes,
    required String xmp,
  }) =>
      rust_export.exportRawDng(rawBytes: rawBytes, xmp: xmp);

  /// Creates an opaque cancel token for [exportJpegFull]. Call
  /// [exportCancelSet] to abort a running export, then [exportCancelDrop].
  static Future<int> exportCancelNew() async =>
      (await rust_export.exportCancelNew()).toInt();

  /// Signals the export running with [token] to stop at its next band boundary.
  static Future<void> exportCancelSet(int token) =>
      rust_export.exportCancelSet(token: BigInt.from(token));

  /// Releases [token]. Safe to call more than once.
  static Future<void> exportCancelDrop(int token) =>
      rust_export.exportCancelDrop(token: BigInt.from(token));

  /// Reads the engine's progress cell for [token] as permille (0..1000).
  /// Token 0 and dropped tokens report 0. Callers wanting a 0..1 fraction
  /// should use [exportProgressFraction].
  static Future<int> exportProgressGet(int token) =>
      rust_export.exportProgressGet(token: BigInt.from(token));

  /// Reads the engine's progress cell for [token] as a 0..1 fraction,
  /// suitable for `LinearProgressIndicator.value` and `ExportProgressPoller`.
  static Future<double> exportProgressFraction(int token) async =>
      (await exportProgressGet(token)) / 1000.0;
}
