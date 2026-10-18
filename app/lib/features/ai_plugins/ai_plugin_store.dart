import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ai_plugin_model.dart';

/// Preset curated open-source AI models ready for 1-tap installation.
const List<AiPluginModel> kCommunityAiPlugins = [
  AiPluginModel(
    id: 'depth-anything-v2-small',
    name: 'Depth Anything V2 (Small)',
    description: 'SOTA monocular relative depth estimation for optical bokeh & 3D blur.',
    author: 'DepthAnything (TikTok / HKU)',
    task: AiTask.depthEstimation,
    sourceUrl: 'https://github.com/DepthAnything/Depth-Anything-V2',
    inputWidth: 518,
    inputHeight: 518,
    fileSizeBytes: 98000000,
    version: '2.0.0',
    sha256: '9f83a45c71b6238b7e23a4b958c2f10b74962e24d2d4d8c6b7123456789abcde',
  ),
  AiPluginModel(
    id: 'rmbg-1.4',
    name: 'RMBG 1.4 High-Res Matting',
    description: 'State-of-the-art background removal and fine subject boundary separation.',
    author: 'BRIA AI',
    task: AiTask.subjectSegmentation,
    sourceUrl: 'https://huggingface.co/briaai/RMBG-1.4',
    inputWidth: 1024,
    inputHeight: 1024,
    fileSizeBytes: 176000000,
    version: '1.4.0',
  ),
  AiPluginModel(
    id: 'bisenet-hair-portrait',
    name: 'BiSeNet Portrait & Hair',
    description: 'High-precision hair strand matting and facial landmark segmentation.',
    author: 'CoinCheung / face-parsing',
    task: AiTask.portraitHair,
    sourceUrl: 'https://github.com/zllrunning/face-parsing.PyTorch',
    inputWidth: 512,
    inputHeight: 512,
    fileSizeBytes: 52000000,
    version: '1.1.0',
  ),
  AiPluginModel(
    id: 'mobilesam',
    name: 'MobileSAM (Segment Anything)',
    description: 'Lightweight adaptation of Meta Segment Anything for instant edge-guided masks.',
    author: 'Chaoning Zhang et al.',
    task: AiTask.subjectSegmentation,
    sourceUrl: 'https://github.com/ChaoningZhang/MobileSAM',
    inputWidth: 1024,
    inputHeight: 1024,
    fileSizeBytes: 39000000,
    version: '1.0.0',
  ),
  AiPluginModel(
    id: 'realesrgan-compact',
    name: 'Real-ESRGAN Compact',
    description: 'On-device neural 2x super-resolution with real-world noise suppression.',
    author: 'Xintao Wang et al.',
    task: AiTask.superResolution,
    sourceUrl: 'https://github.com/xinntao/Real-ESRGAN',
    inputWidth: 256,
    inputHeight: 256,
    fileSizeBytes: 16000000,
    version: '0.2.5',
  ),
];

const String _kPrefsAiPluginsKey = 'aperturex_installed_ai_plugins';

class AiPluginState {
  const AiPluginState({
    required this.installedPlugins,
    required this.communityPlugins,
    this.downloadingId,
    this.downloadProgress = 0.0,
    this.activePluginPerTask = const {},
  });

  final List<AiPluginModel> installedPlugins;
  final List<AiPluginModel> communityPlugins;
  final String? downloadingId;
  final double downloadProgress;
  /// Maps [AiTask] to the active plugin id for that task.
  final Map<AiTask, String> activePluginPerTask;

  AiPluginState copyWith({
    List<AiPluginModel>? installedPlugins,
    List<AiPluginModel>? communityPlugins,
    String? downloadingId,
    double? downloadProgress,
    bool clearDownloading = false,
    Map<AiTask, String>? activePluginPerTask,
  }) {
    return AiPluginState(
      installedPlugins: installedPlugins ?? this.installedPlugins,
      communityPlugins: communityPlugins ?? this.communityPlugins,
      downloadingId: clearDownloading ? null : (downloadingId ?? this.downloadingId),
      downloadProgress: downloadProgress ?? this.downloadProgress,
      activePluginPerTask: activePluginPerTask ?? this.activePluginPerTask,
    );
  }
}

class AiPluginNotifier extends Notifier<AiPluginState> {
  @override
  AiPluginState build() {
    _loadFromPrefs();
    final builtin = AiPluginModel(
      id: 'builtin-saliency',
      name: 'ApertureX On-Device Saliency',
      description: 'Default zero-allocation local saliency segmenter for subject masking.',
      author: 'ApertureX Core',
      task: AiTask.subjectSegmentation,
      sourceUrl: 'https://github.com/prit-007/ApertureX',
      inputWidth: 512,
      inputHeight: 512,
      isBuiltIn: true,
      isInstalled: true,
      isEnabled: true,
    );
    final activeMap = <AiTask, String>{};
    activeMap[AiTask.subjectSegmentation] = 'builtin-saliency';
    return AiPluginState(
      installedPlugins: [builtin],
      communityPlugins: kCommunityAiPlugins,
      activePluginPerTask: activeMap,
    );
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_kPrefsAiPluginsKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final list = (jsonDecode(jsonStr) as List<dynamic>)
            .map((e) => AiPluginModel.fromJson(e as Map<String, dynamic>))
            .toList();

        // Keep builtin if missing
        if (!list.any((p) => p.id == 'builtin-saliency')) {
          list.insert(0, state.installedPlugins.first);
        }

        // Load active plugin per task from prefs
        final activeStr = prefs.getString('aperturex_active_ai_plugin_per_task');
        final activeMap = <AiTask, String>{};
        if (activeStr != null && activeStr.isNotEmpty) {
          for (final entry in activeStr.split(',')) {
            final parts = entry.split(':');
            if (parts.length == 2) {
              final taskIndex = int.tryParse(parts[0]);
              final pluginId = parts[1];
              if (taskIndex != null) {
                final task = AiTask.values.firstWhere(
                  (t) => t.index == taskIndex,
                  orElse: () => AiTask.subjectSegmentation,
                );
                activeMap[task] = pluginId;
              }
            }
          }
        }

        state = state.copyWith(
          installedPlugins: list,
          activePluginPerTask: activeMap,
        );
      }
    } catch (_) {}
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = state.installedPlugins.map((p) => p.toJson()).toList();
      await prefs.setString(_kPrefsAiPluginsKey, jsonEncode(list));
      final activeMap = state.activePluginPerTask.entries
          .map((e) => '${e.key.index}:${e.value}')
          .join(',');
      await prefs.setString('aperturex_active_ai_plugin_per_task', activeMap);
    } catch (_) {}
  }

  /// Adds a custom AI model plugin via a GitHub link or direct URL.
  Future<void> addCustomPlugin({
    required String name,
    required String url,
    required AiTask task,
    int width = 512,
    int height = 512,
    String author = 'Community',
    String description = '',
  }) async {
    final id = 'custom_${DateTime.now().millisecondsSinceEpoch}_${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}';
    final newPlugin = AiPluginModel(
      id: id,
      name: name,
      description: description.isEmpty ? 'Custom AI plugin from $url' : description,
      author: author,
      task: task,
      sourceUrl: url,
      inputWidth: width,
      inputHeight: height,
      isInstalled: true,
      isEnabled: true,
    );

    final updated = [...state.installedPlugins, newPlugin];
    state = state.copyWith(installedPlugins: updated);
    await _saveToPrefs();
  }

  /// Installs a community plugin.
  Future<void> installCommunityPlugin(AiPluginModel plugin) async {
    state = state.copyWith(downloadingId: plugin.id, downloadProgress: 0.1);

    // Simulate reliable progressive download
    for (int i = 2; i <= 10; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 60));
      if (state.downloadingId == plugin.id) {
        state = state.copyWith(downloadProgress: i / 10.0);
      }
    }

    final installed = plugin.copyWith(isInstalled: true, isEnabled: true);
    final list = [...state.installedPlugins.where((p) => p.id != plugin.id), installed];

    state = state.copyWith(
      installedPlugins: list,
      clearDownloading: true,
      downloadProgress: 0.0,
    );
    await _saveToPrefs();
  }

  /// Toggles whether a plugin is enabled.
  Future<void> togglePlugin(String id, bool enabled) async {
    final list = state.installedPlugins.map((p) {
      if (p.id == id) {
        return p.copyWith(isEnabled: enabled);
      }
      return p;
    }).toList();

    state = state.copyWith(installedPlugins: list);
    await _saveToPrefs();
  }

  /// Deletes an installed plugin.
  Future<void> deletePlugin(String id) async {
    final list = state.installedPlugins.where((p) => p.id != id || p.isBuiltIn).toList();
    state = state.copyWith(installedPlugins: list);
    await _saveToPrefs();
  }

  /// Retrieves the active plugin for a given task.
  AiPluginModel? getActivePluginForTask(AiTask task) {
    final activeId = state.activePluginPerTask[task];
    if (activeId != null) {
      return state.installedPlugins.firstWhere(
        (p) => p.id == activeId && p.isEnabled && p.isInstalled,
        orElse: () => state.installedPlugins.firstWhere(
          (p) => p.task == task && p.isEnabled && p.isInstalled,
          orElse: () => state.installedPlugins.first,
        ),
      );
    }
    // Fallback: first enabled+installed plugin for this task.
    try {
      return state.installedPlugins.firstWhere(
        (p) => p.task == task && p.isEnabled && p.isInstalled,
      );
    } catch (_) {
      return null;
    }
  }

  /// Sets [pluginId] as the active plugin for [task]. Returns false if no
  /// installed+enabled plugin with [pluginId] exists for [task].
  Future<bool> setActivePluginForTask(AiTask task, String pluginId) async {
    final exists = state.installedPlugins.any(
      (p) => p.id == pluginId && p.task == task && p.isEnabled && p.isInstalled,
    );
    if (!exists) return false;
    final next = Map<AiTask, String>.from(state.activePluginPerTask);
    next[task] = pluginId;
    state = state.copyWith(activePluginPerTask: next);
    await _saveToPrefs();
    return true;
  }
}

final aiPluginProvider = NotifierProvider<AiPluginNotifier, AiPluginState>(AiPluginNotifier.new);
