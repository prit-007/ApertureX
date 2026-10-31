import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/design_tokens.dart';
import 'tether_controller.dart';

/// Top studio camera telemetry bar and remote shutter release trigger.
class TetherHud extends ConsumerWidget {
  const TetherHud({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tetherProvider);
    final notifier = ref.read(tetherProvider.notifier);
    final theme = Theme.of(context);
    final telemetry = state.telemetry;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          // Connection Status Indicator
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: state.isConnected ? Colors.greenAccent.shade400 : Colors.redAccent,
              boxShadow: state.isConnected
                  ? [
                      BoxShadow(
                        color: Colors.greenAccent.withValues(alpha: 0.5),
                        blurRadius: 6,
                        spreadRadius: 1,
                      )
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: Insets.sm),

          // Scrollable telemetry details
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Camera Model Pill
                  Chip(
                    avatar: const Icon(Icons.camera_alt, size: 16),
                    label: Text(
                      telemetry.cameraModel,
                      style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: Insets.md),

                  // Live Exposure Telemetry Pills
                  _buildTelemetryPill(
                    context,
                    label: 'SS',
                    value: telemetry.shutterSpeed,
                    key: const Key('telemetry-shutter-text'),
                  ),
                  const SizedBox(width: Insets.xs),
                  _buildTelemetryPill(
                    context,
                    label: 'F',
                    value: telemetry.aperture,
                    key: const Key('telemetry-aperture-text'),
                  ),
                  const SizedBox(width: Insets.xs),
                  _buildTelemetryPill(
                    context,
                    label: 'ISO',
                    value: '${telemetry.iso}',
                    key: const Key('telemetry-iso-text'),
                  ),
                  const SizedBox(width: Insets.md),

                  // Battery & Storage Info
                  Row(
                    children: [
                      Icon(
                        telemetry.batteryPercent > 20 ? Icons.battery_full : Icons.battery_alert,
                        size: 18,
                        color: telemetry.batteryPercent > 20 ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${telemetry.batteryPercent}%',
                        style: theme.textTheme.labelSmall?.copyWith(fontFamily: 'monospace'),
                      ),
                      const SizedBox(width: Insets.sm),
                      Text(
                        '${telemetry.shotsRemaining} left',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.outline,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: Insets.md),

          // Remote Shutter Release Trigger
          FilledButton.icon(
            key: const Key('remote-shutter-btn'),
            style: FilledButton.styleFrom(
              backgroundColor: state.isShutterTriggered ? Colors.amber : Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: state.isConnected && !state.isShutterTriggered
                ? () {
                    HapticFeedback.heavyImpact();
                    notifier.triggerShutter();
                  }
                : null,
            icon: state.isShutterTriggered
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.radio_button_checked, size: 18),
            label: Text(state.isShutterTriggered ? 'Exposing…' : 'Capture'),
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryPill(
    BuildContext context, {
    required String label,
    required String value,
    required Key key,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label ',
            style: TextStyle(
              fontSize: 10,
              color: theme.colorScheme.outline,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            value,
            key: key,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
