import 'dart:typed_data';

import 'package:flutter/services.dart' show MethodCall, SystemChannels;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:aperturex/edit/parameter.dart';
import 'package:aperturex/edit/recipe.dart';
import 'package:aperturex/edit/recipe_controller.dart';
import 'package:aperturex/edit/recipe_store.dart';
import 'package:aperturex/features/editor/editor_screen.dart';
import 'package:aperturex/gallery/gallery_asset.dart';
import 'package:aperturex/gallery/gallery_controller.dart';
import 'package:aperturex/gallery/gallery_source.dart';
import 'package:aperturex/settings/shell_preference.dart';
import 'package:aperturex/ui/lightroom/lightroom_shell.dart';
import 'package:aperturex/ui/app_shell.dart';
import 'package:aperturex/viewport/image_canvas.dart';

/// A valid 1×1 PNG (non-empty bytes so the editor proceeds to the canvas).
final Uint8List _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

void main() {
  ProviderContainer containerWith({Map<String, Uint8List> images = const {}}) =>
      ProviderContainer(
        overrides: [
          gallerySourceProvider.overrideWithValue(
            FakeGallerySource(images: images),
          ),
        ],
      );

  testWidgets('shows the editor chrome (app bar + shell) for an asset', (
    tester,
  ) async {
    final container = containerWith(images: {'a': _png});
    addTearDown(container.dispose);

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

    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Export'), findsOneWidget);
    expect(find.byTooltip('Undo'), findsOneWidget);
    expect(find.byTooltip('Redo'), findsOneWidget);
    expect(find.byType(AppShell), findsOneWidget);
  });

  testWidgets('shows a recoverable error when the image cannot be read', (
    tester,
  ) async {
    final container = containerWith(); // empty bytes for every asset
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: EditorScreen(asset: GalleryAsset(id: 'missing', width: 1, height: 1)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not open this photo'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('restores a saved recipe and saves edits back', (tester) async {
    final container = containerWith(images: {'a': _png});
    addTearDown(container.dispose);
    container
        .read(recipeStoreProvider.notifier)
        .put('a', EditRecipe.neutral.copyWith(exposure: 1.2));

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

    // The saved recipe was loaded into the session.
    expect(container.read(recipeControllerProvider).recipe.exposure, 1.2);

    // A new edit is persisted back to the same asset.
    container
        .read(recipeControllerProvider.notifier)
        .update(Parameter.contrast, 0.5);
    await tester.pump();

    expect(container.read(recipeStoreProvider)['a']!.contrast, 0.5);
    expect(container.read(recipeStoreProvider)['a']!.exposure, 1.2);
  });

  group('Active Mode (issue #26)', () {
    double appBarOpacity(WidgetTester tester) =>
        tester
            .widget<AnimatedOpacity>(
              find
                  .ancestor(
                    of: find.byType(AppBar),
                    matching: find.byType(AnimatedOpacity),
                  )
                  .first,
            )
            .opacity;

    Future<List<MethodCall>> pumpEditor(WidgetTester tester) async {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );

      final container = containerWith(images: {'a': _png});
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: EditorScreen(
              asset: GalleryAsset(id: 'a', width: 1, height: 1),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      return calls;
    }

    testWidgets('hiding the app bar and system bars while touching the photo', (
      tester,
    ) async {
      final calls = await pumpEditor(tester);
      expect(appBarOpacity(tester), 1);

      final center = tester.getRect(find.byType(ImageCanvas)).center;
      final gesture = await tester.startGesture(center);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(appBarOpacity(tester), 0);

      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 400));

      expect(appBarOpacity(tester), 1);

      final modeCalls = calls
          .where((c) => c.method == 'SystemChrome.setEnabledSystemUIMode')
          .toList();
      expect(modeCalls, hasLength(2));
      expect(modeCalls.first.arguments.toString(), contains('immersiveSticky'));
      expect(modeCalls.last.arguments.toString(), contains('edgeToEdge'));
    });

    testWidgets('the gesture shell moves the actions onto a floating HUD', (
      tester,
    ) async {
      final container = containerWith(images: {'a': _png});
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: EditorScreen(
              asset: GalleryAsset(id: 'a', width: 1, height: 1),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      container
          .read(shellPreferenceProvider.notifier)
          .select(AppShellKind.snapseed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      // AppBar is bare (back + title only) ...
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byTooltip('Undo'),
        ),
        findsNothing,
      );
      // ... the actions float over the photo instead.
      expect(find.byTooltip('Undo'), findsOneWidget);
      expect(find.byTooltip('Redo'), findsOneWidget);
      expect(find.text('Export'), findsOneWidget);
    });
  });

  group('bottom-heavy ergonomics (issue #28)', () {
    testWidgets('undo/redo live with the Lightroom tabs, not the app bar', (
      tester,
    ) async {
      final container = containerWith(images: {'a': _png});
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: EditorScreen(
              asset: GalleryAsset(id: 'a', width: 1, height: 1),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // The app bar keeps only crop / more / export.
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byTooltip('Undo'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byTooltip('Redo'),
        ),
        findsNothing,
      );

      // History + compare sit with the tabs at the bottom.
      final shell = find.byType(LightroomShell);
      expect(
        find.descendant(of: shell, matching: find.byTooltip('Undo')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: shell, matching: find.byTooltip('Redo')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: shell, matching: find.byTooltip('Hold to compare')),
        findsOneWidget,
      );

      // And undo works from there.
      final controller = container.read(recipeControllerProvider.notifier);
      controller
        ..update(Parameter.exposure, 1.5)
        ..commit(label: 'Exposure');
      await tester.pump();
      expect(container.read(recipeControllerProvider).recipe.exposure, 1.5);

      await tester.tap(
        find.descendant(of: shell, matching: find.byTooltip('Undo')),
      );
      await tester.pump();
      expect(container.read(recipeControllerProvider).recipe.exposure, 0);
    });
  });
}
