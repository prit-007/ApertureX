/// Photo navigation state and controls for the visible filmstrip.
///
/// Tracks which [GalleryAsset] is currently being edited and provides
/// previous/next navigation through the gallery's asset list. Wraps at both
/// ends so the user can cycle continuously through their library.
library;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'gallery_asset.dart';
import 'gallery_controller.dart';

class PhotoNavigatorState {
  const PhotoNavigatorState({
    required this.assets,
    required this.currentIndex,
  });

  final List<GalleryAsset> assets;
  final int currentIndex;

  GalleryAsset? get currentAsset =>
      assets.isEmpty || currentIndex < 0 || currentIndex >= assets.length
          ? null
          : assets[currentIndex];

  int get assetCount => assets.length;

  bool get canGoPrevious => assets.isNotEmpty && currentIndex > 0;
  bool get canGoNext => assets.isNotEmpty && currentIndex < assets.length - 1;

  PhotoNavigatorState copyWith({
    List<GalleryAsset>? assets,
    int? currentIndex,
  }) {
    return PhotoNavigatorState(
      assets: assets ?? this.assets,
      currentIndex: currentIndex ?? this.currentIndex,
    );
  }
}

/// Navigates through gallery assets for the visible filmstrip.
class PhotoNavigator extends Notifier<PhotoNavigatorState> {
  @override
  PhotoNavigatorState build() {
    final assets = ref.watch(galleryControllerProvider.select((s) => s.assets));
    return PhotoNavigatorState(
      assets: assets,
      currentIndex: assets.isEmpty ? -1 : 0,
    );
  }

  /// Moves to the next asset, wrapping to the first at the end.
  void goNext() {
    final assets = state.assets;
    if (assets.isEmpty) return;
    final next = (state.currentIndex + 1) % assets.length;
    state = state.copyWith(currentIndex: next);
  }

  /// Moves to the previous asset, wrapping to the last at the start.
  void goPrevious() {
    final assets = state.assets;
    if (assets.isEmpty) return;
    final prev = (state.currentIndex - 1 + assets.length) % assets.length;
    state = state.copyWith(currentIndex: prev);
  }

  /// Jumps to the asset at [index]. Ignores out-of-range indices.
  void jumpTo(int index) {
    final assets = state.assets;
    if (assets.isEmpty || index < 0 || index >= assets.length) return;
    state = state.copyWith(currentIndex: index);
  }

  /// Sets the current asset by matching its id.
  void setCurrentAsset(GalleryAsset asset) {
    final index = state.assets.indexWhere((a) => a.id == asset.id);
    if (index >= 0) {
      state = state.copyWith(currentIndex: index);
    }
  }

  /// Refreshes the asset list when the gallery reloads, keeping the current
  /// index valid.
  void refreshAssets() {
    final assets = ref.read(galleryControllerProvider.select((s) => s.assets));
    if (assets.isEmpty) {
      state = state.copyWith(assets: const [], currentIndex: -1);
      return;
    }
    final validIndex = state.currentIndex.clamp(0, assets.length - 1);
    state = state.copyWith(assets: assets, currentIndex: validIndex);
  }
}

/// Provider for photo navigation state.
final photoNavigatorProvider =
    NotifierProvider<PhotoNavigator, PhotoNavigatorState>(
  PhotoNavigator.new,
);
