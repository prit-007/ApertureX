import 'dart:typed_data';

import '../color/grade_spec.dart';
import '../color/spatial_spec.dart';
import '../edit/adjustment_layer.dart';
import '../edit/geometry_spec.dart';
import '../src/rust/api/color.dart' as rust_color;
import '../src/rust/api/decode.dart' show ImageDims, RgbaImage;
import '../src/rust/api/decode.dart' as rust_decode;
import '../src/rust/api/engine.dart' as rust_engine;
import '../src/rust/api/exif.dart' as rust_exif;
import '../src/rust/api/export.dart' as rust_export;
import '../src/rust/api/geometry.dart' as rust_geometry;
import '../src/rust/api/histogram.dart' as rust_hist;
import '../src/rust/api/icc.dart' as rust_icc;
import '../src/rust/api/mask.dart' as rust_mask;
import '../src/rust/api/preview.dart' as rust_preview;
import '../src/rust/api/preview.dart' show PreviewBaseSpec;
import '../src/rust/api/raw.dart' as rust_raw;
import '../src/rust/api/spatial.dart' as rust_spatial;
import '../src/rust/frb_generated.dart';

export '../src/rust/api/color.dart' show LutData;
export '../src/rust/api/decode.dart' show ImageDims, RgbaImage;
export '../src/rust/api/histogram.dart' show Histogram;
export '../src/rust/api/preview.dart' show PreviewBaseSpec;
export '../src/rust/frb_generated.dart' show RustLib;

/// Thin, app-facing facade over the generated `flutter_rust_bridge` bindings.
///
/// Keeping the generated `src/rust/` package behind this wrapper means the rest
/// of the app depends on our own names, not on codegen symbols.
class TesseraEngine {
  const TesseraEngine._();

  /// Initialises the Rust library. Must be awaited before any engine call.
  static Future<void> init() => RustLib.init();

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

  // --- colour / 3D LUT (P2 Slice D) -----------------------------------------

  static rust_color.ColorParams _colorParams(GradeSpec s) =>
      rust_color.ColorParams(
        exposure: s.exposure,
        contrast: s.contrast,
        saturation: s.saturation,
        temperature: s.temperature,
        tint: s.tint,
        vibrance: s.vibrance,
        gradeShadowHue: s.gradeShadowHue,
        gradeShadowSat: s.gradeShadowSat,
        gradeMidHue: s.gradeMidHue,
        gradeMidSat: s.gradeMidSat,
        gradeHighlightHue: s.gradeHighlightHue,
        gradeHighlightSat: s.gradeHighlightSat,
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
    denoiseLuma: spec.denoiseLuma,
    denoiseChroma: spec.denoiseChroma,
    dehaze: spec.dehaze,
    vignette: spec.vignette,
    grain: spec.grain,
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

  // --- masking / local adjustments (P2.5) -----------------------------------

  static rust_color.ColorParams _localParams(AdjustmentLayer l) =>
      rust_color.ColorParams(
        exposure: l.exposure,
        contrast: l.contrast,
        saturation: l.saturation,
        temperature: l.temperature,
        tint: l.tint,
        vibrance: 0,
        gradeShadowHue: 0,
        gradeShadowSat: 0,
        gradeMidHue: 0,
        gradeMidSat: 0,
        gradeHighlightHue: 0,
        gradeHighlightSat: 0,
      );

  /// Composites local adjustment [layers] over [rgba] (masks + sub-grades).
  static Future<Uint8List> applyMasks(
    Uint8List rgba, {
    required int width,
    required int height,
    required List<AdjustmentLayer> layers,
  }) {
    if (layers.isEmpty) return Future.value(rgba);
    return rust_mask.applyMasks(
      rgba: rgba,
      width: width,
      height: height,
      layers: [
        for (final l in layers)
          rust_mask.MaskLayer(
            kind: l.maskKind.index,
            mask: Float32List.fromList(l.maskParams),
            params: _localParams(l),
          ),
      ],
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
  }) => rust_preview.previewBase(
    handle: BigInt.from(handle),
    spec: spec,
    layers: [
      for (final l in layers)
        rust_mask.MaskLayer(
          kind: l.maskKind.index,
          mask: Float32List.fromList(l.maskParams),
          params: _localParams(l),
        ),
    ],
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
    required GradeSpec grade,
    required bool baseChanged,
  }) => rust_preview.previewRender(
    handle: BigInt.from(handle),
    spec: spec,
    layers: [
      for (final l in layers)
        rust_mask.MaskLayer(
          kind: l.maskKind.index,
          mask: Float32List.fromList(l.maskParams),
          params: _localParams(l),
        ),
    ],
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
    GeometrySpec geometry = const GeometrySpec(),
    List<AdjustmentLayer> layers = const <AdjustmentLayer>[],
    List<int> exif = const <int>[],
    int quality = 90,
    int? maxDim,
    int cancelToken = 0,
  }) async {
    final result = await rust_export.exportFull(
      rgba: rgba,
      width: width,
      height: height,
      spec: rust_export.ExportSpec(
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
        denoiseLuma: spatial.denoiseLuma,
        denoiseChroma: spatial.denoiseChroma,
        dehaze: spatial.dehaze,
        vignette: spatial.vignette,
        grain: spatial.grain,
        quality: quality,
        maxDim: maxDim ?? 0,
        bandRows: 256,
        cancelToken: BigInt.from(cancelToken),
      ),
      layers: [
        for (final l in layers)
          rust_mask.MaskLayer(
            kind: l.maskKind.index,
            mask: Float32List.fromList(l.maskParams),
            params: _localParams(l),
          ),
      ],
      params: _colorParams(spec),
      curves: _curveParams(spec),
      hsl: spec.hsl,
      exif: exif,
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
    GeometrySpec geometry = const GeometrySpec(),
    List<AdjustmentLayer> layers = const <AdjustmentLayer>[],
    List<int> exif = const <int>[],
    int quality = 90,
    int? maxDim,
  }) async {
    final jpeg = await exportJpegFull(
      rgba: rgba,
      width: width,
      height: height,
      spec: spec,
      spatial: spatial,
      geometry: geometry,
      layers: layers,
      exif: exif,
      quality: quality,
      maxDim: maxDim,
    );
    // Token 0 never cancels, so this is always non-null.
    return jpeg!;
  }

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
}
