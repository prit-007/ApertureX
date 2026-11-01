import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' as material_ui;

import 'package:aperturex/features/presets/content_classifier.dart';
import 'package:aperturex/features/presets/preset_catalog.dart';
import 'package:aperturex/features/presets/preset_ids.dart';
import 'package:aperturex/ui/common/looks_sheet.dart';

void main() {
  testWidgets('RecommendedPresetsChipRow shows primary and alternate chips', (
    WidgetTester tester,
  ) async {
    final result = ClassificationResult(
      category: PresetCategory.portrait,
      primaryPresetId: PresetIds.mainCharacter,
      primaryPresetName: 'Main Character',
      alternatePresets: const [
        AlternatePreset(id: PresetIds.softCore, name: 'Soft Core'),
        AlternatePreset(id: PresetIds.cleanGirl, name: 'Clean Girl'),
      ],
      reason: 'Faces detected — portrait presets',
    );

    final selectedId = <String>[];
    await tester.pumpWidget(
      material_ui.MaterialApp(
        home: material_ui.Material(
          child: RecommendedPresetsChipRow(
            result: result,
            onPresetSelected: (id) => selectedId.add(id),
          ),
        ),
      ),
    );

    // Primary chip should be visible
    expect(find.text('Main Character'), findsOneWidget);
    // Alternate chips should be visible
    expect(find.text('Soft Core'), findsOneWidget);
    expect(find.text('Clean Girl'), findsOneWidget);
    // Reason should be visible
    expect(find.text('Faces detected — portrait presets'), findsOneWidget);
  });

  testWidgets('RecommendedPresetsChipRow calls onPresetSelected when chip tapped', (
    WidgetTester tester,
  ) async {
    final result = ClassificationResult(
      category: PresetCategory.portrait,
      primaryPresetId: PresetIds.mainCharacter,
      primaryPresetName: 'Main Character',
      alternatePresets: const [],
      reason: 'Test',
    );

    final selectedId = <String>[];
    await tester.pumpWidget(
      material_ui.MaterialApp(
        home: material_ui.Material(
          child: RecommendedPresetsChipRow(
            result: result,
            onPresetSelected: (id) => selectedId.add(id),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Main Character'));
    await tester.pumpAndSettle();

    expect(selectedId, contains(PresetIds.mainCharacter));
  });

  testWidgets('RecommendedPresetsChipRow shows nothing when no presets', (
    WidgetTester tester,
  ) async {
    final result = ClassificationResult(
      category: PresetCategory.all,
      primaryPresetId: '',
      primaryPresetName: '',
      alternatePresets: const [],
      reason: 'No recommendations',
    );

    await tester.pumpWidget(
      material_ui.MaterialApp(
        home: material_ui.Material(
          child: RecommendedPresetsChipRow(
            result: result,
            onPresetSelected: (id) {},
          ),
        ),
      ),
    );

    expect(find.byType(RecommendedPresetsChipRow), findsOneWidget);
    expect(find.text('Main Character'), findsNothing);
  });
}
