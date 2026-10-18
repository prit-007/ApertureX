import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

/// Asset keys of the shaders declared in `pubspec.yaml`.
const String lutShaderAsset = 'shaders/lut.frag';
const String gradeShaderAsset = 'shaders/grade.frag';

/// The app-wide warmup singleton, handed to the tree by [bootstrapApp].
final shaderWarmupProvider = Provider<ShaderWarmup>((ref) => ShaderWarmup());

/// The shared `lut.frag` program every canvas awaits instead of compiling on
/// first editor open (issue #72). Deliberately not `autoDispose`: the program
/// (and its GPU pipeline) lives for the whole session.
final lutProgramProvider = FutureProvider<ui.FragmentProgram>(
  (ref) => ref.read(shaderWarmupProvider).lutProgram(),
);

/// Compiles the declared fragment programs and — the actual point — forces
/// each GPU pipeline (Impeller PSO / Skia runtime-effect program) to be built
/// during startup, so the first photo open doesn't hitch (issue #72).
///
/// [call] is idempotent: [bootstrapApp] kicks it once before the first frame
/// and any later caller simply awaits the same pass. The rasterize step draws
/// one 1×1 offscreen quad per program: `FragmentProgram.fromAsset` alone only
/// loads the bytecode, while the pipeline is created on first draw.
class ShaderWarmup {
  /// [warm] injects the warmup action (tests record it instead of touching a
  /// GPU); the production default loads and rasterizes both programs.
  ShaderWarmup({Future<void> Function()? warm}) : _warmOverride = warm;

  final Future<void> Function()? _warmOverride;

  /// Cached program futures — the engine keeps its own static registry, but
  /// the app must hand *one* future to every consumer so the pipeline the
  /// warmup builds is the same object the canvas draws with.
  Future<ui.FragmentProgram>? _lut;
  Future<ui.FragmentProgram>? _grade;

  Future<void>? _pending;

  /// The cached `lut.frag` program (single load, shared by every canvas).
  Future<ui.FragmentProgram> lutProgram() =>
      _lut ??= ui.FragmentProgram.fromAsset(lutShaderAsset);

  /// The cached `grade.frag` program — declared in `pubspec.yaml` since the
  /// slice-D spike but never loaded until now; the warmup pays its (one-time,
  /// essentially free) compile so wiring it later can't stutter.
  Future<ui.FragmentProgram> gradeProgram() =>
      _grade ??= ui.FragmentProgram.fromAsset(gradeShaderAsset);

  /// Runs (or awaits) the warmup pass. Concurrent callers share one run; a
  /// failed pass stays failed for the session (no retry storm) — the canvas
  /// then falls back to its lazy load exactly as before.
  Future<void> call() => _pending ??= (_warmOverride ?? _warmPrograms)();

  Future<void> _warmPrograms() async {
    final lut = await lutProgram();
    final grade = await gradeProgram();
    // One white pixel serves every sampler slot: values are irrelevant,
    // only the pipeline build matters.
    final pixel = await _onePixel();
    try {
      await _rasterize(
        lut,
        pixel,
        // uSize(0,1), uLutSize(2), uMaskBlend(3), uSrcW(4), uSrcH(5),
        // uZoneLo(6), uZoneHi(7), uZebraMode(8), uTime(9), uZebraHigh(10), uZebraLow(11) —
        // must match the uniform contract in `shaders/lut.frag`.
        floats: const [1, 1, 1, 0, 1, 1, -1.0, -1.0, 0.0, 0.0, 0.98, 0.02],
        samplerCount: 2,
      );
      await _rasterize(
        grade,
        pixel,
        // uSize(0,1), uExposure(2), uContrast(3), uSaturation(4),
        // uTemperature(5), uTint(6), uVibrance(7), uHighlights(8), uShadows(9) —
        // matches `shaders/grade.frag` (see `edit/grade_mapping.dart`).
        floats: const [1, 1, 0, 0, 0, 0, 0, 0, 0, 0],
        samplerCount: 1,
      );
    } finally {
      pixel.dispose();
    }
  }

  /// Draws one 1×1 quad with [program] into an offscreen image. Rasterizing
  /// (not just painting) is what makes the engine create the pipeline now.
  static Future<void> _rasterize(
    ui.FragmentProgram program,
    ui.Image sampler, {
    required List<double> floats,
    required int samplerCount,
  }) async {
    final shader = program.fragmentShader();
    try {
      for (var i = 0; i < floats.length; i++) {
        shader.setFloat(i, floats[i]);
      }
      // The engine rejects a shader whose sampler slots are unset, so every
      // slot must be filled before the shader reaches a Paint.
      for (var i = 0; i < samplerCount; i++) {
        shader.setImageSampler(i, sampler);
      }
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 1, 1),
        Paint()..shader = shader,
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(1, 1);
      image.dispose();
      picture.dispose();
    } finally {
      shader.dispose();
    }
  }

  static Future<ui.Image> _onePixel() {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
      const Rect.fromLTWH(0, 0, 1, 1),
      Paint()..color = const Color(0xFFFFFFFF),
    );
    return recorder.endRecording().toImage(1, 1);
  }
}

/// Builds the app root: creates the [ShaderWarmup], kicks it **before the
/// first frame** (the splash covers the pipeline compile), and provides that
/// exact instance to the tree (issue #72). Extracted from `main()` so the
/// ordering seam is testable without a device.
ProviderScope bootstrapApp({
  ShaderWarmup? warmup,
  List<Override> overrides = const [],
  required Widget child,
}) {
  final shaderWarmup = warmup ?? ShaderWarmup();
  // Best-effort: a warmup failure must never block or crash-report startup —
  // every program still loads lazily through [lutProgramProvider] as before.
  shaderWarmup().ignore();
  return ProviderScope(
    overrides: [
      shaderWarmupProvider.overrideWithValue(shaderWarmup),
      ...overrides,
    ],
    child: child,
  );
}
