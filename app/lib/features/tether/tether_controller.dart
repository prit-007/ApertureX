import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tether_model.dart';

/// Combined state for tethered shooting session and live camera link.
class TetherState {
  const TetherState({
    this.connectionState = TetherConnectionState.connected,
    this.telemetry = const CameraTelemetry(),
    this.session = const TetherSession(),
    this.selectedCapture,
    this.isShutterTriggered = false,
    this.statusMessage,
  });

  final TetherConnectionState connectionState;
  final CameraTelemetry telemetry;
  final TetherSession session;
  final TetherCaptureItem? selectedCapture;
  final bool isShutterTriggered;
  final String? statusMessage;

  bool get isConnected => connectionState == TetherConnectionState.connected;

  TetherState copyWith({
    TetherConnectionState? connectionState,
    CameraTelemetry? telemetry,
    TetherSession? session,
    TetherCaptureItem? selectedCapture,
    bool clearSelectedCapture = false,
    bool? isShutterTriggered,
    String? statusMessage,
  }) {
    return TetherState(
      connectionState: connectionState ?? this.connectionState,
      telemetry: telemetry ?? this.telemetry,
      session: session ?? this.session,
      selectedCapture:
          clearSelectedCapture ? null : (selectedCapture ?? this.selectedCapture),
      isShutterTriggered: isShutterTriggered ?? this.isShutterTriggered,
      statusMessage: statusMessage ?? this.statusMessage,
    );
  }
}

/// Provider managing tethered shooting camera link and capture workflow.
final tetherProvider = NotifierProvider<TetherController, TetherState>(
  TetherController.new,
);

class TetherController extends Notifier<TetherState> {
  @override
  TetherState build() {
    return const TetherState();
  }

  void connect({String model = 'Sony α7R V'}) {
    state = state.copyWith(
      connectionState: TetherConnectionState.connecting,
      statusMessage: 'Negotiating PTP/IP session with $model…',
    );

    // Simulate instant connection negotiation
    state = state.copyWith(
      connectionState: TetherConnectionState.connected,
      telemetry: state.telemetry.copyWith(cameraModel: model),
      statusMessage: 'Connected to $model via USB 3.2 Gen 2',
    );
  }

  void disconnect() {
    state = state.copyWith(
      connectionState: TetherConnectionState.disconnected,
      statusMessage: 'Camera disconnected',
    );
  }

  Future<TetherCaptureItem?> triggerShutter({Uint8List? sampleImage}) async {
    if (!state.isConnected) return null;

    state = state.copyWith(
      connectionState: TetherConnectionState.capturing,
      isShutterTriggered: true,
      statusMessage: 'Exposing…',
    );

    // Simulate shutter exposure & high-speed PTP transfer
    await Future<void>.delayed(const Duration(milliseconds: 150));

    final filename = state.session.generateFilename();
    final capture = TetherCaptureItem(
      id: 'cap-${DateTime.now().millisecondsSinceEpoch}',
      filename: filename,
      path: '${state.session.destinationPath}/$filename',
      timestamp: DateTime.now(),
      sizeBytes: 64 * 1024 * 1024, // 64 MB uncompressed RAW
      thumbnailBytes: sampleImage,
      exifSummary: state.telemetry.exposureSummary,
    );

    final updatedFiles = [...state.session.capturedFiles, capture];
    final updatedSession = state.session.copyWith(
      capturedFiles: updatedFiles,
      sequenceNumber: state.session.sequenceNumber + 1,
    );

    final updatedTelemetry = state.telemetry.copyWith(
      shotsRemaining: (state.telemetry.shotsRemaining - 1).clamp(0, 99999),
    );

    state = state.copyWith(
      connectionState: TetherConnectionState.connected,
      isShutterTriggered: false,
      session: updatedSession,
      telemetry: updatedTelemetry,
      selectedCapture: state.session.autoSelectLatest ? capture : state.selectedCapture,
      statusMessage: 'Transferred $filename (64.0 MB)',
    );

    return capture;
  }

  void selectCapture(TetherCaptureItem item) {
    state = state.copyWith(selectedCapture: item);
  }

  void configureSession({
    String? sessionName,
    String? destinationPath,
    bool? autoApplyRecipe,
    bool? autoSelectLatest,
  }) {
    state = state.copyWith(
      session: state.session.copyWith(
        sessionName: sessionName,
        destinationPath: destinationPath,
        autoApplyRecipe: autoApplyRecipe,
        autoSelectLatest: autoSelectLatest,
      ),
    );
  }

  void updateTelemetry({
    String? shutterSpeed,
    String? aperture,
    int? iso,
    int? batteryPercent,
  }) {
    state = state.copyWith(
      telemetry: state.telemetry.copyWith(
        shutterSpeed: shutterSpeed,
        aperture: aperture,
        iso: iso,
        batteryPercent: batteryPercent,
      ),
    );
  }

  void clearSession() {
    state = state.copyWith(
      session: state.session.copyWith(
        capturedFiles: const [],
        sequenceNumber: 1,
      ),
      clearSelectedCapture: true,
      statusMessage: 'Session reset',
    );
  }
}
