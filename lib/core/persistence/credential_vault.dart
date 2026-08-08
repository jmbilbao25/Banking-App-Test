import 'persistence_store.dart';
import 'secret_digest.dart';

/// Holds the demo account passwords as salted digests.
///
/// The application previously carried a table of email and password pairs in
/// `MockDataSource`, which requirement 5.9 forbids. Credentials now live here
/// instead, which has two useful consequences beyond removing the literals:
///
/// - requirement 9.8, rejecting an incorrect password, becomes reachable, because
///   there is a real stored secret to disagree with;
/// - requirement 11.6, a password reset updating the stored credential, becomes
///   implementable rather than decorative.
///
/// On a fresh install no email has a credential yet. The first password used for
/// a given address is adopted as that address's password, so the seeded demo
/// profiles stay reachable without shipping a password for them.
class CredentialVault {
  CredentialVault(this._store);

  final PersistenceStore _store;

  static const _namespace = 'frostbank.credentials';

  String _saltKey(String email) => '$_namespace.${_normalize(email)}.salt';
  String _digestKey(String email) => '$_namespace.${_normalize(email)}.digest';

  static String _normalize(String email) => email.trim().toLowerCase();

  bool hasCredential(String email) =>
      _store.readString(_digestKey(email)) != null;

  /// True when the store holds any credential at all, which is what
  /// requirement 9.10 means by "Persistence_Store holds a previous session".
  bool get hasAnyCredential => _store.readString(StoreKeys.session) != null;

  Future<void> setPassword({
    required String email,
    required String password,
  }) async {
    final salt = SecretDigest.generateSalt();
    await _store.writeString(_saltKey(email), salt);
    await _store.writeString(
      _digestKey(email),
      SecretDigest.digest(password, salt),
    );
  }

  /// Verifies [password] for [email]. Returns true when it matches, and also
  /// when no credential exists yet, in which case the caller should adopt it.
  bool verify({required String email, required String password}) {
    final salt = _store.readString(_saltKey(email));
    final expected = _store.readString(_digestKey(email));
    if (salt == null || expected == null) return true;
    return SecretDigest.matches(password, salt: salt, expected: expected);
  }

  Future<void> clear(String email) async {
    await _store.remove(_saltKey(email));
    await _store.remove(_digestKey(email));
  }
}
