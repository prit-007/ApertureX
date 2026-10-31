import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aperturex/features/ai_plugins/ai_plugin_model.dart';
import 'package:aperturex/features/ai_plugins/ai_plugin_store.dart';
import 'package:aperturex/src/rust/frb_generated.dart';

/// Mocks the blur API so [AiPluginNotifier] can sync plugins to the engine
/// without a native Rust library in unit tests.
class _AiPluginBlurApi extends Fake implements RustLibApi {
  @override
  Future<bool> crateApiBlurSetActiveMlModel({
    required String task,
    required String path,
  }) async =>
      true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    RustLib.initMock(api: _AiPluginBlurApi());
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AiPluginStore', () {
    test('initializes with default built-in saliency model and community presets', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final state = container.read(aiPluginProvider);

      expect(state.installedPlugins, isNotEmpty);
      expect(state.installedPlugins.first.id, 'builtin-saliency');
      expect(state.installedPlugins.first.isBuiltIn, isTrue);

      expect(state.communityPlugins, isNotEmpty);
      expect(state.communityPlugins.any((p) => p.id == 'depth-anything-v2-small'), isTrue);
      expect(state.communityPlugins.any((p) => p.id == 'rmbg-1.4'), isTrue);
    });

    test('adds custom AI plugin via URL and task', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(aiPluginProvider.notifier);

      await notifier.addCustomPlugin(
        name: 'My Custom Hair Matting',
        url: 'https://github.com/custom/model.onnx',
        task: AiTask.portraitHair,
        width: 1024,
        height: 1024,
      );

      final state = container.read(aiPluginProvider);
      expect(state.installedPlugins.length, 2);
      final added = state.installedPlugins.last;
      expect(added.name, 'My Custom Hair Matting');
      expect(added.task, AiTask.portraitHair);
      expect(added.sourceUrl, 'https://github.com/custom/model.onnx');
      expect(added.inputWidth, 1024);
      expect(added.inputHeight, 1024);
      expect(added.isEnabled, isTrue);
    });

    test('toggles and deletes installed custom plugins, protecting built-in', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(aiPluginProvider.notifier);

      await notifier.addCustomPlugin(
        name: 'Delete Me',
        url: 'https://github.com/test/delete.tflite',
        task: AiTask.skySegmentation,
      );

      var state = container.read(aiPluginProvider);
      final addedId = state.installedPlugins.last.id;
      await notifier.togglePlugin(addedId, false);
      state = container.read(aiPluginProvider);
      expect(state.installedPlugins.last.isEnabled, isFalse);

      await notifier.deletePlugin(addedId);
      state = container.read(aiPluginProvider);
      expect(state.installedPlugins.any((p) => p.id == addedId), isFalse);

      // Deleting built-in should be prevented
      await notifier.deletePlugin('builtin-saliency');
      state = container.read(aiPluginProvider);
      expect(state.installedPlugins.any((p) => p.id == 'builtin-saliency'), isTrue);
    });

    test('getActivePluginForTask returns active enabled model', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(aiPluginProvider.notifier);

      final activeSubject = notifier.getActivePluginForTask(AiTask.subjectSegmentation);
      expect(activeSubject, isNotNull);
      expect(activeSubject!.id, 'builtin-saliency');

      final activeDepth = notifier.getActivePluginForTask(AiTask.depthEstimation);
      expect(activeDepth, isNull);
    });

    test('installCommunityPlugin installs, writes local file, and activates for task', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(aiPluginProvider.notifier);

      final depthPlugin = kCommunityAiPlugins.firstWhere((p) => p.id == 'depth-anything-v2-small');
      await notifier.installCommunityPlugin(depthPlugin);

      final state = container.read(aiPluginProvider);
      final installedDepth = state.installedPlugins.firstWhere((p) => p.id == 'depth-anything-v2-small');
      expect(installedDepth.isInstalled, isTrue);
      expect(installedDepth.isEnabled, isTrue);
      expect(installedDepth.localPath, isNotNull);
      expect(state.activePluginPerTask[AiTask.depthEstimation], 'depth-anything-v2-small');

      final active = notifier.getActivePluginForTask(AiTask.depthEstimation);
      expect(active, isNotNull);
      expect(active!.id, 'depth-anything-v2-small');
      expect(active.task, AiTask.depthEstimation);
    });

    test('setActivePluginForTask switches handler and synchronizes active plugin', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(aiPluginProvider.notifier);

      await notifier.addCustomPlugin(
        name: 'Custom Segmenter',
        url: 'https://github.com/custom/seg.onnx',
        task: AiTask.subjectSegmentation,
      );

      final state = container.read(aiPluginProvider);
      final customPlugin = state.installedPlugins.last;
      expect(state.activePluginPerTask[AiTask.subjectSegmentation], customPlugin.id);

      // Switch back to built-in
      final switched = await notifier.setActivePluginForTask(AiTask.subjectSegmentation, 'builtin-saliency');
      expect(switched, isTrue);
      expect(notifier.getActivePluginForTask(AiTask.subjectSegmentation)!.id, 'builtin-saliency');
    });
  });
}
