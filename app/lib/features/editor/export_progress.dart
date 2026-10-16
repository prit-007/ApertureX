import 'dart:async';

import 'package:flutter/material.dart';

/// The coarse stages of a full-res export, in the order they run:
/// original fetch → decode → Rust render (the long one) → gallery save.
/// Each phase floors the progress bar a little higher so the UI never
/// jumps backwards when a phase starts.
enum ExportPhase { loading, decoding, rendering, saving }

/// Human label for [phase], shown next to the bar in the editor.
String phaseLabel(ExportPhase phase) => switch (phase) {
  ExportPhase.loading => 'Loading',
  ExportPhase.decoding => 'Decoding',
  ExportPhase.rendering => 'Rendering',
  ExportPhase.saving => 'Saving',
};

/// Maps a phase + the engine's within-render fraction (0..1) to an overall
/// bar value in 0..1. The floors are ordered so the bar is monotonic:
/// loading→0.05, decoding→0.15, rendering→0.15..0.95, saving→1.0.
double exportOverall(ExportPhase phase, double renderFraction) {
  final f = renderFraction.clamp(0.0, 1.0);
  return switch (phase) {
    ExportPhase.loading => 0.05,
    ExportPhase.decoding => 0.15,
    ExportPhase.rendering => 0.15 + f * 0.80,
    ExportPhase.saving => 1.0,
  };
}

/// Polls a Rust cancel token's progress cell (permille 0..1000, see
/// `export_progress_get`) on a fixed interval and forwards 0..1 fractions
/// to [onValue]. Stopping drops any read still in flight.
class ExportProgressPoller {
  ExportProgressPoller({
    required this.token,
    required this.read,
    required this.onValue,
    this.interval = const Duration(milliseconds: 80),
  });

  /// The cancel token whose progress cell to poll (0 = never polls).
  final int token;

  /// Reads the current fraction (0..1) for [token]; injected so tests can
  /// fake it without the Rust engine.
  final Future<double> Function(int token) read;

  /// Receives each polled fraction (0..1).
  final void Function(double fraction) onValue;

  final Duration interval;

  Timer? _timer;
  var _stopped = false;

  /// Starts polling; a [token] of 0 (no cancellation / no progress cell)
  /// is a no-op so the caller can pass the token through unconditionally.
  void start() {
    if (token == 0 || _timer != null) return;
    _timer = Timer.periodic(interval, (_) async {
      if (_stopped) return;
      final fraction = await read(token);
      if (_stopped) return;
      onValue(fraction);
    });
  }

  /// Stops polling and drops in-flight reads.
  void stop() {
    _stopped = true;
    _timer?.cancel();
    _timer = null;
  }
}

/// Slim determinate/indeterminate progress strip with a phase label and a
/// percent readout. Used by the editor's full-res export; [value] null means
/// an indeterminate (marquee) bar. Implements [PreferredSize] so it can drop
/// straight into `Scaffold.bottom`.
class ExportProgressBar extends StatelessWidget implements PreferredSizeWidget {
  const ExportProgressBar({
    super.key,
    required this.label,
    this.value,
    this.onCancel,
  });

  final String label;

  /// 0..1, or null for indeterminate.
  final double? value;

  final VoidCallback? onCancel;

  @override
  Size get preferredSize => const Size.fromHeight(36);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: LinearProgressIndicator(value: value, minHeight: 4),
            ),
            const SizedBox(width: 12),
            Text(
              value == null ? '' : '${(value! * 100).round()}%',
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (onCancel != null) ...[
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Cancel export',
                visualDensity: VisualDensity.compact,
                iconSize: 18,
                onPressed: onCancel,
                icon: const Icon(Icons.close),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
