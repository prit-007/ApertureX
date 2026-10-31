import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/features/guide/gesture_animation_player.dart';

void main() {
  group('GestureAnimationPlayer', () {
    testWidgets('renders verticalDrag demo without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GestureAnimationPlayer(type: GestureDemoType.verticalDrag),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GestureAnimationPlayer), findsOneWidget);
    });

    testWidgets('renders horizontalScrub demo without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GestureAnimationPlayer(type: GestureDemoType.horizontalScrub),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GestureAnimationPlayer), findsOneWidget);
    });

    testWidgets('renders twoFingerPrecisionGear demo without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GestureAnimationPlayer(type: GestureDemoType.twoFingerPrecisionGear),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GestureAnimationPlayer), findsOneWidget);
    });

    testWidgets('renders splitWiper demo without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GestureAnimationPlayer(type: GestureDemoType.splitWiper),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GestureAnimationPlayer), findsOneWidget);
    });

    testWidgets('isAnimating true overrides test environment and animates', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GestureAnimationPlayer(
              type: GestureDemoType.verticalDrag,
              isAnimating: true,
            ),
          ),
        ),
      );
      // Looping animation never settles; just pump a frame to verify it renders.
      await tester.pump();
      expect(find.byType(GestureAnimationPlayer), findsOneWidget);
    });

    testWidgets('isAnimating false disables animation', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GestureAnimationPlayer(
              type: GestureDemoType.horizontalScrub,
              isAnimating: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GestureAnimationPlayer), findsOneWidget);
    });

    testWidgets('renders with custom height', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GestureAnimationPlayer(
              type: GestureDemoType.splitWiper,
              height: 200,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GestureAnimationPlayer), findsOneWidget);
    });
  });
}
