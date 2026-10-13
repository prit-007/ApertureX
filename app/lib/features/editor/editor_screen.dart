import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

import '../../color/grade_spec.dart';
import '../../color/spatial_spec.dart';
import '../../core/theme/design_tokens.dart';
import '../../edit/geometry_spec.dart';
import '../../edit/recipe_controller.dart';
import '../../gallery/gallery_asset.dart';
import '../../gallery/gallery_controller.dart';
import '../../engine/engine.dart';
import '../../ui/app_shell.dart';
import '../../ui/common/app_primitives.dart';
import '../../ui/common/app_sheet.dart';
import '../../ui/common/settings_sheet.dart';

/// The full-screen editor: a top app bar (back · undo · redo · export ·
/// overflow) over the shared [AppShell] (canvas + active shell toolbar). One
/// recipe is the single source of truth for the whole session (ADR 0008).
class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({super.key, this.asset, this.imageBytes});

  /// Photo to edit, loaded from [gallerySourceProvider].
  final GalleryAsset? asset;

  /// Direct JPEG bytes (used by the sample-editor entry point).
  final Uint8List? imageBytes;

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  Uint8List? _bytes;
  bool _loading = true;
  String? _error;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bytes = widget.imageBytes ??
          (widget.asset != null
              ? await ref.read(gallerySourceProvider).loadImage(widget.asset!.id)
              : await TesseraEngine.syntheticJpeg(width: 1024, height: 1024));
      if (bytes.isEmpty) throw StateError('The image could not be read.');
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _export() async {
    final bytes = _bytes;
    if (bytes == null) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _exporting = true);
    try {
      final recipe = ref.read(recipeControllerProvider).recipe;
      final decoded = await TesseraEngine.decodeJpegRgba(bytes);
      final exif = await TesseraEngine.extractExif(bytes);
      final jpeg = await TesseraEngine.exportJpeg(
        rgba: decoded.rgba,
        width: decoded.width,
        height: decoded.height,
        spec: GradeSpec.fromRecipe(recipe),
        spatial: SpatialSpec.fromRecipe(recipe),
        geometry: GeometrySpec.fromRecipe(recipe),
        layers: recipe.layers,
        exif: exif,
      );
      final dir = await getApplicationDocumentsDirectory();
      final file = File(
        '${dir.path}/aperturex_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await file.writeAsBytes(jpeg, flush: true);
      messenger.showSnackBar(
        const SnackBar(content: Text('Exported to your documents')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recipeControllerProvider);
    final notifier = ref.read(recipeControllerProvider.notifier);
    final canUndo = state.index > 0;
    final canRedo = state.index < state.history.length - 1;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Edit'),
        actions: [
          IconButton(
            tooltip: 'Undo',
            onPressed: canUndo ? notifier.undo : null,
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            tooltip: 'Redo',
            onPressed: canRedo ? notifier.redo : null,
            icon: const Icon(Icons.redo),
          ),
          IconButton(
            tooltip: 'More',
            onPressed: () => _openSettings(context),
            icon: const Icon(Icons.more_vert),
          ),
          Padding(
            padding: const EdgeInsets.only(right: Insets.sm),
            child: FilledButton.tonalIcon(
              onPressed: _exporting || _bytes == null ? null : _export,
              icon: _exporting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.ios_share, size: 18),
              label: const Text('Export'),
            ),
          ),
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return EmptyState(
        icon: Icons.broken_image_outlined,
        title: 'Could not open this photo',
        message: _error,
        action: FilledButton.tonal(
          onPressed: _resolve,
          child: const Text('Try again'),
        ),
      );
    }
    return AppShell(imageBytes: _bytes);
  }

  void _openSettings(BuildContext context) {
    showAppSheet(context, const SettingsSheet());
  }
}
