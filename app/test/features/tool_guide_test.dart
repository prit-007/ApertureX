import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/features/guide/tool_guide_model.dart';
import 'package:aperturex/features/guide/tool_guide_registry.dart';

void main() {
  group('ToolGuideRegistry', () {
    test('contains comprehensive guides for all core photography tools', () {
      final guides = ToolGuideRegistry.allGuides;
      expect(guides.length, greaterThanOrEqualTo(15));

      // Key tools exist
      final exposure = ToolGuideRegistry.getById('exposure');
      expect(exposure, isNotNull);
      expect(exposure!.title, 'Exposure & Dynamic Range');
      expect(exposure.category, ToolCategory.light);
      expect(exposure.proTips, isNotEmpty);

      final curves = ToolGuideRegistry.getById('curves');
      expect(curves, isNotNull);
      expect(curves!.title, contains('Curves'));

      final tat = ToolGuideRegistry.getById('tat');
      expect(tat, isNotNull);
      expect(tat!.title, contains('Targeted Adjustment'));

      final depthBokeh = ToolGuideRegistry.getById('depth_bokeh');
      expect(depthBokeh, isNotNull);
      expect(depthBokeh!.title, contains('Depth'));

      final neuralPlugins = ToolGuideRegistry.getById('neural_plugins');
      expect(neuralPlugins, isNotNull);
      expect(neuralPlugins!.title, contains('Neural'));

      final stylus = ToolGuideRegistry.getById('stylus');
      expect(stylus, isNotNull);
      expect(stylus!.category, ToolCategory.masking);
    });

    test('filters guides by category', () {
      final lightGuides = ToolGuideRegistry.getByCategory(ToolCategory.light);
      expect(lightGuides, isNotEmpty);
      expect(lightGuides.every((g) => g.category == ToolCategory.light), isTrue);

      final maskingGuides = ToolGuideRegistry.getByCategory(ToolCategory.masking);
      expect(maskingGuides, isNotEmpty);
      expect(maskingGuides.every((g) => g.category == ToolCategory.masking), isTrue);
    });

    test('searches guides by query in title, summary, or pro tips', () {
      final bokehResults = ToolGuideRegistry.search('bokeh');
      expect(bokehResults, isNotEmpty);
      expect(bokehResults.any((g) => g.id == 'depth_bokeh'), isTrue);

      final rawResults = ToolGuideRegistry.search('DNG');
      expect(rawResults, isNotEmpty);
    });
  });
}
