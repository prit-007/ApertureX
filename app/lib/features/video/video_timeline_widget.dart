import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/design_tokens.dart';
import 'video_grading_controller.dart';
import 'video_model.dart';

/// Interactive timeline scrubber with In/Out trim handles, filmstrip track,
/// playhead cursor, and SMPTE timecode transport controls.
class VideoTimelineWidget extends ConsumerWidget {
  const VideoTimelineWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(videoGradingProvider);
    final notifier = ref.read(videoGradingProvider.notifier);
    final theme = Theme.of(context);

    final clip = state.clip;
    final playback = state.playback;
    final totalMs = clip.durationMs > 0 ? clip.durationMs : 1;
    final progress = (playback.positionMs / totalMs).clamp(0.0, 1.0);
    final inProgress = (clip.inPointMs / totalMs).clamp(0.0, 1.0);
    final outProgress = (clip.outPointMs / totalMs).clamp(0.0, 1.0);

    return Container(
      color: theme.colorScheme.surfaceContainerHigh,
      padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Timecode and Duration HUD
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                VideoClip.formatTimecode(playback.positionMs, fps: clip.fps),
                key: const Key('current-timecode-text'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
              Row(
                children: [
                  Text(
                    'Trim: ${VideoClip.formatTimecode(clip.trimmedDurationMs, fps: clip.fps)}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(width: Insets.sm),
                  Text(
                    '/ ${VideoClip.formatTimecode(clip.durationMs, fps: clip.fps)}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.outline,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: Insets.sm),

          // Filmstrip & Trim Timeline Bar
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
                  height: 48,
                  child: Stack(
                    children: [
                      // Filmstrip Track Background
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: theme.dividerColor),
                        ),
                        child: Row(
                          children: List.generate(
                            8,
                            (index) => Expanded(
                              child: Container(
                                margin: const EdgeInsets.all(1),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Trim Highlighted Region
                      Positioned(
                        left: inProgress * trackWidth,
                        width: ((outProgress - inProgress) * trackWidth).clamp(0.0, trackWidth),
                        top: 0,
                        bottom: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.18),
                            border: Border.symmetric(
                              horizontal: BorderSide(
                                color: theme.colorScheme.primary,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // In-Point Handle Bracket
                      Positioned(
                        left: (inProgress * trackWidth - 6).clamp(0.0, trackWidth - 12),
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 12,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: const BorderRadius.horizontal(left: Radius.circular(3)),
                          ),
                          child: const Center(
                            child: Icon(Icons.chevron_left, size: 10, color: Colors.white),
                          ),
                        ),
                      ),

                      // Out-Point Handle Bracket
                      Positioned(
                        left: (outProgress * trackWidth - 6).clamp(0.0, trackWidth - 12),
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 12,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: const BorderRadius.horizontal(right: Radius.circular(3)),
                          ),
                          child: const Center(
                            child: Icon(Icons.chevron_right, size: 10, color: Colors.white),
                          ),
                        ),
                      ),

                      // Playhead Needle
                      Positioned(
                        left: (progress * trackWidth - 1.5).clamp(0.0, trackWidth - 3),
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 3,
                          color: Colors.amberAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: Insets.sm),

          // Transport Buttons Row
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
