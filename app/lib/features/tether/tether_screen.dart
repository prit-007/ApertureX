import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/design_tokens.dart';
import 'tether_controller.dart';
import 'tether_hud.dart';

/// Professional Studio Tethered Capture screen.
class TetherScreen extends ConsumerWidget {
  const TetherScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tetherProvider);
    final notifier = ref.read(tetherProvider.notifier);
    final theme = Theme.of(context);
    final selected = state.selectedCapture;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Studio Tethered Capture'),
            Text(
              '${state.session.sessionName} · ${state.session.totalCaptures} photo(s)',
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
            ),
          ],
        ),
        actions: [
          IconButton(
            key: const Key('tether-connection-toggle-btn'),
            tooltip: state.isConnected ? 'Disconnect Camera' : 'Connect Camera',
            icon: Icon(
              state.isConnected ? Icons.usb : Icons.usb_off,
              color: state.isConnected ? Colors.green : Colors.grey,
            ),
            onPressed: () {
              if (state.isConnected) {
                notifier.disconnect();
              } else {
                notifier.connect();
              }
            },
          ),
          IconButton(
            key: const Key('tether-settings-btn'),
            tooltip: 'Session Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _showSessionSettings(context, ref),
          ),
          const SizedBox(width: Insets.sm),
        ],
      ),
      body: Column(
        children: [
          // Studio Telemetry HUD Bar
          const TetherHud(),

          // Main Live Loupe Viewport
          Expanded(
            child: Container(
              color: const Color(0xFF101010),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (selected != null)
                    Center(
                      child: selected.thumbnailBytes != null
                          ? Image.memory(selected.thumbnailBytes!, fit: BoxFit.contain)
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.raw_on, size: 80, color: Colors.white24),
                                const SizedBox(height: Insets.md),
                                Text(
                                  selected.filename,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: Insets.xs),
                                Text(
                                  selected.exifSummary,
                                  style: const TextStyle(
                                    color: Colors.white38,
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                    )
                  else
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            state.isConnected ? Icons.camera_alt_outlined : Icons.link_off,
                            size: 64,
                            color: Colors.white24,
                          ),
                          const SizedBox(height: Insets.md),
                          Text(
                            state.isConnected
                                ? 'Ready for Shutter Release'
                                : 'Camera Disconnected',
                            style: const TextStyle(color: Colors.white54, fontSize: 16),
                          ),
                          const SizedBox(height: Insets.xs),
                          Text(
                            state.isConnected
                                ? 'Press Capture button or release on camera'
                                : 'Connect USB 3.2 or Wi-Fi PTP to begin session',
                            style: const TextStyle(color: Colors.white30, fontSize: 12),
                          ),
                        ],
                      ),
                    ),

                  // Session status badge at bottom left
                  if (state.statusMessage != null)
                    Positioned(
                      bottom: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Text(
                          state.statusMessage!,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Bottom Filmstrip Carousel
          Container(
            height: 90,
            color: theme.colorScheme.surfaceContainerHighest,
            child: state.session.capturedFiles.isEmpty
                ? const Center(
                    child: Text(
                      'No captures yet in this session',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  )
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: Insets.xs),
                    itemCount: state.session.capturedFiles.length,
                    itemBuilder: (context, index) {
                      final item = state.session.capturedFiles[index];
                      final isSelected = item.id == selected?.id;

                      return GestureDetector(
                        onTap: () => notifier.selectCapture(item),
                        child: Container(
                          width: 80,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.image, size: 28, color: Colors.white38),
                              const SizedBox(height: 2),
                              Text(
                                '#${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                item.filename.split('.').first,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showSessionSettings(BuildContext context, WidgetRef ref) {
    final state = ref.read(tetherProvider);
    final notifier = ref.read(tetherProvider.notifier);

    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Insets.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Tether Session Settings',
                  style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: Insets.md),
                ListTile(
                  dense: true,
                  title: const Text('Session Name'),
                  subtitle: Text(state.session.sessionName),
                ),
                ListTile(
                  dense: true,
                  title: const Text('Destination Folder'),
                  subtitle: Text(state.session.destinationPath),
                ),
                SwitchListTile(
                  title: const Text('Auto-Select Latest Capture'),
                  value: state.session.autoSelectLatest,
                  onChanged: (v) => notifier.configureSession(autoSelectLatest: v),
                ),
                SwitchListTile(
                  title: const Text('Auto-Apply Active Edit Recipe'),
                  subtitle: const Text('Instantly grade incoming RAW captures'),
                  value: state.session.autoApplyRecipe,
                  onChanged: (v) => notifier.configureSession(autoApplyRecipe: v),
                ),
                const SizedBox(height: Insets.sm),
                OutlinedButton.icon(
                  onPressed: () {
                    notifier.clearSession();
                    Navigator.of(sheetContext).pop();
                  },
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Reset Session Captures'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
