import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tessera/gallery/gallery_screen.dart';
import 'package:tessera/gallery/gallery_source.dart';

final Uint8List _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

class _CountingSource extends FakeGallerySource {
  _CountingSource() : super(thumbnails: {'a': _png});

  int calls = 0;

  @override
  Future<Uint8List> loadThumbnail(String id, {int size = 256}) {
    calls++;
    return super.loadThumbnail(id, size: size);
  }
}

void main() {
  testWidgets('a thumbnail is resolved once, not on every rebuild', (
    tester,
  ) async {
    final source = _CountingSource();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GalleryThumbnail(source: source, assetId: 'a'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(source.calls, 1);

    // Force a few rebuilds; the future must be reused (not re-decoded).
    await tester.pump();
    await tester.pump();
    expect(source.calls, 1);
  });
}
