import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/log/activity_log.dart';
import '../core/log/log_providers.dart';
import '../ui/common/mask_controls.dart'
    show FaceDetectorFn, SkyDetectorFn, SubjectSegmenterFn;
import 'adjustment_layer.dart';
import 'recipe.dart';

/// Riverpod provider for [AiMaskResolver].
final aiMaskResolverProvider = Provider<AiMaskResolver>((ref) => AiMaskResolver());

/// Current active ML model version for subject and sky segmentation.
/// Bumping this version automatically invalidates stale mask cache entries.
const int kAiModelVersion = 1;

/// Computes an 8-character FNV-1a hex hash.
String computeFnv1a(String input) {
  var hash = 0xcbf29ce484222325;
  final bytes = utf8.encode(input);
  for (final b in bytes) {
    hash ^= b;
    hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
  }
  return (hash & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0');
}

/// Orchestrates resolving and re-inferring intent-based AI masks (#96).
///
/// Implements shared recipe lifetime semantics:
/// Recipes remain shared references in the store; per-asset mask resolutions
/// are cached independently keyed by `FNV-1a(assetId|intent|modelVersion)`.
class AiMaskResolver {
  /// `key -> (blob, params)`: a bitmap layer needs its `[w, h]` params as
  /// well as the blob, so a cache hit can restore the complete bitmap form
  /// instead of bolting a blob onto a parametric layer (#D: kind/params used
  /// to be dropped, so the renderer kept the old analytic contract).
  final Map<String, ({Uint8List blob, List<double> params})> _cache = {};

  /// Checks if a mask blob for [assetId] and [intent] is present in cache.
  bool hasCached(
    String assetId,
    String intent, {
    int modelVersion = kAiModelVersion,
  }) {
    final key = computeFnv1a('$assetId|$intent|$modelVersion');
    return _cache.containsKey(key);
  }

  /// Clears in-memory resolution cache.
  void clearCache() => _cache.clear();

  /// Resolves an adjustment layer for a target photo [targetAssetId].
  Future<AdjustmentLayer> resolveLayer(
    AdjustmentLayer layer, {
    required String targetAssetId,
    required Uint8List targetProxyBytes,
    SubjectSegmenterFn? segmenter,
    SkyDetectorFn? skyDetector,
    FaceDetectorFn? faceDetector,
    int modelVersion = kAiModelVersion,
  }) async {
    final intent = layer.aiIntent;
    if (intent == null) return layer;
    if (layer.originAssetId == targetAssetId) return layer;

    final key = computeFnv1a('$targetAssetId|$intent|$modelVersion');
    final cached = _cache[key];
    if (cached != null) {
      return layer.copyWith(
        maskKind: MaskKind.bitmap,
        maskParams: cached.params,
        maskBlob: cached.blob,
        originAssetId: targetAssetId,
      );
    }

    if (intent == 'subject' || intent == 'background' || intent == 'person') {
      if (segmenter != null) {
        try {
          final alphas = await segmenter(
            targetProxyBytes,
            targetWidth: 256,
            targetHeight: 256,
          );
          if (alphas != null && alphas.isNotEmpty) {
            final tempLayer = AdjustmentLayer.bitmap(
              width: 256,
              height: 256,
              alphas: alphas,
              inverted: layer.inverted,
            );
            if (tempLayer.maskBlob != null) {
              _cache[key] = (
                blob: tempLayer.maskBlob!,
                params: List<double>.from(tempLayer.maskParams),
              );
              return layer.copyWith(
                maskKind: MaskKind.bitmap,
                maskParams: tempLayer.maskParams,
                maskBlob: tempLayer.maskBlob,
                originAssetId: targetAssetId,
              );
            }
          }
        } catch (e, st) {
          axLog(LogDomain.editor, 'AI mask subject resolver fallback: $e', level: LogLevel.debug, error: e.toString(), stack: st.toString());
        }
      }
    } else if (intent == 'sky') {
      if (skyDetector != null) {
        try {
          final detected = await skyDetector(targetProxyBytes);
          if (detected != null) {
            return layer.copyWith(
              maskParams: [
                detected.horizonY,
                detected.feather,
                detected.blueWeight,
              ],
              originAssetId: targetAssetId,
            );
          }
        } catch (e, st) {
          axLog(LogDomain.editor, 'AI mask sky resolver fallback: $e', level: LogLevel.debug, error: e.toString(), stack: st.toString());
        }
      }
    } else if (intent == 'face' || intent == 'personFace') {
      if (faceDetector != null) {
        try {
          final face = await faceDetector(targetProxyBytes);
          if (face != null) {
            return layer.copyWith(
              maskKind: MaskKind.personFace,
              maskParams: [
                face.cx.clamp(0.05, 0.95),
                face.cy.clamp(0.05, 0.95),
                (face.rx * 1.15).clamp(0.04, 0.45),
                (face.ry * 1.25).clamp(0.05, 0.50),
                0.35,
              ],
              originAssetId: targetAssetId,
            );
          }
        } catch (e, st) {
          axLog(LogDomain.editor, 'AI mask face resolver fallback: $e', level: LogLevel.debug, error: e.toString(), stack: st.toString());
        }
      }
    } else if (intent == 'skin' || intent == 'personSkin') {
      if (faceDetector != null) {
        try {
          final face = await faceDetector(targetProxyBytes);
          if (face != null) {
            return layer.copyWith(
              maskKind: MaskKind.personSkin,
              maskParams: [
                face.cx.clamp(0.05, 0.95),
                face.cy.clamp(0.05, 0.95),
                (face.rx * 1.15).clamp(0.04, 0.45),
                (face.ry * 1.25).clamp(0.05, 0.50),
                0.35,
              ],
              originAssetId: targetAssetId,
            );
          }
        } catch (e, st) {
          axLog(LogDomain.editor, 'AI mask skin resolver fallback: $e', level: LogLevel.debug, error: e.toString(), stack: st.toString());
        }
      }
    } else if (intent == 'hair' || intent == 'personHair') {
      if (faceDetector != null) {
        try {
          final face = await faceDetector(targetProxyBytes);
          if (face != null) {
            return layer.copyWith(
              maskKind: MaskKind.personHair,
              maskParams: [
                face.cx.clamp(0.05, 0.95),
                (face.cy - face.ry * 0.4).clamp(0.05, 0.95),
                (face.rx * 1.1).clamp(0.04, 0.45),
                (face.ry * 0.6).clamp(0.04, 0.45),
                0.2,
              ],
              originAssetId: targetAssetId,
            );
          }
        } catch (e, st) {
          axLog(LogDomain.editor, 'AI mask hair resolver fallback: $e', level: LogLevel.debug, error: e.toString(), stack: st.toString());
        }
      }
    } else if (intent == 'object') {
      if (segmenter != null) {
        try {
          final alphas = await segmenter(
            targetProxyBytes,
            targetWidth: 256,
            targetHeight: 256,
          );
          if (alphas != null && alphas.isNotEmpty) {
            final tempLayer = AdjustmentLayer.bitmap(
              width: 256,
              height: 256,
              alphas: alphas,
              inverted: layer.inverted,
            );
            if (tempLayer.maskBlob != null) {
              _cache[key] = (
                blob: tempLayer.maskBlob!,
                params: List<double>.from(tempLayer.maskParams),
              );
              return layer.copyWith(
                maskKind: MaskKind.bitmap,
                maskParams: tempLayer.maskParams,
                maskBlob: tempLayer.maskBlob,
                originAssetId: targetAssetId,
              );
            }
          }
        } catch (e, st) {
          axLog(LogDomain.editor, 'AI mask object resolver fallback: $e', level: LogLevel.debug, error: e.toString(), stack: st.toString());
        }
      }
    }

    return layer;
  }

  /// Resolves all intent-bearing layers in [recipe] for [targetAssetId].
  Future<EditRecipe> resolveRecipe(
    EditRecipe recipe, {
    required String targetAssetId,
    required Uint8List targetProxyBytes,
    SubjectSegmenterFn? segmenter,
    SkyDetectorFn? skyDetector,
    FaceDetectorFn? faceDetector,
    int modelVersion = kAiModelVersion,
  }) async {
    final resolvedLayers = <AdjustmentLayer>[];
    for (final layer in recipe.layers) {
      resolvedLayers.add(
        await resolveLayer(
          layer,
          targetAssetId: targetAssetId,
          targetProxyBytes: targetProxyBytes,
          segmenter: segmenter,
          skyDetector: skyDetector,
          faceDetector: faceDetector,
          modelVersion: modelVersion,
        ),
      );
    }
    return recipe.copyWith(layers: resolvedLayers);
  }
}
