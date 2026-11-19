import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aperturex/features/panorama/panorama_merge_sheet.dart';
import 'package:aperturex/features/head_pose/head_pose_sheet.dart';
import 'package:aperturex/ui/common/expand_canvas_sheet.dart';
import 'package:aperturex/src/rust/api/panorama.dart' as rust_panorama;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Panorama, Head Pose, and Expand Sheets UI Tests', () {
    testWidgets('PanoramaMergeSheet renders projection selector and merge button', (tester) async {
      final img1 = rust_panorama.ApiPanoramaInput(
        rgba: Uint8List(32 * 32 * 4),
        width: 32,
        height: 32,
      );
      final img2 = rust_panorama.ApiPanoramaInput(
        rgba: Uint8List(32 * 32 * 4),
        width: 32,
        height: 32,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PanoramaMergeSheet(inputImages: [img1, img2]),
            ),
          ),
        ),
      );

      expect(find.text('Panorama Merge'), findsOneWidget);
      expect(find.text('2 Photos'), findsOneWidget);
      expect(find.text('Cylindrical'), findsOneWidget);
      expect(find.text('Merge Panorama'), findsOneWidget);

      await tester.tap(find.text('Spherical'));
      await tester.pumpAndSettle();
    });

    testWidgets('HeadPoseSheet renders face sliders and reset action', (tester) async {
      final dummyRgba = Uint8List(32 * 32 * 4);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: HeadPoseSheet(
                rgba: dummyRgba,
                width: 32,
                height: 32,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Head Pose & Face'), findsOneWidget);
      expect(find.text('Yaw (Turn)'), findsOneWidget);
      expect(find.text('Smile'), findsOneWidget);
      expect(find.text('Reset'), findsOneWidget);
      expect(find.text('Apply Pose'), findsOneWidget);

      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
    });

    testWidgets('ExpandCanvasSheet renders mode options and slider', (tester) async {
      final dummyRgba = Uint8List(32 * 32 * 4);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ExpandCanvasSheet(
                rgba: dummyRgba,
                width: 32,
                height: 32,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Smart'), findsOneWidget);
      expect(find.text('White'), findsOneWidget);
      expect(find.text('Black'), findsOneWidget);
      expect(find.text('Reflect'), findsOneWidget);
      expect(find.text('Expand Canvas'), findsNWidgets(2)); // Title and Button

      await tester.tap(find.text('White'));
      await tester.pumpAndSettle();
    });
  });
}
