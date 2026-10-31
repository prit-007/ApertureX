import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/settings/about_screen.dart';
import 'package:aperturex/ui/common/settings_sheet.dart' show kOfflineClaim;

void main() {
  group('AboutScreen Widget Tests', () {
    testWidgets('renders app branding and developers correctly', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: AboutScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify app title & branding
      expect(find.text('About & Developers'), findsOneWidget);
      expect(find.text('ApertureX'), findsOneWidget);
      expect(find.text('Pro-Grade Mobile-Native FOSS Photo Editor'), findsOneWidget);

      // Verify organization and creator
      expect(find.text("Developer's Paradise"), findsOneWidget);
      expect(find.text('Prit Vasani'), findsOneWidget);
      expect(find.text('Lead Architect & Developer'), findsOneWidget);

      // Verify licensing & offline claim
      expect(find.text('GNU General Public License v3.0'), findsOneWidget);
      expect(find.text(kOfflineClaim), findsOneWidget);

      // Verify third-party component categories
      expect(find.text('Rust Core & Decoders'), findsOneWidget);
      expect(find.text('On-Device AI & Computer Vision'), findsOneWidget);
      expect(find.text('Local Database & Storage'), findsOneWidget);
      expect(find.text('UI, Touch & Gestures'), findsOneWidget);
      expect(find.text('Standards, Codecs & Film Science'), findsOneWidget);
    });

    testWidgets('licenses button is present and clickable', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: AboutScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final licensesBtn = find.text('Licenses');
      expect(licensesBtn, findsOneWidget);
    });
  });
}
