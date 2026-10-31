import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aperturex/features/video/video_editor_screen.dart';
import 'package:aperturex/features/video/video_model.dart';

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (methodCall) async {
      if (methodCall.method == 'Clipboard.setData') {
        return null;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  const testClip = VideoClip(
    id: 'test_reel',
    path: '/storage/test_reel.mp4',
    title: 'Test Reel 4K',
    durationMs: 10000,
    fps: 30.0,
    width: 3840,
    height: 2160,
  );

  Widget buildSubject({VideoClip? clip}) {
    return ProviderScope(
      child: MaterialApp(
        home: VideoEditorScreen(
          initialClip: clip ?? testClip,
        ),
      ),
    );
  }

  testWidgets('renders Video Color Studio title and transport controls', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Test Reel 4K'), findsOneWidget);
    expect(find.byKey(const Key('play-pause-btn')), findsOneWidget);
    expect(find.byKey(const Key('step-back-btn')), findsOneWidget);
    expect(find.byKey(const Key('step-fwd-btn')), findsOneWidget);
    expect(find.byKey(const Key('mark-in-btn')), findsOneWidget);
    expect(find.byKey(const Key('mark-out-btn')), findsOneWidget);
    expect(find.text('Grading'), findsOneWidget);
    expect(find.text('Wheels'), findsOneWidget);
    expect(find.text('Export / Info'), findsOneWidget);
  });

  testWidgets('toggles playback with play/pause button', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    final playBtn = find.byKey(const Key('play-pause-btn'));
    expect(find.text('Play'), findsOneWidget);

    await tester.tap(playBtn);
    await tester.pump();

    expect(find.text('Pause'), findsOneWidget);

    await tester.tap(playBtn);
    await tester.pump();

    expect(find.text('Play'), findsOneWidget);
  });

  testWidgets('adjusts exposure slider and shows 3D LUT APPLIED badge', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('3D LUT APPLIED'), findsNothing);

    final exposureSlider = find.byType(Slider).first;
    await tester.drag(exposureSlider, const Offset(60, 0));
    await tester.pumpAndSettle();

    expect(find.text('3D LUT APPLIED'), findsOneWidget);

    // Reset grade button restores neutral
    await tester.tap(find.byKey(const Key('reset-grade-btn')));
    await tester.pumpAndSettle();

    expect(find.text('3D LUT APPLIED'), findsNothing);
  });

  testWidgets('exports 3D .CUBE LUT and triggers success notification', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    final exportCubeBtn = find.byKey(const Key('export-cube-btn'));
    expect(exportCubeBtn, findsOneWidget);

    await tester.tap(exportCubeBtn);
    await tester.pumpAndSettle();

    expect(find.textContaining('Exported 33³ .CUBE LUT to clipboard'), findsOneWidget);
  });
}
