import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences key for on-device AI user data consent.
const String kAiConsentPrefKey = 'ai_processing_consent';

/// Status of user consent for local on-device AI processing.
enum AiConsentStatus {
  /// The user has explicitly granted consent for local AI inference.
  granted,

  /// The user has declined consent for local AI inference.
  declined,

  /// The user has not yet been prompted for consent.
  unprompted,
}

/// Manages and persists user consent for local, on-device AI operations.
///
/// Complies with F-Droid inclusion policies and privacy standards:
/// All inference is 100% on-device, offline, with zero data transmission.
class AiConsentNotifier extends Notifier<AiConsentStatus> {
  bool _userSet = false;

  @override
  AiConsentStatus build() {
    _restore();
    return AiConsentStatus.unprompted;
  }

  /// Whether the user has actively consented to on-device AI processing.
  bool get hasConsent => state == AiConsentStatus.granted;

  /// Grants consent and persists the preference.
  Future<void> grantConsent() async {
    _userSet = true;
    state = AiConsentStatus.granted;
    await _persist(true);
  }

  /// Revokes consent and persists the preference.
  Future<void> revokeConsent() async {
    _userSet = true;
    state = AiConsentStatus.declined;
    await _persist(false);
  }

  /// Resets consent state to unprompted.
  Future<void> resetConsent() async {
    _userSet = true;
    state = AiConsentStatus.unprompted;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(kAiConsentPrefKey);
    } catch (_) {}
  }

  /// Prompts the user with an explicit privacy and consent dialog if unprompted.
  ///
  /// Returns `true` if consent is granted, `false` otherwise.
  Future<bool> requestConsentDialog(BuildContext context) async {
    if (state == AiConsentStatus.granted) return true;
    if (state == AiConsentStatus.declined) return false;

    if (!context.mounted) return false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('On-Device AI Masking'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ApertureX uses local machine learning models for one-tap Select Subject and Select Sky.\n',
              style: TextStyle(fontSize: 14),
            ),
            Text('• 100% On-Device: Models run purely on your hardware.'),
            SizedBox(height: 4),
            Text('• Zero Network: No photos or personal data ever leave your device.'),
            SizedBox(height: 4),
            Text('• F-Droid Clean: Zero remote telemetry or tracking.'),
            SizedBox(height: 12),
            Text(
              'Do you consent to enabling on-device AI processing?',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Decline'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Consent'),
          ),
        ],
      ),
    );

    if (result == true) {
      await grantConsent();
      return true;
    } else {
      await revokeConsent();
      return false;
    }
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_userSet) return;
      if (!prefs.containsKey(kAiConsentPrefKey)) {
        state = AiConsentStatus.unprompted;
        return;
      }
      final granted = prefs.getBool(kAiConsentPrefKey);
      if (granted == true) {
        state = AiConsentStatus.granted;
      } else if (granted == false) {
        state = AiConsentStatus.declined;
      }
    } catch (_) {
      // Storage unavailable in tests
    }
  }

  Future<void> _persist(bool granted) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kAiConsentPrefKey, granted);
    } catch (_) {}
  }
}

/// Provider for user data consent state for on-device AI features.
final aiConsentProvider =
    NotifierProvider<AiConsentNotifier, AiConsentStatus>(AiConsentNotifier.new);
