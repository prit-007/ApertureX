import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show SystemChrome, SystemUiMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../color/grade_spec.dart';
import '../../color/spatial_spec.dart';
import '../../core/log/activity_log.dart';
import '../../core/log/log_providers.dart';
import '../../core/theme/design_tokens.dart';
import '../../edit/geometry_spec.dart';
import '../../edit/recipe.dart';
import '../../edit/recipe_controller.dart';
import '../../edit/recipe_store.dart';
import '../../features/crop/crop_screen.dart';
import '../../gallery/gallery_asset.dart';
import '../../gallery/gallery_controller.dart';
import '../../engine/engine.dart';
import '../../settings/export_settings.dart';
import '../../settings/shell_preference.dart';
import '../../ui/app_shell.dart';
import '../../ui/common/app_primitives.dart';
import '../../ui/common/app_sheet.dart';
import '../../ui/common/settings_sheet.dart';
import '../../ui/edit_activity.dart';

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
              ? await ref
                    .read(gallerySourceProvider)
                    .loadPreview(widget.asset!.id)
              : await TesseraEngine.syntheticJpeg(width: 1024, height: 1024));
      if (bytes.isEmpty) throw StateError('The image could not be read.');
      if (!mounted) return;
      axLog(LogDomain.editor, 'Opened ${widget.asset?.id ?? 'sample image'}');

      // Restore this photo's saved (non-destructive) recipe, or start neutral.
      final notifier = ref.read(recipeControllerProvider.notifier);
      if (widget.asset != null) {
        final saved = ref.read(recipeStoreProvider)[widget.asset!.id];
        notifier.loadRecipe(saved ?? EditRecipe.neutral, label: 'Opened');
      } else {
        notifier.loadRecipe(EditRecipe.neutral, label: 'Sample');
      }

      setState(() {
        _bytes = bytes;
        _loading = false;
      });
    } catch (e) {
      axLog(LogDomain.editor, 'Open failed: $e', LogLevel.error);
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _export() async {
    final previewBytes = _bytes;
    if (previewBytes == null) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _exporting = true);
    try {
      // Export at full resolution: fetch the original only now (never during
      // preview), so the editor's memory stays at preview size until export.
      final bytes = widget.asset != null
          ? await ref.read(gallerySourceProvider).loadImage(widget.asset!.id)
          : previewBytes;
      if (bytes.isEmpty) throw StateError('The image could not be read.');

      final recipe = ref.read(recipeControllerProvider).recipe;
      final settings = ref.read(exportSettingsProvider);
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
        quality: settings.quality,
        maxDim: settings.maxDim == 0 ? null : settings.maxDim,
      );
      if (!await Gal.hasAccess()) await Gal.requestAccess();
      await Gal.putImageBytes(
        jpeg,
        name: 'aperturex_${DateTime.now().millisecondsSinceEpoch}',
      );
      axLog(
        LogDomain.export,
        'Exported ${decoded.width}×${decoded.height} '
            '(q${settings.quality}, ${jpeg.length} bytes)',
      );
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Saved to your photos'),
          action: SnackBarAction(
            label: 'Share',
            onPressed: () => _share(jpeg),
          ),
        ),
      );
    } catch (e) {
      axLog(LogDomain.export, 'Export failed: $e', LogLevel.error);
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _share(Uint8List jpeg) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/aperturex-share.jpg');
      await file.writeAsBytes(jpeg, flush: true);
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path, mimeType: 'image/jpeg')]),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Share failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Persist every edit back to this photo's recipe (non-destructive editing:
    // the recipe survives leaving and re-opening the photo).
    ref.listen(recipeControllerProvider, (previous, next) {
      if (widget.asset != null) {
        ref.read(recipeStoreProvider.notifier).put(widget.asset!.id, next.recipe);
      }
    });

    final state = ref.watch(recipeControllerProvider);
    final notifier = ref.read(recipeControllerProvider.notifier);
    final canUndo = state.index > 0;
    final canRedo = state.index < state.history.length - 1;
    final gestureShell = ref.watch(shellPreferenceProvider) ==
        AppShellKind.snapseed;
    final active = ref.watch(editActivityProvider);

    // Active Mode (issue #26): hand the whole screen to the photo while the
    // user is touching it — system bars out, chrome faded; restore on lift.
    ref.listen(editActivityProvider, (previous, next) {
      if (previous == next) return;
      SystemChrome.setEnabledSystemUIMode(
        next ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
      );
    });

    final crop = IconButton(
      tooltip: 'Crop & rotate',
      onPressed: _bytes == null
          ? null
          : () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CropScreen(imageBytes: _bytes!),
              ),
            ),
      icon: const Icon(Icons.crop),
    );
    final undo = IconButton(
      tooltip: 'Undo',
      onPressed: canUndo ? notifier.undo : null,
      icon: const Icon(Icons.undo),
    );
    final redo = IconButton(
      tooltip: 'Redo',
      onPressed: canRedo ? notifier.redo : null,
      icon: const Icon(Icons.redo),
    );
    final more = IconButton(
      tooltip: 'More',
      onPressed: () => _openSettings(context),
      icon: const Icon(Icons.more_vert),
    );
    final export = Padding(
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
    );

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: AnimatedOpacity(
          opacity: active ? 0 : 1,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: IgnorePointer(
            ignoring: active,
            child: AppBar(
              leading: const BackButton(),
              title: const Text('Edit'),
              // The gesture shell carries these on the floating top HUD.
              actions: gestureShell
                  ? null
                  : [crop, undo, redo, more, export],
            ),
          ),
        ),
      ),
      body: _body(
        gestureShell: gestureShell,
        hud: Row(children: [crop, undo, redo, more, const Spacer(), export]),
      ),
    );
  }

  Widget _body({required bool gestureShell, required Widget hud}) {
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
    return AppShell(imageBytes: _bytes, topHud: gestureShell ? hud : null);
  }

  void _openSettings(BuildContext context) {
    showAppSheet(context, const SettingsSheet());
  }
}
