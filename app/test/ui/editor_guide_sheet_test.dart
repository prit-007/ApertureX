import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:aperturex/ui/common/editor_guide_sheet.dart';

void main() {
  testWidgets('EditorGuideSheet renders title, tabs, and gesture instructions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: EditorGuideSheet(),
          ),
        ),
      ),
    );

    // Verify title and header
    expect(find.text('ApertureX Pro Guide'), findsOneWidget);
    expect(
      find.text('Master gestures, non-destructive editing & pro tools'),
      findsOneWidget,
    );

    // Verify tabs are available
    expect(find.text('Gestures'), findsOneWidget);
    expect(find.text('Pro Tools'), findsOneWidget);
    expect(find.text('Masking & Pen'), findsOneWidget);
    expect(find.text('Panels & Keys'), findsOneWidget);

    // Gestures tab should show core gestures by default
    expect(find.text('Vertical Drag'), findsOneWidget);
    expect(find.text('Horizontal Scrub'), findsOneWidget);
    expect(find.text('2D Invisible Trackball'), findsOneWidget);
    expect(find.text('Two-Finger Precision Gear'), findsOneWidget);
    expect(find.text('Ansel Adams Zone Masking'), findsOneWidget);
    expect(find.text('3-Finger Speed Editor Macros'), findsOneWidget);
    expect(find.text('Hold to Compare'), findsOneWidget);

    // Switch to Pro Tools tab
    await tester.tap(find.text('Pro Tools'));
    await tester.pumpAndSettle();

    expect(find.text('Targeted Adjustment (TAT)'), findsOneWidget);
    expect(find.text('Selective Control Points'), findsOneWidget);
    expect(find.text('Tone & RGB Curves'), findsOneWidget);
    expect(find.text('Zen Top Bar & History Tree'), findsOneWidget);
    expect(find.text('Rotary Jog Dial'), findsOneWidget);
    expect(find.text('Cine Peaking & Zebras'), findsOneWidget);
    expect(find.text('False Color Heatmap'), findsOneWidget);
    expect(find.text('Precision Straighten & Rotate'), findsOneWidget);

    // Switch to Masking & Pen tab
    await tester.tap(find.text('Masking & Pen'));
    await tester.pumpAndSettle();

    expect(find.text('Pressure-Sensitive Stylus'), findsOneWidget);
    expect(find.text('Inverted Stylus Eraser'), findsOneWidget);
    expect(find.text('Mask Peek & Invert'), findsOneWidget);

    // Switch to Panels & Keys tab
    await tester.tap(find.text('Panels & Keys'));
    await tester.pumpAndSettle();

    expect(find.text('6 Master Tabs Architecture'), findsOneWidget);
    expect(find.text('Dual-Shell Architecture'), findsOneWidget);
    expect(find.text('Keyboard Shortcuts'), findsOneWidget);
  });

  testWidgets('EditorGuideSheet close button dismisses sheet when opened as modal', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => EditorGuideSheet.show(context),
                child: const Text('Open Guide'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Guide'));
    await tester.pumpAndSettle();

    expect(find.text('ApertureX Pro Guide'), findsOneWidget);

    // Tap close button
    await tester.tap(find.byKey(const Key('editor-guide-close')));
    await tester.pumpAndSettle();

    expect(find.text('ApertureX Pro Guide'), findsNothing);
  });
}
