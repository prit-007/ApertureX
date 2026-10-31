import 'package:flutter_test/flutter_test.dart';

import 'package:aperturex/features/video/video_model.dart';

void main() {
  group('VideoAudioSettings', () {
    test('computes volume, mute state, and gain in dB correctly', () {
      const audio = VideoAudioSettings(
        volume: 1.0,
        isMuted: false,
        fadeInMs: 500,
        fadeOutMs: 1000,
      );

      expect(audio.volume, 1.0);
      expect(audio.isMuted, isFalse);
      expect(audio.audioGainDb, closeTo(0.0, 0.01));
      expect(audio.fadeInMs, 500);
      expect(audio.fadeOutMs, 1000);

      // Volume doubling is ~+6dB
      final boosted = audio.copyWith(volume: 2.0);
      expect(boosted.audioGainDb, closeTo(6.02, 0.05));

      // Volume at 0 is -60dB minimum floor
      final silent = audio.copyWith(volume: 0.0);
      expect(silent.audioGainDb, -60.0);
    });
  });

  group('VideoTransform & VideoFramingPreset', () {
    test('provides standard aspect ratios and transform options', () {
      expect(VideoFramingPreset.ratio16x9.aspectRatio, closeTo(16.0 / 9.0, 0.001));
      expect(VideoFramingPreset.ratio9x16.aspectRatio, closeTo(9.0 / 16.0, 0.001));
      expect(VideoFramingPreset.ratio1x1.aspectRatio, 1.0);
      expect(VideoFramingPreset.ratio4x5.aspectRatio, 0.8);
      expect(VideoFramingPreset.ratio21x9.aspectRatio, closeTo(21.0 / 9.0, 0.001));

      const transform = VideoTransform(
        framing: VideoFramingPreset.ratio9x16,
        fitMode: VideoFitMode.fill,
        rotationDegrees: 90,
        flipHorizontal: true,
        scale: 1.25,
      );

      expect(transform.framing, VideoFramingPreset.ratio9x16);
      expect(transform.fitMode, VideoFitMode.fill);
      expect(transform.rotationDegrees, 90);
      expect(transform.flipHorizontal, isTrue);
      expect(transform.flipVertical, isFalse);
      expect(transform.scale, 1.25);

      final rotated = transform.rotateClockwise();
      expect(rotated.rotationDegrees, 180);
      final rotatedAgain = rotated.rotateClockwise().rotateClockwise();
      expect(rotatedAgain.rotationDegrees, 0);
    });
  });

  group('VideoTextOverlay', () {
    test('manages visibility window and styling', () {
      const overlay = VideoTextOverlay(
        id: 'title-1',
        text: 'ApertureX Cinematic Reel',
        startMs: 1000,
        durationMs: 3000,
        position: VideoTextPosition.lowerThird,
        animation: VideoTextAnimation.fadeIn,
        fontSize: 26.0,
      );

      expect(overlay.endMs, 4000);
      expect(overlay.isVisibleAt(500), isFalse);
      expect(overlay.isVisibleAt(1000), isTrue);
      expect(overlay.isVisibleAt(2500), isTrue);
      expect(overlay.isVisibleAt(4000), isTrue);
      expect(overlay.isVisibleAt(4001), isFalse);
    });
  });

  group('KeyframeTrack', () {
    test('interpolates values between keyframes smoothly', () {
      const track = KeyframeTrack(
        property: 'exposure',
        keyframes: [
          VideoKeyframe(timeMs: 0, value: 0.0),
          VideoKeyframe(timeMs: 2000, value: 1.0),
          VideoKeyframe(timeMs: 6000, value: -1.0),
        ],
      );

      expect(track.evaluateAt(-500, 0.0), 0.0);
      expect(track.evaluateAt(0, 0.0), 0.0);
      expect(track.evaluateAt(1000, 0.0), closeTo(0.5, 0.01));
      expect(track.evaluateAt(2000, 0.0), 1.0);
      expect(track.evaluateAt(4000, 0.0), closeTo(0.0, 0.01));
      expect(track.evaluateAt(6000, 0.0), -1.0);
      expect(track.evaluateAt(8000, 0.0), -1.0);
    });
  });

  group('VideoSequence & Multi-clip Editing', () {
    const clipA = VideoClip(
      id: 'clip-a',
      path: '/media/a.mp4',
      title: 'Scene A',
      durationMs: 6000,
      inPointMs: 0,
      outPointMs: 6000,
    );

    const clipB = VideoClip(
      id: 'clip-b',
      path: '/media/b.mp4',
      title: 'Scene B',
      durationMs: 4000,
      inPointMs: 0,
      outPointMs: 4000,
    );

    test('calculates total sequence duration and maps sequence time to clip', () {
      final seq = VideoSequence(
        id: 'seq-1',
        clips: const [clipA, clipB],
      );

      expect(seq.totalDurationMs, 10000);
      expect(seq.clipCount, 2);

      // Sequence time 2500ms -> clipA at 2500ms
      final mapA = seq.mapSequenceTimeToClip(2500);
      expect(mapA.clipIndex, 0);
      expect(mapA.localMs, 2500);

      // Sequence time 7000ms -> clipB at 1000ms (7000 - 6000 = 1000)
      final mapB = seq.mapSequenceTimeToClip(7000);
      expect(mapB.clipIndex, 1);
      expect(mapB.localMs, 1000);
    });

    test('splits clip at timestamp (Razor tool)', () {
      final seq = VideoSequence(
        id: 'seq-1',
        clips: const [clipA],
      );

      // Split clipA (6000ms) at local 2000ms
      final splitSeq = seq.splitClip(0, 2000);

      expect(splitSeq.clipCount, 2);
      expect(splitSeq.clips[0].trimmedDurationMs, 2000);
      expect(splitSeq.clips[0].inPointMs, 0);
      expect(splitSeq.clips[0].outPointMs, 2000);

      expect(splitSeq.clips[1].trimmedDurationMs, 4000);
      expect(splitSeq.clips[1].inPointMs, 2000);
      expect(splitSeq.clips[1].outPointMs, 6000);

      expect(splitSeq.totalDurationMs, 6000);
    });

    test('supports ripple delete, duplication, and reordering', () {
      var seq = VideoSequence(
        id: 'seq-1',
        clips: const [clipA, clipB],
      );

      // Duplicate clipB
      seq = seq.duplicateClip(1);
      expect(seq.clipCount, 3);
      expect(seq.clips[2].title, contains('Scene B'));

      // Reorder: move clipA (index 0) to end (index 2)
      seq = seq.reorderClip(0, 2);
      expect(seq.clips[0].title, contains('Scene B'));
      expect(seq.clips[2].title, 'Scene A');

      // Ripple delete middle clip
      seq = seq.removeClip(1);
      expect(seq.clipCount, 2);
    });

    test('manages transitions between clips', () {
      var seq = VideoSequence(
        id: 'seq-1',
        clips: const [clipA, clipB],
      );

      expect(seq.transitions.length, 1);
      expect(seq.transitions[0].type, VideoTransitionType.none);

      seq = seq.setTransition(
        0,
        const VideoTransition(
          type: VideoTransitionType.crossDissolve,
          durationMs: 750,
        ),
      );

      expect(seq.transitions[0].type, VideoTransitionType.crossDissolve);
      expect(seq.transitions[0].durationMs, 750);
    });
  });
}
