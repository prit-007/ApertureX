import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds the active image bytes for the current editing session.
final activeImageBytesProvider = NotifierProvider<ActiveImageBytesNotifier, Uint8List?>(
  ActiveImageBytesNotifier.new,
);

class ActiveImageBytesNotifier extends Notifier<Uint8List?> {
  @override
  Uint8List? build() => null;

  void setBytes(Uint8List? bytes) => state = bytes;
}
