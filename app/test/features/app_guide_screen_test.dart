import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/features/guide/app_guide_screen.dart';

void main() {
  testWidgets('AppGuideScreen renders search bar, category chips, and guide items', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: AppGuideScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ApertureX Academy'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget); // Search bar
    expect(find.widgetWithText(FilterChip, 'All'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Light'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Color'), findsOneWidget);

    // Initial list displays guides
    expect(find.text('Exposure & Dynamic Range'), findsOneWidget);

    // Filter by searching 'bokeh'
    await tester.enterText(find.byType(TextField), 'bokeh');
    await tester.pumpAndSettle();

    expect(find.text('Exposure & Dynamic Range'), findsNothing);
    expect(find.text('Depth Bokeh & Lens Blur'), findsOneWidget);

    // Tap to expand guide card
    await tester.tap(find.text('Depth Bokeh & Lens Blur'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Pro Tips:'), findsOneWidget);
  });

  testWidgets('AppGuideScreen.showModal opens as a bottom sheet', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => AppGuideScreen.showModal(context, initialToolId: 'exposure'),
              child: const Text('Open Guide'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Guide'));
    await tester.pumpAndSettle();

    expect(find.text('ApertureX Academy'), findsOneWidget);
    expect(find.text('Exposure & Dynamic Range'), findsOneWidget);
    // Since initialToolId was 'exposure', it should already be expanded
    expect(find.textContaining('Pro Tips:'), findsOneWidget);
  });
}
