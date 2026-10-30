import 'package:aperturex/ui/desktop/desktop_menu_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('DesktopMenuBar renders child widget cleanly', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: DesktopMenuBar(
            child: Scaffold(
              body: Text('Gallery Content'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Gallery Content'), findsOneWidget);
  });
}
