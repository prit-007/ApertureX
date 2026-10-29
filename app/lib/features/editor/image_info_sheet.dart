import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/design_tokens.dart';
import '../../edit/recipe.dart';
import '../../engine/engine.dart';
import '../../gallery/gallery_asset.dart';
import '../../ui/common/app_sheet.dart';
import '../c2pa/c2pa_service.dart';
import '../lens/lens_database.dart';
import '../../src/rust/api/c2pa.dart';

/// Shows a comprehensive, professional EXIF and metadata inspector sheet (#85).
class ImageInfoSheet extends ConsumerStatefulWidget {
  const ImageInfoSheet({
    super.key,
    required this.imageBytes,
    this.recipe,
    this.asset,
  });

  final Uint8List imageBytes;
  final EditRecipe? recipe;
  final GalleryAsset? asset;

  static Future<void> show(
    BuildContext context, {
    required Uint8List imageBytes,
    EditRecipe? recipe,
    GalleryAsset? asset,
  }) {
    return showAppSheet<void>(
      context,
      ImageInfoSheet(
        imageBytes: imageBytes,
        recipe: recipe,
        asset: asset,
      ),
    );
  }

  @override
  ConsumerState<ImageInfoSheet> createState() => _ImageInfoSheetState();
}

class _ImageInfoSheetState extends ConsumerState<ImageInfoSheet> {
  ImageMetadata? _metadata;
  C2paVerifyResult? _c2paResult;
  bool _loading = true;
  bool _verifyingC2pa = true;

  @override
  void initState() {
    super.initState();
    _loadMetadata();
  }

  Future<void> _loadMetadata() async {
    try {
      final meta = await AxEngine.getImageMetadata(widget.imageBytes);
      C2paVerifyResult? c2pa;
      try {
        final c2paService = ref.read(c2paServiceProvider);
        c2pa = await c2paService.verifyImage(widget.imageBytes);
      } catch (_) {}

      if (mounted) {
        setState(() {
          _metadata = meta;
          _c2paResult = c2pa;
          _loading = false;
          _verifyingC2pa = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _verifyingC2pa = false;
        });
      }
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  String _formatMegapixels(int? width, int? height) {
    if (width == null || height == null || width == 0 || height == 0) return '';
    final mp = (width * height) / 1000000.0;
    return '$width×$height (${mp.toStringAsFixed(1)} MP)';
  }

  void _copyToClipboard(BuildContext context) {
    final meta = _metadata;
    final buffer = StringBuffer();
    buffer.writeln('--- ApertureX Image Info ---');
    if (meta?.formatName != null) buffer.writeln('Format: ${meta!.formatName}');
    if (meta?.width != null && meta?.height != null) {
      buffer.writeln('Dimensions: ${meta!.width} × ${meta.height}');
    }
    buffer.writeln('Size: ${_formatFileSize(widget.imageBytes.length)}');
    if (meta?.make != null || meta?.model != null) {
      buffer.writeln('Camera: ${meta?.make ?? ''} ${meta?.model ?? ''}');
    }
    if (meta?.lensModel != null) buffer.writeln('Lens: ${meta!.lensModel}');
    if (meta?.focalLength != null) buffer.writeln('Focal Length: ${meta!.focalLength} mm');
    if (meta?.fNumber != null) buffer.writeln('Aperture: f/${meta!.fNumber}');
    if (meta?.exposureTime != null) buffer.writeln('Shutter Speed: ${meta!.exposureTime}');
    if (meta?.iso != null) buffer.writeln('ISO: ${meta!.iso}');
    if (meta?.dateTime != null) buffer.writeln('Date/Time: ${meta!.dateTime}');
    if (meta?.gpsLatitude != null && meta?.gpsLongitude != null) {
      buffer.writeln('GPS: ${meta!.gpsLatitude}, ${meta.gpsLongitude}');
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Image info copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meta = _metadata;
    final bytesLen = widget.imageBytes.length;

    final lensMatch = meta != null
        ? LensDatabase.findBestMatch(
            lensModel: meta.lensModel,
            lensMake: meta.lensMake,
            cameraMake: meta.make,
            cameraModel: meta.model,
            focalLength: meta.focalLength,
          )
        : null;

    return AppSheet(
      title: 'Image Information',
      subtitle: meta?.formatName ?? 'EXIF & Capture Metadata',
      actions: [
        IconButton(
          tooltip: 'Copy info',
          icon: const Icon(Icons.copy_rounded, size: 20),
          onPressed: () => _copyToClipboard(context),
        ),
      ],
      children: [
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: Insets.lg),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          // Exposure & Camera Quick Pills
          _buildQuickStats(theme, meta),
          const SizedBox(height: Insets.md),

          // File & Format Section
          _buildSectionCard(
            theme,
            title: 'File & Sensor',
            icon: Icons.image_outlined,
            items: [
              _InfoRow(
                label: 'Format',
                value: meta?.formatName ?? (widget.asset != null ? 'Asset' : 'JPEG'),
              ),
              _InfoRow(
                label: 'Resolution',
                value: _formatMegapixels(meta?.width ?? widget.asset?.width, meta?.height ?? widget.asset?.height),
              ),
              _InfoRow(
                label: 'File Size',
                value: _formatFileSize(bytesLen),
              ),
              if (meta?.whiteBalanceMode != null)
                _InfoRow(label: 'White Balance', value: meta!.whiteBalanceMode!),
              if (meta?.meteringMode != null)
                _InfoRow(label: 'Metering', value: meta!.meteringMode!),
            ],
          ),
          const SizedBox(height: Insets.sm),

          // Hardware & Optics Section
          _buildSectionCard(
            theme,
            title: 'Camera & Lens Optics',
            icon: Icons.camera_alt_outlined,
            items: [
              if (meta?.make != null || meta?.model != null)
                _InfoRow(
                  label: 'Camera',
                  value: '${meta?.make ?? ''} ${meta?.model ?? ''}'.trim(),
                ),
              if (meta?.lensModel != null || lensMatch != null)
                _InfoRow(
                  label: 'Lens Model',
                  value: meta?.lensModel ?? lensMatch?.displayName ?? 'Standard Lens',
                ),
              if (lensMatch != null) ...[
                _InfoRow(
                  label: 'Lensfun Profile',
                  value: '${lensMatch.mount} (${lensMatch.focalRangeLabel})',
                ),
                _InfoRow(
                  label: 'Optics Calibration',
                  value: 'Distortion +${lensMatch.distortionCorrection.round()} · Vignette +${lensMatch.vignetteCorrection.round()}',
                ),
              ],
              if (meta?.flashFired != null)
                _InfoRow(
                  label: 'Flash',
                  value: meta!.flashFired! ? 'Fired' : 'Did not fire',
                ),
            ],
          ),
          const SizedBox(height: Insets.sm),

          // Date & GPS Section
          if (meta?.dateTime != null || (meta?.gpsLatitude != null && meta?.gpsLongitude != null))
            _buildSectionCard(
              theme,
              title: 'Date & Location',
              icon: Icons.location_on_outlined,
              items: [
                if (meta?.dateTime != null)
                  _InfoRow(label: 'Capture Date', value: meta!.dateTime!),
                if (meta?.gpsLatitude != null && meta?.gpsLongitude != null)
                  _InfoRow(
                    label: 'Coordinates',
                    value: '${meta!.gpsLatitude!.toStringAsFixed(5)}, ${meta.gpsLongitude!.toStringAsFixed(5)}',
                  ),
                if (meta?.gpsAltitude != null)
                  _InfoRow(
                    label: 'Altitude',
                    value: '${meta!.gpsAltitude!.toStringAsFixed(1)} m',
                  ),
              ],
            ),

          // Recipe & Session Section
          if (widget.recipe != null)
            _buildSectionCard(
              theme,
              title: 'Non-Destructive Session',
              icon: Icons.tune_rounded,
              items: [
                _InfoRow(
                  label: 'Active Masks',
                  value: '${widget.recipe!.maskGroups.length} mask groups (${widget.recipe!.layers.length} layers)',
                ),
                _InfoRow(
                  label: 'Tone Adjustments',
                  value: 'Exp: ${widget.recipe!.exposure >= 0 ? "+" : ""}${widget.recipe!.exposure.toStringAsFixed(2)} EV · Contrast: ${widget.recipe!.contrast.toStringAsFixed(1)}',
                ),
                const _InfoRow(
                  label: 'Color Space',
                  value: 'Linear ProPhoto RGB (Impeller GPU Canvas)',
                ),
              ],
            ),
          const SizedBox(height: Insets.sm),

          // C2PA Provenance & Content Credentials
          _buildC2paSection(theme),
          const SizedBox(height: Insets.sm),
        ],
      ],
    );
  }

  Widget _buildC2paSection(ThemeData theme) {
    final report = _c2paResult;
    final isVerified = report?.isValid == true;
    final isTampered = report?.status == 'Tampered';

    Color cardBorder;
    Color? cardBg;
    IconData statusIcon;
    Color iconColor;
    String statusTitle;
    String statusSubtitle;

    if (_verifyingC2pa) {
      cardBorder = theme.colorScheme.outlineVariant;
      statusIcon = Icons.hourglass_top_rounded;
      iconColor = theme.colorScheme.onSurfaceVariant;
      statusTitle = 'Verifying Authenticity...';
      statusSubtitle = 'Checking offline cryptographic provenance';
    } else if (isVerified) {
      cardBorder = Colors.green.withAlpha(120);
      cardBg = Colors.green.withAlpha(18);
      statusIcon = Icons.verified_user_rounded;
      iconColor = Colors.green;
      statusTitle = '✓ C2PA Content Credentials Verified';
      statusSubtitle = 'Cryptographic provenance and pixel hash confirmed authentic';
    } else if (isTampered) {
      cardBorder = Colors.red.withAlpha(140);
      cardBg = Colors.red.withAlpha(20);
      statusIcon = Icons.gpp_bad_rounded;
      iconColor = Colors.red;
      statusTitle = '⚠ Tampered / Signature Broken';
      statusSubtitle = 'Pixels have been altered since export. Authenticity check failed.';
    } else {
      cardBorder = theme.colorScheme.outlineVariant;
      statusIcon = Icons.shield_outlined;
      iconColor = theme.colorScheme.onSurfaceVariant;
      statusTitle = 'Content Credentials (C2PA)';
      statusSubtitle = 'No cryptographic manifest found. Enable C2PA in Export to sign your photos.';
    }

    return Container(
      decoration: BoxDecoration(
        color: cardBg ?? theme.colorScheme.surfaceContainerHighest.withAlpha(60),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder, width: isVerified || isTampered ? 1.5 : 1.0),
      ),
      padding: const EdgeInsets.all(Insets.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isVerified)
                Container(
                  width: 26,
                  height: 26,
                  margin: const EdgeInsets.only(right: Insets.xs),
                  decoration: BoxDecoration(
                    color: Colors.green.withAlpha(40),
                    shape: BoxShape.circle,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(
                    'icons/app_icon_monochrome.png',
                    color: Colors.green,
                    errorBuilder: (_, _, _) =>
                        Icon(statusIcon, color: iconColor, size: 20),
                  ),
                )
              else
                Icon(statusIcon, color: iconColor, size: 22),
              const SizedBox(width: Insets.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusTitle,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isVerified
                            ? Colors.green
                            : isTampered
                                ? Colors.red
                                : theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      statusSubtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isVerified && report != null) ...[
            const Divider(height: Insets.md),
            _buildDetailRow(theme, 'Signer Key ID', report.signerKeyId),
            _buildDetailRow(theme, 'Generator', report.claimGenerator),
            if (report.actions.isNotEmpty)
              _buildDetailRow(theme, 'Audit Trail', report.actions.join(', ')),
            if (report.cameraMetadata.isNotEmpty)
              _buildDetailRow(theme, 'Origin EXIF', report.cameraMetadata),
            if (report.pixelHash.isNotEmpty)
              _buildDetailRow(
                theme,
                'Pixel SHA-256',
                '${report.pixelHash.substring(0, 16)}...',
              ),
            _buildDetailRow(theme, 'Verification', '100% Offline (Local Ed25519)'),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(ThemeData theme, ImageMetadata? meta) {
    return Row(
      children: [
        _buildStatBadge(
          theme,
          title: 'SHUTTER',
          value: meta?.exposureTime ?? '--',
          icon: Icons.shutter_speed_rounded,
        ),
        const SizedBox(width: Insets.xs),
        _buildStatBadge(
          theme,
          title: 'APERTURE',
          value: meta?.fNumber != null ? 'f/${meta!.fNumber}' : '--',
          icon: Icons.camera_outlined,
        ),
        const SizedBox(width: Insets.xs),
        _buildStatBadge(
          theme,
          title: 'ISO',
          value: meta?.iso != null ? '${meta!.iso}' : '--',
          icon: Icons.iso_rounded,
        ),
        const SizedBox(width: Insets.xs),
        _buildStatBadge(
          theme,
          title: 'FOCAL',
          value: meta?.focalLength != null ? '${meta!.focalLength!.round()}mm' : '--',
          icon: Icons.lens_outlined,
        ),
      ],
    );
  }

  Widget _buildStatBadge(
    ThemeData theme, {
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: Insets.xs, horizontal: Insets.xs),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: theme.colorScheme.primary),
            const SizedBox(height: 2),
            Text(
              title,
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 9,
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(
    ThemeData theme, {
    required String title,
    required IconData icon,
    required List<_InfoRow> items,
  }) {
    final validItems = items.where((it) => it.value.isNotEmpty).toList();
    if (validItems.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Insets.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: Insets.xs),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const Divider(height: Insets.md),
            for (final item in validItems)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(
                        item.label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item.value,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;
}
