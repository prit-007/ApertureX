import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:aperturex/edit/library_catalog.dart';
import 'package:aperturex/edit/parameter.dart';
import 'package:aperturex/edit/recipe_controller.dart';
import 'package:aperturex/edit/settings_clipboard.dart';
import 'package:aperturex/features/editor/editor_screen.dart';
import 'package:aperturex/features/editor/editor_shortcuts.dart';
import 'package:aperturex/gallery/gallery_asset.dart';
import 'package:aperturex/gallery/gallery_controller.dart';
import 'package:aperturex/gallery/gallery_source.dart';
import 'package:aperturex/viewport/compare_hold.dart';

/// A valid 1×1 PNG so `Image.memory` decodes in tests.
final Uint8List _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        gallerySourceProvider.overrideWithValue(
          FakeGallerySource(
            images: {'a': _png},
            thumbnails: {'a': _png},
            assets: const [GalleryAsset(id: 'a', width: 1, height: 1)],
          ),
        ),
      ],
    );
  });
  tearDown(() => container.dispose());

  Future<void> pumpEditor(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: EditorScreen(asset: GalleryAsset(id: 'a', width: 1, height: 1)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// Sends a chord: modifiers are pressed as real keys first (the test
  /// binding derives the event's modifier state from the pressed-key set).
  Future<void> press(
    WidgetTester tester,
    LogicalKeyboardKey key, {
    bool ctrl = false,
    bool meta = false,
    bool shift = false,
  }) async {
    if (ctrl) {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    }
    if (meta) {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    }
    if (shift) {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    }
    await tester.sendKeyDownEvent(key);
    await tester.sendKeyUpEvent(key);
    if (shift) {
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    }
    if (meta) {
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    }
    if (ctrl) {
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    }
    await tester.pump();
  }

  testWidgets(r'\ toggles the before/after compare', (tester) async {
    await pumpEditor(tester);
    expect(container.read(compareHoldProvider), isFalse);

    await press(tester, LogicalKeyboardKey.backslash);
    expect(container.read(compareHoldProvider), isTrue);

    await press(tester, LogicalKeyboardKey.backslash);
    expect(container.read(compareHoldProvider), isFalse);
  });

  testWidgets('Cmd/Ctrl+Z undoes and Cmd/Ctrl+Shift+Z redoes', (tester) async {
    await pumpEditor(tester);
    final notifier = container.read(recipeControllerProvider.notifier);
    notifier.update(Parameter.exposure, 1);
    // update() only edits the live recipe — commit() creates the history node
    // that undo/redo step through (as gesture-end does in the UI).
    notifier.commit(label: 'Exposure');
    await tester.pump();
    expect(container.read(recipeControllerProvider).recipe.exposure, 1);

    await press(tester, LogicalKeyboardKey.keyZ, ctrl: true);
    expect(container.read(recipeControllerProvider).recipe.exposure, 0);

    await press(tester, LogicalKeyboardKey.keyZ, ctrl: true, shift: true);
    expect(container.read(recipeControllerProvider).recipe.exposure, 1);
  });

  testWidgets('Cmd/Ctrl+C copies and Cmd/Ctrl+V pastes the recipe', (
    tester,
  ) async {
    await pumpEditor(tester);
    final notifier = container.read(recipeControllerProvider.notifier);
    notifier.update(Parameter.exposure, 1);
    notifier.commit(label: 'Exposure');
    await tester.pump();

    await press(tester, LogicalKeyboardKey.keyC, ctrl: true);
    expect(
      container.read(settingsClipboardProvider)!.exposure,
      1,
    );

    // Undo the edit, then paste the copied recipe back.
    await press(tester, LogicalKeyboardKey.keyZ, ctrl: true);
    expect(container.read(recipeControllerProvider).recipe.exposure, 0);
    await press(tester, LogicalKeyboardKey.keyV, ctrl: true);
    expect(container.read(recipeControllerProvider).recipe.exposure, 1);
  });

  testWidgets('1-5 rate the current entry and X flags it', (tester) async {
    await pumpEditor(tester);

    await press(tester, LogicalKeyboardKey.digit3);
    expect(
      container.read(libraryCatalogProvider)[originalEntryId('a')]!.rating,
      3,
    );

    await press(tester, LogicalKeyboardKey.digit5);
    expect(
      container.read(libraryCatalogProvider)[originalEntryId('a')]!.rating,
      5,
    );

    await press(tester, LogicalKeyboardKey.keyX);
    expect(
      container.read(libraryCatalogProvider)[originalEntryId('a')]!.flag,
      isTrue,
    );

    // Digits 6-9 set color labels (Red, Yellow, Green, Blue)
    await press(tester, LogicalKeyboardKey.digit6);
    expect(
      container.read(libraryCatalogProvider)[originalEntryId('a')]!.colorLabel,
      ColorLabel.red,
    );

    await press(tester, LogicalKeyboardKey.digit7);
    expect(
      container.read(libraryCatalogProvider)[originalEntryId('a')]!.colorLabel,
      ColorLabel.yellow,
    );

    // Pressing same digit toggles it off
    await press(tester, LogicalKeyboardKey.digit7);
    expect(
      container.read(libraryCatalogProvider)[originalEntryId('a')]!.colorLabel,
      isNull,
    );

    // Digit 0 clears rating
    await press(tester, LogicalKeyboardKey.digit0);
    expect(
      container.read(libraryCatalogProvider)[originalEntryId('a')]!.rating,
      0,
    );
  });

  testWidgets('? opens the shortcut cheat sheet', (tester) async {
    await pumpEditor(tester);

    await press(tester, LogicalKeyboardKey.slash, shift: true);

    expect(find.text('Keyboard shortcuts'), findsOneWidget);
    expect(find.text('Cmd/Ctrl+Z — Undo'), findsOneWidget);
  });

  testWidgets('keys are ignored while a text field has focus', (tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: EditorShortcuts(
            entryId: 'orig:a',
            child: Scaffold(body: TextField()),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byType(TextField));
    await tester.pump();

    await press(tester, LogicalKeyboardKey.backslash);
    expect(container.read(compareHoldProvider), isFalse);

    await press(tester, LogicalKeyboardKey.digit3);
    expect(
      container.read(libraryCatalogProvider).containsKey(originalEntryId('a')),
      isFalse,
    );
  });
}
