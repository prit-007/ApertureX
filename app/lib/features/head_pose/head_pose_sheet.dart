import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/log/activity_log.dart';
import '../../core/log/log_providers.dart';
import '../../core/theme/design_tokens.dart';
import '../../engine/engine.dart';

/// Sheet for interactive facial orientation and expression adjustment.
class HeadPoseSheet extends ConsumerStatefulWidget {
  const HeadPoseSheet({
    super.key,
    required this.rgba,
    required this.width,
    required this.height,
    this.onApplied,
  });

  final Uint8List rgba;
  final int width;
  final int height;
  final void Function(Uint8List modifiedRgba)? onApplied;

  @override
  ConsumerState<HeadPoseSheet> createState() => _HeadPoseSheetState();
}

class _HeadPoseSheetState extends ConsumerState<HeadPoseSheet> {
  double _yaw = 0.0;
  double _pitch = 0.0;
  double _roll = 0.0;
  double _smile = 0.0;
  double _pupilDistance = 0.0;

  bool _isProcessing = false;
  String? _errorMessage;

  Future<void> _apply() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final out = await AxEngine.adjustHeadPose(
        rgba: widget.rgba,
        width: widget.width,
        height: widget.height,
        deltaYaw: _yaw,
        deltaPitch: _pitch,
        deltaRoll: _roll,
        smile: _smile,
        pupilDistance: _pupilDistance,
      );
      if (mounted) {
        widget.onApplied?.call(out);
        Navigator.of(context).pop(out);
      }
    } catch (e, st) {
      axLog(
        LogDomain.engine,
        'Head pose adjustment failed: $e',
        level: LogLevel.error,
        error: e.toString(),
        stack: st.toString(),
      );
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isProcessing = false;
        });
      }
    }
  }

  void _reset() {
    setState(() {
      _yaw = 0.0;
      _pitch = 0.0;
      _roll = 0.0;
      _smile = 0.0;
      _pupilDistance = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Head Pose & Face',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: _reset,
                    child: const Text('Reset'),
                  ),
                ],
              ),
              const SizedBox(height: Insets.sm),
              _buildSlider('Yaw (Turn)', _yaw, -30.0, 30.0, (v) => setState(() => _yaw = v)),
              _buildSlider('Pitch (Tilt)', _pitch, -20.0, 20.0, (v) => setState(() => _pitch = v)),
              _buildSlider('Roll (Rotate)', _roll, -20.0, 20.0, (v) => setState(() => _roll = v)),
              _buildSlider('Smile', _smile, 0.0, 1.0, (v) => setState(() => _smile = v)),
              _buildSlider('Pupil Distance', _pupilDistance, -1.0, 1.0, (v) => setState(() => _pupilDistance = v)),
              if (_errorMessage != null) ...[
                const SizedBox(height: Insets.sm),
                Text(
                  _errorMessage!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: Insets.md),
              FilledButton.icon(
                onPressed: _isProcessing ? null : _apply,
                icon: _isProcessing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.face_retouching_natural_outlined),
                label: Text(_isProcessing ? 'Applying…' : 'Apply Pose'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Expanded(
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              value.toStringAsFixed(1),
              textAlign: TextAlign.end,
              style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}
