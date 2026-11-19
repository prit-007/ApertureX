import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/log/activity_log.dart';
import '../core/log/log_providers.dart';
import '../engine/engine.dart';
import 'depth_sidecar.dart';
import 'parameter.dart';
import 'recipe_controller.dart';

/// State of the Lens Blur feature.
enum LensBlurStatus {
  off,
  analyzing,
  ready,
  failed,
}

/// Typed categories of depth estimation failure.
enum LensBlurErrorType {
  none,
  noDepth,
  modelMissing,
  outOfMemory,
  formatUnsupported,
}

/// State representation for Lens Blur controls and direct canvas interactions.
class LensBlurState {
  const LensBlurState({
    this.status = LensBlurStatus.off,
    this.depthConfidence = 0.0,
    this.showDepthVisualizer = false,
    this.focusPointNormalized,
    this.statusMessage,
    this.errorType = LensBlurErrorType.none,
    this.cachedDepth,
    this.depthWidth = 0,
    this.depthHeight = 0,
  });

  final LensBlurStatus status;
  final double depthConfidence;
  final bool showDepthVisualizer;
  final (double, double)? focusPointNormalized;
  final String? statusMessage;
  final LensBlurErrorType errorType;
  final Float32List? cachedDepth;
  final int depthWidth;
  final int depthHeight;

  LensBlurState copyWith({
    LensBlurStatus? status,
    double? depthConfidence,
    bool? showDepthVisualizer,
    (double, double)? focusPointNormalized,
    String? statusMessage,
    LensBlurErrorType? errorType,
    Float32List? cachedDepth,
    int? depthWidth,
    int? depthHeight,
  }) {
    return LensBlurState(
      status: status ?? this.status,
      depthConfidence: depthConfidence ?? this.depthConfidence,
      showDepthVisualizer: showDepthVisualizer ?? this.showDepthVisualizer,
      focusPointNormalized: focusPointNormalized ?? this.focusPointNormalized,
      statusMessage: statusMessage ?? this.statusMessage,
      errorType: errorType ?? this.errorType,
      cachedDepth: cachedDepth ?? this.cachedDepth,
      depthWidth: depthWidth ?? this.depthWidth,
      depthHeight: depthHeight ?? this.depthHeight,
    );
  }
}

/// Manages depth estimation, focus plane direct manipulation, and depth visualization heatmap.
class LensBlurController extends Notifier<LensBlurState> {
  @override
  LensBlurState build() {
    final blurEnabled = ref.watch(recipeControllerProvider.select((s) => s.recipe.blurEnabled));
    return LensBlurState(
      status: blurEnabled ? LensBlurStatus.ready : LensBlurStatus.off,
    );
  }

  void toggleDepthVisualizer([bool? enabled]) {
    state = state.copyWith(showDepthVisualizer: enabled ?? !state.showDepthVisualizer);
  }

  void setStatusMessage(String? message) {
    state = state.copyWith(statusMessage: message);
  }

  void resetFocusPoint() {
    setFocusPoint(0.5, 0.5);
  }

  /// Sets focal plane from normalized image coordinates `(x, y)` in `[0.0, 1.0]`.
  void setFocusPoint(double x, double y) {
    state = state.copyWith(focusPointNormalized: (x, y));
    HapticFeedback.selectionClick();

    double focalPoint;
    if (state.cachedDepth != null && state.depthWidth > 0 && state.depthHeight > 0) {
      final px = (x * (state.depthWidth - 1)).round().clamp(0, state.depthWidth - 1);
      final py = (y * (state.depthHeight - 1)).round().clamp(0, state.depthHeight - 1);
      focalPoint = state.cachedDepth![py * state.depthWidth + px].clamp(0.0, 1.0);
    } else {
      focalPoint = (0.20 + 0.60 * y).clamp(0.0, 1.0);
    }

    final notifier = ref.read(recipeControllerProvider.notifier);
    notifier.update(Parameter.blurFocalPoint, focalPoint);
    notifier.commit(label: 'Direct Focus Point Selection');
  }

  /// Estimates depth map and confidence from active image proxy or cached sources.
  Future<void> analyzeDepth(Uint8List imageBytes, {int? handle}) async {
    if (state.cachedDepth != null && state.depthWidth > 0 && state.depthHeight > 0) {
      return;
    }

    // Check if recipe already holds preloaded depth data
    final recipe = ref.read(recipeControllerProvider).recipe;
    if (recipe.depthField != null && recipe.depthField!.plane.isNotEmpty) {
      final df = recipe.depthField!;
      state = state.copyWith(
        status: LensBlurStatus.ready,
        depthConfidence: df.confidence,
        cachedDepth: df.plane,
        depthWidth: df.width,
        depthHeight: df.height,
        statusMessage: null,
      );
      return;
    }

    final sidecarPath = recipe.depthSidecarPath ?? recipe.depthSidecar;
    if (sidecarPath != null) {
      final file = File(sidecarPath);
      if (await file.exists()) {
        final loaded = await loadCachedSidecar(file);
        if (loaded) return;
      }
    }

    state = state.copyWith(
      status: LensBlurStatus.analyzing,
      statusMessage: 'Estimating depth field…',
    );

    try {
      // Priority 1: Check embedded container depth metadata (JPEG GDepth, Apple disparity)
      final embedded = await AxEngine.extractEmbeddedDepth(imageBytes);
      if (embedded != null && embedded.width > 0 && embedded.height > 0) {
        final floatPlane = Float32List(embedded.depth.length);
        for (var i = 0; i < embedded.depth.length; i++) {
          floatPlane[i] = 1.0 - (embedded.depth[i] / 255.0);
        }
        final data = DepthSidecarData(
          width: embedded.width,
          height: embedded.height,
          confidence: 0.95,
          source: DepthSourceType.embeddedGDepth,
          contentHash: 0,
          plane: floatPlane,
        );
        ref.read(recipeControllerProvider.notifier).setDepthField(data);

        state = state.copyWith(
          status: LensBlurStatus.ready,
          depthConfidence: 0.95,
          cachedDepth: floatPlane,
          depthWidth: embedded.width,
          depthHeight: embedded.height,
          statusMessage: null,
        );
        return;
      }

      // Priority 2: Reuse pre-computed resident depth from handle if available (non-blocking)
      if (handle != null && handle > 0) {
        try {
          final cachedDepth = await AxEngine.previewGetCachedDepth(handle);
          final residentDepth = cachedDepth ?? await AxEngine.previewEstimateDepth(handle);
          if (residentDepth.isNotEmpty) {
            final decoded = await AxEngine.decodeAnalysisProxy(imageBytes);
            final confidence = await AxEngine.depthConfidence(
              rgba: decoded.rgba,
              width: decoded.width,
              height: decoded.height,
            );
            final data = DepthSidecarData(
              width: decoded.width,
              height: decoded.height,
              confidence: confidence,
              source: DepthSourceType.neural,
              contentHash: 0,
              plane: residentDepth,
            );
            ref.read(recipeControllerProvider.notifier).setDepthField(data);

            state = state.copyWith(
              status: LensBlurStatus.ready,
              depthConfidence: confidence,
              cachedDepth: residentDepth,
              depthWidth: decoded.width,
              depthHeight: decoded.height,
              statusMessage: null,
            );
            return;
          }
        } catch (e, st) {
          axLog(LogDomain.engine, 'Embedded depth sidecar read fallback: $e', level: LogLevel.debug, error: e.toString(), stack: st.toString());
          // Fall back to standard decoding proxy pipeline
        }
      }

      // Priority 3: Monocular depth estimation via proxy
      final decoded = await AxEngine.decodeAnalysisProxy(imageBytes);
      final depth = await AxEngine.estimateDepthMap(
        rgba: decoded.rgba,
        width: decoded.width,
        height: decoded.height,
      );
      final confidence = await AxEngine.depthConfidence(
        rgba: decoded.rgba,
        width: decoded.width,
        height: decoded.height,
      );

      final data = DepthSidecarData(
        width: decoded.width,
        height: decoded.height,
        confidence: confidence,
        source: DepthSourceType.neural,
        contentHash: 0,
        plane: depth,
      );
      ref.read(recipeControllerProvider.notifier).setDepthField(data);

      state = state.copyWith(
        status: LensBlurStatus.ready,
        depthConfidence: confidence,
        cachedDepth: depth,
        depthWidth: decoded.width,
        depthHeight: decoded.height,
        statusMessage: null,
      );
    } catch (e) {
      final msg = e.toString().toLowerCase();
      final LensBlurErrorType errType;
      if (msg.contains('memory') || msg.contains('oom')) {
        errType = LensBlurErrorType.outOfMemory;
      } else if (msg.contains('model') || msg.contains('not found') || msg.contains('missing')) {
        errType = LensBlurErrorType.modelMissing;
      } else if (msg.contains('format') || msg.contains('dimension')) {
        errType = LensBlurErrorType.formatUnsupported;
      } else {
        errType = LensBlurErrorType.noDepth;
      }

      state = state.copyWith(
        status: LensBlurStatus.failed,
        errorType: errType,
        statusMessage: e.toString(),
      );
    }
  }

  /// Attempts to load and restore pre-cached depth from an .axdf sidecar file.
  Future<bool> loadCachedSidecar(File sidecarFile) async {
    final data = await DepthSidecar.load(sidecarFile);
    if (data == null) return false;

    state = state.copyWith(
      status: LensBlurStatus.ready,
      depthConfidence: data.confidence,
      cachedDepth: data.plane,
      depthWidth: data.width,
      depthHeight: data.height,
      statusMessage: null,
    );
    return true;
  }

  /// Persists current cached depth field to an .axdf sidecar file.
  Future<void> persistSidecar(File sidecarFile, {int contentHash = 0}) async {
    final depth = state.cachedDepth;
    if (depth == null || state.depthWidth == 0 || state.depthHeight == 0) return;

    final data = DepthSidecarData(
      width: state.depthWidth,
      height: state.depthHeight,
      confidence: state.depthConfidence,
      source: DepthSourceType.neural,
      contentHash: contentHash,
      plane: depth,
    );
    await DepthSidecar.save(sidecarFile, data);
  }

  /// Applies manual touchups to the cached depth field using brush strokes (Item 4.6).
  /// [strokePoints] are normalized `(x, y)` pairs in `[0.0, 1.0]`.
  /// [targetDepth] is the depth value to paint (e.g. focalPoint for subject focus, or 1.0 for background).
  void applyDepthBrush(
    List<double> strokePoints, {
    double brushRadius = 0.05,
    double targetDepth = 0.0,
    double opacity = 0.8,
  }) {
    final depth = state.cachedDepth;
    final w = state.depthWidth;
    final h = state.depthHeight;
    if (depth == null || w <= 0 || h <= 0 || strokePoints.isEmpty) return;

    final updated = Float32List.fromList(depth);
    final maxDim = w > h ? w : h;
    final rPx = (brushRadius * maxDim).clamp(2.0, 100.0);
    final rPx2 = rPx * rPx;

    for (var i = 0; i < strokePoints.length - 1; i += 2) {
      final cx = strokePoints[i] * (w - 1);
      final cy = strokePoints[i + 1] * (h - 1);

      final minX = (cx - rPx).floor().clamp(0, w - 1);
      final maxX = (cx + rPx).ceil().clamp(0, w - 1);
      final minY = (cy - rPx).floor().clamp(0, h - 1);
      final maxY = (cy + rPx).ceil().clamp(0, h - 1);

      for (var y = minY; y <= maxY; y++) {
        final dy = y - cy;
        final dy2 = dy * dy;
        final row = y * w;
        for (var x = minX; x <= maxX; x++) {
          final dx = x - cx;
          final dist2 = dx * dx + dy2;
          if (dist2 <= rPx2) {
            final falloff = 1.0 - (dist2 / rPx2);
            final weight = falloff * opacity;
            final idx = row + x;
            updated[idx] =
                (updated[idx] * (1.0 - weight) + targetDepth * weight).clamp(0.0, 1.0);
          }
        }
      }
    }

    final data = DepthSidecarData(
      width: w,
      height: h,
      confidence: state.depthConfidence,
      source: DepthSourceType.neural,
      contentHash: 0,
      plane: updated,
    );
    ref.read(recipeControllerProvider.notifier).setDepthField(data);

    state = state.copyWith(cachedDepth: updated);
  }

  /// Snaps depth map edges to photographic boundaries using the color image as guide (Item 4.6).
  Future<void> refineDepthEdges(Uint8List imageBytes) async {
    final depth = state.cachedDepth;
    final w = state.depthWidth;
    final h = state.depthHeight;
    if (depth == null || w <= 0 || h <= 0) return;

    try {
      final decoded = await AxEngine.decodeAnalysisProxy(imageBytes);
      final refined = await AxEngine.refineMask(
        rgba: decoded.rgba,
        width: decoded.width,
        height: decoded.height,
        maskKind: 0,
        maskParams: [w.toDouble(), h.toDouble(), ...depth],
      );
      if (refined.length == w * h) {
        final floatPlane = Float32List.fromList(refined);
        final data = DepthSidecarData(
          width: w,
          height: h,
          confidence: state.depthConfidence,
          source: DepthSourceType.neural,
          contentHash: 0,
          plane: floatPlane,
        );
        ref.read(recipeControllerProvider.notifier).setDepthField(data);
        state = state.copyWith(cachedDepth: floatPlane);
      }
    } catch (e, st) {
      axLog(LogDomain.engine, 'LensBlur recalculate cached depth fallback: $e', level: LogLevel.debug, error: e.toString(), stack: st.toString());
      // Fallback: keep existing depth
    }
  }
}

final lensBlurControllerProvider =
    NotifierProvider<LensBlurController, LensBlurState>(LensBlurController.new);
