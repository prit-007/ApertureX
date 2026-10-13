import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'gallery_asset.dart';
import 'gallery_source.dart';

/// Gallery + multi-selection state.
class GalleryState {
  const GalleryState({
    this.assets = const [],
    this.selected = const {},
    this.loading = false,
    this.selectionMode = false,
    this.error,
  });

  final List<GalleryAsset> assets;
  final Set<String> selected;
  final bool loading;
  final bool selectionMode;
  final String? error;

  int get selectedCount => selected.length;
  bool isSelected(String id) => selected.contains(id);

  GalleryState copyWith({
    List<GalleryAsset>? assets,
    Set<String>? selected,
    bool? loading,
    bool? selectionMode,
    String? error,
  }) => GalleryState(
    assets: assets ?? this.assets,
    selected: selected ?? this.selected,
    loading: loading ?? this.loading,
    selectionMode: selectionMode ?? this.selectionMode,
    error: error,
  );
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
    try {
      final assets = await ref.read(gallerySourceProvider).listImages();
      state = state.copyWith(assets: assets, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: '$e');
    }
  }

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
