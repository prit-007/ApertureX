import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../color/grade_spec.dart';
import '../color/histogram_view.dart';
import '../color/imported_lut.dart';
import '../color/lut_atlas.dart';
import '../color/lut_texture.dart';
import '../color/spatial_spec.dart';
import '../color/tat.dart';
import '../edit/muted_parameters.dart';
import '../edit/parameter.dart';
import '../edit/recipe.dart';
import '../edit/recipe_controller.dart';
import '../engine/engine.dart';
import '../engine/image_format.dart';
import '../engine/preview_texture.dart';
import '../gesture/gesture_interpreter.dart';
import 'compare_hold.dart';
import 'canvas_transform.dart';
import 'live_warp.dart';
import 'mask_peek.dart';
import 'preview_surface.dart';
import 'roi_decoder.dart';
import 'roi_overlay.dart';

/// The shared editing canvas, rendered by BOTH shells (ADR 0008 invariant).
///
/// **Gesture routing** (the fix for the classic zoom-vs-edit conflict): a single
/// scale recognizer owns the surface and routes by finger count —
///  * **1 finger** → the edit model (Snapseed shell, via [editInterpreter]) or,
///    in the Lightroom shell, pan; the Target-Adjust tool uses it too;
///  * **2+ fingers** → zoom + pan (the transform is built here);
///  * **long-press** → before/after compare; **double-tap** → reset zoom.
///
/// **Rendering**: the image is drawn **width-fit** and edge-to-edge; all chrome
/// floats above it as a HUD. Processing runs at proxy resolution with split
/// base/grade bakes (see the field docs below).
class ImageCanvas extends ConsumerStatefulWidget {
  const ImageCanvas({
    super.key,
    this.imageBytes,
    this.editInterpreter,
  });

  /// JPEG bytes of the photo being edited (null → the built-in sample).
  final Uint8List? imageBytes;

  /// When non-null, 1-finger drags are routed to this Snapseed gesture model
  /// instead of panning (Lightroom).
  final GestureInterpreter? editInterpreter;

  @override
  ConsumerState<ImageCanvas> createState() => _ImageCanvasState();
}

class _ImageCanvasState extends ConsumerState<ImageCanvas>
    with TickerProviderStateMixin {
  /// Longest side of the preview proxy. ~1.3MP for a 3:4 phone photo.
  static const int _maxPreviewDim = 1440;

  /// Preview LUT is small; export grades per-pixel exactly.
  static const int _previewLutSize = 33;

  ui.FragmentProgram? _program;
  ui.FragmentShader? _shader;
  ui.Image? _source; // proxy, unedited — for the before/after compare
  /// Handle of the decoded proxy resident in Rust (#37 spike A); all base
  /// bakes and histograms reference it instead of shuttling pixels.
  int? _previewHandle;

  ui.Image? _baseImage; // geometry + spatial + masks applied
  Uint8List? _baseRgba;
  int _baseW = 0;
  int _baseH = 0;

  /// Spike B: platform texture id when Rust writes frames straight into a
  /// Flutter `Texture` (zero pixels over the bridge). Null → spike-A
  /// return-frame + shader path. `_useTexture` is false while an imported LUT
  /// is active (the Rust render path doesn't carry an external atlas), so the
  /// shader path keeps imported-LUT support.
  int? _textureId;
  bool _useTexture = false;

  ui.Image? _lut;
  int _activeLutSize = _previewLutSize;

  bool _failed = false;
  bool _comparing = false;
  bool _editing = false;
  bool _needsReset = true;
  bool _disposed = false;
  int _bakeToken = 0;
  final ValueNotifier<bool> _busy = ValueNotifier(false);
  int? _lastBaseKey;
  int? _lastGradeKey;
  int _importedKey = 0;
  int? _tatBand;
  Timer? _debounce;

  // --- high-zoom ROI overlay (#55/#16) -------------------------------------
  // A full-width band of the ORIGINAL frame, decoded natively (never the full
  // frame) and baked with the same spatial+mask chain as the proxy, drawn over
  // it through the grading shader once the proxy would upscale.
  final RoiDecoder _roiDecoder = RoiDecoder();
  Timer? _roiDebounce;
  int _roiToken = 0;
  ui.Image? _roiImage;
  RoiOverlayPlan? _roiPlan;
  int? _roiKey; // (bandTop, bandBottom, baseKey) — skip unchanged re-runs
  Uint8List? _roiBytes; // the bytes actually loaded (widget bytes or sample)
  int _fullW = 0; // original source dims; 0 while unknown or RAW (no ROI)
  int _fullH = 0;
  Size _lastFitted = Size.zero;
  Size _lastBounds = Size.zero;
  late final AnimationController _compare;

  /// Crossfade into/out of the auto-peeking mask view (issue #27).
  late final AnimationController _maskPeek;

  // Transform (own, so it never fights the edit gestures).
  double _scale = 1;
  Offset _offset = Offset.zero;
  double _minScale = 1;
  double _startScale = 1;
  Offset _startOffset = Offset.zero;
  Offset _startFocal = Offset.zero;
  bool _multi = false;

  @override
  void initState() {
    super.initState();
    _compare = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _maskPeek = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    // Re-evaluate delivery whenever a compare/peek crossfade settles: the
    // fade runs on the shader path, idle returns to zero-copy (#54).
    _compare.addStatusListener(_onDeliveryGestureSettled);
    _maskPeek.addStatusListener(_onDeliveryGestureSettled);
    _load();
  }

  Future<void> _load() async {
    try {
      final program = await ui.FragmentProgram.fromAsset('shaders/lut.frag');
      final jpeg =
          widget.imageBytes ??
          await TesseraEngine.syntheticJpeg(width: 1024, height: 1024);
      // Original frame dims for the ROI overlay (#55): header-only, RAW
      // excluded (no region decode path for demosaiced data).
      _roiBytes = jpeg;
      if (isRawImage(jpeg)) {
        _fullW = 0;
        _fullH = 0;
      } else {
        try {
          final dims = await TesseraEngine.jpegDimensions(jpeg);
          _fullW = dims.width;
          _fullH = dims.height;
        } catch (_) {
          _fullW = 0;
          _fullH = 0;
        }
      }
      final proxy = await _decode(jpeg, maxDim: _maxPreviewDim);
      if (!mounted) {
        proxy.$1.dispose();
        return;
      }
      _program = program;
      _shader = program.fragmentShader();
      _source = proxy.$1;
      // Upload once into the Rust-resident store (#37 spike A); the pixels
      // never need to come back — every bake addresses the handle.
      final handle = await TesseraEngine.previewOpen(
        rgba: proxy.$2,
        width: proxy.$3,
        height: proxy.$4,
      );
      if (!mounted) {
        proxy.$1.dispose();
        unawaited(TesseraEngine.previewClose(handle));
        return;
      }
      _previewHandle = handle;
      // Spike B: prefer zero-copy texture delivery when the platform supports
      // it (Android). Any failure leaves `_textureId` null and we keep the
      // spike-A return-frame path.
      await _tryBindTexture(handle, proxy.$3, proxy.$4);
      _useTexture = _computeUseTexture();
      _needsReset = true;
      await _rebake(
        _renderRecipe(ref.read(recipeControllerProvider).recipe),
        baseChanged: true,
        gradeChanged: true,
      );
      if (mounted && (_baseImage != null || _useTexture)) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  /// Registers a platform texture and binds it to the resident [handle].
  /// Silent no-op on platforms without the plugin (iOS, widget tests).
  Future<void> _tryBindTexture(int handle, int width, int height) async {
    final tex = await PreviewTextureChannel.create(
      width: width,
      height: height,
    );
    if (tex == null) return;
    final bound = await PreviewTextureChannel.bind(
      textureId: tex,
      handle: handle,
    );
    if (!mounted || !bound) {
      unawaited(PreviewTextureChannel.dispose(tex));
      return;
    }
    _textureId = tex;
  }

  /// Texture delivery is used only when a texture is bound, no imported LUT
  /// is active (imported atlases are applied by `lut.frag`, not Rust), and no
  /// compare/peek crossfade is running — those fades are drawn by `lut.frag`
  /// (`blend`/`maskBlend`), which the Rust texture path doesn't carry.
  bool _computeUseTexture() => useTextureDelivery(
    textureId: _textureId,
    hasImportedLut: ref.read(importedLutProvider) != null,
    gestureActive: _gestureActive,
    roiActive: _roiImage != null,
  );

  /// Compare (issue #28) + mask-peek (issue #27) crossfades are active (or
  /// animating towards/away from rest) — delivery must stay on the shader path
  /// for the whole gesture, and flip back to zero-copy once it settles.
  bool get _gestureActive =>
      _comparing ||
      _compare.status != AnimationStatus.dismissed ||
      _maskPeek.status != AnimationStatus.dismissed;

  void _onDeliveryGestureSettled(AnimationStatus _) => _scheduleBake(
    _renderRecipe(ref.read(recipeControllerProvider).recipe),
  );

  /// Debounced (#55): re-plans the high-zoom ROI overlay after the viewport
  /// settles (pan/zoom end) or a recipe change the band must bake.
  void _scheduleRoi() {
    if (_roiBytes == null || _source == null) return;
    _roiDebounce?.cancel();
    _roiDebounce = Timer(const Duration(milliseconds: 180), _runRoi);
  }

  /// Plans, decodes (native region decode for big frames), bakes and mounts
  /// the overlay band — or clears it when the plan goes inactive. Every await
  /// is token-guarded so a newer gesture wins over stale work.
  Future<void> _runRoi() async {
    if (!mounted) return;
    final bytes = _roiBytes;
    final proxy = _source;
    if (bytes == null || proxy == null) return;
    final fitted = _lastFitted;
    final bounds = _lastBounds;
    if (fitted == Size.zero || bounds == Size.zero) return;
    final recipe = _renderRecipe(ref.read(recipeControllerProvider).recipe);

    final plan = planRoiOverlay(
      imageW: _fullW,
      imageH: _fullH,
      proxyW: proxy.width,
      fitted: fitted,
      scale: _scale,
      offset: _offset,
      viewport: bounds,
      geometryActive: roiBlockedByGeometry(recipe),
      roiSupported: _fullW > 0 && _fullH > 0,
    );
    final key = plan == null
        ? null
        : Object.hash(plan.bandTop, Object.hash(plan.bandBottom, _baseKey(recipe)));
    final hasOverlay = _roiImage != null;
    if (key == null && !hasOverlay) return;
    if (key != null && key == _roiKey && hasOverlay) return;

    final token = ++_roiToken;
    if (plan == null) {
      _roiKey = null;
      setState(() {
        _roiImage?.dispose();
        _roiImage = null;
        _roiPlan = null;
      });
      _scheduleBake(recipe); // idle → zero-copy may resume
      return;
    }

    // Geometry is gated to identity above, so the band bakes with the same
    // spec as the proxy; halo rows give the spatial chain true context.
    final spec = _baseSpec(recipe);
    final halo = await TesseraEngine.roiHalo(
      spec: spec,
      fullWidth: _fullW,
      fullHeight: _fullH,
    );
    final decodeTop = math.max(0, plan.bandTop - halo);
    final decodeBottom = math.min(_fullH, plan.bandBottom + halo);
    final band = await _roiDecoder.decodeBand(
      bytes: bytes,
      imageW: _fullW,
      imageH: _fullH,
      bandTop: decodeTop,
      bandBottom: decodeBottom,
    );
    if (!mounted || token != _roiToken) return;
    if (band == null) {
      setState(() {
        _roiImage?.dispose();
        _roiImage = null;
        _roiPlan = null;
        _roiKey = null;
      });
      _scheduleBake(recipe);
      return;
    }
    final baked = await TesseraEngine.bakeRoiBand(
      band.rgba,
      decodeTop: decodeTop,
      outTop: plan.bandTop,
      outRows: plan.bandBottom - plan.bandTop,
      fullWidth: _fullW,
      fullHeight: _fullH,
      spec: spec,
      layers: recipe.layers,
    );
    if (!mounted || token != _roiToken) return;
    final image = await _imageFrom(baked.rgba, baked.width, baked.height);
    if (!mounted || token != _roiToken) {
      image.dispose();
      return;
    }
    setState(() {
      _roiImage?.dispose();
      _roiImage = image;
      _roiPlan = plan;
      _roiKey = key;
    });
    _scheduleBake(recipe); // texture delivery must yield to the overlay pass
  }

  /// Decodes [bytes] to RGBA in a **single** pass, capping the long side at
  /// [maxDim]. Reads the header via [ui.ImageDescriptor] (no pixel decode) so
  /// the one scaled decode is sized correctly — never decodes full-res then
  /// shrinks.
  Future<(ui.Image, Uint8List, int, int)> _decode(
    Uint8List bytes, {
    int? maxDim,
  }) async {
    // RAW/DNG can't go through Flutter's codec; the Rust engine (ADR 0005)
    // demosaics + applies the camera matrix, then we downscale to the proxy.
    if (isRawImage(bytes)) return _decodeRaw(bytes, maxDim: maxDim);

    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    var tw = descriptor.width;
    var th = descriptor.height;
    if (maxDim != null) {
      final longest = math.max(tw, th);
      if (longest > maxDim) {
        final scale = maxDim / longest;
        tw = math.max(1, (tw * scale).round());
        th = math.max(1, (th * scale).round());
      }
    }
    final codec = await ui.instantiateImageCodecFromBuffer(
      buffer,
      targetWidth: tw,
      targetHeight: th,
    );
    final frame = await codec.getNextFrame();
    codec.dispose();
    descriptor.dispose();
    final image = frame.image;
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    // Copy into a tightly-packed buffer with an explicit offset+length — never
    // rely on the ByteData's backing buffer being exactly w*h*4 at offset 0.
    final pixels = Uint8List.fromList(
      data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    return (image, pixels, image.width, image.height);
  }

  /// RAW/DNG branch of [_decode]: the Rust engine demosaics + applies the
  /// camera colour matrix, then we bilinearly downscale to the proxy size.
  Future<(ui.Image, Uint8List, int, int)> _decodeRaw(
    Uint8List bytes, {
    int? maxDim,
  }) async {
    final decoded = await TesseraEngine.decodeRawRgba(bytes);
    var w = decoded.width;
    var h = decoded.height;
    var rgba = decoded.rgba;
    if (maxDim != null && math.max(w, h) > maxDim) {
      final d = await TesseraEngine.downscale(
        rgba,
        width: w,
        height: h,
        maxDim: maxDim,
      );
      rgba = d.rgba;
      w = d.width;
      h = d.height;
    }
    final image = await _imageFrom(rgba, w, h);
    return (image, rgba, w, h);
  }

  Future<ui.Image> _imageFrom(Uint8List rgba, int w, int h) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      rgba,
      w,
      h,
      ui.PixelFormat.rgba8888,
      completer.complete,
      rowBytes: w * 4,
    );
    return completer.future;
  }

  // --- change detection -----------------------------------------------------

  /// Straighten/perspective/skew are GPU-warped during editing (issue #36),
  /// so they are excluded here — a slider tick must not re-run `applyGeometry`.
  /// Export bakes the full GeometrySpec independently.
  int _baseKey(EditRecipe r) => Object.hash(
    r.rotation,
    r.flipH,
    r.flipV,
    r.shadows,
    r.highlights,
    r.clarity,
    r.texture,
    r.dehaze,
    r.vignette,
    r.grain,
    r.sharpen,
    r.denoiseLuma,
    r.denoiseChroma,
    Object.hashAll(r.crop),
    Object.hashAll(r.layers),
  );

  int _gradeKey(EditRecipe r) => Object.hash(
    r.exposure,
    r.contrast,
    r.saturation,
    r.temperature,
    r.tint,
    r.vibrance,
    r.gradeShadowHue,
    r.gradeShadowSat,
    r.gradeMidHue,
    r.gradeMidSat,
    r.gradeHighlightHue,
    r.gradeHighlightSat,
    r.masterCurve,
    r.redCurve,
    r.greenCurve,
    r.blueCurve,
    Object.hashAll(r.hsl),
  );

  /// The recipe as it should be **rendered**: muted parameters neutralised
  /// (tap-to-mute, issue #31). The stored recipe keeps its values.
  EditRecipe _renderRecipe(EditRecipe recipe) =>
      withMuted(recipe, ref.read(mutedParametersProvider));

  void _scheduleBake(EditRecipe recipe) {
    if (_program == null || _previewHandle == null) return;
    recipe = _renderRecipe(recipe);
    final imported = ref.read(importedLutProvider)?.hashCode ?? 0;
    // Switch delivery path when texture availability changes (e.g. an imported
    // LUT is selected, or a failed write dropped us to the shader path). Force
    // a full rebuild across the seam so neither path renders a stale frame.
    final useTexture = _computeUseTexture();
    final modeChanged = useTexture != _useTexture;
    _useTexture = useTexture;
    final baseChanged =
        modeChanged || _baseKey(recipe) != _lastBaseKey;
    final gradeChanged =
        modeChanged ||
        _gradeKey(recipe) != _lastGradeKey ||
        imported != _importedKey;
    if (!baseChanged && !gradeChanged) return;
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 16),
      () => _rebake(recipe, baseChanged: baseChanged, gradeChanged: gradeChanged),
    );
  }

  Future<void> _rebake(
    EditRecipe recipe, {
    required bool baseChanged,
    required bool gradeChanged,
  }) async {
    if (_program == null || _previewHandle == null) return;
    final token = ++_bakeToken;
    try {
      if (_useTexture) {
        // Zero-copy: Rust bakes base + grade and writes the bound texture; no
        // pixels cross the bridge. Histogram still reads Rust's cached base.
        await _rebuildTexture(
          recipe,
          token,
          baseChanged: baseChanged,
          gradeChanged: gradeChanged,
        );
      } else {
        if (baseChanged) {
          _setBusy(true);
          await _rebuildBase(recipe, token);
        }
        if (gradeChanged) await _rebuildLut(recipe, token);
      }
      if (token != _bakeToken) return;
      await _rebuildHistogram(recipe, token);
    } finally {
      if (token == _bakeToken) _setBusy(false);
    }
  }

  /// Spike B: one Rust round trip (params in, size out) bakes base + grade
  /// straight into the platform texture. On any failure the texture is dropped
  /// and we rebuild through the return-frame path so the preview never stalls.
  PreviewBaseSpec _baseSpec(EditRecipe recipe) {
    final spatial = SpatialSpec.fromRecipe(recipe);
    return PreviewBaseSpec(
      flipH: recipe.flipH,
      flipV: recipe.flipV,
      turns: recipe.rotation,
      cropL: recipe.crop[0],
      cropT: recipe.crop[1],
      cropR: recipe.crop[2],
      cropB: recipe.crop[3],
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
    );
  }
  void _setBusy(bool value) {
    if (!_disposed) _busy.value = value;
  }

  Future<void> _rebuildBase(EditRecipe recipe, int token) async {
    final handle = _previewHandle;
    if (handle == null) return;

    final frame = await TesseraEngine.previewBase(
      handle,
      spec: _baseSpec(recipe),
      layers: recipe.layers,
    );
    final image = await _imageFrom(frame.rgba, frame.width, frame.height);
    if (!mounted || token != _bakeToken) {
      image.dispose();
      return;
    }
    setState(() {
      final dimsChanged = _baseW != frame.width || _baseH != frame.height;
      _baseImage?.dispose();
      _baseImage = image;
      _baseRgba = frame.rgba;
      _baseW = frame.width;
      _baseH = frame.height;
      _lastBaseKey = _baseKey(recipe);
      if (dimsChanged) _needsReset = true;
    });
  }

  Future<void> _rebuildLut(EditRecipe recipe, int token) async {
    final spec = GradeSpec.fromRecipe(recipe);
    final imported = ref.read(importedLutProvider);
    final ui.Image lutImage;
    final int lutSize;
    if (imported != null) {
      lutImage = await lutAtlasToImage(imported);
      lutSize = imported.size;
    } else {
      final data = await TesseraEngine.bakeLut3d(
        spec,
        size: _previewLutSize,
      );
      if (token != _bakeToken) return;
      lutImage = await lutAtlasToImage(
        LutAtlas(size: data.size, rgba: data.rgba),
      );
      lutSize = data.size;
    }
    if (!mounted || token != _bakeToken) {
      lutImage.dispose();
      return;
    }
    setState(() {
      _lut?.dispose();
      _lut = lutImage;
      _activeLutSize = lutSize;
      _lastGradeKey = _gradeKey(recipe);
      _importedKey = imported?.hashCode ?? 0;
    });
  }

  Future<void> _rebuildHistogram(EditRecipe recipe, int token) async {
    final handle = _previewHandle;
    if (handle == null) return;
    // Binned from the Rust-resident cached base (#37 spike A) — zero pixels
    // cross the bridge, so scrubbing the grade no longer re-uploads the frame.
    final histogram = await TesseraEngine.previewHistogram(
      handle,
      sampleDim: 256,
      spec: GradeSpec.fromRecipe(recipe),
    );
    if (token != _bakeToken) return;
    ref.read(histogramProvider.notifier).publish(histogram);
  }


  Future<void> _rebuildTexture(
    EditRecipe recipe,
    int token, {
    required bool baseChanged,
    required bool gradeChanged,
  }) async {
    final handle = _previewHandle;
    if (handle == null) return;
    try {
      final size = await TesseraEngine.previewRender(
        handle,
        spec: _baseSpec(recipe),
        layers: recipe.layers,
        grade: GradeSpec.fromRecipe(recipe),
        baseChanged: baseChanged,
      );
      if (!mounted || token != _bakeToken) return;
      setState(() {
        final dimsChanged = _baseW != size.width || _baseH != size.height;
        _baseW = size.width;
        _baseH = size.height;
        _lastBaseKey = _baseKey(recipe);
        _lastGradeKey = _gradeKey(recipe);
        _importedKey = 0;
        _baseRgba = null;
        if (dimsChanged) _needsReset = true;
      });
    } catch (_) {
      _dropTexture();
      if (baseChanged) await _rebuildBase(recipe, token);
      if (gradeChanged) await _rebuildLut(recipe, token);
    }
  }

  void _dropTexture() {
    final id = _textureId;
    _textureId = null;
    _useTexture = false;
    _baseRgba = null;
    if (id != null) unawaited(PreviewTextureChannel.dispose(id));
  }
  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    _compare.dispose();
    _maskPeek.dispose();
    _busy.dispose();
    _shader?.dispose();
    _source?.dispose();
    _baseImage?.dispose();
    _lut?.dispose();
    _dropTexture(); // release the platform texture (#54)
    _roiDebounce?.cancel();
    _roiToken++; // invalidate any in-flight overlay decode/bake
    _roiImage?.dispose();
    _roiImage = null;
    final handle = _previewHandle;
    if (handle != null) {
      unawaited(TesseraEngine.previewClose(handle));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(recipeControllerProvider, (previous, next) {
      if (previous?.recipe != next.recipe) {
        _scheduleBake(next.recipe);
        _scheduleRoi(); // spatial/mask changes must re-bake the overlay band
      }
    });
    ref.listen(
      importedLutProvider,
      (_, _) => _scheduleBake(ref.read(recipeControllerProvider).recipe),
    );
    // Toggling a mute re-renders with that parameter neutralised.
    ref.listen(
      mutedParametersProvider,
      (_, _) => _scheduleBake(ref.read(recipeControllerProvider).recipe),
    );
    // Auto-peeking mask view (issue #27): crossfade while a detail slider is
    // held, back to the graded image on release.
    ref.listen(maskPeekProvider, (previous, next) {
      if (previous == next) return;
      if (next) {
        _maskPeek.forward();
      } else {
        _maskPeek.reverse();
      }
      // The crossfade only renders on the shader path — switch delivery for
      // the gesture and back (#54).
      _scheduleBake(_renderRecipe(ref.read(recipeControllerProvider).recipe));
    });
    // Before/after compare: long-press on the photo or the panel's Compare
    // button both drive the same flag (issue #28).
    ref.listen(compareHoldProvider, (previous, next) {
      if (previous == next) return;
      setState(() => _comparing = next);
      if (next) {
        _compare.forward();
      } else {
        _compare.reverse();
      }
      _scheduleBake(_renderRecipe(ref.read(recipeControllerProvider).recipe));
    });

    final program = _program;
    final shader = _shader;
    final source = _baseImage ?? _source;
    final lut = _lut;
    final zeroCopy = _useTexture && _textureId != null;
    // Texture delivery never bakes `lut`/`base` images, so requiring them
    // would pin the viewport to the placeholder forever (#54).
    if (previewNeedsPlaceholder(
      failed: _failed,
      hasProgram: program != null,
      hasShader: shader != null,
      hasSource: source != null,
      hasLut: lut != null,
      useTexture: zeroCopy,
    )) {
      return _placeholder();
    }
    // The gate above proved the shader-path inputs (it only passes texture
    // mode without a LUT); the `!`s feed definite-assignment analysis.
    final fragShader = shader!;
    final proxySource = source!;

    final tat = ref.watch(tatModeProvider);
    final tatComponent = ref.watch(tatComponentProvider);
    // Warp params no longer schedule a CPU bake (issue #36), so rebuild the
    // Transform directly when they move.
    ref.watch(
      recipeControllerProvider.select(
        (s) => Object.hash(
          s.recipe.straighten,
          Object.hash(
            s.recipe.perspectiveX,
            Object.hash(
              s.recipe.perspectiveY,
              Object.hash(s.recipe.skewX, s.recipe.skewY),
            ),
          ),
        ),
      ),
    );
    // The texture frame carries its own (possibly cropped/rotated) dimensions;
    // fall back to the proxy source until the first render reports them.
    final content = zeroCopy && _baseW > 0 && _baseH > 0
        ? Size(_baseW.toDouble(), _baseH.toDouble())
        : Size(source.width.toDouble(), source.height.toDouble());

    return LayoutBuilder(
      builder: (context, constraints) {
        final bounds = constraints.biggest;
        final fitted = _widthFit(content, bounds);
        // Remembered for the ROI overlay planner (#55) — it runs after the
        // viewport settles, outside this build.
        _lastFitted = fitted;
        _lastBounds = bounds;
        // Publish the view transform so overlays outside this widget (the
        // selective-editing nodes, issue #25) can map image ↔ screen.
        _publishTransform(CanvasTransform(fitted: fitted, offset: _offset, scale: _scale));
        if (_needsReset) {
          _needsReset = false;
          _minScale = math.min(1.0, bounds.height / fitted.height);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _resetView(fitted, bounds));
          });
        }

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onScaleStart: (d) => _onScaleStart(d, fitted, tat),
                onScaleUpdate: (d) => _onScaleUpdate(d, fitted, bounds, tat),
                onScaleEnd: (_) => _onScaleEnd(),
                onDoubleTap: () => _resetView(fitted, bounds),
                onLongPressStart: (_) =>
                    ref.read(compareHoldProvider.notifier).hold(),
                onLongPressEnd: (_) =>
                    ref.read(compareHoldProvider.notifier).release(),
                onLongPressCancel: () =>
                    ref.read(compareHoldProvider.notifier).release(),
                child: ClipRect(
                    child: Transform(
                      alignment: Alignment.center,
                      transform: _computeLiveWarp(
                        ref.read(recipeControllerProvider).recipe,
                        content,
                      ),
                      child: Transform(
                        alignment: Alignment.topLeft,
                        transform: Matrix4.identity()
                          ..translateByDouble(_offset.dx, _offset.dy, 0, 1)
                          ..scaleByDouble(_scale, _scale, _scale, 1),
                        child: SizedBox(
                          width: fitted.width,
                          height: fitted.height,
                        child: AnimatedBuilder(
                          animation: Listenable.merge([_compare, _maskPeek]),
                          builder: (context, _) {
                            // High-zoom ROI overlay (#55): the baked band
                            // strip, drawn over the proxy through the shader.
                            final overlayImage = _roiImage;
                            final overlayRect =
                                overlayImage != null &&
                                    _roiPlan != null &&
                                    _fullH > 0
                                ? roiStripRect(
                                    _roiPlan!,
                                    fullHeight: _fullH,
                                    fitted: fitted,
                                  )
                                : null;
                            return PreviewSurface(
                              // Issue #54: actually display the texture Rust is
                              // writing into; the shader paint is the fallback
                              // (imported LUTs, iOS/tests, compare/peek fades,
                              // ROI overlay).
                              textureId: zeroCopy ? _textureId : null,
                              fallback: (_) => CustomPaint(
                                size: fitted,
                                painter: _CanvasPainter(
                                  shader: fragShader,
                                  source: proxySource,
                                  // Only ever built when `!zeroCopy`, where the
                                  // placeholder gate proved the LUT exists.
                                  lut: lut!,
                                  lutSize: _activeLutSize.toDouble(),
                                  dst: Offset.zero & fitted,
                                  blend: _compare.value,
                                  maskBlend: _maskPeek.value,
                                  overlay: overlayImage,
                                  overlayRect: overlayRect,
                                ),
                              ),
                            );
                          },
                        ),
                        ),
                      ),
                    ),

                ),
              ),
            ),
            if (tat && _tatBand != null)
              Positioned(
                top: 8,
                left: 8,
                child: IgnorePointer(
                  child: _Chip(
                    text:
                        'Target: ${_bandNames[_tatBand!]} · '
                        '${tatComponentLabels[tatComponent]}',
                  ),
                ),
              ),
            if (_comparing)
              const Positioned(
                top: 8,
                right: 8,
                child: IgnorePointer(child: _Badge(text: 'BEFORE')),
              ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ValueListenableBuilder<bool>(
                valueListenable: _busy,
                builder: (context, busy, _) => busy
                    ? LinearProgressIndicator(
                        minHeight: 2,
                        backgroundColor: Colors.transparent,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        );
      },
    );
  }

  /// GPU preview of straighten/perspective/skew (issue #36), with the
  /// auto-crop scale folded in so the rotation never reveals empty corners.
  Matrix4 _computeLiveWarp(EditRecipe r, Size content) {
    final m = calculateLiveGeometry(
      straightenAngle: r.straighten,
      perspectiveX: r.perspectiveX,
      perspectiveY: r.perspectiveY,
      skewX: r.skewX,
      skewY: r.skewY,
    );
    if (r.straighten == 0) return m;
    final scale = calculateAutoCropScale(
      r.straighten * math.pi / 180,
      content.width,
      content.height,
    );
    return m.scaledByDouble(scale, scale, 1, 1);
  }

  void _onScaleStart(ScaleStartDetails d, Size fitted, bool tat) {
    _startScale = _scale;
    _startOffset = _offset;
    _startFocal = d.localFocalPoint;
    _multi = d.pointerCount >= 2;
    _editing = false;
    if (_multi) return;
    if (tat) {
      _tatTouch(d.localFocalPoint, fitted);
    } else if (widget.editInterpreter != null) {
      widget.editInterpreter!.onPanStart(d.localFocalPoint);
      _editing = true;
    }
  }

  void _onScaleUpdate(
    ScaleUpdateDetails d,
    Size fitted,
    Size bounds,
    bool tat,
  ) {
    if (d.pointerCount >= 2 || _multi) {
      if (!_multi) {
        // Transition 1 -> 2 fingers: cancel the edit (no tap-reset) and
        // re-anchor so the pinch doesn't jump.
        if (_editing) {
          widget.editInterpreter?.cancel();
          _editing = false;
        }
        _multi = true;
        _startScale = _scale;
        _startOffset = _offset;
        _startFocal = d.localFocalPoint;
      }
      final scale = (_startScale * d.scale).clamp(_minScale, _maxScale);
      final scene = (_startFocal - _startOffset) / _startScale;
      final offset = d.localFocalPoint - scene * scale;
      setState(() {
        _scale = scale;
        _offset = _clampOffset(offset, scale, fitted, bounds);
      });
      return;
    }
    if (_multi) return;
    if (tat) {
      _tatAdjust(d.localFocalPoint, d.focalPointDelta, fitted);
    } else if (_editing) {
      widget.editInterpreter!.onPanUpdate(d.focalPointDelta);
    } else {
      setState(() {
        _offset = _clampOffset(
          _offset + d.focalPointDelta,
          _scale,
          fitted,
          bounds,
        );
      });
    }
  }

  void _onScaleEnd() {
    if (_editing) widget.editInterpreter?.onPanEnd();
    _editing = false;
    _multi = false;
    // Releasing the photo ends the gesture-shell mask peek (#27).
    ref.read(maskPeekProvider.notifier).set(false);
    // The viewport settled → maybe a sharp band replaces the upscaled proxy.
    _scheduleRoi();
  }

  static const double _maxScale = 8;

  Offset _toScene(Offset viewport) => (viewport - _offset) / _scale;

  Offset _clampOffset(Offset o, double scale, Size fitted, Size bounds) {
    final cw = fitted.width * scale;
    final ch = fitted.height * scale;
    final cx = cw <= bounds.width
        ? (bounds.width - cw) / 2
        : o.dx.clamp(bounds.width - cw, 0.0);
    final cy = ch <= bounds.height
        ? (bounds.height - ch) / 2
        : o.dy.clamp(bounds.height - ch, 0.0);
    return Offset(cx, cy);
  }

  /// The width-fit display size of [content] within [bounds].
  static Size _widthFit(Size content, Size bounds) {
    if (content.width <= 0 || bounds.width <= 0) return bounds;
    return Size(bounds.width, bounds.width * content.height / content.width);
  }

  /// Hands the current view to [canvasTransformProvider], deferred to a
  /// microtask so a widget build never mutates another provider
  /// synchronously; the write is skipped when the value is unchanged.
  void _publishTransform(CanvasTransform next) {
    Future.microtask(() {
      if (!mounted) return;
      if (ref.read(canvasTransformProvider) == next) return;
      ref.read(canvasTransformProvider.notifier).set(next);
    });
  }

  void _resetView(Size fitted, Size bounds) {
    _scale = 1;
    _offset = Offset(
      0,
      fitted.height < bounds.height ? (bounds.height - fitted.height) / 2 : 0,
    );
  }

  static const List<String> _bandNames = [
    'Red',
    'Orange',
    'Yellow',
    'Green',
    'Aqua',
    'Blue',
    'Purple',
    'Magenta',
  ];

  int? _bandAt(Offset viewportLocal, Size fitted) {
    final rgba = _baseRgba;
    if (rgba == null || _baseW == 0 || fitted.width == 0 || fitted.height == 0) {
      return null;
    }
    final scene = _toScene(viewportLocal);
    final fx = (scene.dx / fitted.width).clamp(0.0, 1.0);
    final fy = (scene.dy / fitted.height).clamp(0.0, 1.0);
    if (scene.dx < 0 || scene.dy < 0) return null;
    final x = (fx * _baseW).clamp(0, _baseW - 1).toInt();
    final y = (fy * _baseH).clamp(0, _baseH - 1).toInt();
    final i = (y * _baseW + x) * 4;
    if (i + 2 >= rgba.length) return null;
    return nearestHslBand(hueOf(rgba[i], rgba[i + 1], rgba[i + 2]));
  }

  void _tatTouch(Offset local, Size fitted) {
    final band = _bandAt(local, fitted);
    if (band != null && band != _tatBand) setState(() => _tatBand = band);
  }

  void _tatAdjust(Offset local, Offset delta, Size fitted) {
    final band = _bandAt(local, fitted) ?? _tatBand;
    if (band == null) return;
    if (band != _tatBand) setState(() => _tatBand = band);
    final notifier = ref.read(recipeControllerProvider.notifier);
    final recipe = ref.read(recipeControllerProvider).recipe;
    final amount = (delta.dx / fitted.width) * 2;
    switch (ref.read(tatComponentProvider)) {
      case 0:
        notifier.setHsl(band, hue: recipe.hsl[band * 3] + amount);
      case 1:
        notifier.setHsl(band, saturation: recipe.hsl[band * 3 + 1] + amount);
      default:
        notifier.setHsl(band, luminance: recipe.hsl[band * 3 + 2] + amount);
    }
  }

  Widget _placeholder() {
    final scheme = Theme.of(context).colorScheme;
    if (_failed) {
      return ColoredBox(
        color: scheme.surfaceContainerLowest,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.broken_image_outlined,
                color: scheme.onSurfaceVariant,
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                'Preview unavailable',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }
    return ColoredBox(
      color: scheme.surfaceContainerLowest,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading image…',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xCC000000),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: scheme.onPrimary,
          fontSize: 12,
          letterSpacing: 1.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Draws the base texture through `lut.frag` inside the aspect-correct [dst]
/// rect, sampling the packed 3D LUT atlas, and crossfades to the raw source
/// while comparing ([blend] 0..1).
class _CanvasPainter extends CustomPainter {
  _CanvasPainter({
    required this.shader,
    required this.source,
    required this.lut,
    required this.lutSize,
    required this.dst,
    required this.blend,
    required this.maskBlend,
    this.overlay,
    this.overlayRect,
  });

  final ui.FragmentShader shader;
  final ui.Image source;
  final ui.Image lut;
  final double lutSize;
  final Rect dst;
  final double blend;
  final double maskBlend;

  /// High-zoom ROI band (#55): baked full-width strip of the original frame,
  /// drawn through the same uniforms over the proxy at [overlayRect] (world
  /// coords). Null while the overlay is inactive.
  final ui.Image? overlay;
  final Rect? overlayRect;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(const Color(0xFF000000), BlendMode.src);

    shader
      ..setFloat(0, dst.width)
      ..setFloat(1, dst.height)
      ..setFloat(2, lutSize)
      ..setFloat(3, maskBlend)
      ..setFloat(4, source.width.toDouble())
      ..setFloat(5, source.height.toDouble())
      ..setImageSampler(0, source)
      ..setImageSampler(1, lut);
    canvas.drawRect(dst, Paint()..shader = shader);

    if (blend > 0) {
      canvas.drawImageRect(
        source,
        Rect.fromLTWH(0, 0, source.width.toDouble(), source.height.toDouble()),
        dst,
        Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: blend),
      );
    }

    final ov = overlay;
    final ovRect = overlayRect;
    if (ov != null && ovRect != null) {
      // Translate so the band strip's own rect is the shader's local origin —
      // `FlutterFragCoord` is local-canvas space, so uSize covers the strip
      // exactly, mirroring the proxy pass (which draws at the content origin).
      canvas.save();
      canvas.clipRect(Offset.zero & size);
      canvas.translate(ovRect.left, ovRect.top);
      shader
        ..setFloat(0, ovRect.width)
        ..setFloat(1, ovRect.height)
        ..setFloat(2, lutSize)
        ..setFloat(3, maskBlend)
        ..setFloat(4, ov.width.toDouble())
        ..setFloat(5, ov.height.toDouble())
        ..setImageSampler(0, ov)
        ..setImageSampler(1, lut);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, ovRect.width, ovRect.height),
        Paint()..shader = shader,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_CanvasPainter old) =>
      old.source != source ||
      old.lut != lut ||
      old.blend != blend ||
      old.dst != dst ||
      old.overlay != overlay ||
      old.overlayRect != overlayRect;
}
