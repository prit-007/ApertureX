import 'dart:typed_data';

/// Connection status of the studio tethered camera.
enum TetherConnectionState {
  disconnected('Disconnected'),
  connecting('Connecting…'),
  connected('Connected'),
  capturing('Capturing…'),
  error('Connection Error');

  const TetherConnectionState(this.label);
  final String label;
}

/// Live telemetry streamed from the connected digital camera (PTP/IP or USB).
class CameraTelemetry {
  const CameraTelemetry({
    this.cameraModel = 'Sony α7R V',
    this.batteryPercent = 94,
    this.shutterSpeed = '1/250s',
    this.aperture = 'f/2.8',
    this.iso = 100,
    this.shotsRemaining = 1840,
    this.isShootingRaw = true,
    this.lensModel = 'FE 50mm F1.2 GM',
    this.storageSlot = 'Slot 1 (CFexpress A)',
  });

  final String cameraModel;
  final int batteryPercent;
  final String shutterSpeed;
  final String aperture;
  final int iso;
  final int shotsRemaining;
  final bool isShootingRaw;
  final String lensModel;
  final String storageSlot;

  String get exposureSummary => '$shutterSpeed · $aperture · ISO $iso';

  CameraTelemetry copyWith({
    String? cameraModel,
    int? batteryPercent,
    String? shutterSpeed,
    String? aperture,
    int? iso,
    int? shotsRemaining,
    bool? isShootingRaw,
    String? lensModel,
    String? storageSlot,
  }) {
    return CameraTelemetry(
      cameraModel: cameraModel ?? this.cameraModel,
      batteryPercent: batteryPercent ?? this.batteryPercent,
      shutterSpeed: shutterSpeed ?? this.shutterSpeed,
      aperture: aperture ?? this.aperture,
      iso: iso ?? this.iso,
      shotsRemaining: shotsRemaining ?? this.shotsRemaining,
      isShootingRaw: isShootingRaw ?? this.isShootingRaw,
      lensModel: lensModel ?? this.lensModel,
      storageSlot: storageSlot ?? this.storageSlot,
    );
  }
}

/// A captured photo asset transferred through the tethered pipeline.
class TetherCaptureItem {
  const TetherCaptureItem({
    required this.id,
    required this.filename,
    required this.path,
    required this.timestamp,
    this.sizeBytes = 0,
    this.thumbnailBytes,
    this.exifSummary = '',
  });

  final String id;
  final String filename;
  final String path;
  final DateTime timestamp;
  final int sizeBytes;
  final Uint8List? thumbnailBytes;
  final String exifSummary;
}

/// Configuration for an ongoing studio tether session.
class TetherSession {
  const TetherSession({
    this.sessionName = 'Studio Shoot',
    this.destinationPath = '/storage/tether/session_01',
    this.namingPattern = '[Session]_[Seq4]',
    this.autoApplyRecipe = true,
    this.autoSelectLatest = true,
    this.capturedFiles = const [],
    this.sequenceNumber = 1,
  });

  final String sessionName;
  final String destinationPath;
  final String namingPattern;
  final bool autoApplyRecipe;
  final bool autoSelectLatest;
  final List<TetherCaptureItem> capturedFiles;
  final int sequenceNumber;

  int get totalCaptures => capturedFiles.length;

  String generateFilename() {
    final seq = sequenceNumber.toString().padLeft(4, '0');
    return '${sessionName.replaceAll(' ', '_')}_$seq.ARW';
  }

  TetherSession copyWith({
    String? sessionName,
    String? destinationPath,
    String? namingPattern,
    bool? autoApplyRecipe,
    bool? autoSelectLatest,
    List<TetherCaptureItem>? capturedFiles,
    int? sequenceNumber,
  }) {
    return TetherSession(
      sessionName: sessionName ?? this.sessionName,
      destinationPath: destinationPath ?? this.destinationPath,
      namingPattern: namingPattern ?? this.namingPattern,
      autoApplyRecipe: autoApplyRecipe ?? this.autoApplyRecipe,
      autoSelectLatest: autoSelectLatest ?? this.autoSelectLatest,
      capturedFiles: capturedFiles ?? this.capturedFiles,
      sequenceNumber: sequenceNumber ?? this.sequenceNumber,
    );
  }
}
