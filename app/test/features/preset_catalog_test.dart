import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/edit/recipe.dart';
import 'package:aperturex/edit/tool_definition.dart';
import 'package:aperturex/features/presets/cultural_travel_presets.dart';
import 'package:aperturex/features/presets/movie_presets.dart';
import 'package:aperturex/features/presets/nature_presets.dart';
import 'package:aperturex/features/presets/preset_catalog.dart';

void main() {
  group('PresetCatalog Comprehensive Suite', () {
    test('PresetCatalog contains all curated preset families', () {
      final presets = PresetCatalog.allPresets;
      expect(presets.length, greaterThanOrEqualTo(55));

      final categories = presets.map((p) => p.category).toSet();
      expect(categories, contains(PresetCategory.cinema));
      expect(categories, contains(PresetCategory.anime));
      expect(categories, contains(PresetCategory.nature));
      expect(categories, contains(PresetCategory.portrait));
      expect(categories, contains(PresetCategory.indian));
      expect(categories, contains(PresetCategory.travel));
      expect(categories, contains(PresetCategory.film));
    });

    test('movieLooks contains all requested movies and anime styles', () {
      final names = movieLooks.map((m) => m.name).toList();
      expect(names, contains('Ready Player One'));
      expect(names, contains('Avatar'));
      expect(names, contains('The Terminator'));
      expect(names, contains('John Wick'));
      expect(names, contains('John Wick 2: Rome'));
      expect(names, contains('John Wick 3: Parabellum'));
      expect(names, contains('John Wick 4: Osaka'));
      expect(names, contains('The Dark Knight'));
      expect(names, contains('The Batman'));
      expect(names, contains('Batman v Superman'));
      expect(names, contains('Oppenheimer'));
      expect(names, contains('Interstellar'));
      expect(names, contains('Pulp Fiction'));
      expect(names, contains('Fight Club'));
      expect(names, contains('La La Land'));
      expect(names, contains('Blade Runner (1982)'));
      expect(names, contains('The Revenant'));
      expect(names, contains('Drive'));
      expect(names, contains('Anime: Shinkai Sky'));
      expect(names, contains('Anime: Ghibli Garden'));
      expect(names, contains('Anime: Spirited Away'));
      expect(names, contains('Anime: Neo-Tokyo'));
      expect(names, contains('Anime: 90s Retro Cel'));
      expect(names, contains('Anime: Cyberpunk Edgerunners'));
    });

    test('natureLooks contains scenario-optimized presets', () {
      final names = natureLooks.map((n) => n.name).toList();
      expect(names, contains('Greenery Forest'));
      expect(names, contains('Beach & Ocean'));
      expect(names, contains('Alpine Mountains'));
      expect(names, contains('Golden Outdoors'));
      expect(names, contains('Natural Portrait'));
      expect(names, contains('Dramatic Backlight'));
      expect(names, contains('Moody Indoor'));
      expect(names, contains('Action & Sports'));
    });

    test('culturalTravelLooks contains Indian weddings, festive & tourist postcard presets', () {
      final names = culturalTravelLooks.map((c) => c.name).toList();
      expect(names, contains('Universal Brilliance'));
      expect(names, contains('Clean Editorial Pop'));
      expect(names, contains('Royal Indian Wedding'));
      expect(names, contains('Desi Festive: Diwali & Holi'));
      expect(names, contains('Royal Heritage: Rajasthan'));
      expect(names, contains('Tourist Travel Postcard'));
      expect(names, contains('Wanderlust Sunset'));
      expect(names, contains('Bazaar & Spice Market'));
      expect(names, contains('Ancient Monuments'));
      expect(names, contains('Vivid HDR Radiance'));
      expect(names, contains('Leica M Monochrom'));
      expect(names, contains('Vintage Kodachrome 64'));
      expect(names, contains('Fuji Velvia 50'));
      expect(names, contains('Cinestill 800T'));
      expect(names, contains('Kerala Monsoon & Backwaters'));
      expect(names, contains('Bollywood Golden Hour'));
    });

    test('every preset applies 3-way color wheels and HSL to EditRecipe', () {
      const base = EditRecipe();
      for (final item in PresetCatalog.allPresets) {
        final applied = item.tool.applyTo(base);
        expect(applied, isNotNull);

        // Grade wheels should be applied if present in params
        if (item.tool.params.containsKey('gradeShadowHue')) {
          expect(applied.gradeShadowHue, closeTo(item.tool.params['gradeShadowHue']!, 1e-4));
        }
        if (item.tool.params.containsKey('gradeHighlightHue')) {
          expect(applied.gradeHighlightHue, closeTo(item.tool.params['gradeHighlightHue']!, 1e-4));
        }

        // HSL should be applied if present in tool
        if (item.tool.hsl != null && item.tool.hsl!.isNotEmpty) {
          expect(applied.hsl.length, 24);
          expect(applied.hsl, isNot(equals(neutralHsl)));
        }
      }
    });

    test('search filters across titles, descriptions, and categories', () {
      final searchWick = PresetCatalog.search('Wick');
      expect(searchWick.length, greaterThanOrEqualTo(4));

      final searchBatman = PresetCatalog.search('Batman');
      expect(searchBatman.length, greaterThanOrEqualTo(3));

      final searchIndian = PresetCatalog.search('', category: PresetCategory.indian);
      expect(searchIndian.length, greaterThanOrEqualTo(3));
      for (final p in searchIndian) {
        expect(p.category, PresetCategory.indian);
      }

      final searchTravel = PresetCatalog.search('Postcard', category: PresetCategory.travel);
      expect(searchTravel.length, 1);
      expect(searchTravel.first.name, 'Tourist Travel Postcard');
    });

    test('ToolLibrary.allBuiltins aggregates all preset definitions', () {
      final all = ToolLibrary.allBuiltins;
      expect(all.length, greaterThanOrEqualTo(PresetCatalog.allPresets.length));
    });
  });
}
