import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/design_tokens.dart';
import 'video_grading_controller.dart';
import 'video_model.dart';

/// Professional interactive timeline scrubber with multi-clip sequencing,
/// In/Out trim brackets, split/razor tool, ripple delete, duplicate, transition badges,
/// audio track indicator, and SMPTE transport controls.
class VideoTimelineWidget extends ConsumerWidget {
  const VideoTimelineWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(videoGradingProvider);
    final notifier = ref.read(videoGradingProvider.notifier);
    final theme = Theme.of(context);

    final sequence = state.sequence;
    final playback = state.playback;
    final totalMs = sequence.totalDurationMs > 0 ? sequence.totalDurationMs : 1;
    final progress = (playback.positionMs / totalMs).clamp(0.0, 1.0);

    return Container(
      color: theme.colorScheme.surfaceContainerHigh,
      padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Timecode HUD and Quick Timeline Actions (Split, Duplicate, Delete)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    VideoClip.formatTimecode(playback.positionMs, fps: state.clip.fps),
                    key: const Key('current-timecode-text'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(width: Insets.sm),
                  Text(
                    '/ ${VideoClip.formatTimecode(totalMs, fps: state.clip.fps)}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.outline,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),

              // Razor and Clip Management Action Group
              Wrap(
                spacing: 4,
                children: [
                  IconButton.filledTonal(
                    key: const Key('split-clip-btn'),
                    tooltip: 'Split Active Clip at Playhead (Razor)',
                    icon: const Icon(Icons.content_cut, size: 18),
                    visualDensity: VisualDensity.compact,
                    onPressed: notifier.splitActiveClip,
                  ),
                  IconButton.filledTonal(
                    key: const Key('duplicate-clip-btn'),
                    tooltip: 'Duplicate Active Clip',
                    icon: const Icon(Icons.copy, size: 18),
                    visualDensity: VisualDensity.compact,
                    onPressed: notifier.duplicateActiveClip,
                  ),
                  IconButton.filledTonal(
                    key: const Key('delete-clip-btn'),
                    tooltip: 'Ripple Delete Active Clip',
                    icon: const Icon(Icons.delete_outline, size: 18),
                    visualDensity: VisualDensity.compact,
                    onPressed: sequence.clips.length > 1
                        ? notifier.deleteActiveClip
                        : null,
                  ),
                  PopupMenuButton<double>(
                    key: const Key('speed-ramp-btn'),
                    tooltip: 'Clip Speed Ramping',
                    initialValue: state.clip.speed,
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 0.25, child: Text('0.25x (Super Slow-Mo)')),
                      PopupMenuItem(value: 0.5, child: Text('0.5x (Slow-Mo)')),
                      PopupMenuItem(value: 0.75, child: Text('0.75x')),
                      PopupMenuItem(value: 1.0, child: Text('1.0x (Normal)')),
                      PopupMenuItem(value: 1.5, child: Text('1.5x')),
                      PopupMenuItem(value: 2.0, child: Text('2.0x (Fast Forward)')),
                      PopupMenuItem(value: 4.0, child: Text('4.0x (Hyperlapse)')),
                    ],
                    onSelected: notifier.setActiveClipSpeed,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: Text(
                        '${state.clip.speed}x',
                        style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                    key: const Key('reverse-clip-btn'),
                    tooltip: 'Reverse Clip Playback',
                    icon: Icon(
                      Icons.history,
                      size: 18,
                      color: state.clip.isReversed ? theme.colorScheme.primary : null,
                    ),
                    visualDensity: VisualDensity.compact,
                    onPressed: notifier.toggleActiveClipReverse,
                  ),
                  IconButton.filledTonal(
                    key: const Key('add-clip-btn'),
                    tooltip: 'Append New Clip to Sequence',
                    icon: const Icon(Icons.add_to_photos_outlined, size: 18),
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      final newClip = VideoClip(
                        id: 'clip_${DateTime.now().millisecondsSinceEpoch}',
                        path: '/media/extra.mp4',
                        title: 'Clip ${sequence.clipCount + 1}',
                        durationMs: 5000,
                        fps: 30.0,
                      );
                      notifier.addClip(newClip);
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: Insets.sm),

          // Row 2: Multi-Clip Sequence Visual Track
          LayoutBuilder(
            builder: (context, constraints) {
              final trackWidth = constraints.maxWidth;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: (details) {
                  final localX = details.localPosition.dx.clamp(0.0, trackWidth);
                  final ratio = localX / trackWidth;
                  notifier.seekTo((ratio * totalMs).round());
                },
                onTapDown: (details) {
                  final localX = details.localPosition.dx.clamp(0.0, trackWidth);
                  final ratio = localX / trackWidth;
                  notifier.seekTo((ratio * totalMs).round());
                },
                child: SizedBox(
                  height: 52,
                  child: Stack(
                    children: [
                      // Multi-Clip Sequence Track Blocks
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < sequence.clips.length; i++) ...[
                            Expanded(
                              flex: (sequence.clips[i].effectiveDurationMs).clamp(1, 1000000),
                              child: GestureDetector(
                                onTap: () => notifier.selectClip(i),
                                child: Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 1),
                                  decoration: BoxDecoration(
                                    color: i == state.activeClipIndex
                                        ? theme.colorScheme.primary.withValues(alpha: 0.22)
                                        : Colors.white.withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: i == state.activeClipIndex
                                          ? theme.colorScheme.primary
                                          : theme.dividerColor,
                                      width: i == state.activeClipIndex ? 2 : 1,
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        sequence.clips[i].title.isNotEmpty
                                            ? sequence.clips[i].title
                                            : 'Clip ${i + 1}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: i == state.activeClipIndex
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: i == state.activeClipIndex
                                              ? theme.colorScheme.primary
                                              : Colors.white70,
                                        ),
                                      ),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '${(sequence.clips[i].effectiveDurationMs / 1000).toStringAsFixed(1)}s',
                                            style: const TextStyle(
                                              fontSize: 8,
                                              color: Colors.white38,
                                              fontFamily: 'monospace',
                                            ),
                                          ),
                                          if (sequence.clips[i].audio.isMuted)
                                            const Icon(Icons.volume_off, size: 10, color: Colors.redAccent)
                                          else if (sequence.clips[i].audio.volume > 1.0)
                                            const Icon(Icons.volume_up, size: 10, color: Colors.amberAccent),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // Transition Badge Button between clips
                            if (i < sequence.clips.length - 1)
                              PopupMenuButton<VideoTransitionType>(
                                tooltip: 'Clip Transition',
                                initialValue: i < sequence.transitions.length
                                    ? sequence.transitions[i].type
                                    : VideoTransitionType.none,
                                itemBuilder: (context) => [
                                  for (final t in VideoTransitionType.values)
                                    PopupMenuItem(
                                      value: t,
                                      child: Text(t.label),
                                    ),
                                ],
                                onSelected: (type) {
                                  notifier.setTransition(
                                    i,
                                    VideoTransition(type: type, durationMs: 500),
                                  );
                                },
                                child: Container(
                                  width: 14,
                                  height: 24,
                                  margin: const EdgeInsets.symmetric(vertical: 14),
                                  decoration: BoxDecoration(
                                    color: (i < sequence.transitions.length &&
                                            sequence.transitions[i].type != VideoTransitionType.none)
                                        ? theme.colorScheme.tertiary
                                        : Colors.white24,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.shuffle, size: 9, color: Colors.white),
                                  ),
                                ),
                              ),
                          ],
                        ],
                      ),

                      // Scrubbing Playhead Needle
                      Positioned(
                        left: (progress * trackWidth - 1.5).clamp(0.0, trackWidth - 3),
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 3,
                          decoration: BoxDecoration(
                            color: Colors.amberAccent,
                            borderRadius: BorderRadius.circular(1.5),
                            boxShadow: const [
                              BoxShadow(color: Colors.black45, blurRadius: 3),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: Insets.xs),

          // Row 3: Audio track overview indicator
          Row(
            children: [
              Icon(
                state.clip.audio.isMuted ? Icons.volume_off : Icons.graphic_eq,
                size: 14,
                color: state.clip.audio.isMuted ? Colors.redAccent : theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'Audio: ${state.clip.audio.isMuted ? 'Muted' : '${(state.clip.audio.volume * 100).round()}% (${state.clip.audio.audioGainDb >= 0 ? '+' : ''}${state.clip.audio.audioGainDb.toStringAsFixed(1)} dB)'}',
                style: theme.textTheme.labelSmall?.copyWith(color: Colors.white60),
              ),
              if (state.clip.audio.fadeInMs > 0 || state.clip.audio.fadeOutMs > 0) ...[
                const SizedBox(width: 8),
                Text(
                  'Fade: In ${state.clip.audio.fadeInMs}ms / Out ${state.clip.audio.fadeOutMs}ms',
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.tertiary),
                ),
              ],
            ],
          ),
          const SizedBox(height: Insets.sm),

          // Row 4: Transport Controls Row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                key: const Key('mark-in-btn'),
                tooltip: 'Mark In Point (I)',
                icon: const Icon(Icons.start, size: 20),
                onPressed: () => notifier.setInPoint(playback.positionMs),
              ),
              IconButton(
                key: const Key('step-back-btn'),
                tooltip: 'Step 1 Frame Back',
                icon: const Icon(Icons.skip_previous, size: 22),
                onPressed: notifier.stepFrameBackward,
              ),
              FilledButton.tonalIcon(
                key: const Key('play-pause-btn'),
                onPressed: notifier.togglePlay,
                icon: Icon(playback.isPlaying ? Icons.pause : Icons.play_arrow),
                label: Text(playback.isPlaying ? 'Pause' : 'Play'),
              ),
              IconButton(
                key: const Key('step-fwd-btn'),
                tooltip: 'Step 1 Frame Forward',
                icon: const Icon(Icons.skip_next, size: 22),
                onPressed: notifier.stepFrameForward,
              ),
              IconButton(
                key: const Key('mark-out-btn'),
                tooltip: 'Mark Out Point (O)',
                icon: const Icon(Icons.stop_circle_outlined, size: 20),
                onPressed: () => notifier.setOutPoint(playback.positionMs),
              ),
              const SizedBox(width: Insets.sm),
              IconButton(
                key: const Key('loop-toggle-btn'),
                tooltip: 'Toggle Loop Playback',
                icon: Icon(
                  Icons.repeat,
                  size: 20,
                  color: playback.isLooping ? theme.colorScheme.primary : null,
                ),
                onPressed: notifier.toggleLoop,
              ),
              PopupMenuButton<double>(
                key: const Key('speed-selector-btn'),
                tooltip: 'Playback Speed',
                initialValue: playback.speed,
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 0.5, child: Text('0.5x (Slow)')),
                  PopupMenuItem(value: 1.0, child: Text('1.0x (Normal)')),
                  PopupMenuItem(value: 2.0, child: Text('2.0x (Fast)')),
                ],
                onSelected: notifier.setSpeed,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    '${playback.speed}x',
                    style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
