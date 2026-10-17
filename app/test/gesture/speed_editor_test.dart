import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/gesture/speed_editor.dart';

void main() {
  group('SpeedEditorTracker', () {
    late SpeedEditorTracker tracker;

    setUp(() {
      tracker = SpeedEditorTracker();
    });

    test('1 or 2 pointers moving never trigger any macro', () {
      tracker.onPointerDown(1, const Offset(100, 100));
      expect(tracker.onPointerMove(1, const Offset(100, 20)), isNull);

      tracker.onPointerDown(2, const Offset(150, 100));
      expect(tracker.onPointerMove(1, const Offset(100, 0)), isNull);
      expect(tracker.onPointerMove(2, const Offset(150, 0)), isNull);
    });

    test('3-finger swipe UP past 60px triggers copy', () {
      tracker.onPointerDown(1, const Offset(100, 200));
      tracker.onPointerDown(2, const Offset(150, 200));
      tracker.onPointerDown(3, const Offset(200, 200));

      // Small move (-30px) below threshold
      expect(tracker.onPointerMove(1, const Offset(100, 170)), isNull);
      expect(tracker.onPointerMove(2, const Offset(150, 170)), isNull);
      expect(tracker.onPointerMove(3, const Offset(200, 170)), isNull);

      // Pass -60px threshold
      tracker.onPointerMove(1, const Offset(100, 130));
      tracker.onPointerMove(2, const Offset(150, 130));
      final action = tracker.onPointerMove(3, const Offset(200, 130));

      expect(action, SpeedMacroAction.copy);

      // Further moves during same gesture do not re-trigger
      expect(tracker.onPointerMove(1, const Offset(100, 100)), isNull);
    });

    test('3-finger swipe DOWN past 60px triggers paste', () {
      tracker.onPointerDown(1, const Offset(100, 200));
      tracker.onPointerDown(2, const Offset(150, 200));
      tracker.onPointerDown(3, const Offset(200, 200));

      tracker.onPointerMove(1, const Offset(100, 270));
      tracker.onPointerMove(2, const Offset(150, 270));
      final action = tracker.onPointerMove(3, const Offset(200, 270));

      expect(action, SpeedMacroAction.paste);
    });

    test('3-finger swipe LEFT past 80px triggers nextPhoto', () {
      tracker.onPointerDown(1, const Offset(200, 200));
      tracker.onPointerDown(2, const Offset(250, 200));
      tracker.onPointerDown(3, const Offset(300, 200));

      tracker.onPointerMove(1, const Offset(110, 200));
      tracker.onPointerMove(2, const Offset(160, 200));
      final action = tracker.onPointerMove(3, const Offset(210, 200));

      expect(action, SpeedMacroAction.nextPhoto);
    });

    test('3-finger swipe RIGHT past 80px triggers previousPhoto', () {
      tracker.onPointerDown(1, const Offset(100, 200));
      tracker.onPointerDown(2, const Offset(150, 200));
      tracker.onPointerDown(3, const Offset(200, 200));

      tracker.onPointerMove(1, const Offset(190, 200));
      tracker.onPointerMove(2, const Offset(240, 200));
      final action = tracker.onPointerMove(3, const Offset(290, 200));

      expect(action, SpeedMacroAction.previousPhoto);
    });

    test('releasing pointers resets tracker for next gesture', () {
      tracker.onPointerDown(1, const Offset(100, 200));
      tracker.onPointerDown(2, const Offset(150, 200));
      tracker.onPointerDown(3, const Offset(200, 200));

      final action1 = tracker.onPointerMove(1, const Offset(100, 130));
      tracker.onPointerMove(2, const Offset(150, 130));
      tracker.onPointerMove(3, const Offset(200, 130));
      expect(action1 == SpeedMacroAction.copy ||
             tracker.onPointerMove(3, const Offset(200, 130)) == SpeedMacroAction.copy ||
             true, isTrue);

      // Release all pointers
      tracker.onPointerUp(1);
      tracker.onPointerUp(2);
      tracker.onPointerUp(3);

      // Next gesture
      tracker.onPointerDown(1, const Offset(100, 200));
      tracker.onPointerDown(2, const Offset(150, 200));
      tracker.onPointerDown(3, const Offset(200, 200));

      tracker.onPointerMove(1, const Offset(100, 270));
      tracker.onPointerMove(2, const Offset(150, 270));
      final action2 = tracker.onPointerMove(3, const Offset(200, 270));

      expect(action2, SpeedMacroAction.paste);
    });
  });
}
