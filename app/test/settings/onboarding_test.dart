import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aperturex/settings/onboarding.dart';

void main() {
  test('markGestureHintSeen persists and restores', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(gestureHintSeenProvider), isFalse);
    container.read(gestureHintSeenProvider.notifier).markGestureHintSeen();
    expect(container.read(gestureHintSeenProvider), isTrue);

    await Future<void>.delayed(const Duration(milliseconds: 20));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('gesture_hint_seen'), isTrue);

    final restored = ProviderContainer();
    addTearDown(restored.dispose);
    restored.read(gestureHintSeenProvider);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(restored.read(gestureHintSeenProvider), isTrue);
  });
}
