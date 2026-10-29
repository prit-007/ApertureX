import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'gallery_asset.dart';
import 'gallery_controller.dart' show gallerySourceProvider;
import '../engine/engine.dart';
import '../platform/photo_saver.dart';
import '../src/rust/api/export.dart';
import '../ui/common/app_sheet.dart';
import '../core/theme/design_tokens.dart';

/// EV step options offered to the user for each bracketed exposure.
const List<double> _evSteps = [-2.0, -1.0, 0.0, 1.0, 2.0];

/// Decoded exposure data kept in memory while the merge sheet is open.
class _HdrExposure {
  const _HdrExposure({
    required this.asset,
    required this.rgba,
    required this.width,
    required this.height,
    required this.exif,
  });

  final GalleryAsset asset;
  final Uint8List rgba;
  final int width;
  final int height;
  final Uint8List exif;
}

/// One exposure row inside the HDR merge sheet.
class _HdrExposureRow extends StatelessWidget {
  const _HdrExposureRow({
    required this.exposure,
    required this.ev,
    required this.onEvChanged,
  });

  final _HdrExposure exposure;
  final double ev;
  final ValueChanged<double> onEvChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: Insets.xs),
      child: Padding(
        padding: const EdgeInsets.all(Insets.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 72,
                  height: 72,
                  child: ClipRRect(
                    borderRadius: Radii.mdAll,
                    child: Image.memory(
                      exposure.rgba,
                      fit: BoxFit.cover,
                      width: 72,
                      height: 72,
                    ),
                  ),
                ),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exposure.asset.id,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: scheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${exposure.width} × ${exposure.height}',
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'EV ${ev >= 0 ? '+' : ''}${ev.toStringAsFixed(1)}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.md),
            Slider(
              value: ev.clamp(-2.0, 2.0),
              min: -2.0,
              max: 2.0,
              divisions: 40,
              label: '${ev.toStringAsFixed(1)} EV',
              onChanged: onEvChanged,
              activeColor: scheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Sheet for merging bracketed exposures into an Ultra HDR JPEG (#20).
///
/// Lets the user assign an EV offset to each selected exposure, choose merge
/// quality/headroom, then runs [AxEngine.exportHdrMerge] and saves the result
/// to the device gallery.
class HdrMergeSheet extends ConsumerStatefulWidget {
  const HdrMergeSheet({super.key, required this.assets});

  final List<GalleryAsset> assets;

  @override
  ConsumerState<HdrMergeSheet> createState() => _HdrMergeSheetState();
}

class _HdrMergeSheetState extends ConsumerState<HdrMergeSheet> {
  final List<_HdrExposure> _exposures = [];
  final Map<int, double> _evByIndex = {};
  bool _merging = false;
  String? _error;

  /// Quality for the output JPEG (1..100).
  int _quality = 92;
  /// Quality for the gain map embedding (1..100).
  int _gainQuality = 85;
  /// Tone-mapping headroom in EV stops above mid-gray.
  double _headroomEv = 2.0;

  @override
  void initState() {
    super.initState();
    _loadExposures();
  }

  Future<void> _loadExposures() async {
    final source = ref.read(gallerySourceProvider);
    final loaded = <_HdrExposure>[];
    var evIndex = 0;
    for (final asset in widget.assets) {
      try {
        final src = await source.loadImage(asset.id);
        if (src.isEmpty) continue;
        final decoded = await AxEngine.decodeJpegRgba(src);
        final exif = await AxEngine.extractExif(src);
        loaded.add(
          _HdrExposure(
            asset: asset,
            rgba: decoded.rgba,
            width: decoded.width,
            height: decoded.height,
            exif: exif,
          ),
        );
        _evByIndex[evIndex] =
            _evSteps[evIndex.clamp(0, _evSteps.length - 1)].toDouble();
        evIndex++;
      } catch (_) {
        // Skip exposures that fail to decode.
      }
    }
    if (!mounted) return;
    setState(() {
      _exposures
        ..clear()
        ..addAll(loaded);
      if (_exposures.isEmpty) {
        _error = 'No exposures could be decoded.';
      }
    });
  }

  Future<void> _merge() async {
    if (_exposures.length < 2) {
      setState(() => _error = 'Need at least two exposures for HDR merge.');
      return;
    }
    setState(() {
      _merging = true;
      _error = null;
    });
    try {
      final specs = _exposures.asMap().entries.map((entry) {
        final idx = entry.key;
        final exp = entry.value;
        return HdrExposureSpec(
          rgba: exp.rgba,
          width: exp.width,
          height: exp.height,
          ev: _evByIndex[idx] ?? 0.0,
        );
      }).toList();
      final exif = _exposures.isNotEmpty ? _exposures.first.exif : Uint8List(0);
      final out = await AxEngine.exportHdrMerge(
        exposures: specs,
        quality: _quality,
        gainQuality: _gainQuality,
        headroomEv: _headroomEv,
        exif: exif,
      );
      if (!mounted) return;
      // Desktop → save dialog, mobile → gal; branch lives in PhotoSaver
      // (#104). A cancelled dialog keeps the sheet open so the merge can be
      // retried or shared instead of silently popping.
      final outcome = await ref.read(photoSaverProvider).saveBytes(
            out,
            name: 'aperturex_hdr_merge_'
                '${DateTime.now().millisecondsSinceEpoch}',
          );
      if (outcome == null) return;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: outcome is SavedToFile
                ? Text('HDR merge saved to ${outcome.file.path}')
                : const Text('HDR merge saved to your gallery'),
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _merging = false;
        _error = 'HDR merge failed: $e';
      });
    } finally {
      if (mounted) setState(() => _merging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return FocusTraversalGroup(
      policy: WidgetOrderTraversalPolicy(),
      child: AppSheet(
        title: 'HDR Merge',
        subtitle:
            '${_exposures.length} exposure'
            '${_exposures.length == 1 ? '' : 's'} • '
            'Ultra HDR JPEG (ISO 21496-1)',
        children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.md),
            child: Text(
              _error!,
              style: TextStyle(
                color: scheme.error,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        if (_error != null) const SizedBox(height: Insets.sm),
        Expanded(
          child: _exposures.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: _exposures.length,
                  itemBuilder: (_, i) {
                    final ev = _evByIndex[i] ?? 0.0;
                    return _HdrExposureRow(
                      exposure: _exposures[i],
                      ev: ev,
                      onEvChanged: (v) =>
                          setState(() => _evByIndex[i] = v),
                    );
                  },
                ),
        ),
        const SizedBox(height: Insets.md),
        const Divider(),
        const SizedBox(height: Insets.sm),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Quality',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Text(
                    '$_quality%',
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Slider(
                value: _quality.toDouble(),
                min: 60,
                max: 100,
                divisions: 20,
                label: '$_quality%',
                onChanged: (v) => setState(() => _quality = v.round()),
                activeColor: scheme.primary,
              ),
              const SizedBox(height: Insets.md),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Gain Map Quality',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Text(
                    '$_gainQuality%',
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Slider(
                value: _gainQuality.toDouble(),
                min: 60,
                max: 100,
                divisions: 20,
                label: '$_gainQuality%',
                onChanged: (v) => setState(() => _gainQuality = v.round()),
                activeColor: scheme.primary,
              ),
              const SizedBox(height: Insets.md),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Headroom',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Text(
                    '+${_headroomEv.toStringAsFixed(1)} EV',
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Slider(
                value: _headroomEv,
                min: 0.5,
                max: 4.0,
                divisions: 14,
                label: '${_headroomEv.toStringAsFixed(1)} EV',
                onChanged: (v) => setState(() => _headroomEv = v),
                activeColor: scheme.primary,
              ),
            ],
          ),
        ),
        const SizedBox(height: Insets.lg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.md),
          child: FilledButton.icon(
            key: const Key('hdr-merge-button'),
            onPressed: _merging ? null : _merge,
            icon: _merging
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome, size: 18),
            label: Text(_merging ? 'Merging…' : 'Merge to Ultra HDR'),
          ),
        ),
        const SizedBox(height: Insets.lg),
      ],
    ),
  );
}
}
