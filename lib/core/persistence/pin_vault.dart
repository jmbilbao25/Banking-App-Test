import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'persistence_store.dart';

/// Stores and checks the App_Lock PIN.
///
/// The PIN is never written in the clear. A per install salt is generated once
/// and only the digest of salt plus PIN is stored, so reading the device store
/// does not reveal the PIN. Requirement 5.9 also forbids a credential value in
/// the source, which rules out the previous `'123456'` default and the literal
/// comparison that accepted it on every screen.
class PinVault {
  PinVault(this._store);

  final PersistenceStore _store;

  /// Requirement 5.2: five consecutive incorrect entries clear the session.
  static const maxAttempts = 5;

  /// The PIN length used by App_Lock, referenced everywhere instead of a literal.
  static const pinLength = 6;

  /// Null when [pin] is a valid six digit PIN, otherwise the reason.
  static String? formatError(String pin) {
    if (pin.length != pinLength) {
      return 'Your PIN must be $pinLength digits.';
    }
    if (!RegExp(r'^\d+$').hasMatch(pin)) {
      return 'Your PIN can only contain digits.';
    }
    return null;
  }

  bool get hasPin => _store.readString(StoreKeys.pinDigest) != null;

  int get failedAttempts => _store.readInt(StoreKeys.pinAttempts) ?? 0;

  int get attemptsRemaining => max(0, maxAttempts - failedAttempts);

  /// True once the attempt budget is spent, so the caller clears the session.
  bool get isLockedOut => failedAttempts >= maxAttempts;

  Future<void> setPin(String pin) async {
    final salt = _generateSalt();
    await _store.writeString(StoreKeys.pinSalt, salt);
    await _store.writeString(StoreKeys.pinDigest, _digest(pin, salt));
    await clearFailures();
  }

  /// Constant shape comparison against the stored digest. Returns false when no
  /// PIN has been set, so an empty vault can never be unlocked by guessing.
  bool verify(String pin) {
    final salt = _store.readString(StoreKeys.pinSalt);
    final digest = _store.readString(StoreKeys.pinDigest);
    if (salt == null || digest == null) return false;
    return _constantTimeEquals(_digest(pin, salt), digest);
  }

  Future<void> recordFailure() =>
      _store.writeInt(StoreKeys.pinAttempts, failedAttempts + 1);

  Future<void> clearFailures() => _store.remove(StoreKeys.pinAttempts);

  /// Requirement 5.10: logout clears the PIN as well as the session.
  Future<void> clear() => _store.removeNamespace(StoreKeys.securityNamespace);

  static String _digest(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();

  static String _generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  /// Compares without an early return on the first differing character, so the
  /// duration of a check does not leak how much of the digest matched.
  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var mismatch = 0;
    for (var i = 0; i < a.length; i++) {
      mismatch |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return mismatch == 0;
  }
}
