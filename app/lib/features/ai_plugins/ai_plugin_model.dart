/// AI Task types supported by ApertureX on-device neural plugins.
enum AiTask {
  /// Detects foreground subjects, persons, and main objects for selective masking.
  subjectSegmentation,

  /// Fine portrait hair boundary extraction and matting.
  portraitHair,

  /// Monocular relative depth estimation for realistic optical bokeh blur.
  depthEstimation,

  /// Sky region detection and semantic replacement mask.
  skySegmentation,

  /// On-device super-resolution and neural detail upscaling.
  superResolution,

  /// Neural color, film, or artistic style transfer.
  neuralFilter;

  String get label {
    switch (this) {
      case AiTask.subjectSegmentation:
        return 'Subject Masking';
      case AiTask.portraitHair:
        return 'Hair & Portrait Matting';
      case AiTask.depthEstimation:
        return 'Depth Map Estimation';
      case AiTask.skySegmentation:
        return 'Sky Segmentation';
      case AiTask.superResolution:
        return 'Super Resolution';
      case AiTask.neuralFilter:
        return 'Neural Style Filter';
    }
  }
}

/// Dynamic slider or toggle control declared in a plugin's `manifest.json`.
class AiPluginControl {
  const AiPluginControl({
    required this.id,
    required this.label,
    this.type = 'slider',
    this.min = 0.0,
    this.max = 100.0,
    this.defaultValue = 20.0,
    this.currentValue,
  });

  final String id;
  final String label;
  final String type;
  final double min;
  final double max;
  final double defaultValue;
  final double? currentValue;

  double get value => currentValue ?? defaultValue;

  AiPluginControl copyWith({double? currentValue}) {
    return AiPluginControl(
      id: id,
      label: label,
      type: type,
      min: min,
      max: max,
      defaultValue: defaultValue,
      currentValue: currentValue ?? this.currentValue,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'type': type,
        'min': min,
        'max': max,
        'default': defaultValue,
        if (currentValue != null) 'currentValue': currentValue,
      };

  factory AiPluginControl.fromJson(Map<String, dynamic> json) => AiPluginControl(
        id: json['id'] as String? ?? 'param',
        label: json['label'] as String? ?? 'Amount',
        type: json['type'] as String? ?? 'slider',
        min: (json['min'] as num?)?.toDouble() ?? 0.0,
        max: (json['max'] as num?)?.toDouble() ?? 100.0,
        defaultValue: (json['default'] as num?)?.toDouble() ?? 20.0,
        currentValue: (json['currentValue'] as num?)?.toDouble(),
      );
}

/// Declarative metadata and specification for an on-device AI model / plugin.
class AiPluginModel {
  const AiPluginModel({
    required this.id,
    required this.name,
    required this.description,
    required this.author,
    required this.task,
    required this.sourceUrl,
    this.modelFile,
    this.controls = const [],
    this.inputWidth = 512,
    this.inputHeight = 512,
    this.inputChannels = 3,
    this.outputChannels = 1,
    this.isBuiltIn = false,
    this.isEnabled = true,
    this.isInstalled = false,
    this.localPath,
    this.sha256,
    this.fileSizeBytes = 0,
    this.version = '1.0.0',
  });

  final String id;
  final String name;
  final String description;
  final String author;
  final AiTask task;
  final String sourceUrl;
  final String? modelFile;
  final List<AiPluginControl> controls;
  final int inputWidth;
  final int inputHeight;
  final int inputChannels;
  final int outputChannels;
  final bool isBuiltIn;
  final bool isEnabled;
  final bool isInstalled;
  final String? localPath;
  final String? sha256;
  final int fileSizeBytes;
  final String version;

  AiPluginModel copyWith({
    String? id,
    String? name,
    String? description,
    String? author,
    AiTask? task,
    String? sourceUrl,
    String? modelFile,
    List<AiPluginControl>? controls,
    int? inputWidth,
    int? inputHeight,
    int? inputChannels,
    int? outputChannels,
    bool? isBuiltIn,
    bool? isEnabled,
    bool? isInstalled,
    String? localPath,
    String? sha256,
    int? fileSizeBytes,
    String? version,
  }) {
    return AiPluginModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      author: author ?? this.author,
      task: task ?? this.task,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      modelFile: modelFile ?? this.modelFile,
      controls: controls ?? this.controls,
      inputWidth: inputWidth ?? this.inputWidth,
      inputHeight: inputHeight ?? this.inputHeight,
      inputChannels: inputChannels ?? this.inputChannels,
      outputChannels: outputChannels ?? this.outputChannels,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      isEnabled: isEnabled ?? this.isEnabled,
      isInstalled: isInstalled ?? this.isInstalled,
      localPath: localPath ?? this.localPath,
      sha256: sha256 ?? this.sha256,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      version: version ?? this.version,
    );
  }

  Map<String, dynamic> toJson() => {
        'plugin_id': id,
        'name': name,
        'description': description,
        'author': author,
        'task': task.name,
        'sourceUrl': sourceUrl,
        if (modelFile != null) 'model_file': modelFile,
        'controls': controls.map((c) => c.toJson()).toList(),
        'input_shape': [1, inputChannels, inputHeight, inputWidth],
        'isBuiltIn': isBuiltIn,
        'isEnabled': isEnabled,
        'isInstalled': isInstalled,
        'localPath': localPath,
        'sha256': sha256,
        'fileSizeBytes': fileSizeBytes,
        'version': version,
      };

  factory AiPluginModel.fromJson(Map<String, dynamic> json) {
    final idVal = (json['plugin_id'] ?? json['id'] ?? '') as String;
    final shape = json['input_shape'] as List<dynamic>?;
    final width = shape != null && shape.length >= 4
        ? (shape[3] as num).toInt()
        : ((json['inputWidth'] as num?)?.toInt() ?? 512);
    final height = shape != null && shape.length >= 4
        ? (shape[2] as num).toInt()
        : ((json['inputHeight'] as num?)?.toInt() ?? 512);
    final channels = shape != null && shape.length >= 2
        ? (shape[1] as num).toInt()
        : ((json['inputChannels'] as num?)?.toInt() ?? 3);

    final controlsJson = json['controls'] as List<dynamic>?;
    final controlsList = controlsJson != null
        ? controlsJson.map((c) => AiPluginControl.fromJson(c as Map<String, dynamic>)).toList()
        : const <AiPluginControl>[];

    return AiPluginModel(
      id: idVal,
      name: json['name'] as String? ?? 'Custom AI Plugin',
      description: json['description'] as String? ?? '',
      author: json['author'] as String? ?? 'Community',
      task: AiTask.values.firstWhere(
        (t) => t.name == (json['task'] ?? json['type']),
        orElse: () => AiTask.subjectSegmentation,
      ),
      sourceUrl: json['sourceUrl'] as String? ?? '',
      modelFile: json['model_file'] as String?,
      controls: controlsList,
      inputWidth: width,
      inputHeight: height,
      inputChannels: channels,
      outputChannels: (json['outputChannels'] as num?)?.toInt() ?? 1,
      isBuiltIn: json['isBuiltIn'] as bool? ?? false,
      isEnabled: json['isEnabled'] as bool? ?? true,
      isInstalled: json['isInstalled'] as bool? ?? false,
      localPath: json['localPath'] as String?,
      sha256: json['sha256'] as String?,
      fileSizeBytes: (json['fileSizeBytes'] as num?)?.toInt() ?? 0,
      version: json['version'] as String? ?? '1.0.0',
    );
  }

  String get tensorShapeLabel => '$inputWidth×$inputHeight×$inputChannels';
}
