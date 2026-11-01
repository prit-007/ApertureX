import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/design_tokens.dart';
import '../../edit/recipe.dart';
import '../../engine/engine.dart';
import '../../settings/export_branding_settings.dart';
import '../../settings/export_settings.dart';
import 'export_options_sheet.dart' show ExportAction;

/// Professional Material 3 Export Studio Screen.
///
/// Features interactive live watermarking preview, resolution calculations,
/// Lightroom-aligned image sizing, output sharpening, professional typography &
/// logo watermarking, C2PA provenance signing, and multi-format export.
class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({
    super.key,
    this.previewBytes,
    this.isRaw = false,
    this.recipe,
    this.sourceWidth = 4032,
    this.sourceHeight = 3024,
  });

  final Uint8List? previewBytes;
  final bool isRaw;
  final EditRecipe? recipe;
  final int sourceWidth;
  final int sourceHeight;

  /// Helper to push [ExportScreen] into navigation.
  static Future<ExportAction?> open(
    BuildContext context, {
    Uint8List? previewBytes,
    bool isRaw = false,
    EditRecipe? recipe,
    int sourceWidth = 4032,
    int sourceHeight = 3024,
  }) {
    return Navigator.of(context).push<ExportAction>(
      MaterialPageRoute(
        builder: (_) => ExportScreen(
          previewBytes: previewBytes,
          isRaw: isRaw,
          recipe: recipe,
          sourceWidth: sourceWidth,
          sourceHeight: sourceHeight,
        ),
      ),
    );
  }

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  late final TextEditingController _signatureController;
  late final TextEditingController _tiledController;
  late final TextEditingController _exif1Controller;
  late final TextEditingController _exif2Controller;
  late final TextEditingController _patternController;
  late final TextEditingController _customDimController;

  String _selectedFormat = 'jpeg'; // jpeg, png, tiff16, dng
  bool _watermarkSectionExpanded = true;
  bool _sizingSectionExpanded = false;
  bool _sharpenSectionExpanded = false;
  bool _metadataSectionExpanded = false;
  bool _namingSectionExpanded = false;
  bool _isRenderingLivePreview = false;
  bool _showWatermarkOnPreview = true;
  Uint8List? _livePreviewJpg;

  @override
  void initState() {
    super.initState();
    final branding = ref.read(exportBrandingProvider);
    final settings = ref.read(exportSettingsProvider);

    _signatureController = TextEditingController(text: branding.signatureText);
    _tiledController = TextEditingController(text: branding.tiledText);
    _exif1Controller = TextEditingController(text: branding.exifLine1);
    _exif2Controller = TextEditingController(text: branding.exifLine2);
    _patternController = TextEditingController(text: settings.filenamePattern);
    _customDimController = TextEditingController(
      text: settings.resizeDimension.toString(),
    );

    _selectedFormat = branding.format;
    _scheduleLivePreviewRender();
  }

  @override
  void dispose() {
    _signatureController.dispose();
    _tiledController.dispose();
    _exif1Controller.dispose();
    _exif2Controller.dispose();
    _patternController.dispose();
    _customDimController.dispose();
    super.dispose();
  }

  Future<void> _scheduleLivePreviewRender() async {
    final preview = widget.previewBytes;
    if (preview == null || !mounted) return;
    setState(() => _isRenderingLivePreview = true);

    try {
      final branding = ref.read(exportBrandingProvider);
      if (!_showWatermarkOnPreview ||
          (!branding.enableSignature &&
              !branding.enableLogo &&
              !branding.enableMuseumFrame &&
              !branding.enableTiledWatermark &&
              !branding.enableFossBadge)) {
        setState(() {
          _livePreviewJpg = preview;
          _isRenderingLivePreview = false;
        });
        return;
      }

      final decoded = await AxEngine.decodeAnalysisProxy(preview);
      final rustBranding = branding.toRustBrandingSpec();
      final branded = await AxEngine.renderBrandingPreview(
        rgba: decoded.rgba,
        width: decoded.width,
        height: decoded.height,
        branding: rustBranding,
      );

      final encoded = await AxEngine.encodeJpegRgba(
        rgba: branded.rgba,
        width: branded.width,
        height: branded.height,
        quality: 85,
        exif: Uint8List(0),
      );

      if (!mounted) return;
      setState(() {
        _livePreviewJpg = encoded;
        _isRenderingLivePreview = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _livePreviewJpg = widget.previewBytes;
          _isRenderingLivePreview = false;
        });
      }
    }
  }

  Future<void> _pickLogoImage() async {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
    );
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      ref.read(exportBrandingProvider.notifier).setLogo(
        enabled: true,
        bytes: bytes,
        path: picked.name,
      );
      _scheduleLivePreviewRender();
    }
  }

  void _onExportTriggered() {
    switch (_selectedFormat) {
      case 'png':
        Navigator.of(context).pop(ExportAction.savePng);
        break;
      case 'tiff16':
        Navigator.of(context).pop(ExportAction.saveTiff16);
        break;
      case 'dng':
        Navigator.of(context).pop(ExportAction.saveDngWithXmp);
        break;
      case 'jpeg':
      default:
        Navigator.of(context).pop(ExportAction.saveToPhotos);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final exportSettings = ref.watch(exportSettingsProvider);
    final brandingSettings = ref.watch(exportBrandingProvider);

    final targetDim = exportSettings.computeDimensions(
      widget.sourceWidth,
      widget.sourceHeight,
    );
    final estSize = exportSettings.estimateFileSize(
      width: targetDim.width,
      height: targetDim.height,
      format: _selectedFormat,
    );

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Export Studio',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              '${_selectedFormat.toUpperCase()} • ${targetDim.width}×${targetDim.height} px • $estSize',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share Image',
            onPressed: () => Navigator.of(context).pop(ExportAction.share),
          ),
          IconButton(
            icon: const Icon(Icons.schedule_send_outlined),
            tooltip: 'Background Export Queue',
            onPressed: () =>
                Navigator.of(context).pop(ExportAction.backgroundExport),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 840;
          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 5,
                  child: Container(
                    color: colorScheme.surfaceContainerLowest,
                    child: _buildPreviewPane(theme, targetDim, estSize),
                  ),
                ),
                VerticalDivider(width: 1, color: colorScheme.outlineVariant),
                Expanded(
                  flex: 5,
                  child: _buildControlsPane(
                    theme,
                    exportSettings,
                    brandingSettings,
                    targetDim,
                    estSize,
                  ),
                ),
              ],
            );
          } else {
            return Column(
              children: [
                SizedBox(
                  height: constraints.maxHeight * 0.35,
                  child: Container(
                    color: colorScheme.surfaceContainerLowest,
                    child: _buildPreviewPane(theme, targetDim, estSize),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _buildControlsPane(
                    theme,
                    exportSettings,
                    brandingSettings,
                    targetDim,
                    estSize,
                  ),
                ),
              ],
            );
          }
        },
      ),
      bottomNavigationBar: _buildBottomActionBar(
        theme,
        targetDim,
        estSize,
      ),
    );
  }

  Widget _buildPreviewPane(
    ThemeData theme,
    ({int width, int height}) targetDim,
    String estSize,
  ) {
    final previewBytes = _livePreviewJpg ?? widget.previewBytes;
    final branding = ref.watch(exportBrandingProvider);
    final hasActiveBranding = branding.enableSignature ||
        branding.enableLogo ||
        branding.enableMuseumFrame ||
        branding.enableTiledWatermark ||
        branding.enableFossBadge;

    return Stack(
      alignment: Alignment.center,
      children: [
        if (previewBytes != null)
          Center(
            child: Image.memory(
              previewBytes,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Icon(
                Icons.broken_image_outlined,
                size: 64,
                color: Colors.grey,
              ),
            ),
          )
        else
          const Center(
            child: Icon(Icons.image_outlined, size: 64, color: Colors.grey),
          ),

        if (_isRenderingLivePreview)
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Updating watermark…',
                    style: TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),

        // Live HUD overlay tags
        Positioned(
          top: 12,
          left: 12,
          child: Wrap(
            spacing: 6,
            children: [
              _buildHudChip('${targetDim.width}×${targetDim.height}', Icons.aspect_ratio),
              _buildHudChip(estSize, Icons.data_usage_outlined),
              if (hasActiveBranding)
                _buildHudChip('Watermark On', Icons.branding_watermark, active: true),
            ],
          ),
        ),

        // Bottom preview controls
        Positioned(
          bottom: 12,
          right: 12,
          child: Material(
            color: Colors.black.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                setState(() => _showWatermarkOnPreview = !_showWatermarkOnPreview);
                _scheduleLivePreviewRender();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _showWatermarkOnPreview
                          ? Icons.visibility
                          : Icons.visibility_off,
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _showWatermarkOnPreview ? 'Hide Watermark' : 'Show Watermark',
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHudChip(String label, IconData icon, {bool active = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: active ? Colors.amber.shade900.withValues(alpha: 0.85) : Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsPane(
    ThemeData theme,
    ExportSettings exportSettings,
    ExportBrandingSettings branding,
    ({int width, int height}) targetDim,
    String estSize,
  ) {
    final exportNotifier = ref.read(exportSettingsProvider.notifier);
    final brandingNotifier = ref.read(exportBrandingProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Pro Export Presets Quick Bar
          Text(
            'QUICK PROFILES',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final preset in ExportPresetKind.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      avatar: const Icon(Icons.bolt, size: 14),
                      label: Text(preset.title),
                      onPressed: () {
                        exportNotifier.applyPreset(preset);
                        if (preset == ExportPresetKind.clientProof) {
                          brandingNotifier.applyWatermarkPreset(WatermarkPreset.clientProof);
                        }
                        _scheduleLivePreviewRender();
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Insets.md),

          // 2. Format & Quality Panel
          _buildCard(
            theme: theme,
            title: 'File Settings & Format',
            icon: Icons.photo_camera_back_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<String>(
                  segments: [
                    const ButtonSegment(value: 'jpeg', label: Text('JPEG')),
                    const ButtonSegment(value: 'png', label: Text('PNG')),
                    const ButtonSegment(value: 'tiff16', label: Text('TIFF 16-bit')),
                    if (widget.isRaw)
                      const ButtonSegment(value: 'dng', label: Text('RAW DNG')),
                  ],
                  selected: {_selectedFormat},
                  onSelectionChanged: (set) {
                    setState(() => _selectedFormat = set.first);
                    brandingNotifier.setFormat(set.first);
                  },
                ),
                const SizedBox(height: Insets.sm),
                if (_selectedFormat == 'jpeg') ...[
                  Row(
                    children: [
                      Text(
                        'Quality: ${exportSettings.quality}%',
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      Text(
                        exportSettings.quality >= 90
                            ? 'Maximum Quality'
                            : exportSettings.quality >= 80
                                ? 'High Quality'
                                : 'Standard Web',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: exportSettings.quality.toDouble(),
                    min: 60,
                    max: 100,
                    divisions: 40,
                    onChanged: (val) {
                      exportNotifier.setQuality(val.round());
                    },
                  ),
                ],

                // Color Space (sRGB / Display-P3)
                Row(
                  children: [
                    const Icon(Icons.palette_outlined, size: 16),
                    const SizedBox(width: Insets.xs),
                    Text(
                      'Color Space:',
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: Insets.sm),
                    ChoiceChip(
                      label: const Text('sRGB (Web)'),
                      selected: exportSettings.colorSpace == 0,
                      onSelected: (s) {
                        if (s) exportNotifier.setColorSpace(0);
                      },
                    ),
                    const SizedBox(width: Insets.xs),
                    ChoiceChip(
                      label: const Text('Display-P3 (WCG)'),
                      selected: exportSettings.colorSpace == 1,
                      onSelected: (s) {
                        if (s) exportNotifier.setColorSpace(1);
                      },
                    ),
                  ],
                ),

                // Ultra HDR Gain Map
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.hdr_on_outlined),
                  title: const Text('Ultra HDR (ISO 21496-1)'),
                  subtitle: const Text('Embedded gain map for OLED screens & HDR displays'),
                  value: exportSettings.ultraHdr,
                  onChanged: (enabled) => exportNotifier.setUltraHdr(enabled),
                ),
                if (exportSettings.ultraHdr)
                  Row(
                    children: [
                      Text('Headroom: +${exportSettings.hdrHeadroom.toStringAsFixed(1)} EV'),
                      Expanded(
                        child: Slider(
                          value: exportSettings.hdrHeadroom,
                          min: 1.0,
                          max: 4.0,
                          divisions: 30,
                          onChanged: (val) => exportNotifier.setHdrHeadroom(val),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: Insets.sm),

          // 3. Image Sizing Panel
          _buildCollapsibleCard(
            theme: theme,
            title: 'Image Sizing',
            subtitle: '${targetDim.width} × ${targetDim.height} px',
            icon: Icons.photo_size_select_large_outlined,
            isExpanded: _sizingSectionExpanded,
            onToggle: () => setState(() => _sizingSectionExpanded = !_sizingSectionExpanded),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 6,
                  children: [
                    for (final mode in ExportResizeMode.values)
                      ChoiceChip(
                        label: Text(mode.label),
                        selected: exportSettings.resizeMode == mode,
                        onSelected: (selected) {
                          if (selected) {
                            exportNotifier.setResizeMode(mode);
                          }
                        },
                      ),
                  ],
                ),
                const SizedBox(height: Insets.sm),
                if (exportSettings.resizeMode == ExportResizeMode.longEdge ||
                    exportSettings.resizeMode == ExportResizeMode.shortEdge) ...[
                  Row(
                    children: [
                      Text('${exportSettings.resizeMode.label}: ${exportSettings.resizeDimension} px'),
                      const Spacer(),
                      Wrap(
                        spacing: 4,
                        children: [
                          for (final px in [1080, 2048, 3840])
                            ActionChip(
                              label: Text('$px px'),
                              onPressed: () {
                                exportNotifier.setResizeMode(
                                  exportSettings.resizeMode,
                                  dimension: px,
                                );
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                  Slider(
                    value: exportSettings.resizeDimension.toDouble().clamp(640, 8000),
                    min: 640,
                    max: 8000,
                    divisions: 100,
                    onChanged: (val) {
                      exportNotifier.setResizeMode(
                        exportSettings.resizeMode,
                        dimension: val.round(),
                      );
                    },
                  ),
                ],
                if (exportSettings.resizeMode == ExportResizeMode.percentage)
                  Row(
                    children: [
                      Text('Scale: ${exportSettings.resizePercentage}%'),
                      Expanded(
                        child: Slider(
                          value: exportSettings.resizePercentage.toDouble(),
                          min: 10,
                          max: 100,
                          divisions: 18,
                          onChanged: (val) {
                            exportNotifier.setResizeMode(
                              ExportResizeMode.percentage,
                              percentage: val.round(),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Don't Enlarge"),
                  subtitle: const Text('Prevent upscaling if original is smaller'),
                  value: exportSettings.dontEnlarge,
                  onChanged: (val) => exportNotifier.setDontEnlarge(val),
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.sm),

          // 4. Output Sharpening
          _buildCollapsibleCard(
            theme: theme,
            title: 'Output Sharpening',
            subtitle: exportSettings.outputSharpenMedia == 0
                ? 'Off'
                : exportSettings.outputSharpenMedia == 1
                    ? 'Screen (${(exportSettings.outputSharpen * 100).round()}%)'
                    : 'Print (${(exportSettings.outputSharpen * 100).round()}%)',
            icon: Icons.details_outlined,
            isExpanded: _sharpenSectionExpanded,
            onToggle: () => setState(() => _sharpenSectionExpanded = !_sharpenSectionExpanded),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 6,
                  children: [
                    ChoiceChip(
                      label: const Text('None'),
                      selected: exportSettings.outputSharpenMedia == 0,
                      onSelected: (s) {
                        if (s) exportNotifier.setOutputSharpen(media: 0, amount: 0.0);
                      },
                    ),
                    ChoiceChip(
                      label: const Text('Screen'),
                      selected: exportSettings.outputSharpenMedia == 1,
                      onSelected: (s) {
                        if (s) exportNotifier.setOutputSharpen(media: 1, amount: 0.5);
                      },
                    ),
                    ChoiceChip(
                      label: const Text('Matte Paper'),
                      selected: exportSettings.outputSharpenMedia == 2,
                      onSelected: (s) {
                        if (s) exportNotifier.setOutputSharpen(media: 2, amount: 0.6);
                      },
                    ),
                    ChoiceChip(
                      label: const Text('Glossy Paper'),
                      selected: exportSettings.outputSharpenMedia == 3,
                      onSelected: (s) {
                        if (s) exportNotifier.setOutputSharpen(media: 3, amount: 0.6);
                      },
                    ),
                  ],
                ),
                if (exportSettings.outputSharpenMedia != 0) ...[
                  const SizedBox(height: Insets.sm),
                  Row(
                    children: [
                      Text('Amount: ${(exportSettings.outputSharpen * 100).round()}%'),
                      Expanded(
                        child: Slider(
                          value: exportSettings.outputSharpen,
                          min: 0.1,
                          max: 1.0,
                          divisions: 18,
                          onChanged: (val) => exportNotifier.setOutputSharpen(amount: val),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: Insets.sm),

          // 5. Pro Watermarking & Branding Studio (The Core Request!)
          _buildCollapsibleCard(
            theme: theme,
            title: 'Watermarking & Branding Studio',
            subtitle: branding.enableSignature
                ? 'Signature (${branding.signatureText.isEmpty ? "Active" : branding.signatureText})'
                : branding.enableLogo
                    ? 'PNG Logo Active'
                    : branding.enableTiledWatermark
                        ? 'Tiled Proof Grid'
                        : branding.enableMuseumFrame
                            ? 'Museum Frame Mat'
                            : 'Off',
            icon: Icons.branding_watermark_outlined,
            isExpanded: _watermarkSectionExpanded,
            onToggle: () => setState(() => _watermarkSectionExpanded = !_watermarkSectionExpanded),
            child: _buildWatermarkStudio(theme, branding, brandingNotifier),
          ),
          const SizedBox(height: Insets.sm),

          // 6. Metadata & Privacy
          _buildCollapsibleCard(
            theme: theme,
            title: 'Metadata & Privacy',
            subtitle: exportSettings.metadataMode.label,
            icon: Icons.security_outlined,
            isExpanded: _metadataSectionExpanded,
            onToggle: () => setState(() => _metadataSectionExpanded = !_metadataSectionExpanded),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final mode in ExportMetadataMode.values)
                      ChoiceChip(
                        label: Text(mode.label),
                        selected: exportSettings.metadataMode == mode,
                        onSelected: (selected) {
                          if (selected) exportNotifier.setMetadataMode(mode);
                        },
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Insets.xs),
                  child: Text(
                    exportSettings.metadataMode.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const Divider(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.fingerprint),
                  title: const Text('C2PA Content Credentials'),
                  subtitle: const Text('Embed tamper-evident cryptographic provenance in APP11'),
                  value: branding.enableC2pa,
                  onChanged: (val) => brandingNotifier.setC2pa(val),
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.sm),

          // 7. Filename Template
          _buildCollapsibleCard(
            theme: theme,
            title: 'File Naming Template',
            subtitle: exportSettings.formatFilename(
              original: 'IMG_4021',
              preset: 'graded',
              outWidth: targetDim.width,
              outHeight: targetDim.height,
            ),
            icon: Icons.label_outlined,
            isExpanded: _namingSectionExpanded,
            onToggle: () => setState(() => _namingSectionExpanded = !_namingSectionExpanded),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _patternController,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Template Pattern',
                    hintText: '{original}_{date}',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) => exportNotifier.setFilenamePattern(val),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  children: [
                    for (final token in [
                      '{original}',
                      '{date}',
                      '{year}',
                      '{preset}',
                      '{counter}',
                      '{dimensions}',
                      '{quality}',
                    ])
                      InkWell(
                        onTap: () {
                          final cur = _patternController.text;
                          final next = cur.isEmpty ? token : '$cur-$token';
                          _patternController.text = next;
                          exportNotifier.setFilenamePattern(next);
                        },
                        child: Chip(
                          label: Text(
                            token,
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                          ),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.lg),
        ],
      ),
    );
  }

  Widget _buildWatermarkStudio(
    ThemeData theme,
    ExportBrandingSettings branding,
    ExportBrandingNotifier notifier,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Watermark Presets
        Row(
          children: [
            const Icon(Icons.style_outlined, size: 16),
            const SizedBox(width: Insets.xs),
            Text(
              'Watermark Styles:',
              style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final preset in WatermarkPreset.values)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ActionChip(
                    label: Text(preset.title),
                    onPressed: () {
                      notifier.applyWatermarkPreset(preset);
                      _scheduleLivePreviewRender();
                    },
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 24),

        // 1. Text Signature
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.draw_outlined),
          title: const Text('Photographer Text Signature'),
          subtitle: const Text('Vector typography with anti-halation drop shadow'),
          value: branding.enableSignature,
          onChanged: (val) {
            notifier.setSignature(enabled: val);
            _scheduleLivePreviewRender();
          },
        ),
        if (branding.enableSignature) ...[
          TextField(
            key: const Key('watermark_signature_field'),
            controller: _signatureController,
            decoration: const InputDecoration(
              labelText: 'Signature Text',
              hintText: '© 2026 Your Name',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onChanged: (text) {
              notifier.setSignature(enabled: true, text: text);
              _scheduleLivePreviewRender();
            },
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            children: [
              for (final t in ['© {year}', '{photographer}', '{camera}', '{lens}'])
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  label: Text(t, style: const TextStyle(fontSize: 10)),
                  onPressed: () {
                    final cur = _signatureController.text;
                    final next = cur.isEmpty ? t : '$cur • $t';
                    _signatureController.text = next;
                    notifier.setSignature(enabled: true, text: next);
                    _scheduleLivePreviewRender();
                  },
                ),
            ],
          ),
          const SizedBox(height: Insets.sm),

          // 9-point Anchor Grid
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Placement Grid:', style: theme.textTheme.labelMedium),
                    const SizedBox(height: 4),
                    _build9PointGrid(
                      selectedIndex: branding.signatureAnchorIndex,
                      onSelected: (idx) {
                        notifier.setSignature(enabled: true, anchorIndex: idx);
                        _scheduleLivePreviewRender();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Color Theme:', style: theme.textTheme.labelMedium),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _buildColorDot(
                          label: 'White',
                          color: Colors.white,
                          selected: branding.signatureColor == 0,
                          onTap: () {
                            notifier.setSignature(enabled: true, color: 0);
                            _scheduleLivePreviewRender();
                          },
                        ),
                        _buildColorDot(
                          label: 'Dark',
                          color: const Color(0xFF1A1A1A),
                          selected: branding.signatureColor == 1,
                          onTap: () {
                            notifier.setSignature(enabled: true, color: 1);
                            _scheduleLivePreviewRender();
                          },
                        ),
                        _buildColorDot(
                          label: 'Ivory',
                          color: const Color(0xFFF7F5F0),
                          selected: branding.signatureColor == 2,
                          onTap: () {
                            notifier.setSignature(enabled: true, color: 2);
                            _scheduleLivePreviewRender();
                          },
                        ),
                        _buildColorDot(
                          label: 'Gold',
                          color: const Color(0xFFD4AF37),
                          selected: branding.signatureColor == 3,
                          onTap: () {
                            notifier.setSignature(enabled: true, color: 3);
                            _scheduleLivePreviewRender();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.sm),

          // Sliders: Opacity, Size, Inset
          Row(
            children: [
              Text('Opacity: ${(branding.signatureOpacity * 100).round()}%'),
              Expanded(
                child: Slider(
                  value: branding.signatureOpacity,
                  min: 0.1,
                  max: 1.0,
                  divisions: 18,
                  onChanged: (val) {
                    notifier.setSignature(enabled: true, opacity: val);
                    _scheduleLivePreviewRender();
                  },
                ),
              ),
            ],
          ),
          Row(
            children: [
              Text('Size: ${branding.signatureSizePct.toStringAsFixed(1)}%'),
              Expanded(
                child: Slider(
                  value: branding.signatureSizePct,
                  min: 1.0,
                  max: 8.0,
                  divisions: 14,
                  onChanged: (val) {
                    notifier.setSignature(enabled: true, sizePct: val);
                    _scheduleLivePreviewRender();
                  },
                ),
              ),
            ],
          ),
          Row(
            children: [
              Text('Margin: ${branding.signatureInsetPct.toStringAsFixed(1)}%'),
              Expanded(
                child: Slider(
                  value: branding.signatureInsetPct,
                  min: 0.5,
                  max: 12.0,
                  divisions: 23,
                  onChanged: (val) {
                    notifier.setSignature(enabled: true, insetPct: val);
                    _scheduleLivePreviewRender();
                  },
                ),
              ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Anti-halation Drop Shadow'),
            subtitle: const Text('Ensures text remains visible on any photo background'),
            value: branding.signatureDropShadow,
            onChanged: (val) {
              notifier.setSignature(enabled: true, dropShadow: val);
              _scheduleLivePreviewRender();
            },
          ),
        ],

        const Divider(height: 24),

        // 2. Custom PNG Logo
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.photo_outlined),
          title: const Text('Custom Graphic Logo (PNG)'),
          subtitle: const Text('Transparent vector/PNG logo watermark'),
          value: branding.enableLogo,
          onChanged: (val) {
            notifier.setLogo(enabled: val);
            _scheduleLivePreviewRender();
          },
        ),
        if (branding.enableLogo) ...[
          Row(
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.file_upload_outlined),
                label: Text(branding.logoBytes != null && branding.logoBytes!.isNotEmpty ? 'Change Logo' : 'Select Logo File'),
                onPressed: _pickLogoImage,
              ),
              const SizedBox(width: Insets.sm),
              if (branding.logoBytes != null && branding.logoBytes!.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Remove Logo',
                  onPressed: () {
                    notifier.clearLogo();
                    _scheduleLivePreviewRender();
                  },
                ),
            ],
          ),
          if (branding.logoPath != null && branding.logoPath!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'File: ${branding.logoPath!.split(Platform.pathSeparator).last}',
                style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
              ),
            ),
          Row(
            children: [
              Text('Scale: ${branding.logoScalePct.round()}%'),
              Expanded(
                child: Slider(
                  value: branding.logoScalePct,
                  min: 3.0,
                  max: 35.0,
                  divisions: 32,
                  onChanged: (val) {
                    notifier.setLogo(enabled: true, scalePct: val);
                    _scheduleLivePreviewRender();
                  },
                ),
              ),
            ],
          ),
          Row(
            children: [
              Text('Opacity: ${(branding.logoOpacity * 100).round()}%'),
              Expanded(
                child: Slider(
                  value: branding.logoOpacity,
                  min: 0.1,
                  max: 1.0,
                  divisions: 18,
                  onChanged: (val) {
                    notifier.setLogo(enabled: true, opacity: val);
                    _scheduleLivePreviewRender();
                  },
                ),
              ),
            ],
          ),
        ],

        const Divider(height: 24),

        // 3. Tiled Proof Grid
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.grid_4x4),
          title: const Text('Tiled Pattern (Client Proof Protection)'),
          subtitle: const Text('Repeats watermark across full canvas for proofing'),
          value: branding.enableTiledWatermark,
          onChanged: (val) {
            notifier.setTiledWatermark(enabled: val);
            _scheduleLivePreviewRender();
          },
        ),
        if (branding.enableTiledWatermark) ...[
          TextField(
            controller: _tiledController,
            decoration: const InputDecoration(
              labelText: 'Proof Text',
              hintText: 'PROOF - DO NOT COPY',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onChanged: (val) {
              notifier.setTiledWatermark(enabled: true, text: val);
              _scheduleLivePreviewRender();
            },
          ),
          Row(
            children: [
              Text('Opacity: ${(branding.tiledOpacity * 100).round()}%'),
              Expanded(
                child: Slider(
                  value: branding.tiledOpacity,
                  min: 0.05,
                  max: 0.60,
                  divisions: 11,
                  onChanged: (val) {
                    notifier.setTiledWatermark(enabled: true, opacity: val);
                    _scheduleLivePreviewRender();
                  },
                ),
              ),
            ],
          ),
        ],

        const Divider(height: 24),

        // 4. Museum Frame (Exhibition Mat)
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.crop_original_outlined),
          title: const Text('Museum Frame (EXIF Mat)'),
          subtitle: const Text('Expands canvas with gallery border & camera typography'),
          value: branding.enableMuseumFrame,
          onChanged: (val) {
            notifier.setMuseumFrame(enabled: val);
            _scheduleLivePreviewRender();
          },
        ),
        if (branding.enableMuseumFrame) ...[
          Wrap(
            spacing: 6,
            children: [
              ChoiceChip(
                label: const Text('Studio White'),
                selected: branding.frameThemeIndex == 0,
                onSelected: (s) {
                  if (s) notifier.setMuseumFrame(enabled: true, themeIndex: 0);
                  _scheduleLivePreviewRender();
                },
              ),
              ChoiceChip(
                label: const Text('Matte Dark'),
                selected: branding.frameThemeIndex == 1,
                onSelected: (s) {
                  if (s) notifier.setMuseumFrame(enabled: true, themeIndex: 1);
                  _scheduleLivePreviewRender();
                },
              ),
              ChoiceChip(
                label: const Text('Warm Gallery'),
                selected: branding.frameThemeIndex == 2,
                onSelected: (s) {
                  if (s) notifier.setMuseumFrame(enabled: true, themeIndex: 2);
                  _scheduleLivePreviewRender();
                },
              ),
            ],
          ),
          const SizedBox(height: Insets.xs),
          TextField(
            controller: _exif1Controller,
            decoration: const InputDecoration(
              labelText: 'Camera & Lens Line',
              hintText: 'e.g. SONY ILCE-7M3 • FE 35mm F1.4',
              isDense: true,
            ),
            onChanged: (val) {
              notifier.setMuseumFrame(enabled: true, line1: val);
              _scheduleLivePreviewRender();
            },
          ),
        ],

        const Divider(height: 24),

        // 5. ApertureX FOSS Badge
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.verified_outlined),
          title: const Text('ApertureX Offline Badge'),
          subtitle: const Text('⬡ Edited in ApertureX | 100% Offline'),
          value: branding.enableFossBadge,
          onChanged: (val) {
            notifier.setFossBadge(val);
            _scheduleLivePreviewRender();
          },
        ),
      ],
    );
  }

  Widget _build9PointGrid({
    required int selectedIndex,
    required ValueChanged<int> onSelected,
  }) {
    return Container(
      width: 108,
      height: 108,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
        ),
        itemCount: 9,
        itemBuilder: (context, idx) {
          final isSelected = selectedIndex == idx;
          return InkWell(
            onTap: () => onSelected(idx),
            borderRadius: BorderRadius.circular(4),
            child: Container(
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(4),
              ),
              child: isSelected
                  ? const Icon(Icons.circle, size: 8, color: Colors.white)
                  : null,
            ),
          );
        },
      ),
    );
  }

  Widget _buildColorDot({
    required String label,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: selected
              ? Border.all(color: Theme.of(context).colorScheme.primary, width: 1.5)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade400, width: 0.5),
              ),
            ),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({
    required ThemeData theme,
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Insets.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: Insets.sm),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: Insets.sm),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildCollapsibleCard({
    required ThemeData theme,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isExpanded,
    required VoidCallback onToggle,
    required Widget child,
  }) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.all(Insets.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: Insets.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
              if (isExpanded) ...[
                const Divider(height: 20),
                child,
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActionBar(
    ThemeData theme,
    ({int width, int height}) targetDim,
    String estSize,
  ) {
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: FilledButton.icon(
                key: const Key('export_studio_primary_btn'),
                icon: const Icon(Icons.file_download_outlined),
                label: Text(
                  'Export ${_selectedFormat.toUpperCase()} (${targetDim.width}×${targetDim.height})',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _onExportTriggered,
              ),
            ),
            const SizedBox(width: Insets.sm),
            IconButton.filledTonal(
              tooltip: 'Save to In-App Edits Library',
              icon: const Icon(Icons.auto_fix_high_outlined),
              onPressed: () =>
                  Navigator.of(context).pop(ExportAction.saveToApertureX),
            ),
          ],
        ),
      ),
    );
  }
}
