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
import 'editor_shortcuts.dart';
import 'export_progress.dart';
import '../../edit/geometry_spec.dart';
import '../../edit/library_catalog.dart';
import '../../edit/recipe.dart';
import '../../edit/recipe_controller.dart';
import '../../edit/recipe_store.dart';
import '../../edit/xmp_sidecar.dart';
import '../../edit/xmp_writer.dart';
import '../../features/crop/crop_screen.dart';
import '../../gallery/gallery_asset.dart';
import '../../gallery/gallery_controller.dart';
import '../../engine/engine.dart';
import '../../engine/image_format.dart';
import '../../settings/export_settings.dart';
import '../../settings/shell_preference.dart';
import '../../ui/app_shell.dart';
import '../../ui/common/app_primitives.dart';
import '../../ui/common/app_sheet.dart';
import '../../ui/common/editor_guide_sheet.dart';
import '../../ui/common/settings_sheet.dart';
import '../../ui/edit_activity.dart';

/// The full-screen editor: a top app bar (back · undo · redo · export ·
/// overflow) over the shared [AppShell] (canvas + active shell toolbar). One
/// recipe is the single source of truth for the whole session (ADR 0008).
class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({super.key, this.asset, this.entryId, this.imageBytes});

  /// Photo to edit, loaded from [gallerySourceProvider].
  final GalleryAsset? asset;

  /// Catalog entry to read/write the recipe under (#73). Defaults to the
  /// original entry of [asset] (`orig:<assetId>`); virtual copies pass their
  /// own `vc:<…>` id while sharing [asset]'s pixels.
  final String? entryId;

  /// Direct JPEG bytes (used by the sample-editor entry point).
  final Uint8List? imageBytes;

  /// The entry id this session saves to (null in sample mode, which has
  /// nothing to persist).
  String? get _entryId =>
      entryId ?? (asset != null ? originalEntryId(asset!.id) : null);

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  Uint8List? _bytes;
  bool _loading = true;
  String? _error;
  bool _exporting = false;
  /// Live cancel token for an in-flight export (P4); null when idle.
  int? _exportCancelToken;
  /// Current export phase for the progress bar; null when idle.
  ExportPhase? _exportPhase;
  /// Engine render fraction (0..1) polled from the Rust progress cell.
  double _exportRenderFraction = 0;
  /// True while the share sheet is being prepared (temp files writing).
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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
              : await AxEngine.syntheticJpeg(width: 1024, height: 1024));
      if (bytes.isEmpty) throw StateError('The image could not be read.');
      if (!mounted) return;
      axLog(LogDomain.editor, 'Opened ${widget.asset?.id ?? 'sample image'}');

      // Restore this entry's saved (non-destructive) recipe, or start neutral.
      final notifier = ref.read(recipeControllerProvider.notifier);
      final entryId = widget._entryId;
      if (entryId != null) {
        final saved = ref.read(recipeStoreProvider)[entryId];
        notifier.loadRecipe(saved ?? EditRecipe.neutral, label: 'Opened');
      } else {
        notifier.loadRecipe(EditRecipe.neutral, label: 'Sample');
      }

      setState(() {
        _bytes = bytes;
        _loading = false;
      });
    } catch (e) {
      axLog(LogDomain.editor, 'Open failed: $e', level: LogLevel.error);
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
    setState(() {
      _exporting = true;
      _exportPhase = ExportPhase.loading;
      _exportRenderFraction = 0;
    });
    var token = 0;
    ExportProgressPoller? poller;
    try {
      // Export at full resolution: fetch the original only now (never during
      // preview), so the editor's memory stays at preview size until export.
      final bytes = widget.asset != null
          ? await ref.read(gallerySourceProvider).loadImage(widget.asset!.id)
          : previewBytes;
      if (bytes.isEmpty) throw StateError('The image could not be read.');

      final recipe = ref.read(recipeControllerProvider).recipe;
      final settings = ref.read(exportSettingsProvider);
      // RAW/DNG export goes through the Rust RAW path; Exif extraction is
      // JPEG-specific and yields nothing for raw containers (follow-up).
      final isRaw = isRawImage(bytes);
      if (!mounted) return;
      setState(() => _exportPhase = ExportPhase.decoding);
      final decoded = isRaw
          ? await AxEngine.decodeRawRgba(bytes)
          : await AxEngine.decodeJpegRgba(bytes);
      final exif = isRaw
          ? Uint8List(0)
          : await AxEngine.extractExif(bytes);

      // One-call export inside Rust (geometry → banded spatial → masks → grade
      // → encode), cancellable via a token so a big render can be aborted.
      token = await AxEngine.exportCancelNew();
      if (!mounted) return;
      setState(() {
        _exportCancelToken = token;
        _exportPhase = ExportPhase.rendering;
      });
      // Poll the Rust progress cell (permille, updated between bands) so the
      // bar tracks the real render, not a guess.
      poller = ExportProgressPoller(
        token: token,
        read: AxEngine.exportProgressFraction,
        onValue: (fraction) {
          if (!mounted) return;
          setState(() => _exportRenderFraction = fraction);
        },
      )..start();

      final jpeg = await AxEngine.exportJpegFull(
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
        cancelToken: token,
      );
      if (jpeg == null) {
        axLog(LogDomain.export, 'Export cancelled');
        if (mounted) {
          messenger.showSnackBar(const SnackBar(content: Text('Export cancelled')));
        }
        return;
      }
      if (!mounted) return;
      setState(() => _exportPhase = ExportPhase.saving);
      if (!await Gal.hasAccess()) await Gal.requestAccess();
      final outName = 'aperturex_${DateTime.now().millisecondsSinceEpoch}';
      await Gal.putImageBytes(jpeg, name: outName);
      // Sidecar next to the export (#77): the same recipe as a Lightroom-
      // readable .xmp, best effort (a failure logs, never fails the export).
      await emitXmpSidecar(
        ref.read(exportSidecarSinkProvider),
        outName,
        recipe,
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
            onPressed: () => _share(jpeg, recipe),
          ),
        ),
      );
    } catch (e) {
      axLog(LogDomain.export, 'Export failed: $e', level: LogLevel.error);
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    } finally {
      poller?.stop();
      if (token != 0) {
        await AxEngine.exportCancelDrop(token);
      }
      if (mounted) {
        setState(() {
          _exporting = false;
          _exportCancelToken = null;
          _exportPhase = null;
          _exportRenderFraction = 0;
        });
      }
    }
  }

  void _cancelExport() {
    final token = _exportCancelToken;
    if (token == null) return;
    axLog(LogDomain.export, 'Cancel requested');
    AxEngine.exportCancelSet(token);
  }

  Future<void> _share(Uint8List jpeg, EditRecipe recipe) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sharing = true);
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/aperturex-share.jpg');
      await file.writeAsBytes(jpeg, flush: true);
      // The .xmp rides along so the user can drop it next to the photo in
      // Lightroom/darktable (#77 — edits must be able to leave the app).
      final xmp = File(
        '${dir.path}/${XmpSidecar.fileNameFor('aperturex-share.jpg')}',
      );
      await xmp.writeAsString(writeXmp(recipe), flush: true);
      if (!mounted) return;
      setState(() => _sharing = false);
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile(file.path, mimeType: 'image/jpeg'),
            XFile(xmp.path, mimeType: 'application/xml'),
          ],
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _sharing = false);
      messenger.showSnackBar(SnackBar(content: Text('Share failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Persist every edit back to this photo's recipe (non-destructive editing:
    // the recipe survives leaving and re-opening the photo).
    ref.listen(recipeControllerProvider, (previous, next) {
      final entryId = widget._entryId;
      if (entryId != null) {
        ref.read(recipeStoreProvider.notifier).put(entryId, next.recipe);
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
    final guide = IconButton(
      tooltip: 'Editor Guide',
      onPressed: () => EditorGuideSheet.show(context),
      icon: const Icon(Icons.help_outline),
    );
    final more = IconButton(
      tooltip: 'More',
      onPressed: () => _openSettings(context),
      icon: const Icon(Icons.more_vert),
    );
    final export = Padding(
      padding: const EdgeInsets.only(right: Insets.sm),
      child: FilledButton.tonalIcon(
        onPressed: _bytes == null
            ? null
            : _exporting
                ? _cancelExport
                : _export,
        icon: _exporting
            ? const Icon(Icons.cancel_outlined, size: 18)
            : const Icon(Icons.ios_share, size: 18),
        label: Text(_exporting ? 'Cancel' : 'Export'),
      ),
    );

    return EditorShortcuts(
      entryId: widget._entryId,
      child: Scaffold(
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
                actions: gestureShell ? null : [crop, guide, more, export],
              ),
            ),
          ),
        ),
        body: Column(
          children: [
            // Slim determinate bar under the app bar while an export runs:
            // phase label + percent, fed by the Rust progress cell (no more
            // "frozen Cancel button" during a long render).
            if (_exporting)
              ExportProgressBar(
                key: const Key('export-progress'),
                label: _exportPhase == null
                    ? 'Exporting'
                    : phaseLabel(_exportPhase!),
                value: _exportPhase == null
                    ? null
                    : exportOverall(_exportPhase!, _exportRenderFraction),
                onCancel: _cancelExport,
              ),
            Expanded(
              child: Stack(
                children: [
                  _body(
                    gestureShell: gestureShell,
                    hud: Row(
                      children: [crop, undo, redo, guide, more, const Spacer(), export],
                    ),
                  ),
                  // Modal barrier while the share sheet's temp files are
                  // being written. It dismisses itself right before the system
                  // share UI opens, so the user only ever sees it for the
                  // file-write window.
                  if (_sharing)
                    Positioned.fill(
                      child: ColoredBox(
                        color: Theme.of(context)
                            .colorScheme
                            .scrim
                            .withValues(alpha: 0.32),
                        child: const Center(
                          child: Card(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 28,
                                    height: 28,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                    ),
                                  ),
                                  SizedBox(height: 14),
                                  Text('Preparing share…'),
                                ],
                              ),
                            ),
                          ),
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

  Widget _body({required bool gestureShell, Widget? hud}) {
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
