import 'package:aperturex/viewport/preview_surface.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Spike B (issue #54): the preview must actually mount the platform `Texture`
/// Rust writes into — before this landed, the canvas bound a texture and baked
/// frames into it but never displayed it, so the viewport sat on the loading
/// placeholder forever. These tests pin the delivery decision:
///
///  * bound texture  -> zero-copy `Texture`
///  * no texture     -> the spike-A shader/atlas fallback
///  * gesture fades  -> shader path (`lut.frag` owns blend/maskBlend)
void main() {
  const WidgetBuilder fallback = _fallbackBuilder;

  testWidgets('mounts the platform Texture when a texture id is bound', (
    tester,
  ) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: PreviewSurface(textureId: 7, fallback: fallback),
      ),
    );

    expect(find.byType(Texture), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) => w is Texture && w.textureId == 7),
      findsOneWidget,
    );
    expect(find.byKey(const Key('shader-fallback')), findsNothing);
  });

  testWidgets('falls back to the shader child when no texture is bound', (
    tester,
  ) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: PreviewSurface(textureId: null, fallback: fallback),
      ),
    );

    expect(find.byType(Texture), findsNothing);
    expect(find.byKey(const Key('shader-fallback')), findsOneWidget);
  });

  group('previewNeedsPlaceholder', () {
    test('is true while the shader path is missing its baked LUT', () {
      expect(
        previewNeedsPlaceholder(
          failed: false,
          hasProgram: true,
          hasShader: true,
          hasSource: true,
          hasLut: false,
          useTexture: false,
        ),
        isTrue,
      );
    });

    test('is false in texture mode even with no baked LUT (#54)', () {
      // The zero-copy path never builds the LUT/base images — requiring them
      // is exactly what pinned the viewport to the placeholder.
      expect(
        previewNeedsPlaceholder(
          failed: false,
          hasProgram: true,
          hasShader: true,
          hasSource: true,
          hasLut: false,
          useTexture: true,
        ),
        isFalse,
      );
    });

    test('is true when the load failed, regardless of delivery', () {
      expect(
        previewNeedsPlaceholder(
          failed: true,
          hasProgram: true,
          hasShader: true,
          hasSource: true,
          hasLut: true,
          useTexture: true,
        ),
        isTrue,
      );
    });

    test('is true while the source image is still missing', () {
      expect(
        previewNeedsPlaceholder(
          failed: false,
          hasProgram: true,
          hasShader: true,
          hasSource: false,
          hasLut: true,
          useTexture: false,
        ),
        isTrue,
      );
    });
  });

  group('useTextureDelivery', () {
    test('requires a bound texture', () {
      expect(
        useTextureDelivery(
          textureId: null,
          hasImportedLut: false,
          gestureActive: false,
          roiActive: false,
        ),
        isFalse,
      );
    });

    test('yields to the shader path while an imported LUT is active', () {
      expect(
        useTextureDelivery(
          textureId: 3,
          hasImportedLut: true,
          gestureActive: false,
          roiActive: false,
        ),
        isFalse,
      );
    });

    test('yields to the shader path during compare/peek crossfades', () {
      expect(
        useTextureDelivery(
          textureId: 3,
          hasImportedLut: false,
          gestureActive: true,
          roiActive: false,
        ),
        isFalse,
      );
    });

    test('yields to the shader path while the ROI tiles are active', () {
      // The overlay is drawn through the grading shader (lut.frag), which
      // needs the baked LUT atlas — texture mode has none (#55/#16).
      expect(
        useTextureDelivery(
          textureId: 3,
          hasImportedLut: false,
          gestureActive: false,
          roiActive: true,
        ),
        isFalse,
      );
    });

    test('yields to the shader path while geometry edits are non-identity', () {
      // Correctness gate: a HardwareBuffer-backed SurfaceProducer ignores
      // setBuffersGeometry, so a cropped/rotated frame written into the
      // proxy buffer would be stretched to the wrong aspect. The shader path
      // bakes geometry into the base image and draws it correctly.
      expect(
        useTextureDelivery(
          textureId: 3,
          hasImportedLut: false,
          gestureActive: false,
          roiActive: false,
          geometryActive: true,
        ),
        isFalse,
      );
    });

    test('geometryActive defaults to false (identity geometry)', () {
      expect(
        useTextureDelivery(
          textureId: 3,
          hasImportedLut: false,
          gestureActive: false,
          roiActive: false,
        ),
        isTrue,
      );
    });

    test('is the zero-copy path when bound and idle with identity geometry', () {
      expect(
        useTextureDelivery(
          textureId: 3,
          hasImportedLut: false,
          gestureActive: false,
          roiActive: false,
          geometryActive: false,
        ),
        isTrue,
      );
    });
  });
}

const WidgetBuilder _fallbackBuilder = _fallbackCanvas;

Widget _fallbackCanvas(BuildContext context) =>
    const SizedBox(key: Key('shader-fallback'));
