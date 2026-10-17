import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aperturex/core/updater/app_update_model.dart';
import 'package:aperturex/core/updater/update_dialog.dart';

void main() {
  testWidgets('UpdateDialog displays release version, notes, and actions', (tester) async {
    final release = AppReleaseInfo(
      tagName: 'v0.2.0',
      version: '0.2.0',
      releaseName: 'ApertureX v0.2.0',
      changelog: '- Added Declarative ONNX AI Plugins\n- Added Lossless DNG CFA Export',
      htmlUrl: 'https://github.com/prit-007/ApertureX/releases/tag/v0.2.0',
      apkDownloadUrl: 'https://github.com/prit-007/ApertureX/releases/download/v0.2.0/aperturex.apk',
      apkSizeBytes: 41943040, // 40 MB
      publishedAt: DateTime.now(),
      isPrerelease: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => UpdateDialog.show(context, release),
              child: const Text('Show Dialog'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Update Available'), findsOneWidget);
    expect(find.text('v0.2.0'), findsOneWidget);
    expect(find.textContaining('Declarative ONNX AI Plugins'), findsOneWidget);
    expect(find.text('40.0 MB'), findsOneWidget);
    expect(find.text('Update Now'), findsOneWidget);
    expect(find.text('Later'), findsOneWidget);
  });
}
