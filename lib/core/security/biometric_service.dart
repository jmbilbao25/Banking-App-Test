import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Outcome of a biometric confirmation attempt.
enum BiometricResult {
  /// The device confirmed the customer.
  success,

  /// The customer dismissed the prompt, so PIN entry should take over.
  cancelled,

  /// No biometric is enrolled, or the hardware refused. PIN entry takes over.
  unavailable,
}

/// Wraps the platform biometric prompt.
///
/// Requirement 5.3 makes biometric confirmation the primary unlock method where
/// the device reports an enrolled biometric, with PIN entry as the fallback, and
/// requirement 23.7 needs the enrolment state so the profile toggle can explain
/// itself when nothing is enrolled. Both read through this interface, so widget
/// tests can supply an implementation instead of a platform channel.
abstract interface class BiometricService {
  /// True when the device has hardware and at least one enrolled biometric.
  Future<bool> isEnrolled();

  Future<BiometricResult> authenticate({required String reason});
}

class LocalAuthBiometricService implements BiometricService {
  LocalAuthBiometricService([LocalAuthentication? auth])
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> isEnrolled() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      if (!await _auth.canCheckBiometrics) return false;
      final enrolled = await _auth.getAvailableBiometrics();
      return enrolled.isNotEmpty;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<BiometricResult> authenticate({required String reason}) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          // The lock has to survive the customer switching apps mid prompt,
          // otherwise a backgrounded prompt would silently drop the unlock.
          stickyAuth: true,
        ),
      );
      return ok ? BiometricResult.success : BiometricResult.cancelled;
    } on PlatformException {
      return BiometricResult.unavailable;
    } on MissingPluginException {
      return BiometricResult.unavailable;
    }
  }
}

/// Used by tests and by any build without the platform channel.
class UnavailableBiometricService implements BiometricService {
  const UnavailableBiometricService();

  @override
  Future<bool> isEnrolled() async => false;

  @override
  Future<BiometricResult> authenticate({required String reason}) async =>
      BiometricResult.unavailable;
}
