import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/log/activity_log.dart';
import '../../core/log/log_providers.dart';
import '../../core/theme/design_tokens.dart';
import '../../edit/look_qr_codec.dart';
import '../../edit/recipe_controller.dart';
import '../../ui/common/app_sheet.dart';
import '../../ui/common/paste_button.dart';
import 'qr_image_decoder.dart';

/// Modal bottom sheet to scan, pick, or paste an ApertureX Look QR code.
class QrScannerSheet extends ConsumerStatefulWidget {
  const QrScannerSheet({super.key});

  @override
  ConsumerState<QrScannerSheet> createState() => _QrScannerSheetState();
}

class _QrScannerSheetState extends ConsumerState<QrScannerSheet> {
  final TextEditingController _textController = TextEditingController();
  LookQrPayload? _decodedPayload;
  String? _errorMessage;
  bool _isProcessing = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _parseText() {
    setState(() {
      _errorMessage = null;
      _decodedPayload = null;
    });

    final input = _textController.text.trim();
    if (input.isEmpty) {
      setState(() => _errorMessage = 'Please enter or paste a QR code string or URI');
      return;
    }

    final payload = QrImageDecoder.decodeLookString(input);
    if (payload != null) {
      setState(() => _decodedPayload = payload);
    } else {
      setState(() => _errorMessage = 'Could not find a valid look in the provided text.');
    }
  }

  Future<void> _pickImage() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
      );

      if (picked != null) {
        final bytes = await picked.readAsBytes();
        final payload = QrImageDecoder.decodeFromImageBytes(bytes);
        if (payload != null) {
          setState(() => _decodedPayload = payload);
        } else {
          setState(() => _errorMessage = 'No QR code or ApertureX Look found in the selected image.');
        }
      }
    } catch (e) {
      setState(() => _errorMessage = 'Failed to read image: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _applyLook() {
    if (_decodedPayload == null) return;
    final tool = _decodedPayload!.toToolDefinition();
    ref.read(recipeControllerProvider.notifier).applyTool(tool);
    ref.read(recipeControllerProvider.notifier).commit(label: 'Look: ${tool.name}');
    axLog(LogDomain.preset, 'Applied Look from QR: "${tool.name}"');
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: AppSheet(
        title: 'Scan / Import Look',
        subtitle: 'Scan a QR code from your gallery or paste an open apx:// look.',
        children: [
        // Screenshot / Image Picker button
        Card(
          elevation: 0,
          color: scheme.surfaceContainerHigh,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.qr_code_scanner, color: scheme.onPrimaryContainer),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Scan from Screenshot / Image',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Pick an image from your gallery or Reddit/Instagram download',
                            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  key: const Key('pick-image-qr-button'),
                  onPressed: _isProcessing ? null : _pickImage,
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.photo_library, size: 18),
                  label: const Text('Choose Photo or Screenshot'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Insets.md),
        // Direct text/URI input
        Row(
          children: [
            Expanded(child: Divider(color: scheme.outlineVariant.withValues(alpha: 0.5))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'OR PASTE URI / JSON',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            Expanded(child: Divider(color: scheme.outlineVariant.withValues(alpha: 0.5))),
          ],
        ),
        const SizedBox(height: Insets.sm),
        TextField(
          key: const Key('qr-text-input'),
          controller: _textController,
          maxLines: 2,
          style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
          decoration: InputDecoration(
            hintText: 'Paste apx://look/v1?... or Look JSON',
            suffixIcon: PasteButton(controller: _textController),
          ),
        ),
        const SizedBox(height: Insets.xs),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            key: const Key('parse-qr-text-button'),
            onPressed: _parseText,
            icon: const Icon(Icons.check, size: 16),
            label: const Text('Parse String'),
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: Insets.sm),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, size: 18, color: scheme.onErrorContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(fontSize: 12, color: scheme.onErrorContainer),
                  ),
                ),
              ],
            ),
          ),
        ],
        // Decoded Look Preview Card
        if (_decodedPayload != null) ...[
          const SizedBox(height: Insets.md),
          Card(
            color: scheme.primaryContainer.withValues(alpha: 0.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: scheme.primary),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _decodedPayload!.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                      if (_decodedPayload!.author != null)
                        Flexible(
                          child: Text(
                            'by ${_decodedPayload!.author!}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: scheme.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (_decodedPayload!.description != null &&
                      _decodedPayload!.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      _decodedPayload!.description!,
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    'PARAMETERS (${_decodedPayload!.params.length})',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final entry in _decodedPayload!.params.entries.take(8))
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text(
                            '${entry.key}: ${entry.value >= 0 ? '+' : ''}${entry.value.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      if (_decodedPayload!.params.length > 8)
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text(
                            '+${_decodedPayload!.params.length - 8} more',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    key: const Key('apply-decoded-look-button'),
                    onPressed: _applyLook,
                    icon: const Icon(Icons.auto_fix_high),
                    label: Text('Apply "${_decodedPayload!.name}" to Photo'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    ),
  );
  }
}
