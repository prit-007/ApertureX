import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../color/cube_lut.dart';
import '../../color/grade_spec.dart';
import '../../edit/recipe.dart';
import '../../engine/engine.dart';
import 'video_model.dart';

/// Combined state for video playback, timeline sequence, and color grading.
class VideoGradingState {
  const VideoGradingState({
    required this.sequence,
    this.activeClipIndex = 0,
    this.playback = const VideoPlaybackState(),
    this.recipe = EditRecipe.neutral,
    this.isScrubbing = false,
    this.selectedOverlayId,
  });

  final VideoSequence sequence;
  final int activeClipIndex;
  final VideoPlaybackState playback;
  final EditRecipe recipe;
  final bool isScrubbing;
  final String? selectedOverlayId;

  /// Convenience getter for currently active clip in the sequence.
  VideoClip get clip {
    if (sequence.clips.isEmpty) {
      return const VideoClip(id: 'empty', path: '');
    }
    final index = activeClipIndex.clamp(0, sequence.clips.length - 1);
    return sequence.clips[index];
  }

  VideoGradingState copyWith({
    VideoSequence? sequence,
    int? activeClipIndex,
    VideoPlaybackState? playback,
    EditRecipe? recipe,
    bool? isScrubbing,
    String? selectedOverlayId,
    bool clearSelectedOverlay = false,
  }) {
    return VideoGradingState(
      sequence: sequence ?? this.sequence,
      activeClipIndex: activeClipIndex ?? this.activeClipIndex,
      playback: playback ?? this.playback,
      recipe: recipe ?? this.recipe,
      isScrubbing: isScrubbing ?? this.isScrubbing,
      selectedOverlayId: clearSelectedOverlay
          ? null
          : (selectedOverlayId ?? this.selectedOverlayId),
    );
  }
}

/// Provider managing multi-clip video playback, timeline trim, transitions, and color grading.
final videoGradingProvider =
    NotifierProvider<VideoGradingController, VideoGradingState>(
  VideoGradingController.new,
);

class VideoGradingController extends Notifier<VideoGradingState> {
  Timer? _playbackTimer;

  @override
  VideoGradingState build() {
    ref.onDispose(() {
      _playbackTimer?.cancel();
    });

    const defaultClip = VideoClip(
      id: 'demo_clip',
      path: '',
      title: 'Demo Reel',
      durationMs: 15000, // 15 seconds
      fps: 30.0,
      width: 1920,
      height: 1080,
    );

    final defaultSequence = VideoSequence(
      id: 'seq_demo',
      title: 'Demo Reel Project',
      clips: const [defaultClip],
    );

    return VideoGradingState(
      sequence: defaultSequence,
      activeClipIndex: 0,
      playback: const VideoPlaybackState(outPointMs: 15000),
      recipe: EditRecipe.neutral,
    );
  }

  void loadClip(VideoClip clip) {
    _playbackTimer?.cancel();
    final newSequence = VideoSequence(
      id: 'seq_${clip.id}',
      title: clip.title.isNotEmpty ? clip.title : 'Project Sequence',
      clips: [clip],
    );

    state = state.copyWith(
      sequence: newSequence,
      activeClipIndex: 0,
      playback: VideoPlaybackState(
        positionMs: clip.inPointMs,
        inPointMs: clip.inPointMs,
        outPointMs: clip.outPointMs,
      ),
    );
  }

  void loadSequence(VideoSequence sequence) {
    _playbackTimer?.cancel();
    state = state.copyWith(
      sequence: sequence,
      activeClipIndex: 0,
      playback: VideoPlaybackState(
        positionMs: 0,
        inPointMs: 0,
        outPointMs: sequence.totalDurationMs,
      ),
    );
  }

  void selectClip(int index) {
    if (index < 0 || index >= state.sequence.clips.length) return;
    state = state.copyWith(activeClipIndex: index);
  }

  void addClip(VideoClip clip) {
    final updatedSeq = state.sequence.addClip(clip);
    state = state.copyWith(
      sequence: updatedSeq,
      playback: state.playback.copyWith(outPointMs: updatedSeq.totalDurationMs),
    );
  }

  void splitActiveClip() {
    if (state.sequence.clips.isEmpty) return;
    final timeMap = state.sequence.mapSequenceTimeToClip(state.playback.positionMs);
    final clip = state.sequence.clips[timeMap.clipIndex];
    final localMs = timeMap.localMs;

    // Must be strictly within clip bounds
    if (localMs <= clip.inPointMs || localMs >= clip.outPointMs) return;

    final updatedSeq = state.sequence.splitClip(timeMap.clipIndex, localMs);
    state = state.copyWith(
      sequence: updatedSeq,
      activeClipIndex: (timeMap.clipIndex + 1).clamp(0, updatedSeq.clips.length - 1),
    );
  }

  void deleteActiveClip() {
    if (state.sequence.clips.length <= 1) return;
    final currentIndex = state.activeClipIndex;
    final updatedSeq = state.sequence.removeClip(currentIndex);
    final newIndex = currentIndex >= updatedSeq.clips.length
        ? updatedSeq.clips.length - 1
        : currentIndex;

    state = state.copyWith(
      sequence: updatedSeq,
      activeClipIndex: newIndex,
      playback: state.playback.copyWith(
        outPointMs: updatedSeq.totalDurationMs,
        positionMs: state.playback.positionMs.clamp(0, updatedSeq.totalDurationMs),
      ),
    );
  }

  void duplicateActiveClip() {
    if (state.sequence.clips.isEmpty) return;
    final currentIndex = state.activeClipIndex;
    final updatedSeq = state.sequence.duplicateClip(currentIndex);
    state = state.copyWith(
      sequence: updatedSeq,
      activeClipIndex: currentIndex + 1,
      playback: state.playback.copyWith(outPointMs: updatedSeq.totalDurationMs),
    );
  }

  void reorderClip(int oldIndex, int newIndex) {
    final updatedSeq = state.sequence.reorderClip(oldIndex, newIndex);
    state = state.copyWith(
      sequence: updatedSeq,
      activeClipIndex: newIndex.clamp(0, updatedSeq.clips.length - 1),
    );
  }

  void setTransition(int index, VideoTransition transition) {
    final updatedSeq = state.sequence.setTransition(index, transition);
    state = state.copyWith(sequence: updatedSeq);
  }

  // --- Audio Tools ---

  void updateActiveClipAudio(VideoAudioSettings audio) {
    final updatedClip = state.clip.copyWith(audio: audio);
    final updatedSeq = state.sequence.updateClip(state.activeClipIndex, updatedClip);
    state = state.copyWith(sequence: updatedSeq);
  }

  void setVolume(double volume) {
    final clamped = volume.clamp(0.0, 2.0);
    updateActiveClipAudio(state.clip.audio.copyWith(volume: clamped));
  }

  void toggleMute() {
    updateActiveClipAudio(state.clip.audio.copyWith(isMuted: !state.clip.audio.isMuted));
  }

  void setFadeIn(int ms) {
    updateActiveClipAudio(state.clip.audio.copyWith(fadeInMs: ms.clamp(0, 5000)));
  }

  void setFadeOut(int ms) {
    updateActiveClipAudio(state.clip.audio.copyWith(fadeOutMs: ms.clamp(0, 5000)));
  }

  // --- Transform & Spatial Tools ---

  void updateActiveClipTransform(VideoTransform transform) {
    final updatedClip = state.clip.copyWith(transform: transform);
    final updatedSeq = state.sequence.updateClip(state.activeClipIndex, updatedClip);
    state = state.copyWith(sequence: updatedSeq);
  }

  void rotateActiveClip() {
    updateActiveClipTransform(state.clip.transform.rotateClockwise());
  }

  void toggleFlipH() {
    updateActiveClipTransform(state.clip.transform.toggleFlipH());
  }

  void toggleFlipV() {
    updateActiveClipTransform(state.clip.transform.toggleFlipV());
  }

  void setFraming(VideoFramingPreset preset) {
    final updatedSeq = state.sequence.copyWith(globalFraming: preset);
    state = state.copyWith(sequence: updatedSeq);
  }

  void setFitMode(VideoFitMode fitMode) {
    updateActiveClipTransform(state.clip.transform.copyWith(fitMode: fitMode));
  }

  void setScale(double scale) {
    updateActiveClipTransform(state.clip.transform.copyWith(scale: scale.clamp(0.5, 3.0)));
  }

  // --- Text Overlay Tools ---

  void addTextOverlay(VideoTextOverlay overlay) {
    final updatedSeq = state.sequence.addOverlay(overlay);
    state = state.copyWith(sequence: updatedSeq, selectedOverlayId: overlay.id);
  }

  void updateTextOverlay(VideoTextOverlay overlay) {
    final updatedSeq = state.sequence.updateOverlay(overlay);
    state = state.copyWith(sequence: updatedSeq);
  }

  void removeTextOverlay(String id) {
    final updatedSeq = state.sequence.removeOverlay(id);
    state = state.copyWith(
      sequence: updatedSeq,
      clearSelectedOverlay: state.selectedOverlayId == id,
    );
  }

  void selectOverlay(String? id) {
    state = state.copyWith(selectedOverlayId: id, clearSelectedOverlay: id == null);
  }

  // --- Speed & Reverse ---

  void setActiveClipSpeed(double speed) {
    final clamped = speed.clamp(0.25, 8.0);
    final updatedClip = state.clip.copyWith(speed: clamped);
    final updatedSeq = state.sequence.updateClip(state.activeClipIndex, updatedClip);
    state = state.copyWith(
      sequence: updatedSeq,
      playback: state.playback.copyWith(outPointMs: updatedSeq.totalDurationMs),
    );
  }

  void toggleActiveClipReverse() {
    final updatedClip = state.clip.copyWith(isReversed: !state.clip.isReversed);
    final updatedSeq = state.sequence.updateClip(state.activeClipIndex, updatedClip);
    state = state.copyWith(sequence: updatedSeq);
  }

  // --- Playback & Transport ---

  void togglePlay() {
    if (state.playback.isPlaying) {
      pause();
    } else {
      play();
    }
  }

  void play() {
    if (state.playback.isPlaying) return;
    _playbackTimer?.cancel();

    // If at or past outPoint, wrap to inPoint
    var pos = state.playback.positionMs;
    final maxDuration = state.sequence.totalDurationMs > 0
        ? state.sequence.totalDurationMs
        : state.clip.outPointMs;

    if (pos >= maxDuration) {
      pos = state.clip.inPointMs;
    }

    state = state.copyWith(
      playback: state.playback.copyWith(isPlaying: true, positionMs: pos),
    );

    const intervalMs = 33; // ~30 fps tick
    _playbackTimer = Timer.periodic(const Duration(milliseconds: intervalMs), (_) {
      tick((intervalMs * state.playback.speed).round());
    });
  }

  void pause() {
    _playbackTimer?.cancel();
    _playbackTimer = null;
    state = state.copyWith(
      playback: state.playback.copyWith(isPlaying: false),
    );
  }

  void tick(int elapsedMs) {
    if (!state.playback.isPlaying) return;

    var newPos = state.playback.positionMs + elapsedMs;
    final maxDuration = state.sequence.totalDurationMs > 0
        ? state.sequence.totalDurationMs
        : state.clip.outPointMs;
    final inPt = state.clip.inPointMs;

    if (newPos >= maxDuration) {
      if (state.playback.isLooping) {
        newPos = inPt;
      } else {
        newPos = maxDuration;
        pause();
      }
    }

    final timeMap = state.sequence.mapSequenceTimeToClip(newPos);

    state = state.copyWith(
      activeClipIndex: timeMap.clipIndex,
      playback: state.playback.copyWith(positionMs: newPos),
    );
  }

  void seekTo(int positionMs) {
    final maxDuration = state.sequence.totalDurationMs > 0
        ? state.sequence.totalDurationMs
        : state.clip.durationMs;
    final clamped = positionMs.clamp(0, maxDuration);
    final timeMap = state.sequence.mapSequenceTimeToClip(clamped);

    state = state.copyWith(
      activeClipIndex: timeMap.clipIndex,
      playback: state.playback.copyWith(positionMs: clamped),
    );
  }

  void stepFrameForward() {
    pause();
    final frameDurationMs = (1000.0 / state.clip.fps).round();
    seekTo(state.playback.positionMs + frameDurationMs);
  }

  void stepFrameBackward() {
    pause();
    final frameDurationMs = (1000.0 / state.clip.fps).round();
    seekTo(state.playback.positionMs - frameDurationMs);
  }

  void setInPoint(int ms) {
    final clamped = ms.clamp(0, state.clip.outPointMs);
    final updatedClip = state.clip.copyWith(inPointMs: clamped);
    final updatedSeq = state.sequence.updateClip(state.activeClipIndex, updatedClip);
    final currentPos = state.playback.positionMs < clamped
        ? clamped
        : state.playback.positionMs;

    state = state.copyWith(
      sequence: updatedSeq,
      playback: state.playback.copyWith(
        inPointMs: clamped,
        positionMs: currentPos,
      ),
    );
  }

  void setOutPoint(int ms) {
    final clamped = ms.clamp(state.clip.inPointMs, state.clip.durationMs);
    final updatedClip = state.clip.copyWith(outPointMs: clamped);
    final updatedSeq = state.sequence.updateClip(state.activeClipIndex, updatedClip);
    final currentPos = state.playback.positionMs > clamped
        ? clamped
        : state.playback.positionMs;

    state = state.copyWith(
      sequence: updatedSeq,
      playback: state.playback.copyWith(
        outPointMs: clamped,
        positionMs: currentPos,
      ),
    );
  }

  void toggleLoop() {
    state = state.copyWith(
      playback: state.playback.copyWith(isLooping: !state.playback.isLooping),
    );
  }

  void setSpeed(double speed) {
    state = state.copyWith(
      playback: state.playback.copyWith(speed: speed),
    );
  }

  void updateRecipe(EditRecipe recipe) {
    state = state.copyWith(recipe: recipe);
  }

  void resetGrade() {
    state = state.copyWith(recipe: EditRecipe.neutral);
  }

  Future<String> exportCubeLut({int size = 33, String? title}) async {
    final lutTitle = (title != null && title.isNotEmpty)
        ? title
        : (state.clip.title.isNotEmpty ? state.clip.title : 'ApertureX Video Grade');

    try {
      final spec = GradeSpec.fromRecipe(state.recipe);
      return await AxEngine.exportCubeLut(
        spec,
        size: size,
        title: lutTitle,
      );
    } catch (_) {
      // Pure Dart fallback for headless/test environments
      final n = size;
      final data = Float32List(n * n * n * 3);
      final inv = 1.0 / (n - 1);
      final ev = (1 << state.recipe.exposure.round().clamp(-4, 4)).toDouble();
      for (var b = 0; b < n; b++) {
        for (var g = 0; g < n; g++) {
          for (var r = 0; r < n; r++) {
            final idx = (r + g * n + b * n * n) * 3;
            data[idx] = (r * inv * ev).clamp(0.0, 1.0);
            data[idx + 1] = (g * inv * ev).clamp(0.0, 1.0);
            data[idx + 2] = (b * inv * ev).clamp(0.0, 1.0);
          }
        }
      }
      final lut = CubeLut(size: n, data: data, title: lutTitle);
      return lut.toCubeText(title: lutTitle);
    }
  }
}
