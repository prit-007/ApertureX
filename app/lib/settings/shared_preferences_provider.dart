import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide access to pre-warmed [SharedPreferences].
///
/// Overridden in `main.dart` with the already-resolved instance so that settings
/// notifiers can synchronously read initial state on their first frame without
/// flash-of-default (ADR 0011).
final sharedPreferencesProvider = Provider<SharedPreferences?>((ref) => null);
