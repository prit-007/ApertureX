import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../color/grade_spec.dart';
import '../color/histogram_view.dart';
import '../color/imported_lut.dart';
import '../color/lut_atlas.dart';
import '../color/lut_texture.dart';
import '../color/tat.dart';
import '../edit/muted_parameters.dart';
import '../edit/parameter.dart';
import '../edit/recipe.dart';
import '../edit/recipe_controller.dart';
import '../engine/engine.dart';
import '../engine/image_format.dart';
import '../engine/preview_texture.dart';
import '../core/haptics.dart';
import '../gesture/gesture_interpreter.dart';
import '../gesture/zone_mask.dart';
import 'compare_hold.dart';
import 'base_spec.dart';
import 'change_keys.dart';
import 'wiper_compare.dart';
import 'exposure_assist.dart';
import 'canvas_transform.dart';
import 'exif_orientation.dart';
import 'live_warp.dart';
import 'mask_peek.dart';
import 'preview_surface.dart';
import 'roi_decoder.dart';
import 'roi_overlay.dart';
import 'shader_warmup.dart';
import 'tile_grid.dart';
import 'tile_lru.dart';

/// The contain-fit display size of [content] within [bounds]: the largest
/// size at which the whole content is visible with its aspect preserved.
/// (Top-level so unit tests can pin the behaviour directly.)
Size fitContained(Size content, Size bounds) {
  if (content.width <= 0 || content.height <= 0) return bounds;
  if (bounds.width <= 0 || bounds.height <= 0) return bounds;
  final scale = math.min(
    bounds.width / content.width,
    bounds.height / content.height,
  );
  return Size(content.width * scale, content.height * scale);
}

/// The shared editing canvas, rendered by BOTH shells (ADR 0008 invariant).
///
/// **Gesture routing** (the fix for the classic zoom-vs-edit conflict): a single
/// scale recognizer owns the surface and routes by finger count —
///  * **1 finger** → the edit model (Snapseed shell, via [editInterpreter]) or,
///    in the Lightroom shell, pan; the Target-Adjust tool uses it too;
///  * **2+ fingers** → zoom + pan (the transform is built here);
///  * **long-press** → before/after compare; **double-tap** → reset zoom.
///
/// **Rendering**: the image is drawn **contain-fit** (the whole photo is
/// always visible, centred, aspect preserved — Lightroom-style) and the chrome
/// floats above it as a HUD. Processing runs at proxy resolution with split
/// base/grade bakes (see the field docs below).
class ImageCanvas extends ConsumerStatefulWidget {
  const ImageCanvas({
    super.key,
    this.imageBytes,
    this.editInterpreter,
    this.onTap,
  });

  /// JPEG bytes of the photo being edited (null → the built-in sample).
  final Uint8List? imageBytes;

  /// When non-null, 1-finger drags are routed to this Snapseed gesture model
  /// instead of panning (Lightroom).
  final GestureInterpreter? editInterpreter;

  /// Tapping the canvas toggles Immersive Mode (dissolving HUD chrome).
  final VoidCallback? onTap;

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
  Timer? _histogramDebounce;
  bool _baking = false;
  EditRecipe? _pendingRecipe;
  bool _pendingBaseChanged = false;
  bool _pendingGradeChanged = false;

  // --- high-zoom tiles (#16) ----------------------------------------------
  // Level-0 tiles of the ORIGINAL frame, decoded natively (never the full
  // frame), baked with the same spatial+mask chain as the proxy through
  // `bake_roi_rect`, and drawn over the proxy through the grading shader
  // once the proxy would upscale. The multi-level pyramid stays wired for the
  // `TileViewport` demo/corpus harness; the editing canvas uses level 0 only,
  // because the proxy itself already covers every zoom below the ROI gate
  // (`scale * fitted.width >= proxyW`).
  static const int _tileSize = 512;

  /// Decoded-tile cache budget. A 512×512 RGBA tile is 1 MiB; 64 tiles is
  /// comfortably more than one screenful at the worst zoom.
  static const int _tileBudgetBytes = 64 << 20;

  final RoiDecoder _roiDecoder = RoiDecoder();
  final TileLru<TileCoord, ui.Image> _tiles = TileLru<TileCoord, ui.Image>(
    maxBytes: _tileBudgetBytes,
    sizeOf: (img) => img.width * img.height * 4,
    onEvict: (_, img) => img.dispose(),
  );
  Timer? _roiDebounce;
  int _roiToken = 0;
  Uint8List? _roiBytes; // the bytes actually loaded (widget bytes or sample)
  int _fullW = 0; // original source dims; 0 while unknown or RAW (no ROI)
  int _fullH = 0;
  /// Level-0 tile grid once the full-res dims are known; null → no tiles.
  TileGrid? _tileGrid;
  /// Key of the spatial/mask recipe the cached tiles were baked with; any
  /// other change (including the first tile schedule) re-bakes. Grade-only
  /// edits don't invalidate — the shader picks up the new LUT on repaint.
  int? _tileBaseKey;
  /// True while any tile is decoding/baking — the painter shows the proxy
  /// underneath until the first tiles land, and `useTextureDelivery` stays
  /// off so the shader path (which draws the tiles) is live.
  bool _tilesActive = false;
  Size _lastFitted = Size.zero;
  Size _lastBounds = Size.zero;
  late final AnimationController _compare;

  /// Crossfade into/out of the auto-peeking mask view (issue #27).
  late final AnimationController _maskPeek;

  /// Continuous ticker for animated zebra peaking stripes (Issue #98).
  late final AnimationController _zebraTicker;

  // Transform (own, so it never fights the edit gestures).
  double _scale = 1;
  Offset _offset = Offset.zero;
  double _minScale = 1;
  double _startScale = 1;
  Offset _startOffset = Offset.zero;
  Offset _startFocal = Offset.zero;
  bool _multi = false;
  bool _zoneTargeting = false;
  bool _wiperDragging = false;

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
    _zebraTicker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    // Re-evaluate delivery whenever a compare/peek crossfade settles: the
    // fade runs on the shader path, idle returns to zero-copy (#54).
    _compare.addStatusListener(_onDeliveryGestureSettled);
    _maskPeek.addStatusListener(_onDeliveryGestureSettled);
    _load();
  }

  Future<void> _load() async {
    try {
      // Shared, warm-on-startup program (#72): awaiting the provider skips
      // the first-open compile the splash already paid for.
      final program = await ref.read(lutProgramProvider.future);
      final jpeg =
          widget.imageBytes ??
          await AxEngine.syntheticJpeg(width: 1024, height: 1024);
      // Original frame dims for the ROI overlay (#55): header-only, RAW
      // excluded (no region decode path for demosaiced data).
      _roiBytes = jpeg;
      if (isRawImage(jpeg)) {
        _fullW = 0;
        _fullH = 0;
        _tileGrid = null;
      } else {
        try {
          final dims = await AxEngine.jpegDimensions(jpeg);
          _fullW = dims.width;
          _fullH = dims.height;
          _tileGrid = TileGrid(
            imageWidth: _fullW,
            imageHeight: _fullH,
            tileSize: _tileSize,
          );
        } catch (_) {
          _fullW = 0;
          _fullH = 0;
          _tileGrid = null;
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
      final handle = await AxEngine.previewOpenJpeg(
        jpegBytes: jpeg,
        maxDim: _maxPreviewDim,
      );
      if (!mounted) {
        unawaited(AxEngine.previewClose(handle));
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
  ///
  /// Modern Android HardwareBuffer-backed `SurfaceProducer` allocations introduce
  /// row/stride padding that causes vertical stretching in Flutter's `Texture` widget
  /// (the "stretched image" bug). The Impeller 3D LUT fragment-shader pipeline
  /// renders with exact aspect ratio at 120 FPS, matching the compare view 1:1.
  /// We yield to the aspect-accurate shader pipeline to guarantee zero stretch.
  Future<void> _tryBindTexture(int handle, int width, int height) async {
    return;
  }

  /// Texture delivery is used only when a texture is bound, no imported LUT
  /// is active (imported atlases are applied by `lut.frag`, not Rust), no
  /// compare/peek crossfade is running — those fades are drawn by `lut.frag`
  /// (`blend`/`maskBlend`), which the Rust texture path doesn't carry — no
  /// high-zoom tiles are overlaying the proxy, and recipe geometry is
  /// identity. The geometry gate is required because HardwareBuffer-backed
  /// `SurfaceProducer`s ignore `setBuffersGeometry`, so a cropped/rotated
  /// frame written into the proxy buffer would be stretched to the wrong
  /// aspect by Flutter (see `useTextureDelivery`).
  bool _computeUseTexture() {
    final recipe = ref.read(recipeControllerProvider).recipe;
    return useTextureDelivery(
      textureId: _textureId,
      hasImportedLut: ref.read(importedLutProvider) != null,
      gestureActive: _gestureActive,
      roiActive: _tilesActive,
      geometryActive: roiBlockedByGeometry(recipe),
    );
  }

  /// Compare (issue #28) + mask-peek (issue #27) crossfades are active (or
  /// animating towards/away from rest) — delivery must stay on the shader path
  /// for the whole gesture, and flip back to zero-copy once it settles.
  bool get _gestureActive =>
      _comparing ||
      _compare.status != AnimationStatus.dismissed ||
      _maskPeek.status != AnimationStatus.dismissed ||
      ref.read(zoneMaskProvider).isTargeting ||
      ref.read(wiperCompareProvider).isActive ||
      ref.read(exposureAssistProvider).isActive;

  void _onDeliveryGestureSettled(AnimationStatus _) => _scheduleBake(
    _renderRecipe(ref.read(recipeControllerProvider).recipe),
  );

  /// Debounced (#16): re-plans the high-zoom tiles after the viewport settles
  /// (pan/zoom end) or a spatial/mask recipe change the tiles must re-bake.
  void _scheduleRoi() {
    if (_roiBytes == null || _source == null) return;
    _roiDebounce?.cancel();
    _roiDebounce = Timer(const Duration(milliseconds: 60), _runRoi);
  }

  /// Fetches (native region decode), bakes and caches the level-0 tiles whose
  /// world rect intersects the visible region — or tears the overlay down when
  /// the plan goes inactive. Every await is token-guarded so a newer gesture
  /// wins over stale work; the LRU disposes evicted images.
  ///
  /// Tiles are level-0 only: the proxy already covers every zoom below the
  /// ROI gate (`scale * fitted.width >= proxyW`), so a coarser level would
  /// duplicate what the proxy already shows. Geometry is gated to identity by
  /// the same check the band path used, so each tile bakes with the proxy's
  /// spec plus a full halo on all four sides.
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
    if (plan == null) {
      if (!_tilesActive && _tiles.length == 0) return;
      ++_roiToken; // invalidate in-flight fetches/bakes
      setState(() {
        _tiles.clear();
        _tileBaseKey = null;
        _tilesActive = false;
      });
      _scheduleBake(recipe); // idle → zero-copy may resume
      return;
    }

    final grid = _tileGrid;
    if (grid == null || fitted.width <= 0 || fitted.height <= 0) return;
    final scaleToImageX = _fullW / fitted.width;
    final scaleToImageY = _fullH / fitted.height;
    final imagePixelRect = Rect.fromLTWH(
      plan.dstRect.left * scaleToImageX,
      plan.dstRect.top * scaleToImageY,
      plan.dstRect.width * scaleToImageX,
      plan.dstRect.height * scaleToImageY,
    );
    final visible = grid.visibleTiles(imagePixelRect);

    final baseKey = _baseKey(recipe);
    final spatialChanged = _tileBaseKey != baseKey;
    final needed = [
      for (final t in visible)
        if (spatialChanged || !_tiles.containsKey(t.coord)) t.coord,
    ];
    if (needed.isEmpty) {
      if (!_tilesActive) {
        setState(() => _tilesActive = true);
        _scheduleBake(recipe);
      }
      return;
    }

    final token = ++_roiToken;
    setState(() => _tilesActive = true);
    // Geometry is gated to identity above, so tiles bake with the same spec
    // as the proxy; the halo gives the spatial chain true context on all
    // four sides. One halo fetch covers the whole visible set.
    final spec = _baseSpec(recipe);
    final halo = await AxEngine.roiHalo(
      spec: spec,
      fullWidth: _fullW,
      fullHeight: _fullH,
    );
    if (!mounted || token != _roiToken) return;
    final baked = <TileCoord, ui.Image>{};
    for (final coord in needed) {
      if (!mounted || token != _roiToken) break;
      final tile = await _fetchTile(grid, coord, halo, spec, recipe);
      if (!mounted || token != _roiToken) {
        tile?.dispose();
        break;
      }
      if (tile != null) baked[coord] = tile;
    }
    if (!mounted || token != _roiToken) {
      for (final img in baked.values) {
        img.dispose();
      }
      return;
    }
    setState(() {
      if (spatialChanged) _tiles.clear();
      for (final e in baked.entries) {
        _tiles.put(e.key, e.value);
      }
      _tileBaseKey = baseKey;
    });
    _scheduleBake(recipe); // texture delivery must yield to the overlay pass
  }

  /// Decodes the halo-expanded rect around tile [coord] from the original
  /// frame, bakes it through the spatial+mask chain, and returns the cropped
  /// tile image — or null when the decode/bake fails.
  Future<ui.Image?> _fetchTile(
    TileGrid grid,
    TileCoord coord,
    int halo,
    PreviewBaseSpec spec,
    EditRecipe recipe,
  ) async {
    final bytes = _roiBytes;
    if (bytes == null) return null;
    final rect = grid.tileRect(coord.col, coord.row);
    final x0 = rect.left.toInt();
    final y0 = rect.top.toInt();
    final tw = rect.width.toInt();
    final th = rect.height.toInt();
    final decode = tileDecodeRect(rect, imageW: _fullW, imageH: _fullH, halo: halo);
    final dx = decode.left.toInt();
    final dy = decode.top.toInt();
    final dw = decode.width.toInt();
    final dh = decode.height.toInt();
    final src = await _roiDecoder.decodeRect(
      bytes: bytes,
      imageW: _fullW,
      imageH: _fullH,
      x: dx,
      y: dy,
      width: dw,
      height: dh,
    );
    if (src == null) return null;
    final baked = await AxEngine.bakeRoiRect(
      src.rgba,
      decodeX: dx,
      decodeY: dy,
      decodeW: dw,
      decodeH: dh,
      outX: x0,
      outY: y0,
      outW: tw,
      outH: th,
      fullWidth: _fullW,
      fullHeight: _fullH,
      spec: spec,
      layers: recipe.layers,
      maskGroups: recipe.maskGroups,
    );
    return _imageFrom(baked.rgba, baked.width, baked.height);
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
    if (isRawImage(bytes)) {
      try {
        return await _decodeRaw(bytes, maxDim: maxDim);
      } catch (_) {
        // Fall back to standard codec if Rust raw decode failed
      }
    }

    try {
    // Wide-gamut (P3) detection: if the JPEG is Display-P3 encoded, decode
    // with Rust and convert to sRGB so the preview shader sees correct colors.
    final cs = await AxEngine.detectColorspace(bytes);
    if (cs == 2) {
      final decoded = await AxEngine.decodeJpegRgba(bytes);
      final srgb = await AxEngine.p3ToSrgb(
        decoded.rgba,
        width: decoded.width,
        height: decoded.height,
      );
      final image = await _imageFrom(srgb, decoded.width, decoded.height);
      return (image, Uint8List(0), image.width, image.height);
    }

    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      final orientation = readExifOrientation(bytes);
      final target = computeDecodeTarget(
        rawWidth: descriptor.width,
        rawHeight: descriptor.height,
        orientation: orientation,
        maxDim: maxDim,
      );
      final codec = await ui.instantiateImageCodecFromBuffer(
        buffer,
        targetWidth: target.targetWidth,
        targetHeight: target.targetHeight,
      );
      final frame = await codec.getNextFrame();
      codec.dispose();
      descriptor.dispose();
      final image = frame.image;

      // Zero-copy: Rust already owns the source JPEG via previewOpenJpeg
      // (called from _load). Dart never calls image.toByteData(), avoiding
      // the synchronous GPU readback stall and 6 MB VRAM→RAM copy. The
      // shader path handles color space; P3→sRGB is applied at export time.
      return (image, Uint8List(0), image.width, image.height);
    } catch (_) {
      // If standard codec fails (e.g. uncommon raw or tiff variant), try Rust raw decoder
      return await _decodeRaw(bytes, maxDim: maxDim);
    }
  }

  /// RAW/DNG branch of [_decode]: the Rust engine demosaics + applies the
  /// camera colour matrix, then we bilinearly downscale to the proxy size.
  Future<(ui.Image, Uint8List, int, int)> _decodeRaw(
    Uint8List bytes, {
    int? maxDim,
  }) async {
    final decoded = await AxEngine.decodeRawRgba(bytes);
    var w = decoded.width;
    var h = decoded.height;
    var rgba = decoded.rgba;
    if (maxDim != null && math.max(w, h) > maxDim) {
      final d = await AxEngine.downscale(
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
  int _baseKey(EditRecipe r) => baseKeyOf(r);

  int _gradeKey(EditRecipe r) => gradeKeyOf(r);

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

    if (_baking) {
      _pendingRecipe = recipe;
      _pendingBaseChanged |= baseChanged;
      _pendingGradeChanged |= gradeChanged;
      return;
    }

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
    _baking = true;
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
      _scheduleHistogram(recipe, token);
    } finally {
      _baking = false;
      if (token == _bakeToken) _setBusy(false);
      if (_pendingRecipe != null && mounted && !_disposed) {
        final nextRecipe = _pendingRecipe!;
        final nextBase = _pendingBaseChanged;
        final nextGrade = _pendingGradeChanged;
        _pendingRecipe = null;
        _pendingBaseChanged = false;
        _pendingGradeChanged = false;
        scheduleMicrotask(() {
          if (mounted && !_disposed) {
            _rebake(nextRecipe, baseChanged: nextBase, gradeChanged: nextGrade);
          }
        });
      }
    }
  }

  /// Spike B: one Rust round trip (params in, size out) bakes base + grade
  /// straight into the platform texture. On any failure the texture is dropped
  /// and we rebuild through the return-frame path so the preview never stalls.
  PreviewBaseSpec _baseSpec(EditRecipe recipe) => baseSpecFromRecipe(recipe);
  void _setBusy(bool value) {
    if (!_disposed) _busy.value = value;
  }

  Future<void> _rebuildBase(EditRecipe recipe, int token) async {
    final handle = _previewHandle;
    if (handle == null) return;

    final frame = await AxEngine.previewBase(
      handle,
      spec: _baseSpec(recipe),
      layers: recipe.layers,
      maskGroups: recipe.maskGroups,
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
    _updatePixelSampler();
  }

  void _updatePixelSampler() {
    if (_disposed || !mounted) return;
    final rgba = _baseRgba;
    final w = _baseW;
    final h = _baseH;
    if (rgba == null || w <= 0 || h <= 0) {
      ref.read(pixelSamplerProvider.notifier).setSampler(null);
      return;
    }
    ref.read(pixelSamplerProvider.notifier).setSampler((double u, double v) {
      final x = (u * w).clamp(0, w - 1).toInt();
      final y = (v * h).clamp(0, h - 1).toInt();
      final i = (y * w + x) * 4;
      if (i + 2 >= rgba.length) return null;
      final r = rgba[i] / 255.0;
      final g = rgba[i + 1] / 255.0;
      final b = rgba[i + 2] / 255.0;
      return 0.2126 * r + 0.7152 * g + 0.0722 * b;
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
      final data = await AxEngine.bakeLut3d(
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

  /// The histogram is a non-interactive readout; recomputing it inside every
  /// 16ms scrub tick burns a Rust round trip per frame. Trailing-debounce it
  /// so it lands shortly after the recipe stops moving (and never later than
  /// ~one settle window after the last tick).
  void _scheduleHistogram(EditRecipe recipe, int token) {
    _histogramDebounce?.cancel();
    _histogramDebounce = Timer(const Duration(milliseconds: 280), () {
      if (_disposed || token != _bakeToken) return;
      _rebuildHistogram(recipe, token);
    });
  }

  Future<void> _rebuildHistogram(EditRecipe recipe, int token) async {
    final handle = _previewHandle;
    if (handle == null) return;
    // Binned from the Rust-resident cached base (#37 spike A) — zero pixels
    // cross the bridge, so scrubbing the grade no longer re-uploads the frame.
    final histogram = await AxEngine.previewHistogram(
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
      final size = await AxEngine.previewRender(
        handle,
        spec: _baseSpec(recipe),
        layers: recipe.layers,
        maskGroups: recipe.maskGroups,
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
    if (!_disposed && mounted) {
      _updatePixelSampler();
    }
    if (id != null) unawaited(PreviewTextureChannel.dispose(id));
  }
  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    _histogramDebounce?.cancel();
    _compare.dispose();
    _maskPeek.dispose();
    _zebraTicker.dispose();
    _busy.dispose();
    _shader?.dispose();
    _source?.dispose();
    _baseImage?.dispose();
    _lut?.dispose();
    _dropTexture(); // release the platform texture (#54)
    _roiDebounce?.cancel();
    _roiToken++; // invalidate any in-flight tile decode/bake
    _tiles.clear(); // disposes every cached tile image (onEvict)
    final handle = _previewHandle;
    if (handle != null) {
      unawaited(AxEngine.previewClose(handle));
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
    // Haptic Zone Masking: switch to shader path during 2-finger zone targeting
    ref.listen(zoneMaskProvider, (previous, next) {
      if (previous?.isTargeting != next.isTargeting) {
        _scheduleBake(_renderRecipe(ref.read(recipeControllerProvider).recipe));
      }
    });

    // Multi-touch pan & pinch-to-zoom forwarded by overlays (Retouch, NodeOverlay)
    ref.listen(canvasGestureProvider, (previous, next) {
      if (next == null) return;
      if (next.isStart && next.focalPoint != null) {
        _multi = true;
        _startScale = _scale;
        _startOffset = _offset;
        _startFocal = next.focalPoint!;
      } else if (next.isEnd) {
        _onScaleEnd();
      } else if (_multi && next.focalPoint != null) {
        final scale = (_scale * next.scaleDelta).clamp(_minScale, _maxScale);
        final offset = _offset + next.focalDelta;
        setState(() {
          _scale = scale;
          _offset = _clampOffset(offset, scale, _lastFitted, _lastBounds);
        });
      }
    });

    final program = _program;
    final shader = _shader;
    final baseImage = _baseImage;
    final uneditedSource = _source;
    final lut = _lut;
    final zeroCopy = _useTexture && _textureId != null;
    // Texture delivery never bakes `lut`/`base` images, so requiring them
    // would pin the viewport to the placeholder forever (#54).
    if (previewNeedsPlaceholder(
      failed: _failed,
      hasProgram: program != null,
      hasShader: shader != null,
      hasSource: baseImage != null || uneditedSource != null,
      hasLut: lut != null,
      useTexture: zeroCopy,
    )) {
      return _placeholder();
    }
    // The gate above proved the shader-path inputs (it only passes texture
    // mode without a LUT); the `!`s feed definite-assignment analysis.
    final fragShader = shader!;
    // The shader grades the edited base image when available; falls back to
    // the unedited proxy. The compare "before" side always uses the unedited
    // source so the user sees the true original.
    final proxySource = baseImage ?? uneditedSource!;
    final compareSource = uneditedSource!;

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
        : Size(proxySource.width.toDouble(), proxySource.height.toDouble());

    return LayoutBuilder(
      builder: (context, constraints) {
        final bounds = constraints.biggest;
        final fitted = fitContained(content, bounds);
        final boundsChanged = _lastBounds != bounds && _lastBounds != Size.zero;
        _lastFitted = fitted;
        _lastBounds = bounds;
        if (_needsReset ||
            (_scale == 1.0 && boundsChanged) ||
            (_offset == Offset.zero && bounds.width > 0 && bounds.height > 0)) {
          _needsReset = false;
          // Contain-fit is the baseline: the photo always fits inside the
          // canvas, so zoom only ever goes in.
          _minScale = 1.0;
          _resetView(fitted, bounds);
        } else if (boundsChanged && _scale > 1.0) {
          _offset = _clampOffset(_offset, _scale, fitted, bounds);
        }
        // Publish the view transform so overlays outside this widget (the
        // selective-editing nodes, issue #25) can map image ↔ screen.
        _publishTransform(CanvasTransform(fitted: fitted, offset: _offset, scale: _scale));

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onTap,
                onScaleStart: (d) => _onScaleStart(d, fitted, tat),
                onScaleUpdate: (d) => _onScaleUpdate(d, fitted, bounds, tat),
                onScaleEnd: (_) => _onScaleEnd(),
                onDoubleTap: () {
                  if (ref.read(wiperCompareProvider).isActive) {
                    ref.read(wiperCompareProvider.notifier).resetPosition();
                    HapticFeedback.selectionClick();
                  } else {
                    _resetView(fitted, bounds);
                  }
                },
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
                          animation: Listenable.merge([_compare, _maskPeek, _zebraTicker]),
                          builder: (context, _) {
                            // High-zoom tiles (#16): the cached, baked level-0
                            // tiles, drawn over the proxy through the shader.
                            // World rect → fitted rect, same mapping as the
                            // proxy (image px → contain-fit content px).
                            final tiles = _tilesActive && _fullH > 0
                                ? _visibleTileImages(fitted)
                                : const <_CanvasTile>[];
                            final wiper = ref.watch(wiperCompareProvider);
                            final zoneMask = ref.watch(zoneMaskProvider);
                            final exposureAssist = ref.watch(exposureAssistProvider);
                            if (exposureAssist.mode == ExposureAssistMode.zebras) {
                              if (!_zebraTicker.isAnimating) {
                                _zebraTicker.repeat();
                              }
                            } else {
                              if (_zebraTicker.isAnimating) {
                                _zebraTicker.stop();
                              }
                            }
                            final (zLo, zHi) = zoneMask.isTargeting
                                ? zoneMask.lumaBounds
                                : (-1.0, -1.0);
                            final effectiveMaskBlend = zoneMask.isTargeting
                                ? 1.0
                                : _maskPeek.value;
                            return PreviewSurface(
                              // Issue #54: actually display the texture Rust is
                              // writing into; the shader paint is the fallback
                              // (imported LUTs, iOS/tests, compare/peek fades,
                              // tile overlay, geometry edits, wiper split curtain, exposure assist).
                              textureId: zeroCopy && !zoneMask.isTargeting && !wiper.isActive && !exposureAssist.isActive ? _textureId : null,
                              fallback: (_) => CustomPaint(
                                size: fitted,
                                painter: _CanvasPainter(
                                  shader: fragShader,
                                  source: proxySource,
                                  compareSource: compareSource,
                                  // Only ever built when `!zeroCopy`, where the
                                  // placeholder gate proved the LUT exists.
                                  lut: lut!,
                                  lutSize: _activeLutSize.toDouble(),
                                  dst: Offset.zero & fitted,
                                  blend: _compare.value,
                                  maskBlend: effectiveMaskBlend,
                                  zoneLo: zLo,
                                  zoneHi: zHi,
                                  wiperActive: wiper.isActive,
                                  wiperPosition: wiper.position,
                                  wiperOrientation: wiper.orientation,
                                  zebraMode: exposureAssist.mode,
                                  time: _zebraTicker.value * 1.0,
                                  zebraHigh: exposureAssist.zebraHigh,
                                  zebraLow: exposureAssist.zebraLow,
                                  tiles: tiles,
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
    final wiper = ref.read(wiperCompareProvider);
    if (wiper.isActive) {
      if (d.pointerCount >= 2) {
        ref.read(wiperCompareProvider.notifier).toggleOrientation();
        HapticFeedback.selectionClick();
        return;
      }
      _wiperDragging = true;
      final pos = wiper.orientation == WiperOrientation.vertical
          ? (d.localFocalPoint.dx / fitted.width).clamp(0.0, 1.0)
          : (d.localFocalPoint.dy / fitted.height).clamp(0.0, 1.0);
      ref.read(wiperCompareProvider.notifier).setPosition(pos);
      return;
    }
    _startScale = _scale;
    _startOffset = _offset;
    _startFocal = d.localFocalPoint;
    _multi = d.pointerCount >= 2;
    _editing = false;
    _zoneTargeting = false;
    if (_multi) {
      if (widget.editInterpreter != null && d.pointerCount == 2) {
        _zoneTargeting = true;
        ref.read(zoneMaskProvider.notifier).beginTargeting();
        HapticFeedback.selectionClick();
      }
      return;
    }
    if (tat) {
      _tatTouch(d.localFocalPoint, fitted);
    } else if (widget.editInterpreter != null) {
      widget.editInterpreter!.onPanStart(
        d.localFocalPoint,
        screenWidth: _lastBounds.width > 0 ? _lastBounds.width : null,
      );
      _editing = true;
    }
  }

  void _onScaleUpdate(
    ScaleUpdateDetails d,
    Size fitted,
    Size bounds,
    bool tat,
  ) {
    if (_wiperDragging) {
      final wiper = ref.read(wiperCompareProvider);
      final pos = wiper.orientation == WiperOrientation.vertical
          ? (d.localFocalPoint.dx / fitted.width).clamp(0.0, 1.0)
          : (d.localFocalPoint.dy / fitted.height).clamp(0.0, 1.0);
      ref.read(wiperCompareProvider.notifier).setPosition(pos);
      return;
    }
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
        if (widget.editInterpreter != null && d.pointerCount == 2) {
          _zoneTargeting = true;
          ref.read(zoneMaskProvider.notifier).beginTargeting();
          HapticFeedback.selectionClick();
          return;
        }
      }
      if (_zoneTargeting) {
        if ((d.scale - 1.0).abs() > 0.15) {
          ref.read(zoneMaskProvider.notifier).endTargeting();
          _zoneTargeting = false;
        } else {
          final tick = ref
              .read(zoneMaskProvider.notifier)
              .updateDelta(d.focalPointDelta.dy);
          if (tick != null) {
            fireHaptic(tick);
          }
          return;
        }
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
    if (_wiperDragging) {
      _wiperDragging = false;
      return;
    }
    if (_editing) widget.editInterpreter?.onPanEnd();
    _editing = false;
    _multi = false;
    if (_zoneTargeting) {
      ref.read(zoneMaskProvider.notifier).lockMask();
      HapticFeedback.mediumImpact();
      _zoneTargeting = false;
    }
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
      (bounds.width - fitted.width) / 2,
      (bounds.height - fitted.height) / 2,
    );
  }

  /// The cached tiles that intersect the visible world rect, each mapped to
  /// its fitted-space draw rect (image px → contain-fit content px). Tiles
  /// not yet decoded are simply absent — the proxy underneath shows through
  /// until they land.
  List<_CanvasTile> _visibleTileImages(Size fitted) {
    final grid = _tileGrid;
    if (grid == null || fitted.width <= 0 || fitted.height <= 0) {
      return const [];
    }
    final scale = _scale;
    if (scale <= 0) return const [];
    // Inverse of the viewport transform (translate(offset) * scale, topLeft):
    // world = (screen - offset) / scale (in fitted coordinates).
    final visibleFitted = Rect.fromLTWH(
      -_offset.dx / scale,
      -_offset.dy / scale,
      _lastBounds.width / scale,
      _lastBounds.height / scale,
    ).intersect(Rect.fromLTWH(0, 0, fitted.width, fitted.height));
    if (visibleFitted.width <= 0 || visibleFitted.height <= 0) return const [];
    final scaleToImageX = _fullW / fitted.width;
    final scaleToImageY = _fullH / fitted.height;
    final visibleWorld = Rect.fromLTWH(
      visibleFitted.left * scaleToImageX,
      visibleFitted.top * scaleToImageY,
      visibleFitted.width * scaleToImageX,
      visibleFitted.height * scaleToImageY,
    );

    final sx = fitted.width / _fullW;
    final sy = fitted.height / _fullH;
    final out = <_CanvasTile>[];
    for (final t in grid.visibleTiles(visibleWorld)) {
      final img = _tiles.get(t.coord);
      if (img == null) continue;
      final r = t.worldRect;
      out.add(
        _CanvasTile(
          image: img,
          dst: Rect.fromLTWH(r.left * sx, r.top * sy, r.width * sx, r.height * sy),
        ),
      );
    }
    return out;
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

/// A baked high-zoom tile (#16) and its draw rect in fitted/content space.
class _CanvasTile {
  const _CanvasTile({required this.image, required this.dst});

  final ui.Image image;
  final Rect dst;
}

/// Draws the base texture through `lut.frag` inside the aspect-correct [dst]
/// rect, sampling the packed 3D LUT atlas, and crossfades to the raw source
/// while comparing ([blend] 0..1).
class _CanvasPainter extends CustomPainter {
  _CanvasPainter({
    required this.shader,
    required this.source,
    required this.compareSource,
    required this.lut,
    required this.lutSize,
    required this.dst,
    required this.blend,
    required this.maskBlend,
    this.zoneLo = -1.0,
    this.zoneHi = -1.0,
    this.wiperActive = false,
    this.wiperPosition = 0.50,
    this.wiperOrientation = WiperOrientation.vertical,
    this.zebraMode = ExposureAssistMode.off,
    this.time = 0.0,
    this.zebraHigh = 0.98,
    this.zebraLow = 0.02,
    this.tiles = const [],
  });

  final ui.FragmentShader shader;
  final ui.Image source;
  final ui.Image compareSource;
  final ui.Image lut;
  final double lutSize;
  final Rect dst;
  final double blend;
  final double maskBlend;
  final double zoneLo;
  final double zoneHi;
  final bool wiperActive;
  final double wiperPosition;
  final WiperOrientation wiperOrientation;
  final ExposureAssistMode zebraMode;
  final double time;
  final double zebraHigh;
  final double zebraLow;

  /// High-zoom tiles (#16): baked level-0 tiles of the original frame, drawn
  /// through the same uniforms over the proxy at their fitted-space rects.
  /// Empty while the overlay is inactive or tiles are still loading.
  final List<_CanvasTile> tiles;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(const Color(0xFF000000), BlendMode.src);

    final zebraVal = zebraMode == ExposureAssistMode.zebras
        ? 1.0
        : (zebraMode == ExposureAssistMode.falseColor ? 2.0 : 0.0);

    shader
      ..setFloat(0, dst.width)
      ..setFloat(1, dst.height)
      ..setFloat(2, lutSize)
      ..setFloat(3, maskBlend)
      ..setFloat(4, source.width.toDouble())
      ..setFloat(5, source.height.toDouble())
      ..setFloat(6, zoneLo)
      ..setFloat(7, zoneHi)
      ..setFloat(8, zebraVal)
      ..setFloat(9, time)
      ..setFloat(10, zebraHigh)
      ..setFloat(11, zebraLow)
      ..setImageSampler(0, source)
      ..setImageSampler(1, lut);

    if (wiperActive) {
      if (wiperOrientation == WiperOrientation.vertical) {
        final splitX = dst.left + dst.width * wiperPosition.clamp(0.0, 1.0);

        // 1. Unedited Source on Left side
        canvas.save();
        canvas.clipRect(Rect.fromLTRB(dst.left, dst.top, splitX, dst.bottom));
        canvas.drawImageRect(
          compareSource,
          Rect.fromLTWH(0, 0, compareSource.width.toDouble(), compareSource.height.toDouble()),
          dst,
          Paint(),
        );
        canvas.restore();

        // 2. Graded result on Right side
        canvas.save();
        canvas.clipRect(Rect.fromLTRB(splitX, dst.top, dst.right, dst.bottom));
        canvas.drawRect(dst, Paint()..shader = shader);
        if (tiles.isNotEmpty) {
          for (final tile in tiles) {
            canvas.save();
            canvas.translate(tile.dst.left, tile.dst.top);
            shader
              ..setFloat(0, tile.dst.width)
              ..setFloat(1, tile.dst.height)
              ..setFloat(2, lutSize)
              ..setFloat(3, maskBlend)
              ..setFloat(4, tile.image.width.toDouble())
              ..setFloat(5, tile.image.height.toDouble())
              ..setFloat(6, zoneLo)
              ..setFloat(7, zoneHi)
              ..setFloat(8, zebraVal)
              ..setFloat(9, time)
              ..setFloat(10, zebraHigh)
              ..setFloat(11, zebraLow)
              ..setImageSampler(0, tile.image)
              ..setImageSampler(1, lut);
            canvas.drawRect(
              Rect.fromLTWH(0, 0, tile.dst.width, tile.dst.height),
              Paint()..shader = shader,
            );
            canvas.restore();
          }
        }
        canvas.restore();

        // 3. Glowing cyan divider line
        final glowPaint = Paint()
          ..color = const Color(0x6600E5FF)
          ..strokeWidth = 6.0
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
        canvas.drawLine(Offset(splitX, dst.top), Offset(splitX, dst.bottom), glowPaint);

        final linePaint = Paint()
          ..color = const Color(0xFF00E5FF)
          ..strokeWidth = 2.0;
        canvas.drawLine(Offset(splitX, dst.top), Offset(splitX, dst.bottom), linePaint);

        // 4. Circular thumb handle at center
        final handleCenter = Offset(splitX, dst.top + dst.height * 0.5);
        canvas.drawCircle(handleCenter, 18, Paint()..color = const Color(0xDD000000));
        canvas.drawCircle(
          handleCenter,
          18,
          Paint()
            ..color = const Color(0xFF00E5FF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0,
        );

        final tp = TextPainter(
          text: const TextSpan(
            text: '◀ ▶',
            style: TextStyle(
              color: Color(0xFF00E5FF),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, handleCenter - Offset(tp.width / 2, tp.height / 2));
      } else {
        // Horizontal split
        final splitY = dst.top + dst.height * wiperPosition.clamp(0.0, 1.0);

        // 1. Unedited Source on Top side
        canvas.save();
        canvas.clipRect(Rect.fromLTRB(dst.left, dst.top, dst.right, splitY));
        canvas.drawImageRect(
          compareSource,
          Rect.fromLTWH(0, 0, compareSource.width.toDouble(), compareSource.height.toDouble()),
          dst,
          Paint(),
        );
        canvas.restore();

        // 2. Graded result on Bottom side
        canvas.save();
        canvas.clipRect(Rect.fromLTRB(dst.left, splitY, dst.right, dst.bottom));
        canvas.drawRect(dst, Paint()..shader = shader);
        if (tiles.isNotEmpty) {
          for (final tile in tiles) {
            canvas.save();
            canvas.translate(tile.dst.left, tile.dst.top);
            shader
              ..setFloat(0, tile.dst.width)
              ..setFloat(1, tile.dst.height)
              ..setFloat(2, lutSize)
              ..setFloat(3, maskBlend)
              ..setFloat(4, tile.image.width.toDouble())
              ..setFloat(5, tile.image.height.toDouble())
              ..setFloat(6, zoneLo)
              ..setFloat(7, zoneHi)
              ..setFloat(8, zebraVal)
              ..setFloat(9, time)
              ..setFloat(10, zebraHigh)
              ..setFloat(11, zebraLow)
              ..setImageSampler(0, tile.image)
              ..setImageSampler(1, lut);
            canvas.drawRect(
              Rect.fromLTWH(0, 0, tile.dst.width, tile.dst.height),
              Paint()..shader = shader,
            );
            canvas.restore();
          }
        }
        canvas.restore();

        // 3. Glowing cyan divider line
        final glowPaint = Paint()
          ..color = const Color(0x6600E5FF)
          ..strokeWidth = 6.0
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
        canvas.drawLine(Offset(dst.left, splitY), Offset(dst.right, splitY), glowPaint);

        final linePaint = Paint()
          ..color = const Color(0xFF00E5FF)
          ..strokeWidth = 2.0;
        canvas.drawLine(Offset(dst.left, splitY), Offset(dst.right, splitY), linePaint);

        // 4. Circular thumb handle at center
        final handleCenter = Offset(dst.left + dst.width * 0.5, splitY);
        canvas.drawCircle(handleCenter, 18, Paint()..color = const Color(0xDD000000));
        canvas.drawCircle(
          handleCenter,
          18,
          Paint()
            ..color = const Color(0xFF00E5FF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0,
        );

        final tp = TextPainter(
          text: const TextSpan(
            text: '▲\n▼',
            style: TextStyle(
              color: Color(0xFF00E5FF),
              fontSize: 8,
              fontWeight: FontWeight.bold,
              height: 1.0,
            ),
          ),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
        )..layout();
        tp.paint(canvas, handleCenter - Offset(tp.width / 2, tp.height / 2));
      }
      return;
    }

    canvas.drawRect(dst, Paint()..shader = shader);

    if (blend > 0) {
      canvas.drawImageRect(
        compareSource,
        Rect.fromLTWH(0, 0, compareSource.width.toDouble(), compareSource.height.toDouble()),
        dst,
        Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: blend),
      );
    }

    // High-zoom tiles: one shader pass per tile. Translate so the tile's own
    // rect is the shader's local origin — `FlutterFragCoord` is local-canvas
    // space, so uSize covers the tile exactly, mirroring the proxy pass.
    // The compare crossfade is drawn above, so tiles under the blend are
    // already covered by the raw-source overlay and need no extra fade.
    if (tiles.isNotEmpty) {
      canvas.save();
      canvas.clipRect(Offset.zero & size);
      for (final tile in tiles) {
        canvas.save();
        canvas.translate(tile.dst.left, tile.dst.top);
        shader
          ..setFloat(0, tile.dst.width)
          ..setFloat(1, tile.dst.height)
          ..setFloat(2, lutSize)
          ..setFloat(3, maskBlend)
          ..setFloat(4, tile.image.width.toDouble())
          ..setFloat(5, tile.image.height.toDouble())
          ..setFloat(6, zoneLo)
          ..setFloat(7, zoneHi)
          ..setFloat(8, zebraVal)
          ..setFloat(9, time)
          ..setFloat(10, zebraHigh)
          ..setFloat(11, zebraLow)
          ..setImageSampler(0, tile.image)
          ..setImageSampler(1, lut);
        canvas.drawRect(
          Rect.fromLTWH(0, 0, tile.dst.width, tile.dst.height),
          Paint()..shader = shader,
        );
        canvas.restore();
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_CanvasPainter old) =>
      old.source != source ||
      old.compareSource != compareSource ||
      old.lut != lut ||
      old.blend != blend ||
      old.maskBlend != maskBlend ||
      old.zoneLo != zoneLo ||
      old.zoneHi != zoneHi ||
      old.wiperActive != wiperActive ||
      old.wiperPosition != wiperPosition ||
      old.wiperOrientation != wiperOrientation ||
      old.zebraMode != zebraMode ||
      old.time != time ||
      old.zebraHigh != zebraHigh ||
      old.zebraLow != zebraLow ||
      old.dst != dst ||
      !_sameTiles(old.tiles, tiles);

  static bool _sameTiles(List<_CanvasTile> a, List<_CanvasTile> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].image != b[i].image || a[i].dst != b[i].dst) return false;
    }
    return true;
  }
}
