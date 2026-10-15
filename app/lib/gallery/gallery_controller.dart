import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/log/activity_log.dart';
import '../core/log/log_providers.dart';
import 'gallery_album.dart';
import 'gallery_asset.dart';
import 'gallery_source.dart';

/// Gallery + album + multi-selection state.
class GalleryState {
  const GalleryState({
    this.assets = const [],
    this.albums = const [],
    this.selected = const {},
    this.loading = false,
    this.selectionMode = false,
    this.selectedAlbumId,
    this.permission,
    this.error,
  });

  final List<GalleryAsset> assets;
  final List<GalleryAlbum> albums;
  final Set<String> selected;
  final bool loading;
  final bool selectionMode;

  /// null = the default "Recent / all" stream.
  final String? selectedAlbumId;

  /// Latest photo-permission result (null until first requested).
  final GalleryPermission? permission;
  final String? error;

  int get selectedCount => selected.length;
  bool isSelected(String id) => selected.contains(id);

  /// True once access has been requested and refused.
  bool get permissionDenied => permission == GalleryPermission.denied;

  String get title => selectedAlbumId == null
      ? 'Recent'
      : albums
            .firstWhere(
              (a) => a.id == selectedAlbumId,
              orElse: () => const GalleryAlbum(id: '', name: 'Album', count: 0),
            )
            .name;

  GalleryState copyWith({
    List<GalleryAsset>? assets,
    List<GalleryAlbum>? albums,
    Set<String>? selected,
    bool? loading,
    bool? selectionMode,
    Object? selectedAlbumId = _unset,
    GalleryPermission? permission,
    String? error,
  }) => GalleryState(
    assets: assets ?? this.assets,
    albums: albums ?? this.albums,
    selected: selected ?? this.selected,
    loading: loading ?? this.loading,
    selectionMode: selectionMode ?? this.selectionMode,
    selectedAlbumId: identical(selectedAlbumId, _unset)
        ? this.selectedAlbumId
        : selectedAlbumId as String?,
    permission: permission ?? this.permission,
    error: error,
  );

  static const Object _unset = Object();
}

/// The app overrides this with a `photo_manager`-backed source; tests override
/// it with a [FakeGallerySource].
final gallerySourceProvider = Provider<GallerySource>(
  (ref) => throw UnimplementedError('gallerySourceProvider must be overridden'),
);

class GalleryController extends Notifier<GalleryState> {
  @override
  GalleryState build() => const GalleryState();

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    final source = ref.read(gallerySourceProvider);
    try {
      final permission = await source.requestPermission();
      if (!permission.canRead) {
        axLog(LogDomain.permission, 'Photo access denied', level: LogLevel.warning);
        state = state.copyWith(loading: false, permission: permission);
        return;
      }
      final albums = await source.listAlbums();
      final assets = await source.listImages(albumId: state.selectedAlbumId);
      axLog(LogDomain.gallery, 'Loaded ${assets.length} photo(s)');
      state = state.copyWith(
        assets: assets,
        albums: albums,
        loading: false,
        permission: permission,
      );
    } catch (e) {
      axLog(LogDomain.gallery, 'Gallery load failed: $e', level: LogLevel.error);
      state = state.copyWith(loading: false, error: '$e');
    }
  }

  /// Switches to [albumId] (null = Recent) and reloads that album's photos.
  Future<void> selectAlbum(String? albumId) async {
    if (state.selectedAlbumId == albumId) return;
    axLog(LogDomain.gallery, 'Opened album ${albumId ?? 'Recent'}');
    state = state.copyWith(
      selectedAlbumId: albumId,
      assets: const [],
      selected: const {},
      selectionMode: false,
      loading: true,
      error: null,
    );
    try {
      final assets = await ref
          .read(gallerySourceProvider)
          .listImages(albumId: albumId);
      state = state.copyWith(assets: assets, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: '$e');
    }
  }

  /// Re-requests a denied permission (the "prompt again" path).
  Future<void> requestAccessAgain() => load();

  /// Opens the OS settings page for a permanently-denied permission.
  Future<void> openSettings() =>
      ref.read(gallerySourceProvider).openAppSettings();

  void startSelection(String id) =>
      state = state.copyWith(selectionMode: true, selected: {id});

  void toggle(String id) {
    final selected = {...state.selected};
    if (!selected.remove(id)) selected.add(id);
    state = state.copyWith(
      selected: selected,
      selectionMode: selected.isNotEmpty,
    );
  }

  void clearSelection() =>
      state = state.copyWith(selected: const {}, selectionMode: false);

  void selectAll() => state = state.copyWith(
    selectionMode: true,
    selected: {for (final asset in state.assets) asset.id},
  );
}

final galleryControllerProvider =
    NotifierProvider<GalleryController, GalleryState>(GalleryController.new);
