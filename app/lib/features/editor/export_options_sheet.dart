import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';
import '../../ui/common/app_sheet.dart';

enum ExportAction {
  saveToApertureX,
  saveToPhotos,
  saveDngWithXmp,
  share,
}

/// Action sheet shown when the user taps "Export" in the editor (#85, #79).
class ExportOptionsSheet extends StatelessWidget {
  const ExportOptionsSheet({super.key, this.isRaw = false});

  final bool isRaw;

  static Future<ExportAction?> show(BuildContext context, {bool isRaw = false}) {
    return showAppSheet<ExportAction>(
      context,
      ExportOptionsSheet(isRaw: isRaw),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Insets.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.xs),
                child: Text(
                  'Export & Save',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.auto_fix_high_outlined),
                title: const Text('Save to ApertureX'),
                subtitle: const Text('Render and index in the in-app Edits gallery'),
                onTap: () => Navigator.of(context).pop(ExportAction.saveToApertureX),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Save to Photos'),
                subtitle: const Text('Full-resolution JPEG with XMP sidecar to device'),
                onTap: () => Navigator.of(context).pop(ExportAction.saveToPhotos),
              ),
              if (isRaw)
                ListTile(
                  leading: const Icon(Icons.raw_on_outlined),
                  title: const Text('Export DNG (Lossless + Edits)'),
                  subtitle: const Text('Original raw CFA sensor data with injected XMP recipe'),
                  onTap: () => Navigator.of(context).pop(ExportAction.saveDngWithXmp),
                ),
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: const Text('Share…'),
                subtitle: const Text('Share image and XMP sidecar with other apps'),
                onTap: () => Navigator.of(context).pop(ExportAction.share),
              ),
              const SizedBox(height: Insets.sm),
            ],
          ),
        ),
      ),
    );
  }
}
