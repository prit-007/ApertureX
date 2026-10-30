import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:aperturex/gallery/gallery_asset.dart';
import 'package:aperturex/gallery/gallery_controller.dart';
import 'package:aperturex/gallery/gallery_screen.dart';
import 'package:aperturex/gallery/gallery_source.dart';
import 'package:aperturex/settings/onboarding.dart';

final Uint8List _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

void main() {
  testWidgets('Gallery shows onboarding welcome banner and dismisses it',
      (tester) async {
    final container = ProviderContainer(
      overrides: [
        gallerySourceProvider.overrideWithValue(
          FakeGallerySource(
            assets: const [
              GalleryAsset(id: 'a', width: 1, height: 1),
            ],
            thumbnails: {'a': _png},
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: GalleryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome to ApertureX'), findsOneWidget);
    expect(find.text('Tour'), findsOneWidget);

    // Tap dismiss icon
    final dismissBtn = find.byTooltip('Dismiss');
    expect(dismissBtn, findsOneWidget);
    await tester.tap(dismissBtn);
    await tester.pumpAndSettle();

    expect(container.read(hasCompletedOnboardingProvider), isTrue);
    expect(find.text('Welcome to ApertureX'), findsNothing);
  });
}
