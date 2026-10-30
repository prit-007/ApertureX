import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aperturex/features/tether/tether_hud.dart';
import 'package:aperturex/features/tether/tether_screen.dart';

void main() {
  Widget buildSubject() {
    return const ProviderScope(
      child: MaterialApp(
        home: TetherScreen(),
      ),
    );
  }

  testWidgets('renders Studio Tethered Capture screen and telemetry HUD', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Studio Tethered Capture'), findsOneWidget);
    expect(find.text('Sony α7R V'), findsOneWidget);
    expect(find.byType(TetherHud), findsOneWidget);
    expect(find.byKey(const Key('telemetry-shutter-text')), findsOneWidget);
    expect(find.byKey(const Key('telemetry-aperture-text')), findsOneWidget);
    expect(find.byKey(const Key('telemetry-iso-text')), findsOneWidget);
    expect(find.byKey(const Key('remote-shutter-btn')), findsOneWidget);
  });

  testWidgets('triggers shutter release and adds capture to filmstrip', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('No captures yet in this session'), findsOneWidget);

    final captureBtn = find.byKey(const Key('remote-shutter-btn'));
    await tester.tap(captureBtn);

    // Pump past the simulated exposure delay
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(find.textContaining('Studio_Shoot_0001.ARW'), findsWidgets);
    expect(find.text('#1'), findsOneWidget);
  });

  testWidgets('toggles camera connection status', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    final toggleBtn = find.byKey(const Key('tether-connection-toggle-btn'));

    // Disconnect
    await tester.tap(toggleBtn);
    await tester.pumpAndSettle();

    expect(find.text('Camera Disconnected'), findsOneWidget);

    // Reconnect
    await tester.tap(toggleBtn);
    await tester.pumpAndSettle();

    expect(find.text('Ready for Shutter Release'), findsOneWidget);
  });
}
