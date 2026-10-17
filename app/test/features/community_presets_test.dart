import 'package:aperturex/edit/recipe_controller.dart';
import 'package:aperturex/features/presets/community_preset_model.dart';
import 'package:aperturex/features/presets/community_presets_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CommunityPreset Model', () {
    test('serializes and deserializes correctly', () {
      final preset = CommunityPreset(
        id: 'film_ektar_100',
        name: 'Kodak Ektar 100',
        category: 'Film',
        author: '@devparadise',
        description: 'Vivid color saturation with fine grain',
        previewUrl: 'https://example.com/ektar.webp',
        recipeUrl: 'https://example.com/ektar.aperturex.json',
        downloadCount: 1420,
        rating: 4.9,
        params: {
          'saturation': 0.25,
          'contrast': 0.15,
          'vibrance': 0.18,
          'grain': 0.12,
        },
      );

      final json = preset.toJson();
      final restored = CommunityPreset.fromJson(json);

      expect(restored.id, 'film_ektar_100');
      expect(restored.name, 'Kodak Ektar 100');
      expect(restored.category, 'Film');
      expect(restored.author, '@devparadise');
      expect(restored.downloadCount, 1420);
      expect(restored.rating, 4.9);
      expect(restored.params?['saturation'], 0.25);
    });

    test('toToolDefinition produces valid ToolDefinition', () {
      final preset = CommunityPreset(
        id: 'moody_nordic',
        name: 'Nordic Pines',
        category: 'Moody',
        author: '@lens_wanderer',
        description: 'Desaturated greens with deep crushed blacks',
        params: {
          'contrast': 0.22,
          'shadows': -0.15,
          'saturation': -0.18,
        },
      );

      final tool = preset.toToolDefinition();
      expect(tool.name, 'Nordic Pines');
      expect(tool.description, contains('Desaturated greens'));
      expect(tool.params['contrast'], 0.22);
      expect(tool.params['shadows'], -0.15);
    });
  });

  group('CommunityPresetsNotifier', () {
    test('initializes with curated community presets and loads offline', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(communityPresetsProvider);
      expect(state.presets, isNotEmpty);
      expect(
        state.presets.any((p) => p.name == 'Kodak Ektar 100'),
        isTrue,
        reason: 'Should include verified curated Ektar 100 film preset',
      );
      expect(
        state.presets.any((p) => p.category == 'Film'),
        isTrue,
      );
      expect(
        state.presets.any((p) => p.category == 'Portraits'),
        isTrue,
      );
      expect(
        state.presets.any((p) => p.category == 'Moody'),
        isTrue,
      );
      expect(
        state.presets.any((p) => p.category == 'Landscape'),
        isTrue,
      );
    });

    test('filters presets by category correctly', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(communityPresetsProvider.notifier);

      notifier.selectCategory('Film');
      var state = container.read(communityPresetsProvider);
      expect(state.selectedCategory, 'Film');
      expect(state.filteredPresets.every((p) => p.category == 'Film'), isTrue);

      notifier.selectCategory('Portraits');
      state = container.read(communityPresetsProvider);
      expect(state.selectedCategory, 'Portraits');
      expect(state.filteredPresets.every((p) => p.category == 'Portraits'), isTrue);

      notifier.selectCategory('All');
      state = container.read(communityPresetsProvider);
      expect(state.filteredPresets.length, state.presets.length);
    });

    test('filters presets by search query', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(communityPresetsProvider.notifier);

      notifier.setSearchQuery('ektar');
      final state = container.read(communityPresetsProvider);
      expect(state.filteredPresets, isNotEmpty);
      expect(
        state.filteredPresets.every((p) =>
            p.name.toLowerCase().contains('ektar') ||
            p.description.toLowerCase().contains('ektar')),
        isTrue,
      );
    });

    test('downloadPreset saves to installed list and SharedPreferences', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(communityPresetsProvider.notifier);
      final ektar = container
          .read(communityPresetsProvider)
          .presets
          .firstWhere((p) => p.id == 'film_ektar_100');

      expect(notifier.isInstalled(ektar.id), isFalse);

      await notifier.downloadPreset(ektar);

      expect(notifier.isInstalled(ektar.id), isTrue);

      final prefs = await SharedPreferences.getInstance();
      final installedList = prefs.getStringList('aperturex_downloaded_presets');
      expect(installedList, isNotNull);
      expect(installedList, contains('film_ektar_100'));
    });

    test('applyPreset updates RecipeController and commits', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(communityPresetsProvider.notifier);
      final ektar = container
          .read(communityPresetsProvider)
          .presets
          .firstWhere((p) => p.id == 'film_ektar_100');

      notifier.applyPreset(container, ektar);

      final recipe = container.read(recipeControllerProvider).recipe;
      expect(recipe.saturation, closeTo(0.25, 0.001));
      expect(recipe.contrast, closeTo(0.15, 0.001));
    });
  });
}
