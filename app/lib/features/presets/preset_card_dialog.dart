import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/design_tokens.dart';
import '../../edit/look_qr_codec.dart';
import '../../edit/tool_definition.dart';
import '../../platform/photo_saver.dart';

/// Shows the Creator Preset QR Card export modal dialog.
Future<void> showPresetCardDialog(
  BuildContext context, {
  required ToolDefinition tool,
  String? author,
  Uint8List? previewImageBytes,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => PresetCardDialog(
      tool: tool,
      author: author,
      previewImageBytes: previewImageBytes,
    ),
  );
}

/// Modal dialog for rendering, previewing, and exporting social preset QR cards.
class PresetCardDialog extends ConsumerStatefulWidget {
  const PresetCardDialog({
    super.key,
    required this.tool,
    this.author,
    this.previewImageBytes,
  });

  final ToolDefinition tool;
  final String? author;
  final Uint8List? previewImageBytes;

  @override
  ConsumerState<PresetCardDialog> createState() => _PresetCardDialogState();
}

class _PresetCardDialogState extends ConsumerState<PresetCardDialog> {
  final GlobalKey _cardRepaintKey = GlobalKey();
  late final TextEditingController _titleController;
  late final TextEditingController _authorController;
  bool _isStoryRatio = false; // false = 1:1, true = 9:16
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.tool.name);
    _authorController = TextEditingController(text: widget.author ?? '@creator');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    super.dispose();
  }

  String get _currentQrUri {
    final updatedTool = ToolDefinition(
      name: _titleController.text.trim().isEmpty ? 'Look' : _titleController.text.trim(),
      description: widget.tool.description,
      params: widget.tool.params,
    );
    return LookQrCodec.encodeToUri(
      updatedTool,
      author: _authorController.text.trim().isEmpty ? null : _authorController.text.trim(),
    );
  }

  Future<Uint8List?> _captureCardBytes() async {
    try {
      final boundary = _cardRepaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<void> _shareCard() async {
    setState(() => _isExporting = true);
    try {
      final bytes = await _captureCardBytes();
      if (bytes != null) {
        final xFile = XFile.fromData(
          bytes,
          mimeType: 'image/png',
          name: '${_titleController.text.trim()}_preset_card.png',
        );
        await SharePlus.instance.share(
          ShareParams(
            files: [xFile],
            text: 'Check out my "${_titleController.text}" look on ApertureX!',
          ),
        );
      } else {
        await Clipboard.setData(ClipboardData(text: _currentQrUri));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Copied Look QR URI to clipboard')),
          );
        }
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: _currentQrUri));
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _saveCardToGallery() async {
    setState(() => _isExporting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await _captureCardBytes();
      if (bytes != null) {
        // gal keeps its historical name WITH the extension; the desktop
        // dialog opens with the same file name (#104 branch lives in
        // PhotoSaver — this dialog never calls gal directly).
        final cardName = '${_titleController.text.trim()}_card.png';
        final outcome = await ref.read(photoSaverProvider).saveBytes(
              bytes,
              name: cardName,
              desktopFileName: cardName,
            );
        if (outcome == null) return; // dialog cancelled — quietly abort
        messenger.showSnackBar(
          outcome is SavedToFile
              ? SnackBar(content: Text('Preset card saved to ${outcome.file.path}'))
              : const SnackBar(content: Text('Saved preset card to gallery!')),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not save to gallery: $e')),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final qrData = _currentQrUri;

    return Dialog(
      backgroundColor: scheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Share Preset Card',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: Insets.sm),
              // Aspect ratio toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ChoiceChip(
                    key: const Key('ratio-1-1'),
                    label: const Text('Square 1:1'),
                    selected: !_isStoryRatio,
                    onSelected: (val) {
                      if (val) setState(() => _isStoryRatio = false);
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    key: const Key('ratio-9-16'),
                    label: const Text('Story 9:16'),
                    selected: _isStoryRatio,
                    onSelected: (val) {
                      if (val) setState(() => _isStoryRatio = true);
                    },
                  ),
                ],
              ),
              const SizedBox(height: Insets.md),
              // Preset Card Preview
              Center(
                child: RepaintBoundary(
                  key: _cardRepaintKey,
                  child: Container(
                    width: 280,
                    height: _isStoryRatio ? 400 : 280,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          scheme.surfaceContainerHighest,
                          scheme.surfaceContainerLow,
                        ],
                      ),
                      image: widget.previewImageBytes != null
                          ? DecorationImage(
                              image: MemoryImage(widget.previewImageBytes!),
                              fit: BoxFit.cover,
                            )
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Subtle brand badge on top right
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.camera, size: 12, color: Colors.white70),
                                SizedBox(width: 4),
                                Text(
                                  'ApertureX',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Glass footer with title, author, and QR Code
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                              color: Colors.black.withValues(alpha: 0.78),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _titleController.text.trim().isEmpty
                                            ? 'Custom Preset'
                                            : _titleController.text.trim(),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _authorController.text.trim(),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.white.withValues(alpha: 0.8),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Scan in ApertureX to apply look',
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: Colors.white.withValues(alpha: 0.6),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // High-contrast QR matrix badge
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: QrImageView(
                                    data: qrData,
                                    version: QrVersions.auto,
                                    size: 64,
                                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                                    padding: EdgeInsets.zero,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Insets.lg),
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('save-card-button'),
                      onPressed: _isExporting ? null : _saveCardToGallery,
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('Save Card'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      key: const Key('share-card-button'),
                      onPressed: _isExporting ? null : _shareCard,
                      icon: const Icon(Icons.share, size: 18),
                      label: const Text('Share Card'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Insets.xs),
              TextButton.icon(
                key: const Key('copy-qr-uri-button'),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: qrData));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied Look QR URI to clipboard')),
                    );
                  }
                },
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy apx:// URI'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
