import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Salted digest helpers shared by every stored secret.
///
/// Requirement 5.9 forbids credential values in the source, and a value written
/// to the device store in the clear would be the same problem one layer down.
/// Both the App_Lock PIN and the demo account passwords are therefore held as a
/// salt plus a digest, never as the secret itself.
abstract final class SecretDigest {
  static String generateSalt([Random? random]) {
    final source = random ?? Random.secure();
    final bytes = List<int>.generate(16, (_) => source.nextInt(256));
    return base64Url.encode(bytes);
  }

  static String digest(String secret, String salt) =>
      sha256.convert(utf8.encode('$salt:$secret')).toString();

  /// Compares without an early return on the first differing character, so the
  /// duration of a check does not leak how much of the digest matched.
  static bool matches(String secret, {required String salt, required String expected}) {
    final actual = digest(secret, salt);
    if (actual.length != expected.length) return false;
    var mismatch = 0;
    for (var i = 0; i < actual.length; i++) {
      mismatch |= actual.codeUnitAt(i) ^ expected.codeUnitAt(i);
    }
    return mismatch == 0;
  }
}
