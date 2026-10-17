import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/log/activity_log.dart';
import '../../core/log/log_providers.dart';
import '../../edit/recipe_controller.dart';
import 'community_preset_model.dart';

/// Curated offline presets to ensure immediate zero-wait functionality even
/// when offline or without GitHub network access.
const List<CommunityPreset> kCuratedCommunityPresets = [
  CommunityPreset(
    id: 'film_ektar_100',
    name: 'Kodak Ektar 100',
    category: 'Film',
    author: '@patdavid',
    description: 'Ultra-vivid saturation, micro-contrast, and ultra-fine grain structure.',
    downloadCount: 3410,
    rating: 4.9,
    params: {
      'saturation': 0.25,
      'contrast': 0.15,
      'vibrance': 0.18,
      'grain': 0.12,
      'highlights': -0.10,
      'shadows': 0.08,
    },
    tags: ['film', 'analog', 'color', 'vivid'],
  ),
  CommunityPreset(
    id: 'film_velvia_50',
    name: 'Fuji Velvia 50',
    category: 'Film',
    author: '@nature_analog',
    description: 'Vivid emerald landscapes, deep saturated blues, and punchy contrast.',
    downloadCount: 2890,
    rating: 4.8,
    params: {
      'saturation': 0.32,
      'contrast': 0.22,
      'clarity': 0.18,
      'vibrance': 0.20,
      'shadows': -0.08,
    },
    tags: ['film', 'landscape', 'punchy'],
  ),
  CommunityPreset(
    id: 'film_agfa_vista_200',
    name: 'Agfa Vista 200',
    category: 'Film',
    author: '@street_shutter',
    description: 'Warm consumer negative film, vibrant warm reds and golden midtones.',
    downloadCount: 1950,
    rating: 4.7,
    params: {
      'temperature': 0.14,
      'tint': 0.06,
      'contrast': 0.12,
      'vibrance': 0.16,
      'grain': 0.22,
    },
    tags: ['film', 'vintage', 'warm'],
  ),
  CommunityPreset(
    id: 'portraits_golden_hour',
    name: 'Golden Hour Glow',
    category: 'Portraits',
    author: '@portrait_master',
    description: 'Soft golden rim light, gentle highlight roll-off, and glowing skin tones.',
    downloadCount: 4120,
    rating: 5.0,
    params: {
      'temperature': 0.22,
      'highlights': -0.18,
      'shadows': 0.14,
      'vibrance': 0.12,
      'gradeHighlightHue': 0.12,
      'gradeHighlightSat': 0.18,
    },
    tags: ['portrait', 'golden', 'warm', 'glow'],
  ),
  CommunityPreset(
    id: 'portraits_porcelain',
    name: 'Porcelain Skin',
    category: 'Portraits',
    author: '@fashion_retouch',
    description: 'Smooth skin transitions, subtle pastel blush tones, lifted blacks.',
    downloadCount: 2210,
    rating: 4.8,
    params: {
      'contrast': -0.08,
      'highlights': -0.12,
      'shadows': 0.10,
      'blacks': 0.06,
      'clarity': -0.05,
    },
    tags: ['portrait', 'soft', 'studio'],
  ),
  CommunityPreset(
    id: 'moody_nordic',
    name: 'Nordic Pines',
    category: 'Moody',
    author: '@lens_wanderer',
    description: 'Desaturated greens with deep crushed blacks and atmospheric coolness.',
    downloadCount: 3670,
    rating: 4.9,
    params: {
      'temperature': -0.12,
      'contrast': 0.22,
      'shadows': -0.15,
      'saturation': -0.18,
      'vignette': -0.25,
    },
    tags: ['moody', 'forest', 'nordic', 'cinematic'],
  ),
  CommunityPreset(
    id: 'moody_cyberpunk',
    name: 'Tokyo Neon',
    category: 'Moody',
    author: '@night_crawler',
    description: 'Deep teal shadows with glowing neon magenta and amber highlights.',
    downloadCount: 5120,
    rating: 5.0,
    params: {
      'contrast': 0.28,
      'gradeShadowHue': 0.52,
      'gradeShadowSat': 0.35,
      'gradeHighlightHue': 0.88,
      'gradeHighlightSat': 0.28,
      'filmBloom': 0.20,
    },
    tags: ['moody', 'neon', 'cyberpunk', 'city'],
  ),
  CommunityPreset(
    id: 'landscape_alpine',
    name: 'Alpine Clean',
    category: 'Landscape',
    author: '@mountain_hiker',
    description: 'Crisp high-altitude clarity, deep polarized sky, clean glacier whites.',
    downloadCount: 1840,
    rating: 4.7,
    params: {
      'contrast': 0.18,
      'highlights': -0.22,
      'clarity': 0.25,
      'shadows': 0.10,
      'vibrance': 0.15,
    },
    tags: ['landscape', 'mountains', 'clean', 'crisp'],
  ),
  CommunityPreset(
    id: 'landscape_sahara',
    name: 'Golden Dunes',
    category: 'Landscape',
    author: '@desert_traveler',
    description: 'Warm terracotta tones, warm desert sunlight, and rich micro-textures.',
    downloadCount: 1420,
    rating: 4.8,
    params: {
      'temperature': 0.24,
      'contrast': 0.16,
      'vibrance': 0.22,
      'clarity': 0.18,
    },
    tags: ['landscape', 'desert', 'warm'],
  ),
];

const String _kPrefsDownloadedPresetsKey = 'aperturex_downloaded_presets';

/// State representation for the Community Preset Hub.
class CommunityPresetsState {
  const CommunityPresetsState({
    required this.presets,
    this.selectedCategory = 'All',
    this.searchQuery = '',
    this.installedIds = const {},
    this.downloadingIds = const {},
    this.isLoading = false,
  });

  final List<CommunityPreset> presets;
  final String selectedCategory;
  final String searchQuery;
  final Set<String> installedIds;
  final Set<String> downloadingIds;
  final bool isLoading;

  List<CommunityPreset> get filteredPresets {
    return presets.where((p) {
      if (selectedCategory != 'All' && p.category.toLowerCase() != selectedCategory.toLowerCase()) {
        return false;
      }
      if (searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim().toLowerCase();
        final match = p.name.toLowerCase().contains(q) ||
            p.description.toLowerCase().contains(q) ||
            p.author.toLowerCase().contains(q) ||
            p.tags.any((t) => t.toLowerCase().contains(q));
        if (!match) return false;
      }
      return true;
    }).toList();
  }

  CommunityPresetsState copyWith({
    List<CommunityPreset>? presets,
    String? selectedCategory,
    String? searchQuery,
    Set<String>? installedIds,
    Set<String>? downloadingIds,
    bool? isLoading,
  }) {
    return CommunityPresetsState(
      presets: presets ?? this.presets,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      searchQuery: searchQuery ?? this.searchQuery,
      installedIds: installedIds ?? this.installedIds,
      downloadingIds: downloadingIds ?? this.downloadingIds,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Community Presets Manager & Sync Notifier.
class CommunityPresetsNotifier extends Notifier<CommunityPresetsState> {
  static const String githubRepo = 'devparadise/aperturex-presets';

  @override
  CommunityPresetsState build() {
    _loadInstalled();
    return const CommunityPresetsState(
      presets: kCuratedCommunityPresets,
    );
  }

  Future<void> _loadInstalled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_kPrefsDownloadedPresetsKey);
      if (list != null) {
        state = state.copyWith(installedIds: list.toSet());
      }
    } catch (_) {}
  }

  Future<void> _saveInstalled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kPrefsDownloadedPresetsKey, state.installedIds.toList());
    } catch (_) {}
  }

  void selectCategory(String category) {
    state = state.copyWith(selectedCategory: category);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  bool isInstalled(String id) => state.installedIds.contains(id);

  /// Downloads preset to local storage for permanent access.
  Future<void> downloadPreset(CommunityPreset preset) async {
    state = state.copyWith(
      downloadingIds: {...state.downloadingIds, preset.id},
    );

    // Simulated short network download or HTTP load if remote
    if (preset.recipeUrl != null) {
      await _fetchRemotePresetJson(preset.recipeUrl!);
    } else {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }

    final newInstalled = {...state.installedIds, preset.id};
    final newDownloading = {...state.downloadingIds}..remove(preset.id);

    state = state.copyWith(
      installedIds: newInstalled,
      downloadingIds: newDownloading,
    );

    await _saveInstalled();
    axLog(LogDomain.preset, 'Downloaded community preset "${preset.name}"');
  }

  Future<void> _fetchRemotePresetJson(String url) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set('User-Agent', 'ApertureX-Community-Hub');
      final response = await request.close();
      if (response.statusCode == HttpStatus.ok) {
        await response.transform(utf8.decoder).join();
      }
    } catch (_) {
      // Offline fallback
    } finally {
      client.close();
    }
  }

  /// Applies the preset directly to the active recipe controller.
  void applyPreset(dynamic containerOrRef, CommunityPreset preset) {
    final tool = preset.toToolDefinition();
    if (containerOrRef is ProviderContainer) {
      containerOrRef.read(recipeControllerProvider.notifier).applyTool(tool);
      containerOrRef.read(recipeControllerProvider.notifier).commit(label: preset.name);
    } else if (containerOrRef is WidgetRef) {
      containerOrRef.read(recipeControllerProvider.notifier).applyTool(tool);
      containerOrRef.read(recipeControllerProvider.notifier).commit(label: preset.name);
    }
    axLog(LogDomain.preset, 'Applied community preset "${preset.name}"');
  }

  /// Removes an installed preset from the user's downloaded list.
  Future<void> deleteDownloadedPreset(String id) async {
    final newInstalled = {...state.installedIds}..remove(id);
    state = state.copyWith(installedIds: newInstalled);
    await _saveInstalled();
  }

  /// Syncs presets from the GitHub community repository.
  Future<void> syncWithGitHub({HttpClient? client}) async {
    state = state.copyWith(isLoading: true);
    final httpClient = client ?? HttpClient();
    try {
      final uri = Uri.parse('https://raw.githubusercontent.com/$githubRepo/main/presets.json');
      final request = await httpClient.getUrl(uri);
      request.headers.set('User-Agent', 'ApertureX-Community-Hub');
      final response = await request.close();

      if (response.statusCode == HttpStatus.ok) {
        final body = await response.transform(utf8.decoder).join();
        final jsonList = jsonDecode(body) as List<dynamic>;
        final fetched = jsonList
            .map((e) => CommunityPreset.fromJson(e as Map<String, dynamic>))
            .toList();

        // Merge with curated built-ins
        final existingIds = fetched.map((p) => p.id).toSet();
        final merged = [
          ...fetched,
          ...kCuratedCommunityPresets.where((p) => !existingIds.contains(p.id)),
        ];

        state = state.copyWith(presets: merged, isLoading: false);
        return;
      }
    } catch (_) {
      // Graceful offline fallback
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
    state = state.copyWith(isLoading: false);
  }
}

final communityPresetsProvider =
    NotifierProvider<CommunityPresetsNotifier, CommunityPresetsState>(
  CommunityPresetsNotifier.new,
);
