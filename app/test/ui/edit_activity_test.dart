import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:aperturex/ui/app_shell.dart';
import 'package:aperturex/ui/edit_activity.dart';
import 'package:aperturex/viewport/image_canvas.dart';

void main() {
  test('the activity flag tracks a pointer count, not a flag', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(editActivityProvider), isFalse);
    container.read(editActivityProvider.notifier).begin();
    expect(container.read(editActivityProvider), isTrue);
    // Second finger down — still active.
    container.read(editActivityProvider.notifier).begin();
    expect(container.read(editActivityProvider), isTrue);
    // First finger lifts, second still down — stays active (issue #43).
    container.read(editActivityProvider.notifier).end();
    expect(container.read(editActivityProvider), isTrue);
    // Second finger lifts — now inactive.
    container.read(editActivityProvider.notifier).end();
    expect(container.read(editActivityProvider), isFalse);
    // Extra end (missed down) never goes negative.
    container.read(editActivityProvider.notifier).end();
    expect(container.read(editActivityProvider), isFalse);
  });

  testWidgets('touching the photo starts Active Mode, lifting ends it', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: AppShell())),
      ),
    );
    await tester.pump();

    final center = tester.getRect(find.byType(ImageCanvas)).center;
    final gesture = await tester.startGesture(center);
    await tester.pump();
    expect(container.read(editActivityProvider), isTrue);

    await gesture.up();
    await tester.pump();
    expect(container.read(editActivityProvider), isFalse);
    // Let any gesture-detector timeout fire.
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('lifting one of two fingers keeps Active Mode (issue #43)', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: AppShell())),
      ),
    );
    await tester.pump();

    final center = tester.getRect(find.byType(ImageCanvas)).center;
    final first = await tester.createGesture();
    final second = await tester.createGesture();
    await first.down(center);
    await second.down(center + const Offset(20, 0));
    await tester.pump();
    expect(container.read(editActivityProvider), isTrue);

    // First finger lifts — chrome must stay hidden while the second is down.
    await first.up();
    await tester.pump();
    expect(container.read(editActivityProvider), isTrue);

    await second.up();
    await tester.pump();
    expect(container.read(editActivityProvider), isFalse);
    // Let any gesture-detector timeout fire.
    await tester.pump(const Duration(milliseconds: 400));
  });
}
