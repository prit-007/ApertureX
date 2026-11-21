import 'dart:async';
import 'package:flutter/services.dart';

import '../core/log/activity_log.dart';
import '../core/log/log_providers.dart';

/// Handles incoming Android/iOS system intents (`ACTION_VIEW`, `ACTION_EDIT`, `ACTION_SEND`).
class IntentHandler {
  IntentHandler({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('aperturex/incoming_intent');

  final MethodChannel _channel;
  final _imageStreamController = StreamController<Uint8List>.broadcast();

  Stream<Uint8List> get onImageReceived => _imageStreamController.stream;

  /// Sets up method call listener and checks for any cold-start initial image.
  Future<Uint8List?> init() async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onImageReceived') {
        final bytes = call.arguments;
        if (bytes is Uint8List && bytes.isNotEmpty) {
          _imageStreamController.add(bytes);
        }
      }
    });

    try {
      final initial = await _channel.invokeMethod<Uint8List>('getInitialImage');
      if (initial != null && initial.isNotEmpty) {
        return initial;
      }
    } on MissingPluginException {
      // Running on platform or test where channel is not registered.
    } catch (e) {
      axLog(LogDomain.native, 'Failed to fetch initial intent image: $e', level: LogLevel.warning);
    }
    return null;
  }

  void dispose() {
    _imageStreamController.close();
  }
}
