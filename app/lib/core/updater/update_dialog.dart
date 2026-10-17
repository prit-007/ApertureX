import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/theme/design_tokens.dart';
import 'app_update_model.dart';
import 'app_updater.dart';

/// Interactive modal dialog for previewing release changelog and downloading updates.
class UpdateDialog extends StatefulWidget {
  final AppReleaseInfo release;

  const UpdateDialog({
    super.key,
    required this.release,
  });

  /// Displays the update dialog modally.
  static Future<void> show(BuildContext context, AppReleaseInfo release) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => UpdateDialog(release: release),
    );
  }

  /// Convenience checker: triggers update query and either prompts dialog or shows confirmation.
  static Future<void> checkAndShow(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Checking for updates…'),
        duration: Duration(seconds: 2),
      ),
    );

    final release = await AppUpdater.checkForUpdate();
    if (!context.mounted) return;

    if (release != null) {
      messenger.hideCurrentSnackBar();
      await UpdateDialog.show(context, release);
    } else {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text('ApertureX is up to date (v${AppUpdater.currentVersion})'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0.0;
  int _receivedBytes = 0;
  int _totalBytes = 0;
  File? _downloadedFile;
  String? _errorMessage;

  String _formatSize(int bytes) {
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  Future<void> _startDownload() async {
    final apkUrl = widget.release.apkDownloadUrl;
    if (apkUrl == null) {
      setState(() => _errorMessage = 'No direct APK asset attached to this release.');
      return;
    }

    setState(() {
      _isDownloading = true;
      _errorMessage = null;
      _progress = 0.0;
    });

    try {
      final tempDir = await getTemporaryDirectory();
      final targetPath = '${tempDir.path}/aperturex-${widget.release.version}.apk';

      final file = await AppUpdater.downloadApk(
        apkUrl,
        destinationPath: targetPath,
        onProgress: (received, total) {
          if (mounted) {
            setState(() {
              _receivedBytes = received;
              _totalBytes = total;
              if (total > 0) {
                _progress = received / total;
              }
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadedFile = file;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _errorMessage = 'Download failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final release = widget.release;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titlePadding: const EdgeInsets.fromLTRB(Insets.lg, Insets.lg, Insets.lg, Insets.xs),
      contentPadding: const EdgeInsets.symmetric(horizontal: Insets.lg, vertical: Insets.xs),
      actionsPadding: const EdgeInsets.all(Insets.md),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(Insets.xs + 2),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.system_update, color: scheme.onPrimaryContainer, size: 24),
          ),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Update Available',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Current: v${AppUpdater.currentVersion}',
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: Insets.xs + 2, vertical: 4),
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: Radii.pillAll,
            ),
            child: Text(
              release.tagName,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(height: 16),
            if (release.apkSizeBytes != null) ...[
              Row(
                children: [
                  Icon(Icons.inventory_2_outlined, size: 16, color: scheme.onSurfaceVariant),
                  const SizedBox(width: Insets.xs),
                  Text(
                    _formatSize(release.apkSizeBytes!),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Insets.xs),
            ],
            Text(
              "What's New:",
              style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: Insets.xs),
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              padding: const EdgeInsets.all(Insets.sm),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SingleChildScrollView(
                child: Text(
                  release.changelog.isNotEmpty
                      ? release.changelog
                      : 'Performance improvements and bug fixes.',
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                ),
              ),
            ),
            if (_isDownloading) ...[
              const SizedBox(height: Insets.md),
              LinearProgressIndicator(
                value: _progress > 0 ? _progress : null,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: Insets.xs),
              Row(
                children: [
                  Text(
                    'Downloading update…',
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const Spacer(),
                  if (_totalBytes > 0)
                    Text(
                      '${(_progress * 100).toInt()}% (${_formatSize(_receivedBytes)} / ${_formatSize(_totalBytes)})',
                      style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                ],
              ),
            ],
            if (_downloadedFile != null) ...[
              const SizedBox(height: Insets.sm),
              Row(
                children: [
                  Icon(Icons.check_circle, color: scheme.primary, size: 18),
                  const SizedBox(width: Insets.xs),
                  Expanded(
                    child: Text(
                      'Download complete! Ready to install.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: Insets.sm),
              Text(
                _errorMessage!,
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isDownloading ? null : () => Navigator.of(context).pop(),
          child: const Text('Later'),
        ),
        if (_downloadedFile != null)
          FilledButton.icon(
            icon: const Icon(Icons.install_mobile, size: 18),
            label: const Text('Install Now'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          )
        else
          FilledButton(
            onPressed: _isDownloading ? null : _startDownload,
            child: Text(_isDownloading ? 'Downloading…' : 'Update Now'),
          ),
      ],
    );
  }
}
